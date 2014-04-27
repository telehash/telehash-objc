//
//  THUnreliableChannel.h
//  telehash
//
//  Created by Thomas Muldowney on 4/26/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THChannel.h"

@interface THUnreliableChannel : THChannel
-(void)handlePacket:(THPacket *)packet;
-(void)sendPacket:(THPacket *)packet;
@end

