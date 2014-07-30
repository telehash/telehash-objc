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
	THChannelInbound,
	THChannelOutbound
} THChannelDirection;


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

