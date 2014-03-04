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
#import "CTRAES256.h"
#import "NSString+HexString.h"
#import "THLine.h"
#import "THMeshBuckets.h"
#import "THPendingJob.h"

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
@end

@implementation THCipherSet2a

-(void)processOpen:(THPacket *)openPacket switch:(THSwitch *)thSwitch
{
    // TODO:  Check the open lines for this address?
    
    // Process an open packet
    NSData* eccKey =  [thSwitch.identity.rsaKeys decrypt:[openPacket.body subdataWithRange:NSMakeRange(1, 256)]];
    
    NSData* innerPacketKey = [SHA256 hashWithData:eccKey];
    NSData* iv = [[openPacket.json objectForKey:@"iv"] dataFromHexString];
    THPacket* innerPacket = [THPacket packetData:[CTRAES256Decryptor decryptPlaintext:openPacket.body key:innerPacketKey iv:iv]];
    
    if (!innerPacket) {
        NSLog(@"Invalid inner packet");
        return;
    }
    
    THIdentity* senderIdentity = [THIdentity identityFromPublicKey:innerPacket.body];
    
    // If the new line is older than the current one bail
    if (senderIdentity.currentLine && senderIdentity.currentLine.createdAt > [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue]) {
        NSLog(@"Dumped a line that is older than current");
        return;
    }
    
    // If this is an attempt to reopen the original, just dump it and keep using it
    if ([senderIdentity.currentLine.outLineId isEqualToString:[innerPacket.json objectForKey:@"line"]] &&
        senderIdentity.currentLine.createdAt == [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue]) {
        NSLog(@"Attempted to reopen the line for %@ line id: %@", senderIdentity.hashname, senderIdentity.currentLine.outLineId);
        return;
    } else if (senderIdentity.currentLine.createdAt > 0 && senderIdentity.currentLine.createdAt < [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue]) {
        [senderIdentity.channels removeAllObjects];
        senderIdentity.currentLine = nil;
    }
    
    NSData* rawSigEncrypted = [[NSData alloc] initWithBase64EncodedString:[openPacket.json objectForKey:@"sig"] options:0];
    SHA256* sigKeySha = [SHA256 new];
    [sigKeySha updateWithData:eccKey];
    [sigKeySha updateWithData:[[innerPacket.json objectForKey:@"line" ] dataFromHexString]];
    NSData* sigKey = [sigKeySha finish];
    NSData* rawSig = [CTRAES256Decryptor decryptPlaintext:rawSigEncrypted key:sigKey iv:iv];
    if (![senderIdentity.rsaKeys verify:openPacket.body withSignature:rawSig]) {
        NSLog(@"Invalid signature, dumping.");
        return;
    }
    
    THLine* newLine = senderIdentity.currentLine;
    
    }

@end