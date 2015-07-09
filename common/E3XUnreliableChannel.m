//
//  THUnreliableChannel.m
//  telehash
//
//  Created by Thomas Muldowney on 4/26/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "E3XUnreliableChannel.h"
#import "THPacket.h"
#import "CLCLog.h"

@implementation E3XUnreliableChannel
{
    NSMutableArray* packetBuffer;
    E3XChannelState _state;
}

-(void)dealloc
{
    CLCLogDebug(@"gone for unreliable %@", self.channelId);
}

-(id)initToIdentity:(THLink *)identity;
{
    self = [super initToIdentity:identity];
    return self;
}

-(void)setState:(E3XChannelState)state
{
    _state = state;
    if (_state == E3XChannelOpen) {
        [self flushSend];
    }
}

-(E3XChannelState)state
{
    return _state;
}

-(void)handlePacket:(THPacket *)packet;
{
    [super handlePacket:packet];
    
    // Save the type
    NSString* packetType = [packet.json objectForKey:@"type"];
    if (!self.type && packetType) self.type = packetType;
    
    if (self.state != E3XChannelOpening && [self.delegate respondsToSelector:@selector(channel:handlePacket:)]) {
        [self.delegate channel:self handlePacket:packet];
    }
    if (self.state != E3XChannelEnded && [[packet.json objectForKey:@"end"] boolValue] == YES) {
        self.state = E3XChannelEnded;
        [self close];
    }
}

-(void)sendPacket:(THPacket *)packet;
{
    [super sendPacket:packet];
    
    if (self.state == E3XChannelEnded || self.state == E3XChannelErrored) return;
    
    // Save the type
    NSString* packetType = [packet.json objectForKey:@"type"];
    if (!self.type && packetType) self.type = packetType;
    
    [packet.json setObject:self.channelId forKey:@"c"];
    
    if (self.state == E3XChannelPaused || self.state == E3XChannelOpening) {
        if (!packetBuffer) packetBuffer = [NSMutableArray array];
        [packetBuffer addObject:packet];
    } else if (self.state == E3XChannelOpen) {
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
        if (self.state != E3XChannelOpen) return;
        THPacket* outPacket = [packetBuffer firstObject];
        [packetBuffer removeObjectAtIndex:0];
        [self realSend:outPacket];
    }
}
@end