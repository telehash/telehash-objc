//
//  THCipherSet2a.m
//  telehash
//
//  Created by Thomas Muldowney on 4/21/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THCipherSet2a.h"
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
#import "THRSA.h"
#import "CLCLog.h"
#import "THPath.h"

static unsigned char iv2a[] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1};
static unsigned char csId2a[] = {0x2a};
static unsigned char eccHeader[] = {0x04};

@implementation  THCipherSetLineInfo2a
-(NSData*)encryptLinePacket:(THPacket*)packet iv:(NSData*)iv
{
    // So broken...
    if (!self.encryptorKey) return nil;
    
    NSData* encodedPacket = [packet encode];
    GCMAES256Encryptor* encryptor = [GCMAES256Encryptor encryptPlaintext:encodedPacket key:self.encryptorKey iv:iv];
    NSMutableData* data = [NSMutableData dataWithCapacity:(iv.length + encryptor.cipherText.length + encryptor.mac.length)];
    [data appendData:iv];
    [data appendData:encryptor.cipherText];
    [data appendData:encryptor.mac];
    return data;
}

-(NSData*)encryptLinePacket:(THPacket*)packet
{
    NSData* iv = [RNG randomBytesOfLength:16];
    return [self encryptLinePacket:packet iv:iv];
}

-(void)decryptLinePacket:(THPacket*)packet
{
	if (!self.decryptorKey) return;
	if (packet.body.length < 32) return;
	
    NSData* iv = [packet.body subdataWithRange:NSMakeRange(16, 16)];
    NSData* cipherText = [packet.body subdataWithRange:NSMakeRange(32, packet.body.length - 48)];
    NSData* mac = [packet.body subdataWithRange:NSMakeRange(packet.body.length - 16, 16)];
    GCMAES256Decryptor* decryptor = [GCMAES256Decryptor decryptPlaintext:cipherText mac:mac key:self.decryptorKey iv:iv];
    packet.body = decryptor.plainText;
}
@end

@implementation THCipherSet2a
-(NSString*)identifier
{
    return @"2a";
}

-(NSData*)fingerprint
{
    return [SHA256 hashWithData:self.rsaKeys.DERPublicKey];
}

-(NSData *)publicKey
{
    return self.rsaKeys.DERPublicKey;
}

-(THLine*)processOpen:(THPacket *)openPacket
{
    // Process an open packet
    NSData* remoteECCKey = [self.rsaKeys decrypt:[openPacket.body subdataWithRange:NSMakeRange(1, 256)]];
    if (!remoteECCKey) {
        CLCLog(CLC_LEVEL_WARNING, @"Unable to decrypt remote ecc key");
        return nil;
    }
    NSMutableData* prefixedRemoteEccKey = [NSMutableData dataWithBytes:eccHeader length:1];
    [prefixedRemoteEccKey appendData:remoteECCKey];
    
    NSData* innerPacketKey = [SHA256 hashWithData:remoteECCKey];
    NSData* iv = [NSData dataWithBytesNoCopy:iv2a length:16 freeWhenDone:NO];
    NSData* sigData = [openPacket.body subdataWithRange:NSMakeRange(257, 260)];
    NSData* encryptedInner = [openPacket.body subdataWithRange:NSMakeRange(517, openPacket.body.length - 517 - 16)];
    NSData* mac = [openPacket.body subdataWithRange:NSMakeRange(openPacket.body.length - 16, 16)];
    GCMAES256Decryptor* decryptor = [GCMAES256Decryptor decryptPlaintext:encryptedInner mac:mac key:innerPacketKey iv:iv];
    if (!decryptor) {
        CLCLog(CLC_LEVEL_INFO, @"Unable to verify incoming packet");
        return nil;
    }
    THPacket* innerPacket = [THPacket packetData:decryptor.plainText];
    innerPacket.returnPath = openPacket.returnPath;
    
    if (!innerPacket) {
        CLCLogInfo(@"Invalid inner packet");
        return nil;
    }
    
    THCipherSet2a* incomingCS = [[THCipherSet2a alloc] initWithPublicKey:innerPacket.body privateKey:nil];
    if (!incomingCS) {
        CLCLogInfo(@"Unable to create cipher set for incoming key.");
        return nil;
    }
    NSString* incomingKeyFingerprint = [[SHA256 hashWithData:innerPacket.body] hexString];
    if (![[incomingCS.fingerprint hexString] isEqualToString:incomingKeyFingerprint]) {
        CLCLogInfo(@"Unable to verify the incoming key fingerprint");
        return nil;
    }
    THIdentity* senderIdentity = [THIdentity identityFromParts:[innerPacket.json objectForKey:@"from"] key:incomingCS];
    if (!senderIdentity) {
        CLCLogInfo(@"Unable to validate and verify identity");
        return nil;
    }
    
    if (![senderIdentity.cipherParts objectForKey:@"2a"]) {
        [senderIdentity addCipherSet:incomingCS];
    }
    
    SHA256* sigKeySha = [SHA256 new];
    [sigKeySha updateWithData:remoteECCKey];
    [sigKeySha updateWithData:[[innerPacket.json objectForKey:@"line" ] dataFromHexString]];
    NSData* sigKey = [sigKeySha finish];
    NSData* sigMac = [sigData subdataWithRange:NSMakeRange(sigData.length - 4, 4)];
    GCMAES256Decryptor* sigDecryptor = [GCMAES256Decryptor decryptPlaintext:[sigData subdataWithRange:NSMakeRange(0, 256)] mac:sigMac key:sigKey iv:iv];
    if (!sigDecryptor) {
        CLCLogInfo(@"Unable to authenticate the signature.");
        return nil;
    }
    if (![incomingCS.rsaKeys verify:[openPacket.body subdataWithRange:NSMakeRange(517, openPacket.body.length - 517)] withSignature:sigDecryptor.plainText]) {
        CLCLogInfo(@"Invalid signature, dumping.");
        return nil;
    }
    
    // If the new line is older than the current one bail
    if (senderIdentity.currentLine && senderIdentity.currentLine.createdAt > [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue]) {
        CLCLogInfo(@"Dumped a line that is older than current");
        return nil;
    }
    
    // If this is an attempt to reopen the original, just dump it and keep using it
    if ([senderIdentity.currentLine.outLineId isEqualToString:[innerPacket.json objectForKey:@"line"]] &&
        senderIdentity.currentLine.createdAt == [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue]) {
        // Add the route then bail
        CLCLogInfo(@"Attempted to reopen the line for %@ line id: %@", senderIdentity.hashname, senderIdentity.currentLine.outLineId);
        // XXX TODO:  Should we add a path here?
        /*
        if (![senderIdentity pathMatching:openPacket.returnPath.information]) {
            [senderIdentity addPath:openPacket.returnPath];
        }
        */
        return nil;
    } else if (senderIdentity.currentLine.createdAt > 0 && senderIdentity.currentLine.createdAt < [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue]) {
		[senderIdentity closeChannels];
    }
    
    THLine* newLine = senderIdentity.currentLine;
    
    if (newLine) {
        // This is a partially opened line
        THCipherSetLineInfo2a* lineInfo = (THCipherSetLineInfo2a*)newLine.cipherSetInfo;
        lineInfo.remoteECCKey = prefixedRemoteEccKey;
		
		// TODO temas review
		//newLine.cipherSetInfo = lineInfo; //??
    } else {
        newLine = [THLine new];
        newLine.toIdentity = senderIdentity;
        senderIdentity.currentLine = newLine;
        
        THCipherSetLineInfo2a* lineInfo = [THCipherSetLineInfo2a new];
        lineInfo.cipherSet = incomingCS;
        lineInfo.remoteECCKey = prefixedRemoteEccKey;
        
        newLine.cipherSetInfo = lineInfo;
    }
    [newLine handleOpen:innerPacket];
    
    return newLine;
}

-(void)finalizeLineKeys:(THLine*)line
{
    THCipherSetLineInfo2a* lineInfo = (THCipherSetLineInfo2a*)line.cipherSetInfo;
    // Make sure we have a valid ECDH context
    if (!lineInfo.ecdh) {
        lineInfo.ecdh = [ECDH new];
    }
	// TODO temas review
	if (!lineInfo.remoteECCKey) {
		CLCLogError(@"line has no remoteECCKey");
		return;
	}
	
    NSData* sharedSecret = [lineInfo.ecdh agreeWithRemotePublicKey:lineInfo.remoteECCKey];
    NSMutableData* keyingMaterial = [NSMutableData dataWithLength:32 + sharedSecret.length];
    [keyingMaterial replaceBytesInRange:NSMakeRange(0, sharedSecret.length) withBytes:[sharedSecret bytes] length:sharedSecret.length];
    [keyingMaterial replaceBytesInRange:NSMakeRange(sharedSecret.length, 16) withBytes:[[line.outLineId dataFromHexString] bytes] length:16];
    [keyingMaterial replaceBytesInRange:NSMakeRange(keyingMaterial.length - 16, 16) withBytes:[[line.inLineId dataFromHexString] bytes] length:16];
    lineInfo.decryptorKey = [SHA256 hashWithData:keyingMaterial];
    
    [keyingMaterial replaceBytesInRange:NSMakeRange(sharedSecret.length, 16) withBytes:[[line.inLineId dataFromHexString] bytes] length:16];
    [keyingMaterial replaceBytesInRange:NSMakeRange(keyingMaterial.length - 16, 16) withBytes:[[line.outLineId dataFromHexString] bytes] length:16];
    lineInfo.encryptorKey = [SHA256 hashWithData:keyingMaterial];
}

-(THPacket*)generateOpen:(THLine*)line from:(THIdentity*)fromIdentity
{
    if (!line.cipherSetInfo) {
        // FIXME, should be the remote cipherSet
        THCipherSetLineInfo2a* lineInfo =[THCipherSetLineInfo2a new];
        lineInfo.cipherSet = [line.toIdentity.cipherParts objectForKey:[self identifier]];
        line.cipherSetInfo = lineInfo;
    }
    THCipherSetLineInfo2a* lineInfo = (THCipherSetLineInfo2a*)line.cipherSetInfo;
    THCipherSet2a* remoteCS = (THCipherSet2a*)lineInfo.cipherSet;
    
    THPacket* openPacket = [THPacket new];
    if (!lineInfo.ecdh) {
        lineInfo.ecdh = [ECDH new];
    }
    // Remove the prefix byte
    NSData* rawKey = [lineInfo.ecdh.publicKey subdataWithRange:NSMakeRange(1, lineInfo.ecdh.publicKey.length - 1)];
    // Encrypt the line key
    NSData* lineKey = [remoteCS.rsaKeys encrypt:rawKey];
    
    THPacket* innerPacket = [THPacket new];
    [innerPacket.json setObject:line.toIdentity.hashname forKey:@"to"];
    NSDate* now = [NSDate date];
    NSUInteger at = (NSInteger)([now timeIntervalSince1970]) * 1000;
    CLCLogDebug(@"Open timestamp is %ld", at);
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
    innerPacket.body = self.rsaKeys.DERPublicKey;
    
    NSData* innerPacketData = [innerPacket encode];
    
    SHA256* sha = [SHA256 new];
    [sha updateWithData:rawKey];
    NSData* dhKeyHash = [sha finish];
    
    GCMAES256Encryptor* packetEncryptor = [GCMAES256Encryptor encryptPlaintext:innerPacketData key:dhKeyHash iv:[NSData dataWithBytesNoCopy:iv2a length:16 freeWhenDone:NO]];
    if (!packetEncryptor) {
        CLCLogInfo(@"Unable to encrypt the inner packet");
        return nil;
    }
    
    // Build the signed chunk
    NSMutableData* sigData = [NSMutableData dataWithCapacity:(packetEncryptor.cipherText.length + packetEncryptor.mac.length)];
    [sigData appendData:packetEncryptor.cipherText];
    [sigData appendData:packetEncryptor.mac];
    
    NSData* bodySig = [self.rsaKeys sign:sigData];
    sha = [SHA256 new];
    [sha updateWithData:rawKey];
    [sha updateWithData:[line.inLineId dataFromHexString]];
    GCMAES256Encryptor* sigEncryptor = [GCMAES256Encryptor encryptPlaintext:bodySig key:[sha finish] iv:[NSData dataWithBytesNoCopy:iv2a length:16 freeWhenDone:NO] macLength:4];
    
    NSMutableData* openBody = [NSMutableData dataWithCapacity:(1 + 256 + 260 + openPacket.body.length + 16)];
    [openBody appendBytes:csId2a length:1];
    [openBody appendData:lineKey];
    [openBody appendData:sigEncryptor.cipherText];
    [openBody appendData:sigEncryptor.mac];
    [openBody appendData:packetEncryptor.cipherText];
    [openBody appendData:packetEncryptor.mac];
    
    CLCLogDebug(@"%@", openBody);
    openPacket.body = openBody;
    openPacket.jsonLength = 1;
    
    return openPacket;
}


-(void)generateKeys
{
    self.rsaKeys = [RSA generateRSAKeysOfLength:2048];
}

-(id)initWithPublicKeyPath:(NSString*)publicKeyPath privateKeyPath:(NSString*)privateKeyPath
{
    self = [super init];
    if (self) {
        NSFileManager* fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:publicKeyPath]) {
            return nil;
        }
        self.rsaKeys = [RSA RSAFromPublicKeyPath:publicKeyPath privateKeyPath:privateKeyPath];
    }
    return self;
}

-(id)initWithPublicKey:(NSData*)key privateKey:(NSData *)privateKey
{
    self = [super init];
    if (self) {
        self.rsaKeys = [RSA RSAWithPublicKey:key privateKey:privateKey];
    }
    return self;
}

@end
