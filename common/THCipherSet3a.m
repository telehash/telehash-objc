//
//  THCipherSet3a.m
//  telehash
//
//  Created by Thomas Muldowney on 4/21/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THCipherSet3a.h"
#import "THPacket.h"
#import "SHA256.h"
#import "NSData+HexString.h"
#import "THIdentity.h"
#import "THLine.h"
#import "NSString+HexString.h"
#import "RNG.h"
#import "CLCLog.h"

static unsigned char csId3a[] = {0x3a};
static uint8_t nonce3a[] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1};

@implementation THCipherSet3a
-(NSString*)identifier
{
    return @"3a";
}

-(void)generateKeys
{
    crypto_box_keypair(publicKey, secretKey);
}

-(NSData*)fingerprint
{
    return [SHA256 hashWithData:[NSData dataWithBytesNoCopy:publicKey length:crypto_box_PUBLICKEYBYTES freeWhenDone:NO]];
}

-(THLine*)processOpen:(THPacket*)openPacket;
{
    // Process an open packet
    NSData* pubLineKey = [openPacket.body subdataWithRange:NSMakeRange(33, 32)];
    NSData* encryptedPacket = [openPacket.body subdataWithRange:NSMakeRange(65, openPacket.body.length - 65)];
    
    uint8_t agreedKey[crypto_box_BEFORENMBYTES];
    crypto_box_beforenm(agreedKey, [pubLineKey bytes], secretKey);
    
    NSMutableData* messageOut = [NSMutableData dataWithLength:(encryptedPacket.length - crypto_secretbox_MACBYTES)];
    if (crypto_secretbox_open_easy([messageOut mutableBytes], [encryptedPacket bytes], encryptedPacket.length, nonce3a, agreedKey) == -1) {
        CLCLogInfo(@"Unable to decrypt the incoming packet.");
        return nil;
    }
    
    THPacket* innerPacket = [THPacket packetData:messageOut];
    if (!innerPacket) {
        CLCLogInfo(@"Invalid inner packet");
        return nil;
    }
    innerPacket.returnPath = openPacket.returnPath;
    
    THCipherSet3a* incomingCS = [[THCipherSet3a alloc] initWithPublicKey:innerPacket.body privateKey:nil];
    if (!incomingCS) {
        CLCLogInfo(@"Unable to create cipher set for incoming key.");
        return nil;
    }
    
    NSString* incomingKeyFingerprint = [[SHA256 hashWithData:innerPacket.body] hexString];
    if (![[incomingCS.fingerprint hexString] isEqualToString:incomingKeyFingerprint]) {
        CLCLogInfo(@"Unable to verify the incoming key fingerprint");
        return nil;
    }
    
    // Calculate the line shared key
    NSMutableData* sharedLineKey = [NSMutableData dataWithLength:crypto_box_BEFORENMBYTES];
    crypto_box_beforenm([sharedLineKey mutableBytes], [innerPacket.body bytes], secretKey);
    
    // Use the shared line key to validate the packet
    if (crypto_onetimeauth_verify([openPacket.body bytes], [openPacket.body bytes] + crypto_onetimeauth_BYTES, openPacket.body.length - crypto_onetimeauth_BYTES, [sharedLineKey bytes]) != 0) {
        CLCLogInfo(@"Unable to authenticate the packet body.");
        return nil;
    }
    
    THIdentity* senderIdentity = [THIdentity identityFromParts:[innerPacket.json objectForKey:@"from"] key:incomingCS];
    if (!senderIdentity) {
        CLCLogInfo(@"Unable to validate and verify identity");
        return nil;
    }
    
    if (![senderIdentity.cipherParts objectForKey:@"3a"]) {
        [senderIdentity addCipherSet:incomingCS];
    }
    
    // If the new line is older than the current one bail
    if (senderIdentity.currentLine && senderIdentity.currentLine.createdAt > [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue]) {
        CLCLogInfo(@"Dumped a line that is older than current");
        return nil;
    }
    
    // If this is an attempt to reopen the original, just dump it and keep using it
    if ([senderIdentity.currentLine.outLineId isEqualToString:[innerPacket.json objectForKey:@"line"]] &&
        senderIdentity.currentLine.createdAt == [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue]) {
        CLCLogWarning(@"Attempted to reopen the line for %@ line id: %@", senderIdentity.hashname, senderIdentity.currentLine.outLineId);
        return nil;
    } else if (senderIdentity.currentLine.createdAt > 0 && senderIdentity.currentLine.createdAt < [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue]) {
        [senderIdentity.channels removeAllObjects];
        senderIdentity.currentLine = nil;
    }
    
    THLine* newLine = senderIdentity.currentLine;
    if (newLine) {
        // This is a partially opened line
        THCipherSetLineInfo3a* lineInfo = (THCipherSetLineInfo3a*)newLine.cipherSetInfo;
        lineInfo.remoteLineKey = innerPacket.body;
    } else {
        newLine = [THLine new];
        newLine.toIdentity = senderIdentity;
        senderIdentity.currentLine = newLine;
        
        THCipherSetLineInfo3a* lineInfo = [THCipherSetLineInfo3a new];
        lineInfo.cipherSet = incomingCS;
        lineInfo.remoteLineKey = innerPacket.body;
        
        newLine.cipherSetInfo = lineInfo;
    }
    [newLine handleOpen:innerPacket];
    
    return newLine;
    
}

-(void)finalizeLineKeys:(THLine*)line
{
    THCipherSetLineInfo3a* lineInfo = (THCipherSetLineInfo3a*)line.cipherSetInfo;
    
    NSMutableData* agreedKey = [NSMutableData dataWithLength:crypto_box_BEFORENMBYTES];
    crypto_box_beforenm([agreedKey mutableBytes], [lineInfo.remoteLineKey bytes], [lineInfo.secretLineKey bytes]);
    
    NSMutableData* keyingMaterial = [NSMutableData dataWithLength:32 + agreedKey.length];
    [keyingMaterial replaceBytesInRange:NSMakeRange(0, agreedKey.length) withBytes:[agreedKey bytes] length:agreedKey.length];
    [keyingMaterial replaceBytesInRange:NSMakeRange(agreedKey.length, 16) withBytes:[[line.outLineId dataFromHexString] bytes] length:16];
    [keyingMaterial replaceBytesInRange:NSMakeRange(keyingMaterial.length - 16, 16) withBytes:[[line.inLineId dataFromHexString] bytes] length:16];
    lineInfo.decryptorKey = [SHA256 hashWithData:keyingMaterial];
    //CLCLogInfo(@"decryptor key %@", lineInfo.decryptorKey);
    
    [keyingMaterial replaceBytesInRange:NSMakeRange(agreedKey.length, 16) withBytes:[[line.inLineId dataFromHexString] bytes] length:16];
    [keyingMaterial replaceBytesInRange:NSMakeRange(keyingMaterial.length - 16, 16) withBytes:[[line.outLineId dataFromHexString] bytes] length:16];
    lineInfo.encryptorKey = [SHA256 hashWithData:keyingMaterial];
    //CLCLogInfo(@"Encryptor key %@",  lineInfo.encryptorKey);
    
}
-(THPacket*)generateOpen:(THLine*)line from:(THIdentity*)fromIdentity
{
    if (!line.cipherSetInfo) {
        THCipherSetLineInfo3a* lineInfo = [THCipherSetLineInfo3a new];
        lineInfo.cipherSet = [line.toIdentity.cipherParts objectForKey:[self identifier]];
        line.cipherSetInfo = lineInfo;
    }
    THCipherSetLineInfo3a* lineInfo = (THCipherSetLineInfo3a*)line.cipherSetInfo;
    THCipherSet3a* remoteCS = (THCipherSet3a*)lineInfo.cipherSet;
    
    THPacket* innerPacket = [THPacket new];
    [innerPacket.json setObject:line.toIdentity.hashname forKey:@"to"];
    NSDate* now = [NSDate date];
    NSUInteger at = (NSInteger)([now timeIntervalSince1970]) * 1000;
    CLCLogInfo(@"Open timestamp is %ld", at);
    [innerPacket.json setObject:[NSNumber numberWithInteger:at] forKey:@"at"];
    NSMutableDictionary* fingerprints = [NSMutableDictionary dictionaryWithCapacity:fromIdentity.cipherParts.count];
    for (NSString* csId in fromIdentity.cipherParts) {
        THCipherSet* cipherSet = [fromIdentity.cipherParts objectForKey:csId];
        [fingerprints setObject:[cipherSet.fingerprint hexString] forKey:csId];
    }
    [innerPacket.json setObject:fingerprints forKey:@"from"];
    
    // Generate a new line id if we weren't given one
    if (!line.inLineId) {
        line.inLineId =  [[RNG randomBytesOfLength:16] hexString];
    }
    [innerPacket.json setObject:line.inLineId forKey:@"line"];
    innerPacket.body = [NSData dataWithBytesNoCopy:publicKey length:crypto_box_PUBLICKEYBYTES freeWhenDone:NO];
    
    NSData* innerPacketData = [innerPacket encode];
    
    THPacket* openPacket = [THPacket new];
    
    NSMutableData* authData = [NSMutableData dataWithLength:crypto_onetimeauth_BYTES];
    NSMutableData* openBody = [NSMutableData dataWithCapacity:(1 + crypto_onetimeauth_BYTES + crypto_box_PUBLICKEYBYTES + innerPacketData.length)];
    [openBody appendBytes:csId3a length:1];
    [openBody appendData:authData];
    [openBody appendData:lineInfo.publicLineKey];
    [openBody appendData:innerPacketData];
    
    NSMutableData* authKey = [NSMutableData dataWithLength:crypto_box_BEFORENMBYTES];
    crypto_box_beforenm([authKey mutableBytes], remoteCS->publicKey, secretKey);
    crypto_onetimeauth([authData mutableBytes], [openBody bytes] + 1 + crypto_onetimeauth_BYTES, crypto_box_PUBLICKEYBYTES + innerPacketData.length, [authKey bytes]);
    
    [openBody replaceBytesInRange:NSMakeRange(1, crypto_onetimeauth_BYTES) withBytes:[authData bytes]];
    
    CLCLogInfo(@"%@", openBody);
    openPacket.body = openBody;
    openPacket.jsonLength = 1;
    
    return openPacket;
}
@end

@implementation THCipherSetLineInfo3a
-(id)init
{
    self = [super init];
    if (self) {
        _publicLineKey = [NSMutableData dataWithLength:crypto_box_PUBLICKEYBYTES];
        _secretLineKey = [NSMutableData dataWithLength:crypto_box_SECRETKEYBYTES];
        crypto_box_keypair([_publicLineKey mutableBytes], [_secretLineKey mutableBytes]);
    }
    return self;
}

-(NSData*)encryptLinePacket:(THPacket*)packet
{
    NSData* encodedPacket = [packet encode];
    NSData* nonce = [RNG randomBytesOfLength:crypto_secretbox_NONCEBYTES];
    NSMutableData* encryptedData = [NSMutableData dataWithLength:(crypto_secretbox_NONCEBYTES + encodedPacket.length)];
    crypto_secretbox_easy([encryptedData mutableBytes] + crypto_secretbox_NONCEBYTES, [encodedPacket bytes], encodedPacket.length, [nonce bytes], [self.encryptorKey bytes]);
    
    [encryptedData replaceBytesInRange:NSMakeRange(0, crypto_secretbox_NONCEBYTES) withBytes:[nonce bytes]];
    
    return encryptedData;
}

-(void)decryptLinePacket:(THPacket*)packet
{
    unsigned long long cipherTextLength = packet.body.length - crypto_secretbox_NONCEBYTES - 16;
    NSMutableData* message = [NSMutableData dataWithLength:cipherTextLength];
    crypto_secretbox_open_easy([message mutableBytes], [message bytes] + 16 + crypto_secretbox_NONCEBYTES, cipherTextLength, [message bytes] + 16, [self.decryptorKey bytes]);
    packet.body = message;
}
@end