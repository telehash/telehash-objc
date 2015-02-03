//
//  THLine.h
//  telehash
//
//  Created by Thomas Muldowney on 11/15/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "THLink.h"
#import "THMesh.h"
#import "E3XChannel.h"

@class THPacket;
@class E3XChannel;
@class THCipherSetLineInfo;
@class THPath;

@interface E3XExchange : NSObject

@property THLink* toIdentity;
@property THCipherSetLineInfo* cipherSetInfo;
@property THPacket* cachedOpen;

@property NSString* outLineId;
@property NSString* inLineId;
@property BOOL isOpen;
@property NSUInteger lastActitivy;
@property NSUInteger lastInActivity;
@property NSUInteger lastOutActivity;
@property NSUInteger createdAt;
@property (readonly) NSUInteger nextChannelId;

-(id)init;
-(void)sendOpen;
-(void)openLine;
-(void)handlePacket:(THPacket*)packet;
-(void)sendPacket:(THPacket*)packet;
-(void)sendPacket:(THPacket *)packet path:(THPath*)path;
-(void)close;
-(void)handleOpen:(THPacket*)openPacket;
-(void)negotiatePath;
-(void)addChannelHandler:(id)handler;
-(void)removeChannelHandler:(id)handler;

@end
