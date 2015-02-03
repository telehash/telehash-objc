//
//  THReliableChannel.h
//  telehash
//
//  Created by Thomas Muldowney on 4/26/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "E3XChannel.h"

@interface E3XReliableChannel : E3XChannel {
    NSUInteger sequence;
    NSMutableOrderedSet* inBuffer;
    THPacketBuffer* inPacketBuffer;
    THPacketBuffer* outPacketBuffer;
    NSUInteger lastAck;
    NSUInteger lastProcessed;
}
@property NSUInteger nextExpectedSequence;
-(id)initToIdentity:(THLink*)identity;
-(void)handlePacket:(THPacket*)packet;
-(void)sendPacket:(THPacket*)packet;
-(void)flushOut;
@end