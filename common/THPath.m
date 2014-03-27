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
#include <arpa/inet.h>

@implementation THPath

@end

@implementation THIPV4Path
{
    GCDAsyncUdpSocket* udpSocket;
    NSData* toAddress;
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

-(id)init
{
    self = [super init];
    if (self) {
        udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    }
    return self;
}

-(id)initWithSocket:(GCDAsyncUdpSocket*)socket toAddress:(NSData*)address
{
    self = [super init];
    if (self) {
        udpSocket = socket;
        toAddress = address;
    }
    return self;
}

-(id)initWithSocket:(GCDAsyncUdpSocket *)socket ip:(NSString *)ip port:(NSUInteger)port
{
    // Only valid data please
    if (ip == nil || port == 0) return nil;
    
    self = [super init];
    if (self) {
        udpSocket = socket;

        
        struct sockaddr_in ipAddress;
        ipAddress.sin_len = sizeof(ipAddress);
        ipAddress.sin_family = AF_INET;
        ipAddress.sin_port = htons(port);
        inet_pton(AF_INET, [ip UTF8String], &ipAddress.sin_addr);
        toAddress = [NSData dataWithBytes:&ipAddress length:ipAddress.sin_len];
    }
    return self;
}

-(THPath*)returnPathTo:(NSData*)address
{
    THIPV4Path* returnPath = [[THIPV4Path alloc] initWithSocket:udpSocket toAddress:address];
    return returnPath;
}

-(void)dealloc
{
    NSLog(@"Path go bye bye");
}

-(void)start;
{
    [self startOnPort:0];
}
-(void)startOnPort:(unsigned short)port
{
    NSError* bindError;
    [udpSocket bindToPort:port error:&bindError];
    if (bindError != nil) {
        // TODO:  How do we show errors?!
        NSLog(@"%@", bindError);
        return;
    }
    NSLog(@"Now listening on %d", udpSocket.localPort);
    NSError* recvError;
    [udpSocket beginReceiving:&recvError];
    // TODO: Needs more error handling
}

// TODO XXX FIXME Manage the listening side of the socket too!
-(void)sendPacket:(THPacket *)packet
{
    //TODO:  Evaluate using a timeout!
    NSData* packetData = [packet encode];
    //NSLog(@"Sending %@", packetData);
    [udpSocket sendData:packetData toAddress:toAddress withTimeout:-1 tag:0];
}

#pragma region -- UDP Handlers

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    const struct sockaddr_in* addr = [address bytes];
    //NSLog(@"Incoming data from %@", [NSString stringWithUTF8String:inet_ntoa(addr->sin_addr)]);
    THPacket* incomingPacket = [THPacket packetData:data];
    incomingPacket.fromAddress = address;
    if (!incomingPacket) {
        NSLog(@"Unexpected or unparseable packet from %@: %@", [NSString stringWithUTF8String:inet_ntoa(addr->sin_addr)], [data base64EncodedStringWithOptions:0]);
        return;
    }
    
    incomingPacket.fromAddress = address;
    incomingPacket.path = self;

    if ([self.delegate respondsToSelector:@selector(handlePath:packet:)]) {
        [self.delegate handlePath:self packet:incomingPacket];
    }
}

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    
}

@end

@implementation THRelayPath
-(NSString*)typeName
{
    return @"relay";
}

-(void)sendPacket:(THPacket *)packet
{
    if (!self.peerChannel) return;
    
    THPacket* relayPacket = [THPacket new];
    relayPacket.body = [packet encode];
    
    [self.peerChannel sendPacket:relayPacket];
}

-(BOOL)channel:(THChannel *)channel handlePacket:(THPacket *)packet
{
    THPacket* relayedPacket = [THPacket packetData:packet.body];
    if ([self.delegate respondsToSelector:@selector(handlePath:packet:)]) {
        [self.delegate handlePath:self packet:relayedPacket];
    }
    
    return YES;
}
@end