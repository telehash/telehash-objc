//
//  THMeshBuckets.m
//  telehash
//
//  Created by Thomas Muldowney on 1/7/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THMeshBuckets.h"
#import "THIdentity.h"
#import "THLine.h"
#import "THPacket.h"
#import "RNG.h"
#import "NSData+HexString.h"
#import "THSwitch.h"
#import "THPendingJob.h"
#import "THChannel.h"
#import "THPath.h"
#import "THRelay.h"
#import "THUnreliableChannel.h"
#import "CLCLog.h"


@interface PendingSeekJob : NSObject<THChannelDelegate>
@property THIdentity* localIdentity;
@property THIdentity* seekingIdentity;
@property THSwitch* localSwitch;
@property THIdentity* seed;
@property NSUInteger runningSearches;
@property (nonatomic, copy) SeekCompletionBlock completion;

-(void)runSeek;
-(BOOL)channel:(THChannel *)channel handlePacket:(THPacket *)packet;
@end

@implementation THMeshBuckets
{

}

-(id)init
{
    self = [super init];
    if (self) {

    }
    return self;
}

-(void)seek:(THIdentity*)toIdentity onSeed:(THIdentity*)seed completion:(SeekCompletionBlock)completion
{
    CLCLogDebug(@"Seeking for %@", toIdentity.hashname);
    
    PendingSeekJob* seekJob = [PendingSeekJob new];
    seekJob.localSwitch = self.localSwitch;
    seekJob.localIdentity = self.localIdentity;
    seekJob.seekingIdentity = toIdentity;
    seekJob.completion = completion;
	seekJob.seed = seed;
	
    [self.pendingSeeks setValue:seekJob forKey:toIdentity.hashname];
    
    [seekJob runSeek];
}

// Channel delegate methods
@end


@implementation PendingSeekJob
-(void)runSeek
{
    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
    ++self.runningSearches;
    
	if (!self.seed.activePath) return;
	
    THChannel* seekChannel = [[THUnreliableChannel alloc] initToIdentity:self.seed];
    seekChannel.delegate = self;
    
    THPacket* seekPacket = [THPacket new];
    [seekPacket.json setObject:self.seekingIdentity.hashname forKey:@"seek"];
    [seekPacket.json setObject:@"seek" forKey:@"type"];
    
    [defaultSwitch openChannel:seekChannel firstPacket:seekPacket];
}

 -(BOOL)channel:(THChannel*)channel handlePacket:(THPacket*)packet
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
        }
    }];
    
    if (foundIt) {
        if (self.completion) self.completion(YES);
        return YES;
    }
	
    return YES;
}
-(void)channel:(THChannel *)channel didChangeStateTo:(THChannelState)channelState
{
}

-(void)channel:(THChannel *)channel didFailWithError:(NSError *)error
{
}
@end
