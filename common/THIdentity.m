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
#import "NSString+HexString.h"

#include <arpa/inet.h>

@interface THIdentity() {
    NSString* _hashnameCache;
}
@end

@implementation THIdentity

+(id)generateIdentity;
{
    THIdentity* identity = [THIdentity new];
    identity.rsaKeys = [RSA generateRSAKeysOfLength:2048];
    return identity;
}

+(id)identityFromHashname:(NSString *)hashname;
{
    return [[THIdentity alloc] initWithHashname:hashname];
}

+(id)identityFromPublicKey:(NSString*)publicKeyPath privateKey:(NSString*)privateKeyPath;
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:publicKeyPath]) return nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:privateKeyPath]) return nil;
    
    return [[THIdentity alloc] initWithPublicKeyPath:publicKeyPath privateKey:privateKeyPath];
}

+(id)identityFromPublicKey:(NSData*)key;
{
    return [[THIdentity alloc] initWithPublicKey:key];
}

-(id)initWithHashname:(NSString *)hashname;
{
    self = [super init];
    if (self) {
        _hashnameCache = hashname;
    }
    return self;
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

-(void)setIP:(NSString*)ip port:(NSUInteger)port;
{
    // Only valid data please
    if (ip == nil || port == 0) return;
    
    struct sockaddr_in ipAddress;
    ipAddress.sin_len = sizeof(ipAddress);
    ipAddress.sin_family = AF_INET;
    ipAddress.sin_port = htons(port);
    inet_pton(AF_INET, [ip UTF8String], &ipAddress.sin_addr);
    self.address = [NSData dataWithBytes:&ipAddress length:ipAddress.sin_len];
}

-(NSString*)hashname;
{
    if (!_hashnameCache) {
        SHA256* sha = [SHA256 new];
        [sha updateWithData:self.rsaKeys.DERPublicKey];
        _hashnameCache = [[sha finalize] hexString];
    }
    return _hashnameCache;
}

int nlz(unsigned long x) {
    if (x == 0) return 4;
    if (x > 0x7) return 0;
    if (x > 0x3) return 1;
    if (x > 0x1) return 2;
    return 3;
}

-(NSInteger)distanceFrom:(THIdentity *)identity;
{
    NSData* ourHashname = [self.hashname dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
    const char* ourHashBytes = (const char*)[ourHashname bytes];
    NSData* remoteHashname = [identity.hashname dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
    const char* remoteHashBytes = (const char*)[remoteHashname bytes];
    NSUInteger totalLength = ourHashname.length;
    char curData[] = {0, 0};
    for (int i = 0; i < totalLength; ++i) {
        curData[0] = ourHashBytes[i];
        unsigned long ours = strtoul(curData, NULL, 16);
        curData[0] = remoteHashBytes[i];
        unsigned long theirs = strtoul(curData, NULL, 16);
        
        unsigned long outBit = ours ^ theirs;
        if (outBit != 0) {
            return 255 - (i * 4 + nlz(outBit));
        }
    }
    return 0;
}

@end
