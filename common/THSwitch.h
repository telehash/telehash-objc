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
@class THMeshBuckets;

typedef enum {
    ReliableChannel,
    UnreliableChannel
} THChannelType;

typedef enum {
    THSWitchOffline,
    THSwitchListening,
    THSwitchOnline
} THSwitchStatus;

typedef void(^LineOpenBlock)(THIdentity*);

@class THSwitch;

@protocol THSwitchDelegate <NSObject>

-(void)openedLine:(THLine*)line;
-(void)channelReady:(THChannel*)channel type:(THChannelType)type firstPacket:(THPacket*)packet;
-(void)thSwitch:(THSwitch*)thSwitch status:(THSwitchStatus)status;

@end

@interface THSwitch : NSObject <GCDAsyncUdpSocketDelegate>

+(id)defaultSwitch;

@property THMeshBuckets* meshBuckets;
@property NSMutableDictionary* openLines;
@property NSMutableArray* pendingJobs;
@property THIdentity* identity;
@property id<THSwitchDelegate> delegate;
@property dispatch_queue_t channelQueue;
@property THSwitchStatus status;

+(id)THSWitchWithIdentity:(THIdentity*)identity;

-(void)start;
-(void)startOnPort:(unsigned short)port;
-(void)sendPacket:(THPacket*)packet toAddress:(NSData*)address;
-(THLine*)lineToHashname:(NSString*)hashname;
-(void)openChannel:(THChannel*)channel firstPacket:(THPacket*)packet;
/// Open a line to the given identity
// The identity can be either a complete identity (RSA keys and address filled in) or
// just a hashname.  The switch will do everything it can to open the line.
// The completion block is optional.
-(void)openLine:(THIdentity*)toIdentity completion:(LineOpenBlock)lineOpenCompletion;
-(void)openLine:(THIdentity*)toIdentity;
-(void)closeLine:(THLine*)line;
-(void)loadSeeds:(NSData*)seedData;
-(void)updateStatus:(THSwitchStatus)status;
-(THPacket*)generateOpen:(THLine*)toLine;

// This is an internal handling hack
-(BOOL)findPendingSeek:(THPacket*)packet;

#pragma mark UDP Handlers
-(void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext;
-(void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag;

@end
