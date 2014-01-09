//
//  THMeshBuckets.m
//  telehash
//
//  Created by Thomas Muldowney on 1/7/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THMeshBuckets.h"
#import "THIdentity.h"
#import "THLine.h"
#import "THPacket.h"
#import "RNG.h"
#import "NSData+HexString.h"

@implementation THMeshBuckets
{
    BOOL pendingPings;
}

-(id)init
{
    self = [super init];
    if (self) {
        self.buckets = [NSMutableArray arrayWithCapacity:256];
        for (int i = 0; i < 256; ++i) {
            [self.buckets insertObject:[NSMutableArray array] atIndex:i];
        }
    }
    return self;
}

-(void)pingLines
{
    time_t checkTime = time(NULL);
    [self.buckets enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSArray* bucket = (NSArray*)obj;
        [bucket enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            THLine* line = (THLine*)obj;
            
            // 60s ping based on last activity
            if (line.lastActitivy + 60 > checkTime) return;
            
            THPacket* seekPacket = [THPacket new];
            [seekPacket.json setObject:[[RNG randomBytesOfLength:16] hexString] forKey:@"c"];
            [seekPacket.json setObject:@"seek" forKey:@"type"];
            [seekPacket.json setObject:self.localIdentity.hashname forKey:@"seek"];
            
            [line sendPacket:seekPacket];
        }];
    }];
    
    if (!pendingPings) {
        double delayInSeconds = 60.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            pendingPings = NO;
            [self pingLines];
        });
        pendingPings = YES;
    }
}

-(void)addLine:(THLine *)line
{
    NSInteger bucketIndex = [self.localIdentity distanceFrom:line.toIdentity];
    NSMutableArray* bucket = [self.buckets objectAtIndex:bucketIndex];
    if (bucket == nil) {
        bucket = [NSMutableArray array];
    }
    
    // TODO:  Bucket depth?
    
    // We insert this at position 0 because it is the most recently active
    [bucket insertObject:line atIndex:0];

    [self pingLines];
}

-(void)removeLine:(THLine *)line
{
    NSInteger bucketIndex = [self.localIdentity distanceFrom:line.toIdentity];
    [[self.buckets objectAtIndex:bucketIndex] removeObject:line];
}

// TODO:  Consider if this arg should be THIdentity
-(NSArray*)seek:(THIdentity*)seekIdentity;
{
    NSMutableArray* entries = [NSMutableArray array];
    NSInteger curBucketIndex = [self.localIdentity distanceFrom:seekIdentity];
    while (curBucketIndex < 256 && [entries count] < 5) {
        NSArray* curBucket = [self.buckets objectAtIndex:curBucketIndex];
        [curBucket enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [entries addObject:obj];
            if (entries.count > 5) *stop = YES;
        }];
        ++curBucketIndex;
    }
#if 0 // Old code for sorting the entries, this should happen naturally now
    [entries sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        THLine* lh = (THLine*)obj1;
        THLine* rh = (THLine*)obj2;
        
        NSInteger lhDistance = [self.identity distanceFrom:lh.toIdentity];
        NSInteger rhDistance = [self.identity distanceFrom:rh.toIdentity];
        
        if (lhDistance > rhDistance) return (NSComparisonResult)NSOrderedDescending;
        if (lhDistance < rhDistance) return (NSComparisonResult)NSOrderedAscending;
        return (NSComparisonResult)NSOrderedSame;
    }];
#endif
    NSLog(@"Seek entries: %@", entries);
    return entries;
}

@end
