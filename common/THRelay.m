//
//  THRelay.m
//  telehash
//
//  Created by Thomas Muldowney on 5/17/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THRelay.h"
#import "THTransport.h"
#import "THPacket.h"
#import "CLCLog.h"
#import "THPath.h"

@implementation THRelay

-(void)dealloc
{
    CLCLogDebug(@"We lost a relay to %@!", self.toIdentity.hashname);
}

-(id)initOnChannel:(THUnreliableChannel *)channel
{
    self = [super init];
    if (self) {
        self.relayedPath = channel.toIdentity.activePath;
        self.peerChannel = channel;
    }
    return self;
}

-(void)sendPacket:(THPacket *)packet
{
    if (!self.peerChannel) {
		CLCLogWarning(@"attempting to send on a dead relay, removing relay reference");
		self.toIdentity.relay = nil;
		return;
	}
    
    THPacket* relayPacket = [THPacket new];
    relayPacket.body = [packet encode];
    
    CLCLogDebug(@"Relay sending %@", packet.json);
    [self.peerChannel sendPacket:relayPacket];
}

-(BOOL)channel:(THChannel *)channel handlePacket:(THPacket *)packet
{
    THPacket* relayedPacket = [THPacket packetData:packet.body];
    if (!relayedPacket) {
        CLCLogInfo(@"Garbage on the relay for %@, invalid or unparseable packet with json %@", self.toIdentity.hashname, packet.json);
        return YES;
    }
    relayedPacket.returnPath = nil;
    if ( [packet.json objectForKey:@"bridge"] || [relayedPacket.json objectForKey:@"json"]) {
        NSLog(@"Start a bridge on %@", packet.returnPath.information);
        [self.toIdentity addPath:packet.returnPath];
    }
	
	// overwrite our peerChannel with the one that actually responded
	self.peerChannel = (THUnreliableChannel*)channel;
	
    [[THSwitch defaultSwitch] handlePacket:relayedPacket];
    /*
    THTransport* transport = self.relayedPath.transport;
    if ([transport.delegate respondsToSelector:@selector(transport:handlePacket:)]) {
        [transport.delegate transport:self.transport handlePacket:relayedPacket];
    }
    */
    
    return YES;
}

-(void)channel:(THChannel *)channel didFailWithError:(NSError *)error
{
    // XXX TODO: Shutdown the busted path
	CLCLogWarning(@"relay peerChannel for %@ didFailWithError: %@", self.toIdentity.hashname, [error description]);
	
	self.peerChannel = nil;
    self.toIdentity.relay = nil;
	
	// attempt to re-open line
	[[THSwitch defaultSwitch] openLine:self.toIdentity];
}

-(void)channel:(THChannel *)channel didChangeStateTo:(THChannelState)channelState
{
	CLCLogDebug(@"relay peerChannel for %@ didChangeStateTo: %d", self.toIdentity.hashname, channelState);
    
    // XXX TODO:  Shutdown on channel ended
	// TODO temas, we're getting errors, but not closes...
	if (channelState == THChannelEnded || channelState == THChannelErrored) {
		if (channel == self.peerChannel) {
			CLCLogWarning(@"relay peerChannel for %@ closed", self.toIdentity.hashname);
			self.peerChannel = nil;
            self.toIdentity.relay = nil;
			
			// attempt to re-open line
			[[THSwitch defaultSwitch] openLine:self.toIdentity];
		}
	}
	
}

@end
