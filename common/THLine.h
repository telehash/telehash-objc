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

@interface THLine : NSObject

@property THIdentity* toIdentity;
@property ECDH* ecdh;
@property NSString* outLineId;
@property NSString* inLineId;
@property NSData* address;
@property NSData* decryptorKey;
@property NSData* encryptorKey;
@property NSData* remoteECCKey;

-(void)sendOpen;
-(void)handlePacket:(THPacket*)packet;
-(NSString*)seekString;
-(void)sendPacket:(THPacket*)packet;
@end
