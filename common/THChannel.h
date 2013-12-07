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

@protocol THChannelDelegate <NSObject>
#pragma mark State Handling
-(void)channelDidFinishOpen:(THChannel*)channel;
#pragma mark Error Handling
-(void)channel:(THChannel*)channel didFailWithError:(NSError*)error;
-(BOOL)channel:(THChannel*)channel handlePacket:(THPacket*)packet;
@end

@interface THChannel : NSObject

@property NSNumber* maxSeen;
@property NSArray* missing;
@property id<THChannelDelegate> delegate;
@property BOOL channelIsReady;
@property THIdentity* toIdentity;
@property THLine* line;
@property NSString* channelId;

-(id)initToIdentity:(THIdentity*)identity;
// TODO:  init method that allows creation against THSwitch instances other than the shared one
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
    NSUInteger maxProcessed;
}
@property dispatch_queue_t dispatchQueue;
-(id)initToIdentity:(THIdentity*)identity;
-(void)handlePacket:(THPacket*)packet;
-(void)sendPacket:(THPacket*)packet;
-(void)flushOut;
@end

@interface THBulkTransferChannel : THChannel
@end