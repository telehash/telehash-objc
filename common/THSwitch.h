//
//  THSwitch.h
//  telehash
//
//  Created by Thomas Muldowney on 10/3/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncUdpSocket.h"

@class THIdentity;
@class THChannel;
@class THPacket;
@class THLine;

typedef enum {
    ReliableChannel,
    UnreliableChannel
} THChannelType;

@protocol THSwitchDelegate <NSObject>

-(void)openedLine:(THLine*)line;
-(void)channelReady:(THChannel*)channel type:(THChannelType)type firstPacket:(THPacket*)packet;

@end

@interface THSwitch : NSObject <GCDAsyncUdpSocketDelegate>

+(id)defaultSwitch;

@property NSMutableDictionary* openLines;
@property THIdentity* identity;
@property id<THSwitchDelegate> delegate;
@property dispatch_queue_t channelQueue;
@property dispatch_queue_t dhtQueue;

+(id)THSWitchWithIdentity:(THIdentity*)identity;

-(void)start;
-(void)startOnPort:(unsigned short)port;
-(void)sendPacket:(THPacket*)packet toAddress:(NSData*)address;
-(NSArray*)seek:(NSString*)hashname;
-(THLine*)lineToHashname:(NSString*)hashname;
-(void)openChannel:(THChannel*)channel firstPacket:(THPacket*)packet;
-(void)openLine:(THIdentity*)toIdentity;
-(void)loadSeeds:(NSData*)seedData;

// This is an internal handling hack
-(BOOL)findPendingJob:(THPacket*)packet;

#pragma mark UDP Handlers
-(void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext;
-(void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag;

@end
