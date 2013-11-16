//
//  THSwitch.m
//  telehash
//
//  Created by Thomas Muldowney on 10/3/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THSwitch.h"

@interface THSwitch()

@property GCDAsyncUdpSocket* udpSocket;


@end

@implementation THSwitch

+(id)THSWitchWithIdentity:(THIdentity*)identity;
{
    THSwitch* thSwitch = [THSwitch new];
    if (thSwitch) {
        thSwitch.udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:NULL];
    }
}

-(void)start;
{
    NSError* bindError;
    [self.udpSocket bindToPort:0 error:&bindError];
    // TODO:  Check the error out
    NSError* recvError;
    [self.udpSocket beginReceiving:&recvError];
    // TODO: Needs more error handling
}

-channelForType:(NSString*)type to:(NSString*)hashname;
{
    
}

#pragma region -- UDP Handlers

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    /*
     
     */
}

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    
}

@end
