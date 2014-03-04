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

static unsigned char iv2a[] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1};

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
@end

@implementation THCipherSet2a
{
    ECDH* ecdh;
    NSData* remoteECCKey;
}

-(THLine*)processOpen:(THPacket *)openPacket switch:(THSwitch *)thSwitch
{
    // TODO:  Check the open lines for this address?
    
    // Process an open packet
    remoteECCKey =  [thSwitch.identity.rsaKeys decrypt:[openPacket.body subdataWithRange:NSMakeRange(1, 256)]];
    
    NSData* innerPacketKey = [SHA256 hashWithData:remoteECCKey];
    NSData* iv = [NSData dataWithBytes:iv2a length:16];
    NSData* sigData = [openPacket.body subdataWithRange:NSMakeRange(257, 260)];
    NSData* encryptedInner = [openPacket.body subdataWithRange:NSMakeRange(517, openPacket.body.length - 517)];
    THPacket* innerPacket = [THPacket packetData:[GCMAES256Decryptor decryptPlaintext:encryptedInner key:innerPacketKey iv:iv]];
    
    if (!innerPacket) {
        NSLog(@"Invalid inner packet");
        return nil;
    }
    
    THIdentity* senderIdentity = [THIdentity identityFromPublicKey:innerPacket.body];
    
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
    
    SHA256* sigKeySha = [SHA256 new];
    [sigKeySha updateWithData:eccKey];
    [sigKeySha updateWithData:[[innerPacket.json objectForKey:@"line" ] dataFromHexString]];
    NSData* sigKey = [sigKeySha finish];
    NSData* rawSig = [CTRAES256Decryptor decryptPlaintext:rawSigEncrypted key:sigKey iv:iv];
    if (![senderIdentity.rsaKeys verify:openPacket.body withSignature:rawSig]) {
        NSLog(@"Invalid signature, dumping.");
        return nil;
    }
    
    THLine* newLine = senderIdentity.currentLine;
    
}

@end