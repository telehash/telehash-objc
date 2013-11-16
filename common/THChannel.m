//
//  THChannel.m
//  telehash
//
//  Created by Thomas Muldowney on 10/5/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THChannel.h"
#import "THPacket.h"
#import "THIdentity.h"
#import "RNG.h"
#import "NSData+HexString.h"
#import "SHA256.h"
#import "THSwitch.h"
#import "CTRAES256.h"

@interface THChannel() {
}
-(void)startOpen;
@end

@implementation THChannel

-(id)initToIdentity:(THIdentity*)identity delegate:(id<THChannelDelegate>)delegate;
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        self.channelIsReady = NO;
    }
    return self;
}

-(void)sendPacket:(THPacket *)packet;
{
}

-(void)startOpen;
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
    if (!self.outLineId) {
        self.outLineId =  [[RNG randomBytesOfLength:16] hexString];
    }
    [innerPacket.json setObject:self.outLineId forKey:@"line"];
    innerPacket.body = self.toIdentity.rsaKeys.DERPublicKey;
    
    openPacket.body = [innerPacket encode];
    NSData* packetIV = [RNG randomBytesOfLength:16];
    [openPacket.json setObject:[packetIV hexString] forKey:@"iv"];
    
    SHA256* sha = [SHA256 new];
    [sha updateWithData:self.ecdh.publicKey];
    NSData* dhKeyHash = [sha finalize];
    
    [openPacket encryptWithKey:dhKeyHash iv:packetIV];
    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
    NSData* bodySig = [defaultSwitch.identity.rsaKeys sign:openPacket.body];
    sha = [SHA256 new];
    [sha updateWithData:self.ecdh.publicKey];
    [sha updateWithData:[self.outLineId dataUsingEncoding:NSUTF8StringEncoding]];
    NSData* encryptedSig = [CTRAES256Encryptor encryptPlaintext:bodySig key:[sha finalize] iv:packetIV];
    [openPacket.json setObject:[encryptedSig base64EncodedStringWithOptions:0] forKey:@"sig"];
    
    // TODO:  Encode and send!
}
@end
