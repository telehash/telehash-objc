//
//  CTRAES256.m
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "CTRAES256.h"

#include <cryptopp/aes.h>
using CryptoPP::AES;
#include <cryptopp/ccm.h>
using CryptoPP::CTR_Mode;

@interface CTRAES256Encryptor()
{
@private
    CTR_Mode<AES>::Encryption aes;
}
@end

@interface CTRAES256Decryptor()
{
@private
    CTR_Mode<AES>::Decryption aes;
}
@end

@implementation CTRAES256Decryptor
+(NSData*)decryptPlaintext:(NSData*)data key:(NSData*)key iv:(NSData*)iv;
{
    CTRAES256Decryptor* decryptor = [[CTRAES256Decryptor alloc] initWithKey:key iv:iv];
    if (!decryptor) return nil;
    return [decryptor decryptCiphertext:data];
}

-(id)initWithKey:(NSData *)key iv:(NSData *)iv;
{
    self = [super init];
    if (self) {
        self->aes.SetKeyWithIV((const byte*)[key bytes], 32, (const byte*)[iv bytes], 16);
    }
    return self;
}

-(NSData*)decryptCiphertext:(NSData *)ciphertext;
{
    NSMutableData* plaintext = [NSMutableData dataWithLength:[ciphertext length]];
    aes.ProcessData((byte*)[plaintext mutableBytes], (const byte*)[ciphertext bytes], [ciphertext length]);
    return plaintext;
}
@end

@implementation CTRAES256Encryptor
+(NSData*)encryptPlaintext:(NSData*)data key:(NSData*)key iv:(NSData*)iv;
{
    CTRAES256Encryptor* encryptor = [[CTRAES256Encryptor alloc] initWithKey:key iv:iv];
    if (!encryptor) return nil;
    return [encryptor encryptPlaintext:data];
}

-(id)initWithKey:(NSData *)key iv:(NSData *)iv;
{
    self = [super init];
    if (self) {
        self->aes.SetKeyWithIV((const byte*)[key bytes], 32, (const byte*)[iv bytes], 16);
    }
    return self;
}

-(NSData*)encryptPlaintext:(NSData *)plaintext;
{
    NSMutableData* ciphertext = [NSMutableData dataWithLength:[plaintext length]];
    aes.ProcessData((byte*)[ciphertext mutableBytes], (const byte*)[plaintext bytes], [plaintext length]);
    return ciphertext;
}
@end