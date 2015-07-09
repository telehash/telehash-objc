//
//  E3XCipherSet3a.h
//  telehash
//
//  Created by Thomas Muldowney on 4/21/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "E3XCipherSet.h"
#include <sodium.h>

@interface E3XCipherSet3a : E3XCipherSet
{
    uint8_t publicKey[crypto_box_PUBLICKEYBYTES];
    uint8_t secretKey[crypto_box_SECRETKEYBYTES];
}
-(id)initWithPublicKey:(NSData*)publicKey privateKey:(NSData *)privateKey;
-(id)initWithPublicKeyPath:(NSString*)publicKeyPath privateKeyPath:(NSString*)privateKeyPath;
-(void)savePublicKeyPath:(NSString*)publicKeyPath privateKeyPath:(NSString*)privateKeyPath;
@end

@interface E3XCipherSetLineInfo3a : E3XCipherSetLineInfo
@property (readonly) NSMutableData* publicLineKey;
@property (readonly) NSMutableData* secretLineKey;
@property NSData* remoteLineKey;
@property NSData* encryptorKey;
@property NSData* decryptorKey;
-(id)init;
@end
