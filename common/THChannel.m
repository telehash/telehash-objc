//
//  THChannel.m
//  telehash
//
//  Created by Thomas Muldowney on 10/5/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THChannel.h"
#import "THPacket.h"
#import "THIdentity.h"
#import "RNG.h"
#import "NSData+HexString.h"
#import "SHA256.h"
#import "THSwitch.h"
#import "CTRAES256.h"

@implementation THChannel

-(id)initToIdentity:(THIdentity*)identity delegate:(id<THChannelDelegate>)delegate;
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        self.channelIsReady = NO;
    }
    return self;
}

@end
