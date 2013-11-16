//
//  CryptoPPUtil.m
//  telehash
//
//  Created by Thomas Muldowney on 11/13/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "CryptoPPUtil.h"
#include <cryptopp/osrng.h>

using namespace CryptoPP::AutoSeededRandomPool;

@implementation CryptoPPUtil
+(NSData*)randomBytes:(NSInteger)length;
{
    NSData* retData = [NSData dataWithLength:length];
    
}
@end
