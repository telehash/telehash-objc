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

@property THIdentity* localIdentity;
@property NSMutableArray* buckets;

-(void)addLine:(THLine*)line;
-(void)removeLine:(THLine*)line;
-(NSArray*)seek:(THIdentity*)seekIdentity;
@end
