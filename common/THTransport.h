//
//  THListener.h
//  telehash
//
//  Created by Thomas Muldowney on 4/9/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncUdpSocket.h"

@class THTransport;
@class THPacket;
@class THPath;

@protocol THTransportDelegate <NSObject>
-(void)transport:(THTransport*)transport handlePacket:(THPacket*)packet;
-(void)transportDidChangeActive:(THTransport*)transport;
@end

@interface THTransport : NSObject
@property (readonly) NSString* typeName;
@property (assign, nonatomic) id<THTransportDelegate> delegate;
@property (assign, atomic) BOOL available;
@property NSUInteger priority;
@property BOOL isBridge;
-(void)start;
-(THPath*)returnPathTo:(NSData*)address;
-(THPath*)pathTo:(NSDictionary*)pathInformation;
-(void)send:(NSData*)data to:(NSData*)address;
@end

typedef BOOL(^THInterfaceApproverBlock)(NSString* interface);

@interface THIPv4Transport : THTransport<GCDAsyncUdpSocketDelegate>

-(void)start;
-(void)startOnPort:(unsigned short)port;
-(NSArray*)gatherAvailableInterfacesApprovedBy:(THInterfaceApproverBlock)approver;
@property (readonly) NSUInteger port;
@end

@interface THRelayTransport : THTransport
-(id)initWithPath:(THPath*)path;
@end