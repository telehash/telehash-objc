//
//  THPendingJob.m
//  telehash
//
//  Created by Thomas Muldowney on 1/7/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THPendingJob.h"
#import "THIdentity.h"
#import "THLine.h"
#import "THChannel.h"
#import "THPacket.h"

@implementation THPendingJob
+(id)pendingJobFor:(id)pendingItem completion:(PendingJobBlock)onCompletion;
{
    THPendingJob* pendingJob = [THPendingJob new];
    Class itemClass = [pendingItem class];
    if (itemClass == [THIdentity class]) pendingJob.type = PendingIdentity;
    if (itemClass == [THLine class]) pendingJob.type = PendingLine;
    if ([itemClass superclass] == [THChannel class]) pendingJob.type = PendingChannel;
    pendingJob.pending = pendingItem;
    pendingJob.handler = onCompletion;
    
    return pendingJob;
}
@end
