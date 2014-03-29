//
//  GCMAES256.m
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "GCMAES256.h"

#include <cryptopp/aes.h>
using CryptoPP::AES;
#include <cryptopp/gcm.h>

@interface GCMAES256Encryptor()
{
@private
    CryptoPP::GCM<AES>::Encryption aes;
}
@end

@interface GCMAES256Decryptor()
{
@private
    CryptoPP::GCM<AES>::Decryption aes;
}
@end

@implementation GCMAES256Decryptor
+(GCMAES256Decryptor*)decryptPlaintext:(NSData*)data mac:(NSData*)mac key:(NSData*)key iv:(NSData*)iv;
{
    GCMAES256Decryptor* decryptor = [[GCMAES256Decryptor alloc] initWithKey:key iv:iv];
    if (!decryptor) return nil;
    decryptor->_plainText = [NSMutableData dataWithLength:data.length];
    bool verified = decryptor->aes.DecryptAndVerify((byte*)[decryptor->_plainText mutableBytes], (const byte*)[mac bytes], mac.length, (const byte*)[iv bytes], 16, 0, 0, (const byte*)[data bytes], data.length);
    if (!verified) return nil;
    return decryptor;
}

-(id)initWithKey:(NSData *)key iv:(NSData *)iv;
{
    self = [super init];
    if (self) {
        self->aes.SetKeyWithIV((const byte*)[key bytes], 32, (const byte*)[iv bytes], 16);
    }
    return self;
}
@end

@implementation GCMAES256Encryptor
+(GCMAES256Encryptor*)encryptPlaintext:(NSData*)data key:(NSData*)key iv:(NSData*)iv
{
    return [GCMAES256Encryptor encryptPlaintext:data key:key iv:iv macLength:0];
}

+(GCMAES256Encryptor*)encryptPlaintext:(NSData*)data key:(NSData*)key iv:(NSData*)iv macLength:(unsigned int)macLength
{
    GCMAES256Encryptor* encryptor = [[GCMAES256Encryptor alloc] initWithKey:key iv:iv];
    if (!encryptor) return nil;
    
    encryptor->_cipherText = [NSMutableData dataWithLength:data.length];
    unsigned int macSize = macLength == 0 ? encryptor->aes.DigestSize() : macLength;
    encryptor->_mac = [NSMutableData dataWithLength:macSize];
    encryptor->aes.EncryptAndAuthenticate((byte*)[encryptor->_cipherText mutableBytes], (byte*)[encryptor->_mac mutableBytes], macSize, (const byte*)[iv bytes], 16, 0, 0, (const byte*)[data bytes], data.length);
    
    return encryptor;
}

-(id)initWithKey:(NSData *)key iv:(NSData *)iv;
{
    self = [super init];
    if (self) {
        self->aes.SetKeyWithIV((const byte*)[key bytes], 32, (const byte*)[iv bytes], 16);
    }
    return self;
}
@end