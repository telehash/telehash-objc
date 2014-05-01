//
//  THCipherSet.h
//  telehash
//
//  Created by Thomas Muldowney on 2/27/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@class THPacket;
@class THSwitch;
@class THLine;
@class THIdentity;

@interface THCipherSet : NSObject
@property (readonly) NSData* fingerprint;
@property (readonly) NSData* publicKey;
+(THCipherSet*)cipherSetForOpen:(THPacket*)openPacket;
-(THLine*)processOpen:(THPacket*)openPacket;
-(void)finalizeLineKeys:(THLine*)line;
-(THPacket*)generateOpen:(THLine*)line from:(THIdentity*)fromIdentity;
-(void)generateKeys;
-(NSString*)identifier;
@end

@interface THCipherSetLineInfo : NSObject
@property THCipherSet* cipherSet;
-(NSData*)encryptLinePacket:(THPacket*)packet;
-(void)decryptLinePacket:(THPacket*)packet;
@end
