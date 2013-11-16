//
//  THIdentity.m
//  telehash
//
//  Created by Thomas Muldowney on 10/5/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THIdentity.h"
#import "SHA256.h"
#import "NSData+HexString.h"

@implementation THIdentity
+(id)identityFromPublicKey:(NSString*)publicKeyPath privateKey:(NSString*)privateKeyPath;
{
    return [[THIdentity alloc] initWithPublicKeyPath:publicKeyPath privateKey:privateKeyPath];
}

+(id)identityFromPublicKey:(NSData*)key;
{
    return [[THIdentity alloc] initWithPublicKey:key];
}

-(id)initWithPublicKeyPath:(NSString*)publicKeyPath privateKey:(NSString*)privateKeyPath;
{
    self = [super init];
    if (self) {
        self.rsaKeys = [RSA RSAFromPublicKeyPath:publicKeyPath privateKeyPath:privateKeyPath];
    }
    return self;
}
-(id)initWithPublicKey:(NSData*)key;
{
    self = [super init];
    if (self) {
        self.rsaKeys = [RSA RSAWithPublicKey:key privateKey:nil];
    }
    return self;
}


-(NSString*)hashname;
{
    SHA256* sha = [SHA256 new];
    [sha updateWithData:self.rsaKeys.DERPublicKey];
    return [[sha finalize] hexString];
}

@end
