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
#import "THPath.h"
#import "CLCLog.h"
#import "THRelay.h"
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
    } else {
        // Let's make sure we get it set
        identity.cipherParts = @{cs.identifier:cs};
        identity.parts = parts;
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
        [self commonInit];
        _hashnameCache = hashname;
    }
    return self;
}

-(void)commonInit
{
    self.isLocal = NO;
    self.cipherParts = [NSMutableDictionary dictionary];
    self.availablePaths = [NSMutableArray array];
	self.vias = [NSMutableArray array];
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

-(BOOL)hasLink
{
	THChannel* linkChannel = [self channelForType:@"link"];
	if (linkChannel) return YES;
	
	return NO;
}

-(BOOL)isBridged
{
	if (!self.activePath || self.activePath.isBridge) {
		return YES;
	}
	return NO;
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

-(void)sendPacket:(THPacket *)packet path:(THPath*)path
{
    if (!self.currentLine) {
        [[THSwitch defaultSwitch] openLine:self completion:^(THIdentity* lineIdentity) {
            [self.currentLine sendPacket:packet path:path];
        }];
    } else {
        [self.currentLine sendPacket:packet path:path];
    }
}

-(void)sendPacket:(THPacket *)packet
{
    [self sendPacket:packet path:nil];
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

-(NSString*)seekStringForIdentity:(THIdentity*)identity
{
	NSMutableSet* ourIDs = [NSMutableSet setWithArray:[self.cipherParts allKeys]];
    [ourIDs intersectSet:[NSSet setWithArray:[identity.cipherParts allKeys]]];
	
	NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:NO];
    NSArray* sortedCSIds = [ourIDs sortedArrayUsingDescriptors:@[sort]];
	
	if ([sortedCSIds count] > 0) {
		if (!self.address) {
			return [NSString stringWithFormat:@"%@,%@", self.hashname, [sortedCSIds objectAtIndex:0]];
		} else {
			const struct sockaddr_in* addr = [self.address bytes];
			return [NSString stringWithFormat:@"%@,%@,%s,%d", self.hashname, [sortedCSIds objectAtIndex:0], inet_ntoa(addr->sin_addr),addr->sin_port];
		}
	}
	
	return nil;
}

-(void)addCipherSet:(THCipherSet *)cipherSet
{
    NSMutableDictionary* newParts = [NSMutableDictionary dictionaryWithDictionary:_cipherParts];
    if ([newParts objectForKey:cipherSet.identifier] != nil) {
        CLCLogInfo(@"Tried to add an already existing cipher set.");
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
    // Make sure we don't already have this path
    THPath* existingPath = [self pathMatching:path.information];
    if (existingPath) return;
    
    // See if this path matches any of ours and flag it as local
    THSwitch* thSwitch = [THSwitch defaultSwitch];
    for (THPath* switchPath in thSwitch.identity.availablePaths) {
        if ([switchPath pathIsLocalTo:path]) {
            self.isLocal = YES;
            break;
        }
    }
    
    [self.availablePaths addObject:path];
}

-(NSArray*)pathInformationTo:(THIdentity *)toIdentity allowLocal:(BOOL)allowLocal
{
    NSMutableArray* paths = [NSMutableArray arrayWithCapacity:self.availablePaths.count];
    for(THPath* path in self.availablePaths) {
        if (path.isLocal && !toIdentity.isLocal) continue;
        if (path.isLocal && !allowLocal) continue;
		if (path.isBridge) continue;
		
        [paths addObject:[path information]];
    }
    return paths;
}

-(THPath*)pathMatching:(NSDictionary *)pathInfo
{
    //CLCLogDebug(@"Starting comparisons with %@ against %@", pathInfo, self.availablePaths);
    for (THPath* path in self.availablePaths) {
        if ([path.information isEqualToDictionary:pathInfo]) {
            //CLCLogDebug(@"Matched against %@", path.information);
            return path;
        }
    }

    //CLCLogDebug(@"Didn't match %@", pathInfo);
    return nil;
}

-(void)checkPriorityPath:(THPath *)path
{
    path.priority = 0;
    
    // Local paths are preferred
    if (self.isLocal && path.isLocal) ++path.priority;
    // IP Paths give us better bandwidth usually, prefer them
    if ([path class] == [THIPV4Path class]) ++path.priority;
    
    // If the active path is preferred, go ahead and switch
    if (path.priority > self.activePath.priority) {
        CLCLogInfo(@"Setting active path for %@ to %@", self.hashname, path.information);
        self.activePath = path;
    }
}

-(void)addVia:(THIdentity*)viaIdentity
{
	// quick and dirty to ensure no duups
	[self.vias removeObject:viaIdentity];
	[self.vias addObject:viaIdentity];
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

-(void)closeChannels
{
	[self.channels enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		THChannel* curChannel = (THChannel*)obj;
		curChannel.state = THChannelEnded;
	}];
	
	[self.channels removeAllObjects];
}

-(void)reset
{
	CLCLogWarning(@"resetting identity with hashname %@", self.hashname);
	[self closeChannels];

	[self.availablePaths removeAllObjects];
	[self.vias removeAllObjects];
	
	self.activePath = nil;
	
	// lets REALLY ensure relay is destroyed
	if (self.relay) {
		if (self.relay.peerChannel) {
			[self.relay.peerChannel close];
		}
		self.relay = nil;
	}
	
	self.currentLine = nil;
}
@end
