//
//  THListener.m
//  telehash
//
//  Created by Thomas Muldowney on 4/9/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THTransport.h"
#import "THPacket.h"
#import "THPath.h"
#import "CLCLog.h"
#import <SystemConfiguration/SystemConfiguration.h>
#include <arpa/inet.h>
#include <ifaddrs.h>

static void THReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info);

@implementation THTransport
-(NSString*)typeName
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return nil;
}

-(THPath*)returnPathTo:(NSData*)address
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return nil;
}

-(THPath*)pathTo:(NSDictionary *)pathInformation
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];

    return nil;
}

-(void)start
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

-(void)send:(NSData*)data to:(NSData*)address
{
	[NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}
@end

@implementation THIPv4Transport
{
    GCDAsyncUdpSocket* udpSocket;
    NSString* bindInterface;
    SCNetworkReachabilityRef reachability;
    SCNetworkReachabilityContext reachabilityContext;
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

-(void)dealloc
{
    if (reachability) {
        SCNetworkReachabilitySetCallback(reachability, NULL, NULL);
        CFRelease(reachability);
    }
    CLCLogInfo(@"Listener is gone!");
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
        CLCLogError(@"%@", bindError);
        return;
    }
    reachability = SCNetworkReachabilityCreateWithAddress(NULL, [udpSocket.localAddress_IPv4 bytes]);
    reachabilityContext.version = 0;
    reachabilityContext.info = (__bridge void *)(self);
    reachabilityContext.copyDescription = NULL;
    reachabilityContext.release = NULL;
    reachabilityContext.retain = NULL;
    SCNetworkReachabilitySetCallback(reachability, THReachabilityCallback, &reachabilityContext);
    if (!SCNetworkReachabilitySetDispatchQueue(reachability, dispatch_get_main_queue())) {
        SCNetworkReachabilitySetCallback(reachability, NULL, NULL);
        // XXX TODO:  Should we not use this interface now?
    }
    NSError* recvError;
    [udpSocket beginReceiving:&recvError];
    CLCLogInfo(@"Now listening on %d", udpSocket.localPort);
    // TODO: Needs more error handling
}

-(NSUInteger)port
{
    return [udpSocket localPort_IPv4];
}

-(THPath*)returnPathTo:(NSData*)address
{
    THIPV4Path* returnPath = [[THIPV4Path alloc] initWithTransport:self toAddress:address];
    return returnPath;
}

-(THPath*)pathTo:(NSDictionary *)pathInformation
{
    NSString* ip = [pathInformation objectForKey:@"ip"];
    NSUInteger port = [[pathInformation objectForKey:@"port"] unsignedIntegerValue];
    if (!ip || port == 0) return nil;
    
    THIPV4Path* path = [[THIPV4Path alloc] initWithTransport:self ip:ip port:port];
    return path;
}

-(void)send:(NSData*)data to:(NSData*)address
{
    [udpSocket sendData:data toAddress:address withTimeout:-1 tag:0];
}

-(NSArray*)gatherAvailableInterfacesApprovedBy:(THInterfaceApproverBlock)approver
{
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success != 0) return nil;
    
    // Loop through linked list of interfaces
    temp_addr = interfaces;
    NSMutableArray* ret = [NSMutableArray array];
    while(temp_addr != NULL) {
        if(temp_addr->ifa_addr->sa_family == AF_INET) {
            // See if it's even reachable
            SCNetworkReachabilityRef checkReachability = SCNetworkReachabilityCreateWithAddress(NULL, temp_addr->ifa_addr);
            SCNetworkReachabilityFlags flags;
            BOOL gotFlags = SCNetworkReachabilityGetFlags(checkReachability, &flags);
            CFRelease(checkReachability);
            // Bail on errors doing basic reachability checks
            if (!gotFlags) continue;
            // If this is not actually reachable skip it
            if ((flags & kSCNetworkFlagsReachable) == 0) continue;
            NSString* interface = [NSString stringWithUTF8String:temp_addr->ifa_name];
            if (approver(interface)) {
                NSData* addressData = [NSData dataWithBytes:temp_addr->ifa_addr length:sizeof(struct sockaddr)];
                THIPV4Path* newPath = [[THIPV4Path alloc] initWithTransport:self toAddress:addressData];
                [ret addObject:newPath];
            }
        }
        temp_addr = temp_addr->ifa_next;
    }
    
    // Free memory
    freeifaddrs(interfaces);
    
    return ret;
}

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    //CLCLogInfo(@"Incoming data from %@", [NSString stringWithUTF8String:inet_ntoa(addr->sin_addr)]);
    THPacket* incomingPacket = [THPacket packetData:data];
    if (!incomingPacket) {
        NSString* host;
        uint16_t port;
        [GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
        CLCLogInfo(@"Unexpected or unparseable packet from %@:%d: %@", host, port, [data base64EncodedStringWithOptions:0]);
        return;
    }
    incomingPacket.returnPath = [self returnPathTo:address];
    
    if ([self.delegate respondsToSelector:@selector(transport:handlePacket:)]) {
        [self.delegate transport:self handlePacket:incomingPacket];
    }
}

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    
}


@end

@implementation THRelayTransport
{
    THPath* _path;
}

-(id)initWithPath:(THPath *)path
{
    self = [super init];
    if (self) {
        _path = path;
    }
    return self;
}

-(THPath*)returnPathTo:(NSData *)address
{
    return _path;
}
@end

static void THReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
    THTransport* transport = (__bridge THTransport*)info;
    transport.available = (flags & kSCNetworkFlagsReachable) == kSCNetworkFlagsReachable ? YES : NO;
    transport.available &= (flags & kSCNetworkFlagsConnectionRequired) == kSCNetworkFlagsConnectionRequired ? NO : YES;
    if ([transport.delegate respondsToSelector:@selector(transportDidChangeActive:)]) {
        [transport.delegate transportDidChangeActive:transport];
    }
    CLCLogInfo(@"Interface changed!");
}