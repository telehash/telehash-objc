//
//  THPath.h
//  telehash
//
//  Created by Thomas Muldowney on 3/17/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "THChannel.h"
#import "GCDAsyncUdpSocket.h"

@class THPacket;
@class THUnreliableChannel;

@class THPath;

typedef BOOL(^THInterfaceApproverBlock)(NSString* interface);

@protocol THPathDelegate <NSObject>
-(void)handlePath:(THPath*)path packet:(THPacket*)packet;
@end

@interface THPath : NSObject
@property (nonatomic, assign) id<THPathDelegate> delegate;
@property (readonly) NSString* typeName;
-(void)sendPacket:(THPacket*)packet;
-(THPath*)returnPathTo:(NSData*)address;
-(NSDictionary*)information;
-(NSDictionary*)informationTo:(NSData*)address;
@end

@interface THIPV4Path : THPath<GCDAsyncUdpSocketDelegate>
@property (readonly) NSString* ip;
@property (readonly) NSUInteger port;
+(NSData*)addressTo:(NSString*)ip port:(NSUInteger)port;
-(id)init;
-(id)initWithInterface:(NSString*)interface;
-(id)initWithSocket:(GCDAsyncUdpSocket*)socket toAddress:(NSData*)address;
-(id)initWithSocket:(GCDAsyncUdpSocket*)socket ip:(NSString*)ip port:(NSUInteger)port;
-(void)start;
-(void)startOnPort:(unsigned short)port;
-(void)sendPacket:(THPacket *)packet;
+(NSArray*)gatherAvailableInterfacesApprovedBy:(THInterfaceApproverBlock)approver;
@end

@interface THRelayPath : THPath<THChannelDelegate>
@property (nonatomic, assign) THUnreliableChannel* peerChannel;
-(void)sendPacket:(THPacket *)packet;
@end