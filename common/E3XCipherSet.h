//
//  THCipherSet.h
//  telehash
//
//  Created by Thomas Muldowney on 2/27/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@class THPacket;
@class THMesh;
@class E3XExchange;
@class THLink;

@interface E3XCipherSet : NSObject
@property (readonly) NSData* fingerprint;
@property (readonly) NSData* publicKey;
+(E3XCipherSet*)cipherSetForOpen:(THPacket*)openPacket;
-(E3XExchange*)processOpen:(THPacket*)openPacket;
-(void)finalizeLineKeys:(E3XExchange*)line;
-(THPacket*)generateOpen:(E3XExchange*)line from:(THLink*)fromIdentity;
-(void)generateKeys;
-(NSString*)identifier;
@end

@interface THCipherSetLineInfo : NSObject
@property E3XCipherSet* cipherSet;
-(NSData*)encryptLinePacket:(THPacket*)packet;
-(void)decryptLinePacket:(THPacket*)packet;
@end
