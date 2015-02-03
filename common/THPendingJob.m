//
//  THPendingJob.m
//  telehash
//
//  Created by Thomas Muldowney on 1/7/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THPendingJob.h"
#import "THLink.h"
#import "E3XExchange.h"
#import "E3XChannel.h"
#import "THPacket.h"

@implementation THPendingJob
+(id)pendingJobFor:(id)pendingItem completion:(PendingJobBlock)onCompletion;
{
    THPendingJob* pendingJob = [THPendingJob new];
    Class itemClass = [pendingItem class];
    if (itemClass == [THLink class]) pendingJob.type = PendingIdentity;
    if (itemClass == [E3XExchange class]) pendingJob.type = PendingLine;
    if ([itemClass superclass] == [E3XChannel class]) pendingJob.type = PendingChannel;
    if (itemClass == [THPacket class]) pendingJob.type = PendingSeek;
    pendingJob.pending = pendingItem;
    pendingJob.handler = onCompletion;
    
    return pendingJob;
}
@end
