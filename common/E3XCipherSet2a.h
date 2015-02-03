//
//  THCipherSet2a.h
//  telehash
//
//  Created by Thomas Muldowney on 4/21/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "E3XCipherSet.h"

@class ECDH;
@class RSA;

@interface E3XCipherSet2a : E3XCipherSet
@property (retain) RSA* rsaKeys;
-(void)generateKeys;
-(id)initWithPublicKeyPath:(NSString*)publicKeyPath privateKeyPath:(NSString*)privateKeyPath;
-(id)initWithPublicKey:(NSData *)publicKey privateKey:(NSData *)privateKey;
-(E3XExchange*)processOpen:(THPacket*)openPacket;
-(void)finalizeLineKeys:(E3XExchange*)line;
-(THPacket*)generateOpen:(E3XExchange*)line from:(THLink*)fromIdentity;
@end

@interface THCipherSetLineInfo2a : THCipherSetLineInfo
@property ECDH* ecdh;
@property NSData* remoteECCKey;
@property NSData* encryptorKey;
@property NSData* decryptorKey;
-(NSData*)encryptLinePacket:(THPacket*)packet;
-(void)decryptLinePacket:(THPacket*)packet;
@end