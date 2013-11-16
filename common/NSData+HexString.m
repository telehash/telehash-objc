//
//  NSData+HexString.m
//  telehash
//
//  Created by Thomas Muldowney on 11/13/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "NSData+HexString.h"

@implementation NSData (HexString)
/* http://stackoverflow.com/questions/1305225/best-way-to-serialize-a-nsdata-into-an-hexadeximal-string */
-(NSString*)hexString;
{
    /* Returns hexadecimal string of NSData. Empty string if data is empty.   */
    
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];
    
    if (!dataBuffer)
        return [NSString string];
    
    NSUInteger          dataLength  = [self length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i)
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    
    return [NSString stringWithString:hexString];
}
@end
