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
#import "THPacket.h"
#import "THLine.h"
#import "THSwitch.h"
#import "THChannel.h"
#import "CTRAES256.h"

#include <arpa/inet.h>

static NSMutableDictionary* identityCache;

@interface THIdentity() {
    NSString* _hashnameCache;
}
@end

@implementation THIdentity

+ (void)initialize {
    if (self == [THIdentity self]) {
        identityCache = [NSMutableDictionary dictionary];
    }
}

+(id)generateIdentity;
{
    THIdentity* identity = [THIdentity new];
    identity.rsaKeys = [RSA generateRSAKeysOfLength:2048];
    [identityCache setObject:identity forKey:identity.hashname];
    return identity;
}

+(id)identityFromHashname:(NSString *)hashname;
{
    THIdentity* identity = [identityCache objectForKey:hashname];
    if (!identity) {
        identity = [[THIdentity alloc] initWithHashname:hashname];
        [identityCache setObject:identity forKey:hashname];
    }
    return identity;
}

+(id)identityFromPublicFile:(NSString*)publicKeyPath privateFile:(NSString*)privateKeyPath;
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:publicKeyPath]) return nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:privateKeyPath]) return nil;
    
    // TODO:  Deal with cacheing this?
    RSA* rsaKeys = [RSA RSAFromPublicKeyPath:publicKeyPath privateKeyPath:privateKeyPath];
    SHA256* sha = [SHA256 new];
    [sha updateWithData:rsaKeys.DERPublicKey];
    NSString* hashname = [[sha finish] hexString];
    THIdentity* cachedIdentity = [identityCache objectForKey:hashname];
    if (!cachedIdentity) {
        cachedIdentity = [THIdentity new];
        [identityCache setObject:cachedIdentity forKey:hashname];
    }
    cachedIdentity.rsaKeys = rsaKeys;
    return cachedIdentity;
}

+(id)identityFromPublicKey:(NSData *)publicKey privateKey:(NSData *)privateKey
{
    SHA256* sha = [SHA256 new];
    [sha updateWithData:publicKey];
    NSString* hashname = [[sha finish] hexString];

    THIdentity* identity = [identityCache objectForKey:hashname];
    if (!identity) {
        identity = [[THIdentity alloc] initWithPublicKey:publicKey privateKey:privateKey];
        [identityCache setObject:identity forKey:identity.hashname];
    }
    identity.rsaKeys = [RSA RSAWithPublicKey:publicKey privateKey:privateKey];
    return identity;
}

+(id)identityFromPublicKey:(NSData*)key;
{
    SHA256* sha = [SHA256 new];
    [sha updateWithData:key];
    NSString* hashname = [[sha finish] hexString];

    THIdentity* identity = [identityCache objectForKey:hashname];
    if (!identity) {
        identity = [[THIdentity alloc] initWithPublicKey:key privateKey:nil];
        [identityCache setObject:identity forKey:identity.hashname];
    } else {
        identity.rsaKeys = [RSA RSAWithPublicKey:key privateKey:nil];
    }
    return identity;
}

-(id)initWithHashname:(NSString *)hashname;
{
    self = [super init];
    if (self) {
        [self commonInit];
        _hashnameCache = hashname;
    }
    return self;
}

-(id)initWithPublicKeyPath:(NSString*)publicKeyPath privateKey:(NSString*)privateKeyPath;
{
    self = [super init];
    if (self) {
        [self commonInit];
        self.rsaKeys = [RSA RSAFromPublicKeyPath:publicKeyPath privateKeyPath:privateKeyPath];
    }
    return self;
}

-(id)initWithPublicKey:(NSData*)key privateKey:(NSData *)privateKey
{
    self = [super init];
    if (self) {
        [self commonInit];
        self.rsaKeys = [RSA RSAWithPublicKey:key privateKey:privateKey];
    }
    return self;
}

-(void)commonInit
{
    self.channels = [NSMutableDictionary dictionary];
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
        _hashnameCache = [[sha finish] hexString];
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

-(void)sendPacket:(THPacket *)packet
{
    if (!self.currentLine) {
        [[THSwitch defaultSwitch] openLine:self completion:^(THIdentity* lineIdentity) {
            [self.currentLine sendPacket:packet];
        }];
    } else {
        [self.currentLine sendPacket:packet];
    }
}

-(THChannel*)channelForType:(NSString *)type
{
    __block THChannel* foundChannel = nil;
    [self.channels enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        THChannel* channel = (THChannel*)obj;
        if ([channel.type isEqualToString:type]) {
            foundChannel = channel;
            *stop = YES;
        }
    }];
    
    return foundChannel;
}

-(NSString*)seekString
{
    if (!self.address) return self.hashname;
    const struct sockaddr_in* addr = [self.address bytes];
    return [NSString stringWithFormat:@"%@,%s,%d", self.hashname, inet_ntoa(addr->sin_addr),addr->sin_port];

}

-(void)processOpenPacket:(THPacket*)openPacket innerPacket:(THPacket *)innerPacket
{
    
}
@end
