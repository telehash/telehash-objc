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
#include <arpa/inet.h>

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
        ipAddress.sin_len = sizeof(ipAddress);
        ipAddress.sin_family = AF_INET;
        ipAddress.sin_port = htons(port);
        inet_pton(AF_INET, [ip UTF8String], &ipAddress.sin_addr);
        toAddress = [NSData dataWithBytes:&ipAddress length:ipAddress.sin_len];
    }
    return self;
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
    
    NSLog(@"Path go bye bye for %@ %d", [GCDAsyncUdpSocket hostFromAddress:toAddress], [GCDAsyncUdpSocket portFromAddress:toAddress]);
}

-(void)sendPacket:(THPacket *)packet
{
    //TODO:  Evaluate using a timeout!
    NSData* packetData = [packet encode];
    //NSLog(@"Sending %@", packetData);
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
@end

@implementation THRelayPath
-(id)initOnChannel:(THUnreliableChannel *)channel
{
    self = [super init];
    if (self) {
        self.relayedPath = channel.toIdentity.activePath;
        self.transport = self.relayedPath.transport;
        self.peerChannel = channel;
    }
    return self;
}

-(NSString*)typeName
{
    return @"relay";
}

-(void)sendPacket:(THPacket *)packet
{
    if (!self.peerChannel) return;
    
    THPacket* relayPacket = [THPacket new];
    relayPacket.body = [packet encode];
    
    NSLog(@"Relay sending %@", packet.json);
    [self.peerChannel sendPacket:relayPacket];
}

-(BOOL)channel:(THChannel *)channel handlePacket:(THPacket *)packet
{
    THPacket* relayedPacket = [THPacket packetData:packet.body];
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
}

-(void)channel:(THChannel *)channel didChangeStateTo:(THChannelState)channelState
{
    // XXX TODO:  Shutdown on channel ended
}

-(NSDictionary*)information
{
    return nil;
}

-(NSDictionary*)informationTo:(NSData *)address
{
    return nil;
}
@end

