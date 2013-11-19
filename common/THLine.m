//
//  THLine.m
//  telehash
//
//  Created by Thomas Muldowney on 11/15/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THLine.h"
#import "THPacket.h"
#import "RNG.h"
#import "NSData+HexString.h"
#import "SHA256.h"
#import "THIdentity.h"
#import "RSA.h"
#import "THSwitch.h"
#import "CTRAES256.h"
#import "NSString+HexString.h"

#include <arpa/inet.h>

@implementation THLine
-(void)sendOpen;
{
    THPacket* openPacket = [THPacket new];
    [openPacket.json setObject:@"open" forKey:@"type"];
    if (!self.ecdh) {
        self.ecdh = [ECDH new];
    }
    NSString* encodedKey = [[self.toIdentity.rsaKeys encrypt:self.ecdh.publicKey] base64EncodedStringWithOptions:0];
    [openPacket.json setObject:encodedKey forKey:@"open"];
    
    THPacket* innerPacket = [THPacket new];
    [innerPacket.json setObject:self.toIdentity.hashname forKey:@"to"];
    NSDate* now = [NSDate date];
    NSInteger timestamp = (NSInteger)([now timeIntervalSince1970] * 1000);
    [innerPacket.json setObject:[NSNumber numberWithInteger:timestamp] forKey:@"at"];
    
    // Generate a new line id if we weren't given one
    if (!self.inLineId) {
        self.inLineId =  [[RNG randomBytesOfLength:16] hexString];
    }
    [innerPacket.json setObject:self.inLineId forKey:@"line"];
    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
    innerPacket.body = defaultSwitch.identity.rsaKeys.DERPublicKey;
    
    openPacket.body = [innerPacket encode];
    NSData* packetIV = [RNG randomBytesOfLength:16];
    [openPacket.json setObject:[packetIV hexString] forKey:@"iv"];
    
    SHA256* sha = [SHA256 new];
    [sha updateWithData:self.ecdh.publicKey];
    NSData* dhKeyHash = [sha finalize];
    
    [openPacket encryptWithKey:dhKeyHash iv:packetIV];
    NSData* bodySig = [defaultSwitch.identity.rsaKeys sign:openPacket.body];
    sha = [SHA256 new];
    [sha updateWithData:self.ecdh.publicKey];
    [sha updateWithData:[self.inLineId dataFromHexString]];
    NSData* encryptedSig = [CTRAES256Encryptor encryptPlaintext:bodySig key:[sha finalize] iv:packetIV];
    [openPacket.json setObject:[encryptedSig base64EncodedStringWithOptions:0] forKey:@"sig"];
    
    [defaultSwitch sendPacket:openPacket toAddress:self.address];
    
    NSData* sharedSecret = [self.ecdh agreeWithRemotePublicKey:self.remoteECCKey];
    NSMutableData* keyingMaterial = [NSMutableData dataWithLength:32 + sharedSecret.length];
    [keyingMaterial replaceBytesInRange:NSMakeRange(0, sharedSecret.length) withBytes:[sharedSecret bytes] length:sharedSecret.length];
    [keyingMaterial replaceBytesInRange:NSMakeRange(sharedSecret.length, 16) withBytes:[[self.outLineId dataFromHexString] bytes] length:16];
    [keyingMaterial replaceBytesInRange:NSMakeRange(keyingMaterial.length - 16, 16) withBytes:[[self.inLineId dataFromHexString] bytes] length:16];
    self.decryptorKey = [SHA256 hashWithData:keyingMaterial];
    
    [keyingMaterial replaceBytesInRange:NSMakeRange(sharedSecret.length, 16) withBytes:[[self.inLineId dataFromHexString] bytes] length:16];
    [keyingMaterial replaceBytesInRange:NSMakeRange(keyingMaterial.length - 16, 16) withBytes:[[self.outLineId dataFromHexString] bytes] length:16];
    self.encryptorKey = [SHA256 hashWithData:keyingMaterial];
    NSLog(@"Encryptor key: %@", self.encryptorKey);
    
    NSLog(@"Decryptor key: %@", self.decryptorKey);
}

-(void)handlePacket:(THPacket *)packet;
{
    NSLog(@"Going to handle a packet");
    THPacket* innerPacket = [THPacket packetData:[CTRAES256Decryptor decryptPlaintext:packet.body key:self.decryptorKey iv:[[packet.json objectForKey:@"iv"] dataFromHexString]]];
    NSLog(@"Packet is type %@", [innerPacket.json objectForKey:@"type"]);
    NSString* channelId = [innerPacket.json objectForKey:@"c"];
    NSString* channelType = [innerPacket.json objectForKey:@"type"];
    
    if ([channelType isEqualToString:@"seek"]) {
        // On a seek we send back what we know about
        THPacket* response = [THPacket new];
        [response.json setObject:@(YES) forKey:@"end"];
        [response.json setObject:channelId forKey:@"c"];
        THSwitch* defaultSwitch = [THSwitch defaultSwitch];
        NSArray* sees = [defaultSwitch seek:[innerPacket.json objectForKey:@"seek"]];
        if (sees == nil) {
            sees = [NSArray array];
        }
        [response.json setObject:[sees valueForKey:@"seekString"] forKey:@"see"];
        
        [self sendPacket:response];
    }
}

-(NSString*)seekString;
{
    const struct sockaddr_in* addr = [self.address bytes];
    return [NSString stringWithFormat:@"%@,%s,%d", self.toIdentity.hashname, inet_ntoa(addr->sin_addr),addr->sin_port];
}

-(void)sendPacket:(THPacket *)packet;
{
    THPacket* linePacket = [THPacket new];
    [linePacket.json setObject:self.outLineId forKey:@"line"];
    [linePacket.json setObject:@"line" forKey:@"type"];
    NSData* iv = [RNG randomBytesOfLength:16];
    [linePacket.json setObject:[iv hexString] forKey:@"iv"];
    linePacket.body = [packet encode];
    
    [linePacket encryptWithKey:self.encryptorKey iv:iv];
    
    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
    [defaultSwitch sendPacket:linePacket toAddress:self.address];
}
@end