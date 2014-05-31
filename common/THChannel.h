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
    THChannelPaused,
    THChannelEnded,
    THChannelErrored
} THChannelState;

typedef enum {
	THChannelInbound,
	THChannelOutbound
} THChannelDirection;

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
@property (nonatomic, strong) id<THChannelDelegate> delegate;
@property THIdentity* toIdentity;
@property THLine* line;
@property NSNumber* channelId;
@property THChannelState state;
@property THChannelDirection direction;
@property NSString* type;
@property NSUInteger createdAt;
@property NSUInteger lastInActivity;
@property NSUInteger lastOutActivity;

-(id)initToIdentity:(THIdentity*)identity;
-(void)sendPacket:(THPacket*)packet;
-(void)handlePacket:(THPacket*)packet;
-(void)close;

@end

