//
//  THMeshBuckets.m
//  telehash
//
//  Created by Thomas Muldowney on 1/7/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THMeshBuckets.h"
#import "THLink.h"
#import "E3XExchange.h"
#import "THPacket.h"
#import "RNG.h"
#import "NSData+HexString.h"
#import "THMesh.h"
#import "THPendingJob.h"
#import "E3XChannel.h"
#import "THPath.h"
#import "THRelay.h"
#import "E3XUnreliableChannel.h"
#import "CLCLog.h"

#define K_BUCKET_SIZE 8
#define MAX_LINKS 256
#define MAX_POTENTIAL_BRIDGES 5

@interface PendingSeekJob : NSObject<THChannelDelegate>
@property THLink* localIdentity;
@property THLink* seekingIdentity;
@property THMesh* localSwitch;
@property NSMutableArray* nearby;
@property NSUInteger runningSearches;
@property (nonatomic, copy) SeekCompletionBlock completion;

-(void)runSeek;
-(BOOL)channel:(E3XChannel *)channel handlePacket:(THPacket *)packet;
@end

@implementation THMeshBuckets
{
    BOOL pendingPings;
    NSUInteger linkTotal;
	NSTimer* pingTimer;
}

-(id)init
{
    self = [super init];
    if (self) {
        self.buckets = [NSMutableArray arrayWithCapacity:256];
        for (int i = 0; i < 256; ++i) {
            [self.buckets insertObject:[NSMutableArray array] atIndex:i];
        }
		pingTimer = [NSTimer scheduledTimerWithTimeInterval:25 target:self selector:@selector(pingLines) userInfo:nil repeats:YES];
    }
    return self;
}

-(void)pingLines
{
    time_t checkTime = time(NULL);
	
    [self.buckets enumerateObjectsUsingBlock:^(id obj, NSUInteger bucketIdx, BOOL *stop) {
        NSMutableArray* bucket = (NSMutableArray*)obj;
		
        [bucket enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            THLink* identity = (THLink*)obj;
			E3XChannel* linkChannel = [identity channelForType:@"link"];
			
			if (linkChannel) {
				// if our lastInActivity > 50s and the channel is >5s old
				if ((checkTime >= linkChannel.lastInActivity + 50) && (checkTime > linkChannel.createdAt + 25)) {
					NSUInteger lastInDuration = checkTime - linkChannel.lastInActivity;
					CLCLogWarning(@"line inactive for %@ (in duration %d), removing link channel", identity.hashname, lastInDuration);
					
					[bucket removeObjectAtIndex:idx];
					E3XChannel* channel = [identity channelForType:@"link"];
					if (channel) {
						[identity.channels removeObjectForKey:channel.channelId];
					}
										
					// TODO: this should be moved to line activity check
					[identity reset];
					return;
				}
				
				if (identity.activePath || identity.relay.peerChannel) {
					THPacket* pingPacket = [THPacket new];
					[pingPacket.json setObject:@YES forKey:@"seed"];
					
					[linkChannel sendPacket:pingPacket];
				} else {
					CLCLogWarning(@"no path or relay available for pingLines to %@, attempting a re-open", identity.hashname);
					[identity.currentLine sendOpen];
				}
			} else {
				CLCLogDebug(@"link channel missing for %@ within pingLines, resetting identity", identity.hashname);
				[identity reset];
			}
        }];
    }];
}

-(void)linkToIdentity:(THLink*)identity
{
    [self addIdentity:identity];
	
    THPacket* linkPacket = [THPacket new];
    [linkPacket.json setObject:@YES forKey:@"seed"]; // TODO:  Allow for opting out of seeding?
    
	NSArray* seeIdentities = [self nearby:identity];
    NSMutableArray* sees = [NSMutableArray array];
	
	if (seeIdentities != nil) {
		for (THLink* seeIdentity in seeIdentities) {
			NSString* seekString = [seeIdentity seekStringForIdentity:identity];
			if (seekString) {
				[sees addObject:seekString];
			}
		}
	}
	
    [linkPacket.json setObject:sees forKey:@"see"];
    
	E3XChannel* linkChannel = [identity channelForType:@"link"];
    if (!linkChannel) {
        linkChannel = [[E3XUnreliableChannel alloc] initToIdentity:identity];
        [linkPacket.json setObject:@"link" forKey:@"type"];
		
        [[THMesh defaultSwitch] openChannel:linkChannel firstPacket:linkPacket];
    } else {
        [linkChannel sendPacket:linkPacket];
    }
	
    linkChannel.delegate = self;
}

-(void)addIdentity:(THLink *)identity
{
    NSInteger bucketIndex = [self.localIdentity distanceFrom:identity];
    NSMutableArray* bucket = [self.buckets objectAtIndex:bucketIndex];
    if (bucket == nil) {
        bucket = [NSMutableArray array];
    }
	
	E3XChannel* linkChannel = [identity channelForType:@"link"];
	
    // TODO:  Check our hints for age on this entry, if it's older we should bump the newest from the bucket if it's full
    if (linkTotal >= MAX_LINKS && bucket.count >= K_BUCKET_SIZE) {
        // TODO:  Evict the oldest
        
        if (linkChannel) {
            // TODO:  If we can not evict, we bail on it
            THPacket* endLinkPacket = [THPacket new];
            [endLinkPacket.json setObject:@YES forKey:@"end"];
            [endLinkPacket.json setObject:@NO forKey:@"seed"];
            [linkChannel sendPacket:endLinkPacket];
        }
        
        // TODO:  Check the cleanup on the channel and up the chain?
        return;
    }

    for (NSUInteger i = 0; i < bucket.count; ++i) {
        THLink* curIdentity = (THLink*)[bucket objectAtIndex:i];
        if ([curIdentity.hashname isEqualToString:identity.hashname]) {
            return;
        }
    }
    
    [bucket addObject:identity];
}

-(void)removeLine:(E3XExchange *)line
{
	if (!line) return;
    NSInteger bucketIndex = [self.localIdentity distanceFrom:line.toIdentity];
    [[self.buckets objectAtIndex:bucketIndex] removeObject:line];
}

-(NSArray*)closeInBucket:(THLink*)seekIdentity
{
    NSInteger bucketIndex = [self.localIdentity distanceFrom:seekIdentity];
    NSArray* bucket = [self.buckets objectAtIndex:bucketIndex];
    NSArray* results = [bucket sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSInteger hash1 = [seekIdentity distanceFrom:obj1];
        NSInteger hash2 = [seekIdentity distanceFrom:obj2];
        
        if (hash1 < hash2) {
            return NSOrderedDescending;
        } else if (hash2 > hash1) {
            return NSOrderedAscending;
        }
        
        return NSOrderedSame;
    }];
    return [results subarrayWithRange:NSMakeRange(0, MIN(5, results.count))];
}

-(NSArray*)nearby:(THLink*)seekIdentity;
{
    NSMutableArray* entries = [NSMutableArray array];
    NSInteger initialBucketIndex = [self.localIdentity distanceFrom:seekIdentity];
    // First get the closest
    [entries addObjectsFromArray:[self closeInBucket:seekIdentity]];
    // Go downwards for better matches
    NSInteger curBucketIndex = initialBucketIndex - 1;
    while (curBucketIndex >= 0 && [entries count] < 5) {
        NSArray* curBucket = [self.buckets objectAtIndex:curBucketIndex];
        if (curBucket.count == 0) {
            --curBucketIndex;
            continue;
        }
        [entries addObjectsFromArray:[curBucket subarrayWithRange:NSMakeRange(0, MIN(5 - entries.count, curBucket.count))]];
        --curBucketIndex;
    }
    // Now just make sure we're full with general entries
    curBucketIndex = initialBucketIndex + 1;
    while (curBucketIndex < 256) {
        NSArray* curBucket = [self.buckets objectAtIndex:curBucketIndex];
        if (curBucket.count == 0) {
            ++curBucketIndex;
            continue;
        }
        [entries addObjectsFromArray:[curBucket subarrayWithRange:NSMakeRange(0, MIN(5 - entries.count, curBucket.count))]];
        ++curBucketIndex;
    }
    return entries;
}

-(void)seek:(THLink*)toIdentity completion:(SeekCompletionBlock)completion
{
    CLCLogDebug(@"Seeking for %@", toIdentity.hashname);
    
    PendingSeekJob* seekJob = [PendingSeekJob new];
    seekJob.localSwitch = self.localSwitch;
    seekJob.localIdentity = self.localIdentity;
    seekJob.seekingIdentity = toIdentity;
    seekJob.completion = completion;
    
	// NOTE shortterm hack to only query against seeds
	NSPredicate* activeFilter = [NSPredicate predicateWithFormat:@"NOT (SELF.hashname MATCHES %@) AND SELF.isBridged == NO AND SELF.hasLink == YES", toIdentity.hashname];
	NSArray* nearby = [[self nearby:toIdentity] filteredArrayUsingPredicate:activeFilter];
	
	CLCLogDebug(@"seek for %@ has %d nearby peers", toIdentity.hashname, nearby.count);
	
    seekJob.nearby = [NSMutableArray arrayWithArray:[nearby subarrayWithRange:NSMakeRange(0, MIN(3, nearby.count))]];
    [self.pendingSeeks setValue:seekJob forKey:toIdentity.hashname];
    
    [seekJob.nearby enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [seekJob runSeek];
    }];
    
}

// Channel delegate methods

-(BOOL)channel:(E3XChannel *)channel handlePacket:(THPacket *)packet
{
    THMesh* defaultSwitch = [THMesh defaultSwitch];
    if (defaultSwitch.status != THSwitchOnline) {
        [defaultSwitch updateStatus:THSwitchOnline];
    }
    
    NSArray* bridges = [packet.json objectForKey:@"bridge"];
    if (bridges) {
        channel.toIdentity.availableBridges = bridges;
        [self.localSwitch.potentialBridges addObject:bridges];
        // Let's just maintain 5 potent
        if (self.localSwitch.potentialBridges.count > MAX_POTENTIAL_BRIDGES) {
            [self.localSwitch.potentialBridges removeObjectAtIndex:0];
        }
    }
	
    THIPv4Transport* transport = [self.localSwitch.transports objectForKey:@"ipv4"];
    for (NSString* seeLine in [packet.json objectForKey:@"see"]) {
        NSArray* seeParts = [seeLine componentsSeparatedByString:@","];
        if (seeParts.count < 2) continue; // Minimum of hash,cs
        
        if ([[seeParts objectAtIndex:0] isEqualToString:self.localIdentity.hashname]) continue;
        THLink* seeIdentity = [THLink identityFromHashname:[seeParts objectAtIndex:0]];
        NSInteger bucketIndex = [self.localIdentity distanceFrom:seeIdentity];
        NSMutableArray* bucket = [self.buckets objectAtIndex:bucketIndex];
        if (bucket == nil) {
            bucket = [NSMutableArray array];
        }
        
        // If we have a link channel already, just skip it
        E3XChannel* linkChannel = [seeIdentity channelForType:@"link"];
        if (seeIdentity.activePath || linkChannel) continue;
        
        seeIdentity.suggestedCipherSet = [seeParts objectAtIndex:1];
        
        // TODO:  Check our hints for age on this entry, if it's older we should bump the newest from the bucket if it's full
        if (linkTotal >= MAX_LINKS || bucket.count >= K_BUCKET_SIZE) {
            break;
        }

        [seeIdentity addVia:channel.toIdentity];
        if (seeParts.count == 4) {
            [seeIdentity addPath:[[THIPV4Path alloc] initWithTransport:transport ip:[seeParts objectAtIndex:2] port:[[seeParts objectAtIndex:3] integerValue]]];
		}
		
		// Temas review, this is where our infinite loop happens with hashname lookups
		[self.localSwitch openLine:seeIdentity];
    }
    
	// lets not participate in the DHT anymore
	
    NSUInteger now = time(NULL);
    if (channel.lastOutActivity + 10 < now) {
        THPacket* pingPacket = [THPacket new];
        [pingPacket.json setObject:@YES forKey:@"seed"];
        if (channel.lastOutActivity == 0) {
            // Add the sees, it's our initial response
			NSArray* seeIdentities = [self nearby:channel.toIdentity];
			NSMutableArray* sees = [NSMutableArray array];
			
			if (seeIdentities != nil) {
				for (THLink* seeIdentity in seeIdentities) {
					NSString* seekString = [seeIdentity seekStringForIdentity:channel.toIdentity];
					if (seekString) {
						[sees addObject:seekString];
					}
				}
			}
			
            [pingPacket.json setObject:sees forKey:@"see"];
        }
        [channel sendPacket:pingPacket];
    }
    
    return YES;
}

-(void)channel:(E3XChannel *)channel didChangeStateTo:(THChannelState)channelState
{
    if (channelState == THChannelEnded || channelState == THChannelErrored) {
		CLCLogWarning(@"link channel ended");
        NSMutableArray* bucket = [self.buckets objectAtIndex:[self.localIdentity distanceFrom:channel.toIdentity]];
        [bucket removeObject:channel];
    }
}

-(void)channel:(E3XChannel *)channel didFailWithError:(NSError *)error
{
	CLCLogWarning(@"link channel errored with error: %@", [error description]);
    NSMutableArray* bucket = [self.buckets objectAtIndex:[self.localIdentity distanceFrom:channel.toIdentity]];
    [bucket removeObject:channel];
}
@end


@implementation PendingSeekJob
-(void)runSeek
{
    if (self.nearby.count == 0) return;
    
    // Resort and run the seek
    THLink* identity = [self.nearby objectAtIndex:0];
    [self.nearby removeObjectAtIndex:0];
    
    THMesh* defaultSwitch = [THMesh defaultSwitch];
    ++self.runningSearches;
    
	if (!identity.activePath) return;
	
    E3XChannel* seekChannel = [[E3XUnreliableChannel alloc] initToIdentity:identity];
    seekChannel.delegate = self;
    
    THPacket* seekPacket = [THPacket new];
    [seekPacket.json setObject:self.seekingIdentity.hashname forKey:@"seek"];
    [seekPacket.json setObject:@"seek" forKey:@"type"];
    
    [defaultSwitch openChannel:seekChannel firstPacket:seekPacket];
}

 -(BOOL)channel:(E3XChannel*)channel handlePacket:(THPacket*)packet
{
     
    NSString* error = [packet.json objectForKey:@"err"];
    if (error) return YES;
	
    NSArray* sees = [packet.json objectForKey:@"see"];

    __block BOOL foundIt = NO;
    CLCLogDebug(@"Checking for %@ in sees %@",  self.seekingIdentity.hashname, sees);
    [sees enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString* seeString = (NSString*)obj;
        NSArray* seeParts = [seeString componentsSeparatedByString:@","];
        if (seeParts.count < 2) {
            CLCLogDebug(@"Invalid see parts: %@", seeParts);
            return;
        }
        if ([[seeParts objectAtIndex:0] isEqualToString:self.seekingIdentity.hashname]) {
			CLCLogDebug(@"We found %@!", self.seekingIdentity.hashname);
			// this is it!
			[self.seekingIdentity addVia:channel.toIdentity];
			self.seekingIdentity.suggestedCipherSet = [seeParts objectAtIndex:1];
			
			if (seeParts.count > 2) {
				THIPv4Transport* localTransport = [self.localSwitch.transports objectForKey:@"ipv4"];
				if (localTransport) {
					NSData* remoteAddress = [THIPV4Path addressTo:[seeParts objectAtIndex:2] port:[[seeParts objectAtIndex:3] integerValue]];
					[self.seekingIdentity addPath:[localTransport returnPathTo:remoteAddress]];
				}
			}
			foundIt = YES;
			*stop = YES;
			return;
			
        } else {
            // If they told us to ask ourself ignore it
            if ([[seeParts objectAtIndex:0] isEqualToString:self.localIdentity.hashname]) return;
			
            // If we're moving closer we want to go ahead and start a seek to it
            THLink* nearIdentity = [THLink identityFromHashname:[seeParts objectAtIndex:0]];
            [nearIdentity addVia:channel.toIdentity];
			nearIdentity.suggestedCipherSet = [seeParts objectAtIndex:1];
            [self.nearby addObject:nearIdentity];
        }
    }];
    
    if (foundIt) {
        if (self.completion) self.completion(YES);
        return YES;
    }
     
    // Sort on distance and run again
    [self.nearby sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSInteger hash1 = [self.seekingIdentity distanceFrom:obj1];
        NSInteger hash2 = [self.seekingIdentity distanceFrom:obj2];
         
        if (hash1 < hash2) {
            return NSOrderedDescending;
        } else if (hash2 > hash1) {
            return NSOrderedAscending;
        }
         
        return NSOrderedSame;
    }];
    
    if (self.nearby.count > 0) {
        [self runSeek];
        for (NSUInteger i = self.runningSearches; i < MIN(3, self.nearby.count - 1); ++i) {
            [self runSeek];
        }
    }
     
    return YES;
}

@end
