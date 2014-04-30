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
@class THTransport;
@class THPath;

NSMutableArray* THPathTypeRegistry;

@interface THPath : NSObject
@property (readonly) NSString* typeName;
@property (assign, nonatomic) THTransport* transport;
@property (readonly) BOOL isLocal;
@property (readonly) BOOL isRelay;
@property NSUInteger priority;
@property BOOL available;
-(void)sendPacket:(THPacket*)packet;
-(NSDictionary*)information;
-(BOOL)pathIsLocalTo:(THPath*)path;
@end

@interface THIPV4Path : THPath<GCDAsyncUdpSocketDelegate>
@property (readonly) NSString* ip;
@property (readonly) NSUInteger port;
@property NSUInteger priority;
+(NSData*)addressTo:(NSString*)ip port:(NSUInteger)port;
-(id)initWithTransport:(THTransport*)transport toAddress:(NSData*)address;
-(id)initWithTransport:(THTransport*)transport ip:(NSString*)ip port:(NSUInteger)port;
-(void)sendPacket:(THPacket *)packet;
@end

@interface THRelayPath : THPath<THChannelDelegate>
@property (nonatomic, retain) THPath* relayedPath;
@property (nonatomic, assign) THUnreliableChannel* peerChannel;
-(id)initOnChannel:(THUnreliableChannel*)channel;
-(void)sendPacket:(THPacket *)packet;
@end