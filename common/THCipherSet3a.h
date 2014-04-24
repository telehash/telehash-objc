//
//  THCipherSet3a.h
//  telehash
//
//  Created by Thomas Muldowney on 4/21/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THCipherSet.h"
#include <sodium.h>

@interface THCipherSet3a : THCipherSet
{
    uint8_t publicKey[crypto_box_PUBLICKEYBYTES];
    uint8_t secretKey[crypto_box_SECRETKEYBYTES];
}
-(id)initWithPublicKey:(NSData*)publicKey privateKey:(NSData *)privateKey;
-(id)initWithPublicKeyPath:(NSString*)publicKeyPath privateKeyPath:(NSString*)privateKeyPath;
@end

@interface THCipherSetLineInfo3a : THCipherSetLineInfo
@property (readonly) NSMutableData* publicLineKey;
@property (readonly) NSMutableData* secretLineKey;
@property NSData* remoteLineKey;
@property NSData* encryptorKey;
@property NSData* decryptorKey;
-(id)init;
@end
