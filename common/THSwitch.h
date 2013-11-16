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

@protocol ChannelHandler <NSObject>

-(void)chanelReadyForType:(NSString*)type from:(NSString*)hashname;

@end

@interface THSwitch : NSObject <GCDAsyncUdpSocketDelegate>

+(id)defaultSwitch;

@property THIdentity* identity;
@property id<ChannelHandler> channelHandler;

+(id)THSWitchWithIdentity:(THIdentity*)identity;

-(void)start;

-channelForType:(NSString*)type to:(NSString*)hashname;

#pragma mark UDP Handlers
-(void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext;
-(void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag;

@end
