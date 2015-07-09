//
//  THPeerRelay.m
//  telehash
//
//  Created by Thomas Muldowney on 3/17/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THPeerRelay.h"
#import "THLink.h"
#import "THPacket.h"
#import "CLCLog.h"

@implementation THPeerRelay

-(void)dealloc
{
    CLCLogDebug(@"THPeerRelay went away");
}

-(void)sendPacket:(THPacket *)packet
{
	CLCLogWarning(@"THPeerRelay sendPacket called!");
}

-(BOOL)channel:(E3XChannel *)channel handlePacket:(THPacket *)packet
{
    CLCLogDebug(@"Relay got %@", packet.json);
	
    THPacket* outPacket = [THPacket new];
    outPacket.body = packet.body;
    outPacket.jsonLength = packet.jsonLength;

    // XXX FIXME Rate limiting
    if (channel == self.peerChannel) {
        [self.connectChannel sendPacket:outPacket];
    } else {
        [self.peerChannel sendPacket:outPacket];
    }
    
    return YES;
}

-(void)channel:(E3XChannel *)channel didChangeStateTo:(E3XChannelState)channelState
{
    CLCLogWarning(@"THPeerRelay channel didChangeStateTo: %d", channelState);
}

-(void)channel:(E3XChannel *)channel didFailWithError:(NSError *)error
{
	CLCLogWarning(@"THPeerRelay channel didFailWithError: %@", [error description]);
}
@end
