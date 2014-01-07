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

@interface THMeshBuckets : NSObject
@property NSMutableArray* buckets;

-(void)addLine:(THLine*)line;
-(NSArray*)seek:(THIdentity*)identity;
@end
