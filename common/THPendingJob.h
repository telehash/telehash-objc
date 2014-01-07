//
//  THPendingJob.h
//  telehash
//
//  Created by Thomas Muldowney on 1/7/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    PendingIdentity,
    PendingLine,
    PendingChannel,
    PendingPacket
} THPendingJobType;

typedef void(^PendingJobBlock)(id result);

@interface THPendingJob : NSObject

@property THPendingJobType type;
@property id pending;
@property (copy) PendingJobBlock handler;

+(id)pendingJobFor:(id)pendingItem completion:(PendingJobBlock)onCompletion;

@end

