//
//  THCipherSet.m
//  telehash
//
//  Created by Thomas Muldowney on 2/27/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THCipherSet.h"
#import "THPacket.h"
#import "THIdentity.h"
#import "THSwitch.h"
#import "SHA256.h"
#import "GCMAES256.h"
#import "NSString+HexString.h"
#import "THLine.h"
#import "THMeshBuckets.h"
#import "THPendingJob.h"
#import "ECDH.h"
#import "RNG.h"
#import "NSData+HexString.h"

static unsigned char iv2a[] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1};
static unsigned char csId2a = 0x2a;

@implementation THCipherSet
+(THCipherSet*)cipherSetForOpen:(THPacket *)openPacket
{
    unsigned char* bytes = (unsigned char*)openPacket.body.bytes;
    switch (bytes[0]) {
    case 0x2a:
        return [THCipherSet2a new];
    default:
        return nil;
    }
}

-(THLine*)processOpen:(THPacket*)openPacket switch:(THSwitch*)thSwitch
{
    NSLog(@"Not implemented");
    return nil;
}

-(void)finalizeLineKeys:(THLine *)line
{
    NSLog(@"Not implemented THCipherSet finalizeKeys");
}
@end

@implementation THCipherSet2a
{
    ECDH* ecdh;
    NSData* remoteECCKey;
    NSData* encryptorKey;
    NSData* decryptorKey;
}

-(THLine*)processOpen:(THPacket *)openPacket switch:(THSwitch *)thSwitch
{
    // TODO:  Check the open lines for this address?
    
    // Process an open packet
    remoteECCKey =  [thSwitch.identity.rsaKeys decrypt:[openPacket.body subdataWithRange:NSMakeRange(1, 256)]];
    
    NSData* innerPacketKey = [SHA256 hashWithData:remoteECCKey];
    NSData* iv = [NSData dataWithBytes:iv2a length:16];
    NSData* sigData = [openPacket.body subdataWithRange:NSMakeRange(257, 260)];
    NSData* encryptedInner = [openPacket.body subdataWithRange:NSMakeRange(517, openPacket.body.length - 517 - 16)];
    NSData* mac = [openPacket.body subdataWithRange:NSMakeRange(openPacket.body.length - 16, 16)];
    GCMAES256Decryptor* decryptor = [GCMAES256Decryptor decryptPlaintext:encryptedInner mac:mac key:innerPacketKey iv:iv];
    if (!decryptor.verified) {
        NSLog(@"Unable to verify incoming packet");
        return nil;
    }
    THPacket* innerPacket = [THPacket packetData:decryptor.plainText];
    
    if (!innerPacket) {
        NSLog(@"Invalid inner packet");
        return nil;
    }
    
    THIdentity* senderIdentity = [THIdentity identityFromPublicKey:innerPacket.body];
    
    SHA256* sigKeySha = [SHA256 new];
    [sigKeySha updateWithData:remoteECCKey];
    [sigKeySha updateWithData:[[innerPacket.json objectForKey:@"line" ] dataFromHexString]];
    NSData* sigKey = [sigKeySha finish];
    NSData* sigMac = [sigData subdataWithRange:NSMakeRange(sigData.length - 4, 4)];
    GCMAES256Decryptor* sigDecryptor = [GCMAES256Decryptor decryptPlaintext:sigData mac:sigMac key:sigKey iv:iv];
    if (!sigDecryptor.verified) {
        NSLog(@"Unable to authenticate the signature.");
        return nil;
    }
    if (![senderIdentity.rsaKeys verify:openPacket.body withSignature:sigDecryptor.plainText]) {
        NSLog(@"Invalid signature, dumping.");
        return nil;
    }

    // If the new line is older than the current one bail
    if (senderIdentity.currentLine && senderIdentity.currentLine.createdAt > [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue]) {
        NSLog(@"Dumped a line that is older than current");
        return nil;
    }
    
    // If this is an attempt to reopen the original, just dump it and keep using it
    if ([senderIdentity.currentLine.outLineId isEqualToString:[innerPacket.json objectForKey:@"line"]] &&
        senderIdentity.currentLine.createdAt == [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue]) {
        NSLog(@"Attempted to reopen the line for %@ line id: %@", senderIdentity.hashname, senderIdentity.currentLine.outLineId);
        return nil;
    } else if (senderIdentity.currentLine.createdAt > 0 && senderIdentity.currentLine.createdAt < [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue]) {
        [senderIdentity.channels removeAllObjects];
        senderIdentity.currentLine = nil;
    }
    
    THLine* newLine = senderIdentity.currentLine;
    
    // TODO:  If we have an existing line we update it's info and give it back otherwise create
    
    if (newLine && newLine.inLineId) {
        // This is a partially opened line
        THCipherSet2a* cs = (THCipherSet2a*)newLine.cipherSet;
        cs->remoteECCKey = remoteECCKey;
    } else {
        newLine = [THLine new];
        newLine.toIdentity = senderIdentity;
        senderIdentity.currentLine = newLine;
    }
    [newLine handleOpen:innerPacket];
    
    return newLine;
}

-(void)finalizeLineKeys:(THLine*)line
{
    // Make sure we have a valid ECDH context
    if (!ecdh) {
        ecdh = [ECDH new];
    }
    
    NSData* sharedSecret = [ecdh agreeWithRemotePublicKey:remoteECCKey];
    NSMutableData* keyingMaterial = [NSMutableData dataWithLength:32 + sharedSecret.length];
    [keyingMaterial replaceBytesInRange:NSMakeRange(0, sharedSecret.length) withBytes:[sharedSecret bytes] length:sharedSecret.length];
    [keyingMaterial replaceBytesInRange:NSMakeRange(sharedSecret.length, 16) withBytes:[[line.outLineId dataFromHexString] bytes] length:16];
    [keyingMaterial replaceBytesInRange:NSMakeRange(keyingMaterial.length - 16, 16) withBytes:[[line.inLineId dataFromHexString] bytes] length:16];
    decryptorKey = [SHA256 hashWithData:keyingMaterial];
    
    [keyingMaterial replaceBytesInRange:NSMakeRange(sharedSecret.length, 16) withBytes:[[line.inLineId dataFromHexString] bytes] length:16];
    [keyingMaterial replaceBytesInRange:NSMakeRange(keyingMaterial.length - 16, 16) withBytes:[[line.outLineId dataFromHexString] bytes] length:16];
    encryptorKey = [SHA256 hashWithData:keyingMaterial];
}

-(THPacket*)generateOpen:(THLine*)line
{
    THPacket* openPacket = [THPacket new];
    [openPacket.json setObject:@"open" forKey:@"type"];
    if (!ecdh) {
        ecdh = [ECDH new];
    }
    // Remove the prefix byte
    NSData* rawKey = [ecdh.publicKey subdataWithRange:NSMakeRange(1, ecdh.publicKey.length - 1)];
    // Encrypt the line key
    NSData* lineKey = [line.toIdentity.rsaKeys encrypt:rawKey];
    
    THPacket* innerPacket = [THPacket new];
    [innerPacket.json setObject:line.toIdentity.hashname forKey:@"to"];
    NSDate* now = [NSDate date];
    NSUInteger at = (NSInteger)([now timeIntervalSince1970]) * 1000;
    NSLog(@"Open timestamp is %ld", at);
    [innerPacket.json setObject:[NSNumber numberWithInteger:at] forKey:@"at"];
    
    // Generate a new line id if we weren't given one
    if (!line.inLineId) {
        line.inLineId =  [[RNG randomBytesOfLength:16] hexString];
    }
    [innerPacket.json setObject:line.inLineId forKey:@"line"];
    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
    innerPacket.body = defaultSwitch.identity.rsaKeys.DERPublicKey;
    
    NSData* innerPacketData = [innerPacket encode];
    
    SHA256* sha = [SHA256 new];
    [sha updateWithData:ecdh.publicKey];
    NSData* dhKeyHash = [sha finish];
    
    GCMAES256Encryptor* packetEncryptor = [GCMAES256Encryptor encryptPlaintext:innerPacketData key:dhKeyHash iv:[NSData dataWithBytesNoCopy:iv2a length:16]];

    NSData* bodySig = [defaultSwitch.identity.rsaKeys sign:packetEncryptor.cipherText];
    sha = [SHA256 new];
    [sha updateWithData:ecdh.publicKey];
    [sha updateWithData:[line.inLineId dataFromHexString]];
    GCMAES256Encryptor* sigEncryptor = [GCMAES256Encryptor encryptPlaintext:bodySig key:[sha finish] iv:[NSData dataWithBytesNoCopy:iv2a length:16]];

    NSMutableData* openBody = [NSMutableData dataWithLength:(1 + 256 + 260 + openPacket.body.length + 16)];
    [openBody appendBytes:&csId2a length:1];
    [openBody appendData:lineKey];
    [openBody appendData:sigEncryptor.cipherText];
    [openBody appendData:packetEncryptor.cipherText];
    
    openPacket.body = openBody;
    
    return openPacket;
}

-(void)encryptLinePacket:(THPacket*)packet iv:(NSData*)iv
{
    GCMAES256Encryptor* encryptor = [GCMAES256Encryptor encryptPlaintext:packet.body key:encryptorKey iv:iv];
    NSMutableData* data = [NSMutableData dataWithLength:(packet.body.length + 32)];
    [data appendData:iv];
    [data appendData:encryptor.cipherText];
    [data appendData:encryptor.mac];
    packet.body = data;
}

-(void)encryptLinePacket:(THPacket*)packet
{
    NSData* iv = [RNG randomBytesOfLength:16];
    [self encryptLinePacket:packet iv:iv];
}

-(void)decryptLinePacket:(THPacket*)packet
{
    NSData* iv = [packet.body subdataWithRange:NSMakeRange(0, 16)];
    NSData* cipherText = [packet.body subdataWithRange:NSMakeRange(16, packet.body.length - 32)];
    NSData* mac = [packet.body subdataWithRange:NSMakeRange(packet.body.length - 16, 16)];
    GCMAES256Decryptor* decryptor = [GCMAES256Decryptor decryptPlaintext:cipherText mac:mac key:decryptorKey iv:iv];
    packet.body = decryptor.plainText;
}

@end