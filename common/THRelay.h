//
//  THRelay.h
//  telehash
//
//  Created by Thomas Muldowney on 5/17/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "THChannel.h"
#import "THUnreliableChannel.h"
#import "THPath.h"

@interface THRelay : NSObject<THChannelDelegate>
@property (assign) THLink* toIdentity;
@property (retain) THLink* relayIdentity;
@property (retain) THPath* relayedPath;
@property (weak) THUnreliableChannel* peerChannel;
-(id)initOnChannel:(THUnreliableChannel*)channel;
-(void)attachVia:(THLink*)viaIdentity;
-(void)sendPacket:(THPacket *)packet;
@end
