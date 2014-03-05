//
//  THPacket.m
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THPacket.h"

@implementation THPacket

+(id)packetData:(NSData *)packetData;
{
    unsigned short jsonLength;
    [packetData getBytes:&jsonLength length:sizeof(short)];
    jsonLength = ntohs(jsonLength);
    if (jsonLength > packetData.length) {
        NSLog(@"Invalid JSON header length");
        return nil;
    }
    
    if (packetData.length == 0 || (packetData.length == 2 && jsonLength == 0)) {
        NSLog(@"ignoring a poke packet");
        return nil;
    }
    
    NSError* parserError;
    id parsedJson;
    if (jsonLength >= 2) {
        parsedJson = [NSJSONSerialization JSONObjectWithData:[packetData subdataWithRange:NSMakeRange(2, jsonLength)] options:0 error:&parserError];
        if (parsedJson == nil || ![parsedJson isKindOfClass:[NSDictionary class]]) {
            // TODO:  Something went wrong, deal with it
            NSLog(@"Something went wrong parsing: %@", parserError);
            return nil;
        }
    }
    
    THPacket* packet = [[THPacket alloc] initWithJson:parsedJson];
    packet.jsonLength = jsonLength;
    if (jsonLength == 1) --jsonLength;
    packet.body = [packetData subdataWithRange:NSMakeRange(2 + jsonLength, packetData.length - jsonLength - 2)];

    return packet;
}

-(id)init;
{
    self = [super init];
    if (self) {
        self.json = [NSMutableDictionary dictionary];
    }
    return self;
}

-(id)initWithJson:(NSMutableDictionary *)json;
{
    self = [super init];
    if (self) {
        self.json = json;
    }
    return self;
}


-(NSData*)encode;
{
    NSError* error;
    NSData* encodedJSON = [NSJSONSerialization dataWithJSONObject:self.json options:0 error:&error];
    short totalLength = encodedJSON.length + self.body.length + 2;
    NSMutableData* packetData = [NSMutableData dataWithCapacity:totalLength];
    
    totalLength = htons(encodedJSON.length);
    [packetData appendBytes:&totalLength length:sizeof(short)];
    [packetData appendData:encodedJSON];
    [packetData appendData:self.body];
    
    return packetData;
}

@end
