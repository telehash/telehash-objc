//
//  THPath.m
//  telehash
//
//  Created by Thomas Muldowney on 3/17/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THPath.h"
#import "THPeerRelay.h"
#import "THSwitch.h"
#import "GCDAsyncUdpSocket.h"
#import "THPacket.h"
#import "THTransport.h"
#import "THUnreliableChannel.h"
#import "CLCLog.h"
#include <arpa/inet.h>

#define PRIVATE_192_FIRST   0x0000a8c0
#define PRIVATE_C_MASK      0x0000ffff
#define PRIVATE_172_FIRST   0x000010ac
#define PRIVATE_B_MASK      0x00000fff
#define PRIVATE_127_FIRST   0x0000007f
#define PRIVATE_10_FIRST    0x000000a0
#define PRIVATE_A_MASK      0x000000ff

@implementation THPath
-(void)sendPacket:(THPacket*)packet
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

-(NSDictionary*)information
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return nil;
}

-(BOOL)isLocal
{
    return NO;
}

-(BOOL)pathIsLocalTo:(THPath *)path
{
    return NO;
}

-(BOOL)isRelay
{
    return NO;
}
@end


@implementation THIPV4Path
{
    NSData* toAddress;
}

+(void)initialize
{
    if (THPathTypeRegistry == nil) {
        THPathTypeRegistry = [NSMutableArray array];
    }
    [THPathTypeRegistry addObject:@"ipv4"];
}

+(NSData*)addressTo:(NSString*)ip port:(NSUInteger)port
{
    struct sockaddr_in ipAddress;
    ipAddress.sin_len = sizeof(ipAddress);
    ipAddress.sin_family = AF_INET;
    ipAddress.sin_port = htons(port);
    inet_pton(AF_INET, [ip UTF8String], &ipAddress.sin_addr);
    return [NSData dataWithBytes:&ipAddress length:ipAddress.sin_len];
}

-(NSString*)typeName
{
    return @"ipv4";
}

-(id)initWithTransport:(THTransport *)transport toAddress:(NSData *)address
{
    self = [super init];
    if (self) {
        self.transport = transport;
        toAddress = address;
    }
    return self;
}

-(id)initWithTransport:(THTransport *)transport ip:(NSString *)ip port:(NSUInteger)port
{
    // Only valid data please
    if (ip == nil || port == 0) return nil;
    
    self = [super init];
    if (self) {
        self.transport = transport;
        
        struct sockaddr_in ipAddress;
        ipAddress.sin_family = AF_INET;
        ipAddress.sin_port = htons(port);
        inet_pton(AF_INET, [ip UTF8String], &(ipAddress.sin_addr));
        toAddress = [NSData dataWithBytes:&ipAddress length:sizeof(struct sockaddr_in)];
    }
    return self;
}

-(NSData*)address
{
    return toAddress;
}

-(BOOL)isLocal
{
    struct sockaddr_in* saddr = (struct sockaddr_in*)[toAddress bytes];
    
    in_addr_t addr = saddr->sin_addr.s_addr;
    
    if ((addr & PRIVATE_C_MASK) == PRIVATE_192_FIRST) return YES;
    if ((addr & PRIVATE_B_MASK) == PRIVATE_172_FIRST) return YES;
    if ((addr & PRIVATE_A_MASK) == PRIVATE_127_FIRST) return YES;
    if ((addr & PRIVATE_A_MASK) == PRIVATE_10_FIRST) return YES;

    return NO;
}

-(NSString*)ip
{
    return [GCDAsyncUdpSocket hostFromAddress:toAddress];
}

-(NSUInteger)port
{
    NSUInteger port = [GCDAsyncUdpSocket portFromAddress:toAddress];
    if (port == 0) {
        port = ((THIPv4Transport*)self.transport).port;
    }
    return port;
}

-(void)dealloc
{
    
    CLCLogDebug(@"Path go bye bye for %@ %d", [GCDAsyncUdpSocket hostFromAddress:toAddress], [GCDAsyncUdpSocket portFromAddress:toAddress]);
}

-(void)sendPacket:(THPacket *)packet
{
    //TODO:  Evaluate using a timeout!
    NSData* packetData = [packet encode];
    CLCLogDebug(@"THIPV4Path Sending to %@: %@", self.information, packetData);
    [self.transport send:packetData to:toAddress];
}

-(NSDictionary*)information
{
    NSString* ip;
    uint16_t port;
    
    [GCDAsyncUdpSocket getHost:&ip port:&port fromAddress:toAddress];
    
    return @{
        @"type":self.typeName,
        @"ip":self.ip,
        @"port":@(self.port)
    };
}

-(BOOL)pathIsLocalTo:(THPath *)path
{
    // We can only compare our own type
    if ([path class] != [self class]) return NO;
    
    THIPV4Path* toPath = (THIPV4Path*)path;
    
    if ([toPath.ip isEqualToString:self.ip]) return YES;
    return NO;
}
@end

@implementation THRelayPath {
    THRelayTransport* _relayTransport;
}

-(void)dealloc
{
    CLCLogDebug(@"We lost a relay!");
}

-(id)initOnChannel:(THUnreliableChannel *)channel
{
    self = [super init];
    if (self) {
        _relayTransport = [[THRelayTransport alloc] initWithPath:self];
        self.relayedPath = channel.toIdentity.activePath;
        self.peerChannel = channel;
    }
    return self;
}

-(THTransport*)transport
{
    return _relayTransport;
}

-(BOOL)isRelay
{
    return YES;
}

-(NSString*)typeName
{
    return @"relay";
}

-(void)sendPacket:(THPacket *)packet
{
    if (!self.peerChannel || ![self.peerChannel isKindOfClass:[THChannel class]]) return;
    
    THPacket* relayPacket = [THPacket new];
    relayPacket.body = [packet encode];
    
    CLCLogDebug(@"Relay sending %@", packet.json);
    [self.peerChannel sendPacket:relayPacket];
}

-(BOOL)channel:(THChannel *)channel handlePacket:(THPacket *)packet
{
    THPacket* relayedPacket = [THPacket packetData:packet.body];
    if (!relayedPacket) {
        CLCLogInfo(@"Garbage on the relay, invalid or unparseable packet.");
        return YES;
    }
    relayedPacket.returnPath = self;
    THTransport* transport = self.relayedPath.transport;
    if ([transport.delegate respondsToSelector:@selector(transport:handlePacket:)]) {
        [transport.delegate transport:self.transport handlePacket:relayedPacket];
    }
    
    return YES;
}

-(void)channel:(THChannel *)channel didFailWithError:(NSError *)error
{
    // XXX TODO: Shutdown the busted path
	CLCLogDebug(@"relay peerChannel didFailWithError: %@", [error description]);
}

-(void)channel:(THChannel *)channel didChangeStateTo:(THChannelState)channelState
{
	CLCLogDebug(@"relay peerChannel didChangeStateTo: %d", channelState);

    // XXX TODO:  Shutdown on channel ended
	if (channelState == THChannelEnded || channelState == THChannelErrored) {
		if (channel == self.peerChannel) {
			CLCLogDebug(@"relay peerChannel closed");
			self.peerChannel = nil;
		}
	}
	
}

-(NSDictionary*)information
{
	if (self.peerChannel && [self.peerChannel isKindOfClass:[THChannel class]]) {
		return @{@"type":@"relay", @"to":self.peerChannel.toIdentity.hashname};
	} else {
		return @{@"type":@"relay"};
	}
}

-(NSDictionary*)informationTo:(NSData *)address
{
    return nil;
}
@end

