//
//  THChannel.h
//  telehash
//
//  Created by Thomas Muldowney on 10/5/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ECDH.h"

@class THPacket;
@class THIdentity;
@class THChannel;

@protocol THChannelDelegate <NSObject>
#pragma mark State Handling
-(void)channelDidFinishOpen:(THChannel*)channel;
#pragma mark Error Handling
-(void)channel:(THChannel*)channel didFailWithError:(NSError*)error;
@end

@interface THChannel : NSObject

@property unsigned long maxSeen;
@property NSArray* missing;
@property id<THChannelDelegate> delegate;
@property BOOL channelIsReady;
@property THIdentity* toIdentity;
@property ECDH* ecdh;
@property NSString* outLineId;
@property NSString* inLineId;

-(id)initToIdentity:(THIdentity*)identity delegate:(id<THChannelDelegate>)delegate;
// TODO:  init method that allows creation against THSwitch instances other than the shared one
-(void)sendPacket:(THPacket*)packet;

@end

@interface THLossyChannel : THChannel
@end

@interface THStreamChannel : THChannel
@end

@interface THBulkTransferChannel : THChannel
@end