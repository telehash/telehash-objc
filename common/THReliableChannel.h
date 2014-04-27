//
//  THReliableChannel.h
//  telehash
//
//  Created by Thomas Muldowney on 4/26/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THChannel.h"

@interface THReliableChannel : THChannel {
    NSUInteger sequence;
    NSMutableOrderedSet* inBuffer;
    THPacketBuffer* inPacketBuffer;
    THPacketBuffer* outPacketBuffer;
    NSUInteger lastAck;
}
@property NSUInteger nextExpectedSequence;
@property dispatch_queue_t dispatchQueue;
-(id)initToIdentity:(THIdentity*)identity;
-(void)handlePacket:(THPacket*)packet;
-(void)sendPacket:(THPacket*)packet;
-(void)flushOut;
@end