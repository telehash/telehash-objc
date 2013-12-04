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

-(id)initToIdentity:(THIdentity*)identity
{
    self = [super init];
    if (self) {
        self.toIdentity = identity;
        self.channelIsReady = NO;
        self.channelId  = [[RNG randomBytesOfLength:16] hexString]; // We'll just go ahead and make one
        THSwitch* defaultSwitch = [THSwitch defaultSwitch];
        self.line = [defaultSwitch lineToHashname:self.toIdentity.hashname];
    }
    return self;
}

-(void)sendPacket:(THPacket *)packet;
{
    NSAssert(YES, @"This is a base method that should be implemented in concrete channel types.");
}

-(void)handlePacket:(THPacket *)packet;
{
    NSAssert(YES, @"This is a base method that should be implemented in concrete channel types.");
}
@end

@interface THReliableChannel() {
    dispatch_queue_t channelQueue;
    dispatch_semaphore_t channelSemaphore;
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
    //[self checkAckPing:time(NULL)];
    // If this is a new seq object we'll need to pass it off
    if ([packet.json objectForKey:@"seq"]) {
        NSLog(@"Putting on the buffer: %@ ", packet.json);
        [inPacketBuffer push:packet];
    }
    
    missing = [inPacketBuffer missingSeq];
    [self delegateHandlePackets];
}

-(void)checkAckPing:(NSUInteger)packetTime;
{
    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
    double delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, defaultSwitch.channelQueue, ^(void){
        if (lastAck < (packetTime + 1)) {
            [self sendPacket:[THPacket new]];
        }
    });
}
-(void)sendPacket:(THPacket *)packet;
{
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
    [packet.json setObject:[NSNumber numberWithUnsignedLong:maxProcessed] forKey:@"ack"];
    
    [outPacketBuffer push:packet];
    
    if (self.channelIsReady) [self.line sendPacket:packet];
}

-(void)delegateHandlePackets;
{
    if (channelSemaphore != NULL) {
        dispatch_semaphore_signal(channelSemaphore);
        return;
    };
    channelQueue = dispatch_queue_create([[NSString stringWithFormat:@"telehash.channel.%@", self.channelId] UTF8String], NULL);
    channelSemaphore = dispatch_semaphore_create(0);
    dispatch_async(channelQueue, ^{
        while (self.channelIsReady) {
            BOOL inOrder = YES;
            while (inPacketBuffer.length > 0 && inOrder) {
                if (inPacketBuffer.frontSeq != (maxProcessed + 1)) {
                    inOrder = NO;
                    // XXX dispatch a missing queue?
                    continue;
                }
                THPacket* curPacket = [inPacketBuffer pop];
                [self.delegate channel:self handlePacket:curPacket];
                maxProcessed = [[curPacket.json objectForKey:@"seq"] unsignedIntegerValue];
            }
            dispatch_semaphore_wait(channelSemaphore, DISPATCH_TIME_FOREVER);
        }
    });
}

// Flush our out buffer
-(void)flushOut;
{
    [outPacketBuffer forEach:^(THPacket *packet) {
        NSLog(@"Sending packet on %@ %@", self.line, packet.json);
        [self.line sendPacket:packet];
    }];
}
@end