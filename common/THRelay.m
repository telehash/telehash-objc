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
#import "THCipherSet.h"

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

-(void)attachVia:(THIdentity*)viaIdentity
{
	THSwitch* defaultSwitch = [THSwitch defaultSwitch];
	
	THUnreliableChannel* peerChannel = [[THUnreliableChannel alloc] initToIdentity:viaIdentity];
	peerChannel.type = @"peer";
	peerChannel.delegate = self;
	[defaultSwitch openChannel:peerChannel firstPacket:nil];
	
	if (!peerChannel.channelId) return;
	
	THPacket* peerPacket = [THPacket new];
	[peerPacket.json setObject:[NSNumber numberWithUnsignedInteger:viaIdentity.currentLine.nextChannelId] forKey:@"c"];
	[peerPacket.json setObject:self.toIdentity.hashname forKey:@"peer"];
	[peerPacket.json setObject:@"peer" forKey:@"type"];
	[peerPacket.json setObject:peerChannel.channelId forKey:@"c"];
	NSArray* paths = [defaultSwitch.identity pathInformationTo:self.toIdentity allowLocal:NO];
	if (paths) {
		[peerPacket.json setObject:paths forKey:@"paths"];
	}
	
	THCipherSet* chosenCS = [defaultSwitch.identity.cipherParts objectForKey:self.toIdentity.suggestedCipherSet];
	if (!chosenCS) {
		CLCLogError(@"We did not actually have a key for the CS %@ to connect to %@", self.toIdentity.suggestedCipherSet, self.toIdentity.hashname);
		return;
	}
	
	peerPacket.body = chosenCS.publicKey;
	
	self.relayIdentity = viaIdentity;
	self.relayedPath = viaIdentity.activePath;
	self.peerChannel = peerChannel;
	
	// We blind send this and hope for the best!
	[viaIdentity sendPacket:peerPacket];
}

-(void)sendPacket:(THPacket *)packet
{
    if (!self.peerChannel) {
		// TODO review this
		CLCLogDebug(@"re-opening relay peerChannel via %@", self.relayIdentity.hashname);
		[self attachVia:self.relayIdentity];
		
		if (!self.peerChannel) {
			CLCLogWarning(@"failed to recover relay");
			return;
		}
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
	
	
    if ([packet.json objectForKey:@"bridge"] || [relayedPacket.json objectForKey:@"json"]) {
        NSLog(@"Start a bridge on %@", packet.returnPath.information);
		if (!self.toIdentity.activePath) {
			self.toIdentity.isBridged = YES;
		}
		
        [self.toIdentity addPath:packet.returnPath];
    }
	
	// overwrite our peerChannel and relayIdentity with the one that actually responded
	if (self.peerChannel.lastInActivity == 0) {
		self.peerChannel = (THUnreliableChannel*)channel;
		self.relayIdentity = channel.toIdentity;
	}

    [[THSwitch defaultSwitch] handlePacket:relayedPacket];
    
    return YES;
}

-(void)channel:(THChannel *)channel didFailWithError:(NSError *)error
{
	CLCLogWarning(@"relay peerChannel for %@ didFailWithError: %@", self.toIdentity.hashname, [error description]);
	
	if (channel == self.peerChannel) {
		self.peerChannel = nil;
	}
}

-(void)channel:(THChannel *)channel didChangeStateTo:(THChannelState)channelState
{
	CLCLogDebug(@"relay peerChannel for %@ didChangeStateTo: %d", self.toIdentity.hashname, channelState);
	
	if (channel == self.peerChannel && (channelState == THChannelEnded || channelState == THChannelErrored)) {
		CLCLogWarning(@"relay peerChannel for %@ closed", self.toIdentity.hashname);
		self.peerChannel = nil;
	}
}

@end
