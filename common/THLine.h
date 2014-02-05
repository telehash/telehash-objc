//
//  THLine.h
//  telehash
//
//  Created by Thomas Muldowney on 11/15/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "THIdentity.h"
#import "ECDH.h"

@class THPacket;
@class THChannel;

@interface THLine : NSObject

@property THIdentity* toIdentity;
@property ECDH* ecdh;
@property NSString* outLineId;
@property NSString* inLineId;
@property NSData* address;
@property NSData* decryptorKey;
@property NSData* encryptorKey;
@property NSData* remoteECCKey;
@property BOOL isOpen;
@property NSUInteger lastActitivy;

-(id)init;
-(void)sendOpen;
-(void)openLine;
-(void)handlePacket:(THPacket*)packet;
-(void)sendPacket:(THPacket*)packet;

@end
