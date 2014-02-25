//
//  SHA256.m
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "SHA256.h"
#import "NSData+HexString.h"

#include <cryptopp/sha.h>
using CryptoPP::SHA256;

@interface SHA256()
{
@private
    CryptoPP::SHA256 sha;
}
@end

@implementation SHA256
+(NSData*)hashWithData:(NSData*)data;
{
    SHA256* sha = [SHA256 new];
    [sha updateWithData:data];
    return [sha finish];
}

-(void)updateWithData:(NSData *)data;
{
    sha.Update((const byte*)[data bytes], [data length]);
}

-(NSData*)finish;
{
    NSMutableData* hash = [NSMutableData dataWithLength:32];
    sha.Final((byte*)[hash mutableBytes]);
    return hash;
}
@end
