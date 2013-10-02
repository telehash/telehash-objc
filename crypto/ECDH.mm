//
//  ECDH.m
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "ECDH.h"

#include <cryptopp/asn.h>
using CryptoPP::OID;

#include <cryptopp/oids.h>

#include <cryptopp/eccrypto.h>
using CryptoPP::ECP;

#include <cryptopp/osrng.h>
using CryptoPP::AutoSeededRandomPool;

@interface ECDH()
{
@private
    CryptoPP::ECDH<ECP>::Domain* domain;
}
@end

@implementation ECDH

-(id)init;
{
    self = [super init];
    if (self) {
        _privateKey = [NSMutableData dataWithCapacity:self.privateKeyLength];
        _publicKey = [NSMutableData dataWithCapacity:self.publicKeyLength];
        
        domain = new CryptoPP::ECDH<ECP>::Domain(CryptoPP::ASN1::secp256r1());
        AutoSeededRandomPool rng;
        domain->GenerateKeyPair(rng, (byte*)[self->_privateKey mutableBytes], (byte*)[self->_publicKey mutableBytes]);
    }
    return self;
}

-(void)dealloc;
{
    delete domain;
}

-(unsigned long) publicKeyLength;
{
    return domain->PublicKeyLength();
}

-(unsigned long) privateKeyLength;
{
    return domain->PrivateKeyLength();
}

-(unsigned long) agreedValueLength;
{
    return domain->AgreedValueLength();
}

-(NSData*)agreeWithRemotePublicKey:(NSData*)remotePublicKey;
{
    NSMutableData* agreedValue = [NSMutableData dataWithCapacity:domain->AgreedValueLength()];
    if (!domain->CryptoPP::SimpleKeyAgreementDomain::Agree((byte*)[agreedValue mutableBytes], (const byte*)[_privateKey bytes], (const byte*)[remotePublicKey bytes])) {
        return nil;
    }
    return agreedValue;
}

@end
