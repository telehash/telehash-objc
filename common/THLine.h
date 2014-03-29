//
//  THLine.h
//  telehash
//
//  Created by Thomas Muldowney on 11/15/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "THIdentity.h"

@class THPacket;
@class THChannel;
@class THCipherSetLineInfo;
@class THPath;

@interface THLine : NSObject

@property THIdentity* toIdentity;
@property THCipherSetLineInfo* cipherSetInfo;
@property THPath* activePath;
@property NSString* outLineId;
@property NSString* inLineId;
@property NSData* address;
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
-(void)close;
-(void)handleOpen:(THPacket*)openPacket;

@end
