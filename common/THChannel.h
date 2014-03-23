//
//  THChannel.h
//  telehash
//
//  Created by Thomas Muldowney on 10/5/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ECDH.h"
#import "THLine.h"

@class THPacket;
@class THIdentity;
@class THChannel;
@class THLine;
@class THPacketBuffer;

typedef enum {
    THChannelOpening,
    THChannelOpen,
    THChannelEnded,
    THChannelErrored
} THChannelState;

@protocol THChannelDelegate <NSObject>
#pragma mark State Handling
-(void)channel:(THChannel*)channel didChangeStateTo:(THChannelState)channelState;
#pragma mark Error Handling
-(void)channel:(THChannel*)channel didFailWithError:(NSError*)error;
-(BOOL)channel:(THChannel*)channel handlePacket:(THPacket*)packet;
@end

@interface THChannel : NSObject

@property NSNumber* maxSeen;
@property NSArray* missing;
@property (nonatomic, assign) id<THChannelDelegate> delegate;
@property BOOL channelIsReady;
@property THIdentity* toIdentity;
@property THLine* line;
@property NSNumber* channelId;
@property THChannelState state;
@property NSString* type;
@property NSUInteger lastInActivity;
@property NSUInteger lastOutActivity;

-(id)initToIdentity:(THIdentity*)identity;
-(void)sendPacket:(THPacket*)packet;
-(void)handlePacket:(THPacket*)packet;

@end

@interface THUnreliableChannel : THChannel
-(void)handlePacket:(THPacket *)packet;
-(void)sendPacket:(THPacket *)packet;
@end

@interface THReliableChannel : THChannel {
    NSUInteger sequence;
    NSMutableOrderedSet* inBuffer;
    THPacketBuffer* inPacketBuffer;
    THPacketBuffer* outPacketBuffer;
    NSUInteger lastAck;
    NSUInteger nextExpectedSequence;
}
@property dispatch_queue_t dispatchQueue;
-(id)initToIdentity:(THIdentity*)identity;
-(void)handlePacket:(THPacket*)packet;
-(void)sendPacket:(THPacket*)packet;
-(void)flushOut;
@end

@interface THBulkTransferChannel : THChannel
@end