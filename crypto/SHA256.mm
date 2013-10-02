//
//  SHA256.m
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "SHA256.h"

#include <cryptopp/sha.h>
using CryptoPP::SHA256;

@interface SHA256()
{
@private
    CryptoPP::SHA256 sha;
}
@end

@implementation SHA256
-(void)updateWithData:(NSData *)data;
{
    sha.Update((const byte*)[data bytes], [data length]);
}

-(NSData*)finalize;
{
    NSMutableData* hash = [NSMutableData dataWithCapacity:32];
    sha.Final((byte*)[hash mutableBytes]);
    return hash;
}
@end
