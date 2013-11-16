//
//  THChannel.h
//  telehash
//
//  Created by Thomas Muldowney on 10/5/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@class THPacket;

@interface THChannel : NSObject

@property unsigned long maxSeen;
@property NSArray* missing;

-(void)sendPacket:(THPacket*)packet;

@end
