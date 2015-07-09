//
//  E3XChannel.m
//  telehash
//
//  Created by Thomas Muldowney on 10/5/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "E3XChannel.h"
#import "THPacket.h"
#import "THLink.h"
#import "RNG.h"
#import "NSData+HexString.h"
#import "SHA256.h"
#import "THMesh.h"
#import "CTRAES256.h"
#import "E3XExchange.h"
#import "THPacketBuffer.h"

@implementation E3XChannel
{
    E3XChannelState _state;
}

-(id)initToIdentity:(THLink*)identity
{
    self = [super init];
    if (self) {
        _state = E3XChannelOpening;
		self.direction = E3XChannelOutbound;
        self.toIdentity = identity;
        self.channelId = 0; // We'll just go ahead and make one
		self.createdAt = time(NULL);
        self.lastInActivity = 0;
        self.lastOutActivity = 0;
        THMesh* defaultSwitch = [THMesh defaultSwitch];
        self.line = [defaultSwitch lineToHashname:self.toIdentity.hashname];
    }
    return self;
}

-(E3XChannelState)state
{
    return _state;
}

-(void)setState:(E3XChannelState)state
{
    _state = state;
    if ([self.delegate respondsToSelector:@selector(channel:didChangeStateTo:)]) {
        [self.delegate channel:self didChangeStateTo:_state];
    }
}

-(void)sendPacket:(THPacket *)packet;
{
    if (self.state == E3XChannelEnded) {
        // XXX Error that we're trying to send on an ended channel
    } else if (self.state == E3XChannelErrored) {
        // XXX Error that we're trying to send on an errored channel
    }
	
    self.lastOutActivity = time(NULL);
	self.line.lastOutActivity = time(NULL);
}

-(void)handlePacket:(THPacket *)packet;
{
    self.lastInActivity = time(NULL);
	self.line.lastInActivity = time(NULL);
	
    NSString* err = [packet.json objectForKey:@"err"];
    if (err) {
        [self.delegate channel:self didFailWithError:[NSError errorWithDomain:@"telehash" code:100 userInfo:@{NSLocalizedDescriptionKey:err}]];
        self.state = E3XChannelErrored;
        [self.toIdentity.channels removeObjectForKey:self.channelId];
    }
}

-(void)close
{
	if (!self.channelId) return;
	
    if (self.state != E3XChannelOpening && self.state != E3XChannelEnded) {
        THPacket* endPacket = [THPacket new];
        [endPacket.json setObject:@YES forKey:@"end"];
        [self sendPacket:endPacket];
        self.state = E3XChannelEnded;
    }
	
    [self.toIdentity.channels removeObjectForKey:self.channelId];
}
@end

