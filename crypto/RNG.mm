//
//  RNG.m
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "RNG.h"

#include <cryptopp/osrng.h>

@implementation RNG

+(NSData*)randomBytesOfLength:(unsigned long)length;
{
    NSMutableData* ret = [NSMutableData dataWithCapacity:length];
    CryptoPP::AutoSeededRandomPool rng;
    rng.GenerateBlock((byte*)[ret mutableBytes], length);
    return ret;
}

+(void)randomBytesIn:(void*)destination length:(unsigned long)length;
{
    CryptoPP::AutoSeededRandomPool rng;
    rng.GenerateBlock((byte*)destination, length);
}

@end
