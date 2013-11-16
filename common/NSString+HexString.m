//
//  NSString+HexString.m
//  telehash
//
//  Created by Thomas Muldowney on 11/15/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "NSString+HexString.h"

@implementation NSString (HexString)
// Adapted from http://stackoverflow.com/questions/2501033/nsstring-hex-to-bytes
-(NSData*)dataFromHexString;
{
    const char* chars = [self UTF8String];
    NSMutableData* data = [NSMutableData dataWithCapacity:self.length / 2];
    char byteChars[3] = {0, 0, 0};
    unsigned long wholeByte;
    
    for (int i = 0; i < self.length; i += 2) {
        byteChars[0] = chars[i];
        byteChars[1] = chars[i + 1];
        wholeByte = strtoul(byteChars, NULL, 16);
        [data appendBytes:&wholeByte length:1];
    }
    
    return data;
}
@end
