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
#import "THSwitch.h"
#import "THPendingJob.h"

#define DEFAULT_KMAX 64
#define DEFAULT_KMIN 4

@implementation THMeshBuckets
{
    BOOL pendingPings;
    NSUInteger KMax;
    NSUInteger KMin;
}

-(id)init
{
    self = [super init];
    if (self) {
        KMax = DEFAULT_KMAX;
        KMin = DEFAULT_KMIN;
        self.buckets = [NSMutableArray arrayWithCapacity:256];
        for (int i = 0; i < 256; ++i) {
            [self.buckets insertObject:[NSMutableArray array] atIndex:i];
        }
    }
    return self;
}

-(void)pingLine:(THLine*)line
{
    THPacket* seekPacket = [THPacket new];
    [seekPacket.json setObject:[[RNG randomBytesOfLength:16] hexString] forKey:@"c"];
    [seekPacket.json setObject:@"seek" forKey:@"type"];
    [seekPacket.json setObject:self.localIdentity.hashname forKey:@"seek"];
    
    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
    [defaultSwitch.pendingJobs addObject:[THPendingJob pendingJobFor:seekPacket completion:^(id result) {
        // TODO:  pull out our IP?
    }]];
    
    [line sendPacket:seekPacket];
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
            
            [self pingLine:line];
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

-(NSArray*)nearby:(THIdentity*)seekIdentity;
{
    NSLog(@"Nearby for %@", seekIdentity.hashname);
    NSMutableArray* entries = [NSMutableArray array];
    NSInteger initialBucketIndex = [self.localIdentity distanceFrom:seekIdentity];
    // First descend to get closers
    NSInteger curBucketIndex = initialBucketIndex;
    while (curBucketIndex >= 0 && [entries count] < 5) {
        NSArray* curBucket = [self.buckets objectAtIndex:curBucketIndex];
        [curBucket enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([seekIdentity.hashname isEqualToString:((THLine*)obj).toIdentity.hashname]) return;
            [entries addObject:obj];
            if (entries.count > 5) *stop = YES;
        }];
        --curBucketIndex;
    }
    // Now just make sure we're full with general entries
    curBucketIndex = initialBucketIndex;
    while (curBucketIndex < 256) {
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

-(void)seek:(THIdentity*)toIdentity completion:(SeekCompletionBlock)completion
{
    NSLog(@"Seeking for %@", toIdentity.hashname);
    NSArray* nearby = [self nearby:[THIdentity identityFromHashname:toIdentity.hashname]];
    NSUInteger length = nearby.count > 3 ? 3 : nearby.count;
    [[nearby subarrayWithRange:NSMakeRange(0, length)] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        THLine* curLine = (THLine*)obj;
        NSLog(@"Starting seek for nearby %@", curLine.toIdentity.hashname);
        [self seek:toIdentity via:curLine.toIdentity completion:^(BOOL found) {
            if (completion) completion(found);
        }];
    }];
}

-(void)seek:(THIdentity*)toIdentity via:(THIdentity*)viaIdentity completion:(SeekCompletionBlock)completion
{
    if ([toIdentity.hashname isEqualToString:viaIdentity.hashname]) return;
    
    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
    
    dispatch_queue_t seekQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    NSInteger curBucketIndex = [self.localIdentity distanceFrom:toIdentity];
    
    NSLog(@"Seek to %@ via %@", toIdentity.hashname, viaIdentity.hashname);
    [defaultSwitch openLine:viaIdentity completion:^(THLine *seekLine) {
        THPacket* seekPacket = [THPacket new];
        [seekPacket.json setObject:[[RNG randomBytesOfLength:16] hexString] forKey:@"c"];
        [seekPacket.json setObject:toIdentity.hashname forKey:@"seek"];
        [seekPacket.json setObject:@"seek" forKey:@"type"];

        [defaultSwitch.pendingJobs addObject:[THPendingJob pendingJobFor:seekPacket completion:^(id result) {
            THPacket* response = (THPacket*)result;
            NSArray* sees = [response.json objectForKey:@"see"];
            NSLog(@"Checking for %@ in sees %@",  toIdentity.hashname, sees);
            [sees enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSString* seeString = (NSString*)obj;
                NSArray* seeParts = [seeString componentsSeparatedByString:@","];
                if ([[seeParts objectAtIndex:0] isEqualToString:toIdentity.hashname]) {
                    NSLog(@"We found %@!", toIdentity.hashname);
                    // this is it!
                    toIdentity.via = viaIdentity;
                    if (seeParts.count > 1) {
                        [viaIdentity setIP:[seeParts objectAtIndex:1] port:[[seeParts objectAtIndex:2] integerValue]];
                    }
                    [defaultSwitch openLine:toIdentity completion:^(THLine *openedLine) {
                        if (completion) completion(YES);
                        *stop = YES;
                    }];
                } else {
                    // If we're moving closer we want to go ahead and start a seek to it
                    THIdentity* nearIdentity = [THIdentity identityFromHashname:[seeParts objectAtIndex:0]];
                    nearIdentity.via = viaIdentity;
                    NSInteger distance = [self.localIdentity distanceFrom:nearIdentity];
                    NSLog(@"Step distance is %d", distance);
                    if (distance < curBucketIndex) {
                        dispatch_async(seekQueue, ^{
                            [self seek:toIdentity via:nearIdentity completion:^(BOOL found) {
                                if (found && completion) completion(found);
                            }];
                        });
                    }
                }
                
            }];
        }]];
        
        [seekLine sendPacket:seekPacket];
    }];
    
}
@end
