//
//  E3XChannel.h
//  telehash
//
//  Created by Thomas Muldowney on 10/5/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ECDH.h"
#import "E3XExchange.h"

@class THPacket;
@class THLink;
@class E3XChannel;
@class E3XExchange;
@class THPacketBuffer;

typedef enum {
    E3XChannelOpening,
    E3XChannelOpen,
    E3XChannelPaused,
    E3XChannelEnded,
    E3XChannelErrored
} E3XChannelState;

typedef enum {
	E3XChannelInbound,
	E3XChannelOutbound
} E3XChannelDirection;

@protocol E3XChannelDelegate <NSObject>
#pragma mark State Handling
-(void)channel:(E3XChannel*)channel didChangeStateTo:(E3XChannelState)channelState;
#pragma mark Error Handling
-(void)channel:(E3XChannel*)channel didFailWithError:(NSError*)error;
-(BOOL)channel:(E3XChannel*)channel handlePacket:(THPacket*)packet;
@end

@interface E3XChannel : NSObject

@property NSNumber* maxSeen;
@property NSArray* missing;
@property (nonatomic, strong) id<E3XChannelDelegate> delegate;
@property THLink* toIdentity;
@property E3XExchange* line;
@property NSNumber* channelId;
@property E3XChannelState state;
@property E3XChannelDirection direction;
@property NSString* type;
@property NSUInteger createdAt;
@property NSUInteger lastInActivity;
@property NSUInteger lastOutActivity;

-(id)initToIdentity:(THLink*)identity;
-(void)sendPacket:(THPacket*)packet;
-(void)handlePacket:(THPacket*)packet;
-(void)close;

@end

