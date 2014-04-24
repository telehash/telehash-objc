//
//  THCipherSet2a.h
//  telehash
//
//  Created by Thomas Muldowney on 4/21/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THCipherSet.h"

@class ECDH;
@class RSA;

@interface THCipherSet2a : THCipherSet
@property (retain) RSA* rsaKeys;
-(void)generateKeys;
-(id)initWithPublicKeyPath:(NSString*)publicKeyPath privateKeyPath:(NSString*)privateKeyPath;
-(id)initWithPublicKey:(NSData *)publicKey privateKey:(NSData *)privateKey;
-(THLine*)processOpen:(THPacket*)openPacket;
-(void)finalizeLineKeys:(THLine*)line;
-(THPacket*)generateOpen:(THLine*)line from:(THIdentity*)fromIdentity;
@end

@interface THCipherSetLineInfo2a : THCipherSetLineInfo
@property ECDH* ecdh;
@property NSData* remoteECCKey;
@property NSData* encryptorKey;
@property NSData* decryptorKey;
-(NSData*)encryptLinePacket:(THPacket*)packet;
-(void)decryptLinePacket:(THPacket*)packet;
@end