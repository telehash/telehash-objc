//
//  THPeerRelay.h
//  telehash
//
//  Created by Thomas Muldowney on 3/17/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "THChannel.h"

@class THIdentity;
@class THChannel;

@interface THPeerRelay : NSObject<THChannelDelegate>
@property (nonatomic, assign) THChannel* connectChannel;
@property (nonatomic, assign) THChannel* peerChannel;
-(void)sendPacket:(THPacket*)packet;
@end
