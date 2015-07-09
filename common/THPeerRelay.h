//
//  THPeerRelay.h
//  telehash
//
//  Created by Thomas Muldowney on 3/17/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "E3XChannel.h"

@class THLink;
@class E3XChannel;

@interface THPeerRelay : NSObject<E3XChannelDelegate>
@property E3XChannel* connectChannel;
@property E3XChannel* peerChannel;
-(void)sendPacket:(THPacket*)packet;
@end
