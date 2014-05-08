//
//  THPeerRelay.m
//  telehash
//
//  Created by Thomas Muldowney on 3/17/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THPeerRelay.h"
#import "THIdentity.h"
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

-(BOOL)channel:(THChannel *)channel handlePacket:(THPacket *)packet
{
    CLCLogDebug(@"Relay got %@", packet.body);
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

-(void)channel:(THChannel *)channel didChangeStateTo:(THChannelState)channelState
{
    CLCLogWarning(@"THPeerRelay channel didChangeStateTo: %d", channelState);
}

-(void)channel:(THChannel *)channel didFailWithError:(NSError *)error
{
	CLCLogWarning(@"THPeerRelay channel didFailWithError: %@", [error description]);
}
@end
