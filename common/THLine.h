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
@class THCipherSet;

@interface THLine : NSObject

@property THIdentity* toIdentity;
@property THCipherSet* cipherSet;
@property NSString* outLineId;
@property NSString* inLineId;
@property NSData* address;
@property NSData* decryptorKey;
@property NSData* encryptorKey;
@property NSData* remoteECCKey;
@property BOOL isOpen;
@property NSUInteger lastActitivy;
@property NSUInteger lastInActivity;
@property NSUInteger lastOutActivity;
@property NSUInteger createdAt;

-(id)init;
-(void)sendOpen;
-(void)openLine;
-(void)handlePacket:(THPacket*)packet;
-(void)sendPacket:(THPacket*)packet;
-(void)close;
-(void)handleOpen:(THPacket*)openPacket;

+(THLine*)processOpen:(THPacket*)packet;

@end
