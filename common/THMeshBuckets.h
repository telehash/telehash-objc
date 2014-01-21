//
//  THMeshBuckets.h
//  telehash
//
//  Created by Thomas Muldowney on 1/7/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@class THIdentity;
@class THLine;

typedef void(^SeekCompletionBlock)(BOOL found);

@interface THMeshBuckets : NSObject

@property THIdentity* localIdentity;
@property NSMutableArray* buckets;

-(void)addLine:(THLine*)line;
-(void)removeLine:(THLine*)line;
-(NSArray*)nearby:(THIdentity*)seekIdentity;
-(void)seek:(THIdentity*)seekIdentity completion:(SeekCompletionBlock)completion;
@end
