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
#import "THCipherSet.h"

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

+(id)identityFromParts:(NSDictionary *)parts key:(THCipherSet*)cs
{
    THIdentity* identity = [identityCache objectForKey:[THIdentity hashnameForParts:parts]];
    if (!identity) {
        // Load the parts and validate the key
        identity = [[THIdentity alloc] initWithParts:parts key:cs];
        if (identity) [identityCache setObject:identity forKey:identity.hashname];
    }
    return identity;
}

+(id)identityFromHashname:(NSString *)hashname;
{
    THIdentity* identity = [identityCache objectForKey:hashname];
    if (!identity) {
        identity = [[THIdentity alloc] initWithHashname:hashname];
        if (identity) [identityCache setObject:identity forKey:hashname];
    }
    return identity;
}

-(id)init
{
    self = [super init];
    [self commonInit];
    return self;
}

-(id)initWithParts:(NSDictionary *)parts key:(THCipherSet*)cs
{
    self = [super init];
    if (self) {
        NSString* fingerprint = [parts objectForKey:cs.identifier];
        if (![[cs.fingerprint hexString] isEqualToString:fingerprint]) {
            return nil;
        }

        [self commonInit];
        self.cipherParts = @{cs.identifier:cs};
        self->_parts = parts;
    }
    return self;
}

-(id)initWithHashname:(NSString *)hashname
{
    self = [super init];
    if (self) {
        _hashnameCache = hashname;
    }
    return self;
}

-(void)commonInit
{
    self.cipherParts = [NSMutableDictionary dictionary];
    self.availablePaths = [NSArray array];
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
        _hashnameCache = [THIdentity hashnameForParts:self.parts];
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
    NSString* maxPart = [[[self.parts allKeys] sortedArrayUsingSelector:@selector(compare:)] lastObject];
    // XXX TODO: FIXME Set the part on the seek string
    if (!self.address) {
        return [NSString stringWithFormat:@"%@,%@", self.hashname, maxPart];
    } else {
        const struct sockaddr_in* addr = [self.address bytes];
        return [NSString stringWithFormat:@"%@,%@,%s,%d", self.hashname, maxPart, inet_ntoa(addr->sin_addr),addr->sin_port];
    }
}

-(void)addCipherSet:(THCipherSet *)cipherSet
{
    NSMutableDictionary* newParts = [NSMutableDictionary dictionaryWithDictionary:_cipherParts];
    if ([newParts objectForKey:cipherSet.identifier] != nil) {
        NSLog(@"Tried to add an already existing cipher set.");
        return;
    }
    [newParts setObject:cipherSet forKey:cipherSet.identifier];
    _cipherParts = newParts;
    
    NSMutableDictionary* fingerprintParts = [NSMutableDictionary dictionaryWithCapacity:newParts.count];
    for (NSString* csid in newParts) {
        THCipherSet* cs = [newParts objectForKey:csid];
        [fingerprintParts setObject:[cs.fingerprint hexString] forKey:csid];
    }
    _parts = fingerprintParts;
}

-(void)addPath:(THPath *)path
{
    self.availablePaths = [self.availablePaths arrayByAddingObject:path];
}
                            
+(NSString*)hashnameForParts:(NSDictionary*)parts
{
    NSData* shaBuffer = [NSData data];
    NSArray* sortedKeys = [[parts allKeys] sortedArrayUsingSelector: @selector(compare:)];
    for (NSString* key in sortedKeys) {
        SHA256* sha = [SHA256 new];
        [sha updateWithData:shaBuffer];
        [sha updateWithData:[key dataUsingEncoding:NSUTF8StringEncoding]];
        shaBuffer = [sha finish];
        sha = [SHA256 new];
        [sha updateWithData:shaBuffer];
        NSString* value = [parts objectForKey:key];
        [sha updateWithData:[(NSString*)value dataUsingEncoding:NSUTF8StringEncoding]];
        shaBuffer = [sha finish];
    }
    return [shaBuffer hexString];
}
@end
