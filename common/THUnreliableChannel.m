//
//  THUnreliableChannel.m
//  telehash
//
//  Created by Thomas Muldowney on 4/26/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THUnreliableChannel.h"
#import "THPacket.h"
#import "CLCLog.h"

@implementation THUnreliableChannel
{
    NSMutableArray* packetBuffer;
    THChannelState _state;
}

-(void)dealloc
{
    CLCLogDebug(@"gone for unreliable %@", self.channelId);
}

-(id)initToIdentity:(THIdentity *)identity;
{
    self = [super initToIdentity:identity];
    return self;
}

-(void)setState:(THChannelState)state
{
    _state = state;
    if (_state == THChannelOpen) {
        [self flushSend];
    }
}

-(THChannelState)state
{
    return _state;
}

-(void)handlePacket:(THPacket *)packet;
{
    [super handlePacket:packet];
    
    // Save the type
    NSString* packetType = [packet.json objectForKey:@"type"];
    if (!self.type && packetType) self.type = packetType;
    
    if (self.state != THChannelOpening && [self.delegate respondsToSelector:@selector(channel:handlePacket:)]) {
        [self.delegate channel:self handlePacket:packet];
    }
    if ([[packet.json objectForKey:@"end"] boolValue] == YES) {
        self.state = THChannelEnded;
        [self close];
    }
}

-(void)sendPacket:(THPacket *)packet;
{
    [super sendPacket:packet];
    
    if (self.state == THChannelEnded || self.state == THChannelErrored) return;
    
    // Save the type
    NSString* packetType = [packet.json objectForKey:@"type"];
    if (!self.type && packetType) self.type = packetType;
    
    [packet.json setObject:self.channelId forKey:@"c"];
    
    if (self.state == THChannelPaused || self.state == THChannelOpening) {
        if (!packetBuffer) packetBuffer = [NSMutableArray array];
        [packetBuffer addObject:packet];
    } else if (self.state == THChannelOpen) {
        [self realSend:packet];
    }
}

-(void)realSend:(THPacket*)packet
{
    [self.toIdentity sendPacket:packet];
    if ([[packet.json objectForKey:@"end"] boolValue] == YES) {
        [self.toIdentity.channels removeObjectForKey:self.channelId];
    }
}

-(void)flushSend
{
    while (packetBuffer.count > 0) {
        if (self.state != THChannelOpen) return;
        THPacket* outPacket = [packetBuffer firstObject];
        [packetBuffer removeObjectAtIndex:0];
        [self realSend:outPacket];
    }
}
@end