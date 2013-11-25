//
//  THSwitch.m
//  telehash
//
//  Created by Thomas Muldowney on 10/3/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THSwitch.h"
#import "THPacket.h"
#import "THIdentity.h"
#import "ECDH.h"
#import "SHA256.h"
#import "CTRAES256.h"
#import "NSString+HexString.h"
#import "THLine.h"

@interface THSwitch()

@property NSMutableDictionary* openLines;

@property GCDAsyncUdpSocket* udpSocket;


@end

@implementation THSwitch

+(id)defaultSwitch;
{
    static THSwitch* sharedSwitch;
    static dispatch_once_t oneTime;
    dispatch_once(&oneTime, ^{
        sharedSwitch = [[self alloc] init];
    });
    return sharedSwitch;
}

+(id)THSWitchWithIdentity:(THIdentity*)identity;
{
    THSwitch* thSwitch = [THSwitch new];
    if (thSwitch) {
        
    }
    return thSwitch;
}

-(id)init;
{
    if (self) {
        self.openLines = [NSMutableDictionary dictionary];
        self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        self.channelQueue = dispatch_queue_create("channelWorkQueue", NULL);
        self.dhtQueue = dispatch_queue_create("dhtWorkQueue", NULL);
    }
    return self;
}

-(void)start;
{
    NSError* bindError;
    [self.udpSocket bindToPort:0 error:&bindError];
    if (bindError != nil) {
        // TODO:  How do we show errors?!
        NSLog(@"%@", bindError);
        return;
    }
    NSLog(@"Now listening on %d", self.udpSocket.localPort);
    NSError* recvError;
    [self.udpSocket beginReceiving:&recvError];
    // TODO: Needs more error handling
}

-(void)sendPacket:(THPacket*)packet toAddress:(NSData*)address;
{
    //TODO:  Evaluate using a timeout!
    [self.udpSocket sendData:[packet encode] toAddress:address withTimeout:-1 tag:0];
}

/*
-channelForType:(NSString*)type to:(NSString*)hashname;
{
    
}
*/

-(NSArray*)seek:(NSString *)hashname;
{
    NSMutableArray* entries = [NSMutableArray array];
    [self.openLines enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        THLine* line = (THLine*)obj;
        if ([line.toIdentity.hashname isEqualToString:hashname]) {
            [entries addObject:line];
        }
    }];
    [entries sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        THLine* lh = (THLine*)obj1;
        THLine* rh = (THLine*)obj2;
        
        NSInteger lhDistance = [self.identity distanceFrom:lh.toIdentity];
        NSInteger rhDistance = [self.identity distanceFrom:rh.toIdentity];
        
        if (lhDistance > rhDistance) return (NSComparisonResult)NSOrderedDescending;
        if (lhDistance < rhDistance) return (NSComparisonResult)NSOrderedAscending;
        return (NSComparisonResult)NSOrderedSame;
    }];
    return entries;
}

-(THLine*)lineToHashname:(NSString*)hashname;
{
    // XXX: If we don't have a line should we do an open here?
    return [self.openLines objectForKey:hashname];
}

#pragma region -- UDP Handlers

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    THPacket* incomingPacket = [THPacket packetData:data];
    if (!incomingPacket) {
        NSLog(@"Unexpected or unparseable packet form %@", address);
        return;
    }
    
    if ([[incomingPacket.json objectForKey:@"type"] isEqualToString:@"open"]) {
        // TODO:  Check the open lines for this address?
        
        // Process an open packet
        NSData* decodedKey = [[NSData alloc] initWithBase64EncodedData:[incomingPacket.json objectForKey:@"open"] options:0];
        NSData* eccKey =  [self.identity.rsaKeys decrypt:decodedKey];
        
        NSData* innerPacketKey = [SHA256 hashWithData:eccKey];
        NSData* iv = [[incomingPacket.json objectForKey:@"iv"] dataFromHexString];
        THPacket* innerPacket = [THPacket packetData:[CTRAES256Decryptor decryptPlaintext:incomingPacket.body key:innerPacketKey iv:iv]];
        
        if (!innerPacket) {
            NSLog(@"Invalid inner packet");
            return;
        }
        
        THIdentity* senderIdentity = [THIdentity identityFromPublicKey:innerPacket.body];
        NSData* rawSigEncrypted = [[NSData alloc] initWithBase64EncodedString:[incomingPacket.json objectForKey:@"sig"] options:0];
        SHA256* sigKeySha = [SHA256 new];
        [sigKeySha updateWithData:eccKey];
        [sigKeySha updateWithData:[[innerPacket.json objectForKey:@"line" ] dataFromHexString]];
        NSData* sigKey = [sigKeySha finalize];
        NSData* rawSig = [CTRAES256Decryptor decryptPlaintext:rawSigEncrypted key:sigKey iv:iv];
        if (![senderIdentity.rsaKeys verify:incomingPacket.body withSignature:rawSig]) {
            NSLog(@"Invalid signature, dumping.");
            return;
        }
        
        THLine* newLine = [THLine new];
        newLine.outLineId = [innerPacket.json objectForKey:@"line"];
        newLine.toIdentity = senderIdentity;
        newLine.address = address;
        newLine.remoteECCKey = eccKey;
        
        NSLog(@"Line setup for %@", newLine.outLineId);
        
        [newLine sendOpen];
        [newLine openLine];
        
        [self.openLines setObject:newLine forKey:newLine.inLineId];
        if ([self.delegate respondsToSelector:@selector(openedLine:)]) {
            [self.delegate openedLine:newLine];
        }
        
    } else if([[incomingPacket.json objectForKey:@"type"] isEqualToString:@"line"]) {
        NSLog(@"Received a line packet for %@", [incomingPacket.json objectForKey:@"line"]);
        // Process a line packet
        THLine* line = [self.openLines objectForKey:[incomingPacket.json objectForKey:@"line"]];
        // If there is no line to handle this dump it
        if (line == nil) {
            return;
        }
        [line handlePacket:incomingPacket];
    } else {
        NSLog(@"We received an unknown packet type: %@", [incomingPacket.json objectForKey:@"type"]);
        return;
    }
}

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    
}

@end
