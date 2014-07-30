//
//  THChannelDelegate.h
//  telehash
//
//  Created by Daniel Chote on 7/30/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@class THPacket;
@class THIdentity;
@class THChannel;

typedef enum {
    THChannelOpening,
    THChannelOpen,
    THChannelPaused,
    THChannelEnded,
    THChannelErrored
} THChannelState;

@protocol THChannelDelegate <NSObject>
#pragma mark State Handling
-(void)channel:(THChannel*)channel didChangeStateTo:(THChannelState)channelState;
#pragma mark Error Handling
-(void)channel:(THChannel*)channel didFailWithError:(NSError*)error;
-(BOOL)channel:(THChannel*)channel handlePacket:(THPacket*)packet;
@end
