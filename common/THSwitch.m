//
//  THSwitch.m
//  telehash
//
//  Created by Thomas Muldowney on 10/3/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THSwitch.h"
#import "THPacket.h"
#import "THIdentity.h"
#import "NSString+HexString.h"
#import "THLine.h"
#import "THChannel.h"
#import "THPendingJob.h"
#import "THCipherSet.h"
#import "NSData+HexString.h"
#import "THCipherSet.h"
#import "THTransport.h"
#import "THPath.h"
#import "THCipherSet2a.h"
#import "THCipherSet3a.h"
#import "THUnreliableChannel.h"
#import "CLCLog.h"
#import "THRelay.h"

@interface THSwitch()

@end

@implementation THSwitch
{
    THIdentity* _identity;
}

+(id)defaultSwitch;
{
    static THSwitch* sharedSwitch;
    static dispatch_once_t oneTime;
    dispatch_once(&oneTime, ^{
        sharedSwitch = [[self alloc] init];
    });
    return sharedSwitch;
}

+(id)THSWitchWithIdentity:(THIdentity*)identity;
{
    THSwitch* thSwitch = [THSwitch new];
    if (thSwitch) {
        
    }
    return thSwitch;
}

-(id)init;
{
    if (self) {
        self.openLines = [NSMutableDictionary dictionary];
        self.pendingJobs = [NSMutableArray array];
        self.transports = [NSMutableDictionary dictionary];
        self.potentialBridges = [NSMutableArray array];
        self.status = THSWitchOffline;
    }
    return self;
}

-(void)setIdentity:(THIdentity *)identity
{
    _identity = identity;
}

-(THIdentity*)identity
{
    return _identity;
}

-(void)start
{
    // XXX TODO FIXME For each path start it
    for (NSString* key in self.transports) {
        [[self.transports objectForKey:key] start];
    }
    [self updateStatus:THSwitchListening];
}

-(void)addTransport:(THTransport *)transport
{
    [self.transports setObject:transport forKey:transport.typeName];
}

-(void)loadSeeds:(NSData *)seedData;
{
    NSError* error;
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:seedData options:0 error:&error];
    if (!json) return;

    [json enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSDictionary* entry = (NSDictionary*)obj;
        NSArray* paths = [entry objectForKey:@"paths"];
        NSDictionary* keys = [entry objectForKey:@"keys"];
        // TODO:  XXX make this more generic
        THIdentity* seedIdentity = [THIdentity new];
		seedIdentity.isSeed = YES;
        // 2a
        NSData* keyData = [[NSData alloc] initWithBase64EncodedString:[keys objectForKey:@"2a"] options:0];
        THCipherSet* cs = [[THCipherSet2a alloc] initWithPublicKey:keyData privateKey:nil];
        [seedIdentity addCipherSet:cs];
        // 3a
        keyData = [[NSData alloc] initWithBase64EncodedString:[keys objectForKey:@"3a"] options:0];
        if (keyData) {
            cs = [[THCipherSet3a alloc] initWithPublicKey:keyData privateKey:nil];
            [seedIdentity addCipherSet:cs];
        }
        seedIdentity.parts = [entry objectForKey:@"parts"];

        for (NSDictionary* path in paths) {
            if ([[path objectForKey:@"type"] isEqualToString:@"ipv4"]) {
                THIPv4Transport* ipTransport = [self.transports objectForKey:@"ipv4"];
                if (!ipTransport) continue;
                NSData* address = [THIPV4Path addressTo:[path objectForKey:@"ip"] port:[[path objectForKey:@"port"] unsignedIntegerValue]];
                [seedIdentity addPath:[ipTransport returnPathTo:address]];
            }
        }
        
        if (seedIdentity) [self openLine:seedIdentity];
    }];
}

-(THLine*)lineToHashname:(NSString*)hashname;
{
    // XXX: If we don't have a line should we do an open here?
    // XXX: This is a common lookup, should we cache this another way as well?
    __block THLine* ret = nil;
    [self.openLines enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        THLine* line = (THLine*)obj;
        if ([line.toIdentity.hashname isEqualToString:hashname]) {
            ret = line;
            *stop = YES;
        }
    }];
    //CLCLogInfo(@"We found line to hashname %@ %@", ret.toIdentity.hashname, ret);
    return ret;
}

-(void)channel:(THChannel*)channel line:(THLine*)line firstPacket:(THPacket*)packet
{
    channel.line = line;
    if (!channel.channelId || [channel.channelId isEqualToNumber:@0]) {
        channel.channelId = [NSNumber numberWithUnsignedInteger:line.nextChannelId];
    }
    [channel.toIdentity.channels setObject:channel forKey:channel.channelId];
    channel.state = THChannelOpen;
    if (packet) [channel sendPacket:packet];
}

-(void)openChannel:(THChannel *)channel firstPacket:(THPacket *)packet;
{
    // Check for an already open lines
    THLine* channelLine = channel.toIdentity.currentLine;
    if (!channelLine) {
        [self.pendingJobs addObject:[THPendingJob pendingJobFor:channel completion:^(id result) {
            [self channel:channel line:(THLine*)result firstPacket:packet];
        }]];
        [self openLine:channel.toIdentity];
    } else {
        [self channel:channel line:channelLine firstPacket:packet];
    }

}

-(void)openLine:(THIdentity *)toIdentity
{
    [self openLine:toIdentity completion:nil];
}

-(void)openLine:(THIdentity *)toIdentity completion:(LineOpenBlock)lineOpenCompletion
{
    if (toIdentity.currentLine && (toIdentity.activePath || toIdentity.relay.peerChannel)) {
		CLCLogDebug(@"openLine returning currentLine for identity %@", toIdentity.hashname);
        if (lineOpenCompletion) lineOpenCompletion(toIdentity);
        return;
    }
    
	BOOL existingPendingJob = NO;
	THPendingJob* pendingJob = nil;
	
    for (THPendingJob* pendingJobItem in self.pendingJobs) {
        if (pendingJobItem.type == PendingIdentity) {
            THIdentity* pendingIdentity = (THIdentity*)pendingJobItem.pending;
            if ([pendingIdentity.hashname isEqualToString:toIdentity.hashname]) {
                // We're already trying, bail on this one
                CLCLogWarning(@"Tried to open another line to identity %@ while one pending", toIdentity.hashname);
                pendingJob = pendingJobItem;
				existingPendingJob = YES;
            }
        }
    }
	

	// If we dont have a matched pending line job
	if (!pendingJob) {
		CLCLogDebug(@"creating a pending job for identity %@", toIdentity.hashname);
		
		THPendingJob* pendingJob = [THPendingJob pendingJobFor:toIdentity completion:^(id result) {
			if (lineOpenCompletion) lineOpenCompletion(toIdentity);
		}];
		
		// TODO:  XXX Check this timeout length
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			if (!toIdentity.currentLine.inLineId) {
				CLCLogWarning(@"Unable to finalize the line to %@ after 2s", toIdentity.hashname);
				
				toIdentity.currentLine = nil;
				
				// remove any pending channel jobs
				[self.pendingJobs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
					THPendingJob* job = (THPendingJob*)obj;
					if (job.type == PendingChannel) {
						THChannel* channel = (THChannel*)job.pending;
						if ([channel.toIdentity.hashname isEqualToString:toIdentity.hashname]) {
							[self.pendingJobs removeObjectAtIndex:idx];
						}
					}
				}];
				
				[self.pendingJobs removeObject:pendingJob];
				if (lineOpenCompletion) lineOpenCompletion(nil);
			}
		});
		
		[self.pendingJobs addObject:pendingJob];
	}


    // We have everything we need to direct request
    if (toIdentity.availablePaths.count > 0 && toIdentity.cipherParts.count > 0) {
		CLCLogDebug(@"identity %@ already has known paths", toIdentity.hashname);
		
		if (!toIdentity.currentLine) {
			toIdentity.currentLine = [THLine new];
			toIdentity.currentLine.toIdentity = toIdentity;
		}
        
        [toIdentity.currentLine sendOpen];
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			THChannel* linkChannel = [toIdentity channelForType:@"link"];
			if (!linkChannel) {
				CLCLogError(@"link channel not established 3 seconds after sendOpen, resetting %@", toIdentity.hashname);
				[toIdentity reset];
			}
		});
		
		return;
    };
    

	// FW Helper
	for (THPath* punchPath in toIdentity.availablePaths) {
		if ([punchPath class] == [THIPV4Path class]) {
			THIPV4Path* ipPath = (THIPV4Path*)punchPath;
			[punchPath.transport send:[NSData data] to:ipPath.address];
		}
	}
	
	// setup the relay
	THRelay* relay = [THRelay new];
	toIdentity.relay = relay;
	toIdentity.relay.toIdentity = toIdentity;
	
	NSPredicate* seedFilter = [NSPredicate predicateWithFormat:@"SELF.toIdentity.isSeed == YES"];
	NSArray* seedLines = [[self.openLines allValues] filteredArrayUsingPredicate:seedFilter];
	for (THLine* seedLine in seedLines) {
		[toIdentity.relay attachVia:seedLine.toIdentity];
	}
	
	// we didnt have any valid via's, unset our relay again
	if (!toIdentity.relay.peerChannel) {
		toIdentity.relay = nil;
	}
}

-(void)closeLine:(THLine *)line
{
	if (line.cachedOpen) {
		line.cachedOpen = nil;
	}
	
    if (line.inLineId) [self.openLines removeObjectForKey:line.inLineId];
	
	if (line.toIdentity.currentLine == line) {
        line.toIdentity.currentLine = nil;
    }
}

-(void)processOpen:(THPacket*)incomingPacket
{
    CLCLogInfo(@"Processing an open from %@ with type %@", incomingPacket.returnPath.information, [incomingPacket.body subdataWithRange:NSMakeRange(0, 1)]);
    THCipherSet* cipherSet = [self.identity.cipherParts objectForKey:[[incomingPacket.body subdataWithRange:NSMakeRange(0, 1)] hexString]];
    if (!cipherSet) {
        CLCLogInfo(@"Invalid cipher set requested %@", [[incomingPacket.body subdataWithRange:NSMakeRange(0, 1)] hexString]);
        return;
    }
	
    THLine* newLine = [cipherSet processOpen:incomingPacket];
    if (!newLine) {
        CLCLogInfo(@"Unable to process open packet");
        return;
    }
    
    // Add the incoming path if we have one, relay would not
    if (incomingPacket.returnPath) {
        THPath* path = [newLine.toIdentity pathMatching:incomingPacket.returnPath.information];
        if (!path) {
            path = incomingPacket.returnPath;
            [newLine.toIdentity addPath:path];
        }
		
		CLCLogDebug(@"processOpen setting activePath for %@ to %@", newLine.toIdentity.hashname, path.information);
		newLine.toIdentity.activePath = path;
    }
    
    // remove any existing lines to this hashname
    if (newLine.inLineId) [self.openLines removeObjectForKey:newLine.inLineId];
    
    __block THPendingJob* pendingLineJob = nil;
    [self.pendingJobs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        THPendingJob* job = (THPendingJob*)obj;
        if (job.type != PendingIdentity) return;
        
        THIdentity* pendingIdentity = (THIdentity*)job.pending;
        if ([pendingIdentity.hashname isEqualToString:newLine.toIdentity.hashname]) {
            pendingLineJob = job;
            *stop = YES;
            [self.pendingJobs removeObjectAtIndex:idx];
        }
    }];
    if (pendingLineJob && newLine.inLineId) {
        THIdentity* pendingIdentity = (THIdentity*)pendingLineJob.pending;
        newLine = pendingIdentity.currentLine;
        CLCLogInfo(@"Finish opening line %@ for %@", newLine.inLineId, pendingIdentity.hashname);
        [newLine openLine];

        [self.openLines setObject:newLine forKey:newLine.inLineId];
        
        if ([self.delegate respondsToSelector:@selector(openedLine:)]) {
            [self.delegate openedLine:newLine];
        }
        
        if (pendingLineJob) pendingLineJob.handler(newLine);
        
        [newLine establishLink];
    } else {
        [newLine sendOpen];
        [newLine openLine];
		
        CLCLogInfo(@"Line %@ setup for %@", newLine.inLineId, newLine.toIdentity.hashname);
        [self.openLines setObject:newLine forKey:newLine.inLineId];
        if ([self.delegate respondsToSelector:@selector(openedLine:)]) {
            [self.delegate openedLine:newLine];
        }
        
        if (pendingLineJob) pendingLineJob.handler(newLine);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            THChannel* linkChannel = [newLine.toIdentity channelForType:@"link"];
            if (!linkChannel) {
                [newLine establishLink];
            }
        });
    }
	
    // Check the pending jobs for any lines or channels
    [self.pendingJobs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        THPendingJob* job = (THPendingJob*)obj;
        if (job.type == PendingChannel) {
            THChannel* channel = (THChannel*)job.pending;
            if (![channel.toIdentity.hashname isEqualToString:newLine.toIdentity.hashname]) return;
            [self.pendingJobs removeObjectAtIndex:idx];
            job.handler(newLine);
        } else if (job.type == PendingLine) {
            // TODO:  What is a pending line job?
        }
    }];
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
		CLCLogDebug(@"initial path negotiation for %@", newLine.toIdentity.hashname);
		[newLine negotiatePath];
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			CLCLogDebug(@"secondary path negotiation for %@", newLine.toIdentity.hashname);
			[newLine negotiatePath];
		});
	});
}

-(void)updateStatus:(THSwitchStatus)status
{
    if (status != self.status) {
        self.status = status;
        if ([self.delegate respondsToSelector:@selector(thSwitch:status:)]) {
            [self.delegate thSwitch:self status:self.status];
        }
    }
}

-(THPacket*)generateOpen:(THLine *)toLine
{
    // Find our highest matching cipher set
    NSMutableSet* ourIDs = [NSMutableSet setWithArray:[self.identity.cipherParts allKeys]];
    [ourIDs intersectSet:[NSSet setWithArray:[toLine.toIdentity.cipherParts allKeys]]];
    if (ourIDs.count <= 0) {
        CLCLogInfo(@"Unable to find a matching csid for open, requested cipherParts %@", toLine.toIdentity.cipherParts);
        return nil;
    }
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:NO];
    NSArray* sortedCSIds = [ourIDs sortedArrayUsingDescriptors:@[sort]];
    THCipherSet* cs = [self.identity.cipherParts objectForKey:[sortedCSIds objectAtIndex:0]];
    return [cs generateOpen:toLine from:self.identity];
}

-(void)handlePacket:(THPacket *)packet
{
    if (packet.jsonLength == 1) {
        [self processOpen:packet];
    } else if(packet.jsonLength == 0) {
        // Validate the line id then process it
        NSString* lineId = [[packet.body subdataWithRange:NSMakeRange(0, 16)] hexString];
        //CLCLogInfo(@"Received a line packet for %@", lineId);
        // Process a line packet
        THLine* line = [self.openLines objectForKey:lineId];
        // If there is no line to handle this dump it
        if (line == nil) {
			CLCLogWarning(@"line %@ not found in openLines", lineId);
            return;
        }
        [line handlePacket:packet];
    } else {
        CLCLogInfo(@"Dropping an unknown packet");
    }
}

-(void)transport:(THTransport *)transport handlePacket:(THPacket *)packet
{
    [self handlePacket:packet];
}

-(void)transportDidChangeActive:(THTransport *)transport;
{
    NSUInteger availableCount = 0;
    for (NSString* key in self.transports) {
        THTransport* transport = [self.transports objectForKey:key];
        if (transport.available) ++availableCount;
    }
    if (availableCount <= 0) {
        CLCLogInfo(@"Oh no, we're offline!");
        // XXX TODO:  What to do?
    }
}

@end
