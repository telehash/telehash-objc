//
//  RSA.m
//  telehash
//
//  Created by Thomas Muldowney on 9/30/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "RSA.h"

#include <cryptopp/rsa.h>
using CryptoPP::RSAES;
using CryptoPP::RSASS;
using CryptoPP::OAEP;
#include <cryptopp/osrng.h>
using CryptoPP::AutoSeededRandomPool;
#include <cryptopp/filters.h>
using CryptoPP::StringSink;
using CryptoPP::StringSource;
using CryptoPP::StreamTransformationFilter;
#include <cryptopp/files.h>
using CryptoPP::FileSource;

#include <cryptopp/sha.h>
using CryptoPP::SHA;
using CryptoPP::SHA256;

#include <cryptopp/cryptlib.h>
using CryptoPP::Exception;
using CryptoPP::DecodingResult;

using CryptoPP::PKCS1v15;


@interface RSA ()
{
    CryptoPP::RSA::PublicKey publicKey;
    CryptoPP::RSA::PrivateKey privateKey;
}
@end

@implementation RSA

+(id)generateRSAKeysOfLength:(unsigned int)length;
{
    CryptoPP::AutoSeededRandomPool rng;
    CryptoPP::RSA::PrivateKey pkey;
    pkey.GenerateRandomWithKeySize(rng, length);
    
    RSA* instance = [RSA new];
    instance->publicKey = CryptoPP::RSA::PublicKey(pkey);
    instance->privateKey = pkey;
    
    return instance;
}

-(unsigned long)signatureLength;
{
    RSASS<PKCS1v15, SHA256>::Signer signer(self->privateKey);
    return signer.SignatureLength();
}

-(NSData*)DERPublicKey;
{
    CryptoPP::ByteQueue bytes;
    self->publicKey.DEREncode(bytes);
    
    NSMutableData* DERData = [NSMutableData dataWithLength:bytes.MaxRetrievable()];
    
    CryptoPP::ArraySink out((byte*)[DERData mutableBytes], [DERData length]);
    self->publicKey.DEREncode(out);
    out.MessageEnd();
    
    return DERData;
}

+(id)RSAFromPublicKeyPath:(NSString*)publicKeyPath privateKeyPath:(NSString*)privateKeyPath;
{
    RSA* newInstance = [RSA new];
    
    CryptoPP::ByteQueue bytes;
    
    CryptoPP::FileSource publicFS([publicKeyPath UTF8String], true);
    publicFS.TransferTo(bytes);
    bytes.MessageEnd();
    newInstance->publicKey.Load(bytes);
    
    CryptoPP::FileSource privateFS([privateKeyPath UTF8String], true);
    bytes.Clear();
    privateFS.TransferTo(bytes);
    bytes.MessageEnd();
    newInstance->privateKey.Load(bytes);
    
    AutoSeededRandomPool rng;
    if (!newInstance->publicKey.Validate(rng, 3)) {
        printf("Public key did not validate\n");
    }
    if (!newInstance->privateKey.Validate(rng, 3)) {
        printf("Private key did not validate\n");
    }
    
    return newInstance;
}

+(id)RSAWithPublicKey:(NSData*)publicKey privateKey:(NSData*)privateKey;
{
    RSA* newInstance = [RSA new];

    if (publicKey != nil) {
        CryptoPP::ByteQueue bytes;
        CryptoPP::StringSource inKey((const byte*)[publicKey bytes], [publicKey length], true);
        inKey.TransferTo(bytes);
        newInstance->publicKey.Load(bytes);
        
        AutoSeededRandomPool rng;
        if (!newInstance->publicKey.Validate(rng, 3)) {
            printf("Public key did not validate\n");
        }
    }
    
    if (privateKey != nil) {
        CryptoPP::ByteQueue bytes;
        CryptoPP::StringSource inKey((const byte*)[privateKey bytes], [privateKey length], true);
        inKey.TransferTo(bytes);
        newInstance->privateKey.Load(bytes);
        
        AutoSeededRandomPool rng;
        if (!newInstance->privateKey.Validate(rng, 3)) {
            printf("Public key did not validate\n");
        }
    }
    
    return newInstance;
}

-(NSData*)sign:(NSData*)data;
{
    RSASS<PKCS1v15, SHA256>::Signer signer(self->privateKey);
    AutoSeededRandomPool rng;
    
    NSMutableData* signature = [NSMutableData dataWithLength:self.signatureLength];
    signer.SignMessage(rng, (const byte*)[data bytes], [data length], (byte*)[signature mutableBytes]);
    
    return signature;
}

-(unsigned long) encryptedLength:(unsigned long)plaintextLength;
{
    RSAES< OAEP<SHA> >::Encryptor encryptor(self->publicKey);
    return encryptor.CiphertextLength(plaintextLength);
}

-(NSData*) encrypt:(NSData*)plaintext;
{
    RSAES< OAEP<SHA> >::Encryptor encryptor(self->publicKey);
    AutoSeededRandomPool rng;
    
    NSMutableData* cipherText = [NSMutableData dataWithLength:[self encryptedLength:[plaintext length]]];
    encryptor.Encrypt(rng, (const byte*)[plaintext bytes], [plaintext length], (byte*)[cipherText mutableBytes]);
    
    return cipherText;
}

-(NSData*) decrypt:(NSData*)cipherText;
{
    RSAES< OAEP<SHA> >::Decryptor decryptor(self->privateKey);
    AutoSeededRandomPool rng;
    
    NSMutableData* plaintext = [NSMutableData dataWithLength:decryptor.MaxPlaintextLength([cipherText length])];
    DecodingResult result = decryptor.Decrypt(rng, (const byte*)[cipherText bytes], [cipherText length], (byte*)[plaintext mutableBytes]);
    [plaintext setLength:result.messageLength];
    return plaintext;
}

-(BOOL) verify:(NSData*)message withSignature:(NSData*)signature;
{
    RSASS<PKCS1v15, SHA256>::Verifier verifier(self->publicKey);
    return verifier.VerifyMessage((const byte*)[message bytes], [message length], (const byte*)[signature bytes], [signature length]);
}

-(void)savePublicKey:(NSString *)publicPath privateKey:(NSString *)privatePath
{
    [[self DERPublicKey] writeToFile:publicPath atomically:YES];
    
    CryptoPP::ByteQueue bytes;
    self->privateKey.DEREncode(bytes);
    
    NSMutableData* DERData = [NSMutableData dataWithLength:bytes.MaxRetrievable()];
    
    CryptoPP::ArraySink out((byte*)[DERData mutableBytes], [DERData length]);
    self->privateKey.DEREncode(out);
    out.MessageEnd();
    
    [DERData writeToFile:privatePath atomically:YES];
}

@end
