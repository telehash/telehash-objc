//
//  THMeshBuckets.h
//  telehash
//
//  Created by Thomas Muldowney on 1/7/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "THChannel.h"

@class THLink;
@class E3XExchange;
@class THMesh;

typedef void(^SeekCompletionBlock)(BOOL found);

@interface THMeshBuckets : NSObject<THChannelDelegate>

@property (nonatomic, assign) THMesh* localSwitch;
@property THLink* localIdentity;
@property NSMutableArray* buckets;
@property NSMutableArray* pendingSeeks;

-(void)linkToIdentity:(THLink*)identity;
-(void)addIdentity:(THLink*)identity;
-(void)removeLine:(E3XExchange*)line;
-(NSArray*)closeInBucket:(THLink*)seekIdentity;
-(NSArray*)nearby:(THLink*)seekIdentity;
-(void)seek:(THLink*)seekIdentity completion:(SeekCompletionBlock)completion;
@end
