//
//  THReliableChannel.m
//  telehash
//
//  Created by Thomas Muldowney on 4/26/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THReliableChannel.h"
#import "THPacketBuffer.h"
#import "THPacket.h"
#import "CLCLog.h"
#include <stdlib.h>

#define FUZZY_LOSS YES

@interface THReliableChannel() {
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
    }
    return self;
}
-(void)handlePacket:(THPacket *)packet;
{
	/*
	int rand = arc4random_uniform(10);
	if (rand < 1) {
		CLCLogDebug(@"dropping packet for loss test");
		return;
	}
	*/
    [super handlePacket:packet];
    
	
    NSNumber* curSeq = [packet.json objectForKey:@"seq"];
    if (curSeq.unsignedIntegerValue > self.maxSeen.unsignedIntegerValue) {
        self.maxSeen = curSeq;
    }
	
	NSArray* miss = [packet.json objectForKey:@"miss"];
	if (miss) {
		[self resendMissingPackets:miss];
	}
    
	NSNumber* ack = [packet.json objectForKey:@"ack"];
    if (ack) {
        // Let's clean up the out buffer based on their ack position
        [outPacketBuffer clearThrough:[ack unsignedIntegerValue]];
    }
	
    NSString* packetType = [packet.json objectForKey:@"type"];
    if (!self.type && packetType) self.type = packetType;
    
    // If this is a new seq object we'll need to pass it off
    if ([packet.json objectForKey:@"seq"]) {
		if ([curSeq unsignedIntegerValue] >= lastProcessed) {
			CLCLogInfo(@"Putting on the incoming buffer: %@ ", packet.json);
			[inPacketBuffer push:packet];
		} else {
			CLCLogWarning(@"recieved a packet seq earlier than our lastProcessed position");
		}
    }
    
    // XXX: Make sure we're pinging every second
    [self checkAckPing:time(NULL)];
    
    // Immediately send a missing packet for any packets that are new missing
    NSArray* curMissing = [inPacketBuffer missingSeqFrom:self.nextExpectedSequence];
    NSMutableSet* newMissing = [NSMutableSet setWithCapacity:self.missing.count];
    [newMissing addObjectsFromArray:curMissing];
    [newMissing minusSet:[NSSet setWithArray:self.missing]];
    
    missing = curMissing;
    
    if (newMissing.count > 0) {
        [self sendPacket:[THPacket new]];
    }
    
    [self delegateHandlePackets];
}

-(void)checkAckPing:(NSUInteger)packetTime;
{
	// TODO review this under load
    double delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (lastAck < lastProcessed) {
            [self sendPacket:[THPacket new]];
        }
    });
}
-(void)sendPacket:(THPacket *)packet;
{
    [super sendPacket:packet];
    
    if (self.state == THChannelEnded || self.state == THChannelErrored) return;
    
    // Save the type
    NSString* packetType = [packet.json objectForKey:@"type"];
    if (!self.type && packetType) {
        self.type = packetType;
        CLCLogInfo(@"Channel type set to %@", self.type);
    }
    
    // If the packet has a body or other json we increment the seq
    if ([packet.json count] > 0 || packet.body != nil) {
        // Append seq
        [packet.json setObject:[NSNumber numberWithUnsignedLong:sequence] forKey:@"seq"];
        ++sequence;
    }
	
    // Append misses
    if (![packet.json objectForKey:@"miss"] && missing) {
        [packet.json setObject:missing forKey:@"miss"];
    }
	
    // Append channel id
    [packet.json setObject:self.channelId forKey:@"c"];
    
    // Append ack
    if (lastProcessed >= lastAck) {
        [packet.json setObject:[NSNumber numberWithUnsignedLong:lastProcessed] forKey:@"ack"];
        lastAck = lastProcessed;
    } else {
		CLCLogWarning(@"lastProcessed %d < lastAck %d", lastProcessed, lastAck);
	}
    
	if ([packet.json objectForKey:@"seq"]) {
		[outPacketBuffer push:packet];
	}
    
    if (self.state == THChannelOpen) {
#ifdef FUZZY_LOSS
        // 10% packet loss fuzz
        if ((int)(arc4random() % 11) == 1)
            return;
#endif
        [self.toIdentity sendPacket:packet];
    }
}

-(void)resendMissingPackets:(NSArray*)miss
{
	NSArray* missedPackets = [outPacketBuffer packetsForMiss:miss];
	if (miss.count != missedPackets.count) {
		CLCLogWarning(@"outPacketBuffer returned %d missed packets, we wanted %d", missedPackets.count, miss.count);
	}
	
	if (missedPackets) {
		CLCLogDebug(@"resending %d missing packets", missedPackets.count);
		for (THPacket* packet in missedPackets) {
            [packet.json removeObjectForKey:@"miss"];
			if (self.state == THChannelOpen) [self.toIdentity sendPacket:packet];
		}
	} else {
		CLCLogWarning(@"outPacketBuffer didnt have packets for resendMissingPackets");
	}
}

-(void)delegateHandlePackets;
{
	while (inPacketBuffer.length > 0) {
		if (inPacketBuffer.frontSeq != self.nextExpectedSequence) {
			CLCLogWarning(@"sequence out of order %d expecting %d", inPacketBuffer.frontSeq, self.nextExpectedSequence);
			return;
		}
		
		THPacket* curPacket = [inPacketBuffer pop];
		
		[self.delegate channel:self handlePacket:curPacket];
        
        NSNumber* seqNum = [curPacket.json objectForKey:@"seq"];
        if (seqNum) {
            lastProcessed = [seqNum unsignedIntegerValue];
            self.nextExpectedSequence = lastProcessed + 1;
        }
		
		if (self.state != THChannelEnded && [[curPacket.json objectForKey:@"end"] boolValue] == YES) {
			// TODO: Shut it down!
			self.state = THChannelEnded;
			[self close];
			return;
		}
	}
}

// Flush our out buffer
-(void)flushOut;
{
    [outPacketBuffer forEach:^(THPacket *packet) {
        CLCLogDebug(@"Sending packet on %@ %@", self.line, packet.json);
        [self.toIdentity sendPacket:packet];
    }];
}
@end
