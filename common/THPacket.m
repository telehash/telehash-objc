//
//  THPacket.m
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THPacket.h"

@implementation THPacket

-(void)parse;
{
    short jsonLength;
    [self.raw getBytes:&jsonLength length:sizeof(short)];
    jsonLength = ntohs(jsonLength);
    NSLog(@"Length is %d", jsonLength);
    
    NSError* parserError;
    id parsedJson = [NSJSONSerialization JSONObjectWithData:[self.raw subdataWithRange:NSMakeRange(2, jsonLength)] options:0 error:&parserError];
    if (parsedJson == nil || ![parsedJson isKindOfClass:[NSDictionary class]]) {
        // TODO:  Something went wrong, deal with it
        NSLog(@"Something went wrong parsing: %@", parserError);
        return;
    } else {
        self.json = parsedJson;
    }
    self.body = [self.raw subdataWithRange:NSMakeRange(2 + jsonLength, [self.raw length] - jsonLength - 2)];
}
@end
