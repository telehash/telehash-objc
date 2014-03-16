//
//  THChannel.m
//  telehash
//
//  Created by Thomas Muldowney on 10/5/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THChannel.h"
#import "THPacket.h"
#import "THIdentity.h"
#import "RNG.h"
#import "NSData+HexString.h"
#import "SHA256.h"
#import "THSwitch.h"
#import "CTRAES256.h"
#import "THLine.h"
#import "THPacketBuffer.h"

@implementation THChannel
{
    THChannelState _state;
}

-(id)initToIdentity:(THIdentity*)identity
{
    self = [super init];
    if (self) {
        _state = THChannelOpening;
        self.toIdentity = identity;
        self.channelIsReady = NO;
        self.channelId = 0; // We'll just go ahead and make one
        self.lastInActivity = 0;
        self.lastOutActivity = 0;
        THSwitch* defaultSwitch = [THSwitch defaultSwitch];
        self.line = [defaultSwitch lineToHashname:self.toIdentity.hashname];
    }
    return self;
}

-(THChannelState)state
{
    return _state;
}

-(void)setState:(THChannelState)state
{
    _state = state;
    if ([self.delegate respondsToSelector:@selector(channel:didChangeStateTo:)]) {
        [self.delegate channel:self didChangeStateTo:_state];
    }
}

-(void)sendPacket:(THPacket *)packet;
{
    self.lastOutActivity = time(NULL);
}

-(void)handlePacket:(THPacket *)packet;
{
    self.lastInActivity = time(NULL);
}
@end

@implementation THUnreliableChannel
-(void)dealloc
{
    NSLog(@"gone for unreliable %@", self.channelId);
}

-(id)initToIdentity:(THIdentity *)identity;
{
    self = [super initToIdentity:identity];
    return self;
}

-(void)handlePacket:(THPacket *)packet;
{
    [super handlePacket:packet];
    
    // Save the type
    NSString* packetType = [packet.json objectForKey:@"type"];
    if (!self.type && packetType) self.type = packetType;
    
    [self.delegate channel:self handlePacket:packet];
    if ([[packet.json objectForKey:@"end"] boolValue] == YES) {
        [self.toIdentity.channels removeObjectForKey:self.channelId];
    }
}

-(void)sendPacket:(THPacket *)packet;
{
    [super sendPacket:packet];
    
    // Save the type
    NSString* packetType = [packet.json objectForKey:@"type"];
    if (!self.type && packetType) self.type = packetType;
    
    [packet.json setObject:self.channelId forKey:@"c"];
    [self.toIdentity sendPacket:packet];
    if ([[packet.json objectForKey:@"end"] boolValue] == YES) {
        [self.toIdentity.channels removeObjectForKey:self.channelId];
    }
}
@end

@interface THReliableChannel() {
    dispatch_queue_t channelQueue;
    NSArray* missing;
}
-(void)checkAckPing:(NSUInteger)packetTime;
-(void)delegateHandlePackets;
@end

@implementation THReliableChannel
-(id)initToIdentity:(THIdentity *)identity;
{
    self = [super initToIdentity:identity];
    if (self) {
        sequence = 0;
        inPacketBuffer = [THPacketBuffer new];
        outPacketBuffer = [THPacketBuffer new];
        self.maxSeen = @0;
        channelQueue = NULL;
    }
    return self;
}
-(void)handlePacket:(THPacket *)packet;
{
    [super handlePacket:packet];
    
    NSNumber* curSeq = [packet.json objectForKey:@"seq"];
    if (curSeq.unsignedIntegerValue > self.maxSeen.unsignedIntegerValue) {
        self.maxSeen = curSeq;
    }
    NSNumber* ack = [packet.json objectForKey:@"ack"];
    if (ack) {
        // Let's clean up the out buffer based on their ack position
        [outPacketBuffer clearThrough:[ack unsignedIntegerValue]];
        
    }
    // XXX: Make sure we're pinging every second
    [self checkAckPing:time(NULL)];
    
    // If this is a new seq object we'll need to pass it off
    if ([packet.json objectForKey:@"seq"]) {
        NSLog(@"Putting on the buffer: %@ ", packet.json);
        [inPacketBuffer push:packet];
    }
    
    NSString* packetType = [packet.json objectForKey:@"type"];
    if (!self.type && packetType) self.type = packetType;
    
    missing = [inPacketBuffer missingSeq];
    [self delegateHandlePackets];
}

-(void)checkAckPing:(NSUInteger)packetTime;
{
    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
    double delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, defaultSwitch.channelQueue, ^(void){
        if (lastAck < (nextExpectedSequence - 1)) {
            [self sendPacket:[THPacket new]];
        }
    });
}
-(void)sendPacket:(THPacket *)packet;
{
    [super sendPacket:packet];
    
    // Save the type
    NSString* packetType = [packet.json objectForKey:@"type"];
    if (!self.type && packetType) self.type = packetType;
    
    // If the packet has a body or other json we increment the seq
    if ([packet.json count] > 0 || packet.body != nil) {
        // Append seq
        [packet.json setObject:[NSNumber numberWithUnsignedLong:sequence] forKey:@"seq"];
        ++sequence;
    }
    // Append misses
    if (missing) {
        [packet.json setObject:missing forKey:@"miss"];
    }
    // Append channel id
    [packet.json setObject:self.channelId forKey:@"c"];
    // Append ack
    [packet.json setObject:[NSNumber numberWithUnsignedLong:(nextExpectedSequence - 1)] forKey:@"ack"];
    lastAck = time(NULL);
    
    [outPacketBuffer push:packet];
    
    if (self.channelIsReady) [self.toIdentity sendPacket:packet];
}

-(void)delegateHandlePackets;
{
    if (!channelQueue) {
        channelQueue = dispatch_queue_create([[NSString stringWithFormat:@"telehash.channel.%@", self.channelId] UTF8String], NULL);
        //channelSemaphore = dispatch_semaphore_create(0);
    }

    while (inPacketBuffer.length > 0) {
        if (inPacketBuffer.frontSeq != nextExpectedSequence) {
            // XXX dispatch a missing queue?
            return;
        }
        THPacket* curPacket = [inPacketBuffer pop];
        dispatch_async(channelQueue, ^{
            [self.delegate channel:self handlePacket:curPacket];
            if ([[curPacket.json objectForKey:@"end"] boolValue] == YES) {
                // TODO: Shut it down!
            }
            nextExpectedSequence = [[curPacket.json objectForKey:@"seq"] unsignedIntegerValue] + 1;
        });
    }
}

// Flush our out buffer
-(void)flushOut;
{
    [outPacketBuffer forEach:^(THPacket *packet) {
        NSLog(@"Sending packet on %@ %@", self.line, packet.json);
        [self.toIdentity sendPacket:packet];
    }];
}
@end