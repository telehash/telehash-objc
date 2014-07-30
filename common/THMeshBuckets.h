//
//  THMeshBuckets.h
//  telehash
//
//  Created by Thomas Muldowney on 1/7/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "THChannel.h"

@class THIdentity;
@class THLine;
@class THSwitch;

typedef void(^SeekCompletionBlock)(BOOL found);

@interface THMeshBuckets : NSObject

@property (nonatomic, assign) THSwitch* localSwitch;
@property THIdentity* localIdentity;
@property NSMutableArray* pendingSeeks;
-(void)seek:(THIdentity*)toIdentity onSeed:(THIdentity*)seed completion:(SeekCompletionBlock)completion;
@end
