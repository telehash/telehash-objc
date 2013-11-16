//
//  THPacket.m
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THPacket.h"
#import "CTRAES256.h"

@implementation THPacket

+(id)packetData:(NSData *)packetData;
{
    short jsonLength;
    [packetData getBytes:&jsonLength length:sizeof(short)];
    jsonLength = ntohs(jsonLength);
    if (jsonLength < 0) {
        NSLog(@"Invalid JSON header length");
        return nil;
    }
    NSLog(@"Length is %d", jsonLength);
    
    NSError* parserError;
    NSLog(@"Gonig to parse %@", [packetData subdataWithRange:NSMakeRange(2, jsonLength)]);
    id parsedJson = [NSJSONSerialization JSONObjectWithData:[packetData subdataWithRange:NSMakeRange(2, jsonLength)] options:0 error:&parserError];
    
    THPacket* packet;
    if (parsedJson == nil || ![parsedJson isKindOfClass:[NSDictionary class]]) {
        // TODO:  Something went wrong, deal with it
        NSLog(@"Something went wrong parsing: %@", parserError);
        return nil;
    } else {
        packet = [THPacket new];
        packet.json = parsedJson;
    }
    packet.body = [packetData subdataWithRange:NSMakeRange(2 + jsonLength, packetData.length - jsonLength - 2)];

    return packet;
}

-(NSData*)encode;
{
    NSError* error;
    NSData* encodedJSON = [NSJSONSerialization dataWithJSONObject:self.json options:0 error:&error];
    short totalLength = encodedJSON.length + self.body.length + 2;
    NSMutableData* packetData = [NSMutableData dataWithCapacity:totalLength];
    
    totalLength = HTONS(totalLength);
    [packetData appendBytes:&totalLength length:sizeof(short)];
    [packetData appendData:encodedJSON];
    [packetData appendData:self.body];
    
    return packetData;
}

-(void)encryptWithKey:(NSData*)key iv:(NSData*)iv;
{
    self.body = [CTRAES256Encryptor encryptPlaintext:self.body key:key iv:iv];
}

-(void)decryptWithKey:(NSData *)key iv:(NSData *)iv;
{
    self.body = [CTRAES256Decryptor decryptPlaintext:self.body key:key iv:iv];
}
@end
