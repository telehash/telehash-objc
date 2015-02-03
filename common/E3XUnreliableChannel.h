//
//  THUnreliableChannel.h
//  telehash
//
//  Created by Thomas Muldowney on 4/26/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "E3XChannel.h"

@interface E3XUnreliableChannel : E3XChannel
-(void)handlePacket:(THPacket *)packet;
-(void)sendPacket:(THPacket *)packet;
@end

