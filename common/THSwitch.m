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

@interface THSwitch()

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
        self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
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

/*
-channelForType:(NSString*)type to:(NSString*)hashname;
{
    
}
*/

#pragma region -- UDP Handlers

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    THPacket* incomingPacket = [THPacket packetData:data];
    if (!incomingPacket) {
        NSLog(@"Unexpected or unparseable packet form %@", address);
        return;
    }
    
    if ([[incomingPacket.json objectForKey:@"type"] isEqualToString:@"open"]) {
        // Process an open packet
        NSData* decodedKey = [[NSData alloc] initWithBase64EncodedData:[incomingPacket.json objectForKey:@"open"] options:0];
        NSData* eccKey =  [self.identity.rsaKeys decrypt:decodedKey];
        NSLog(@"Got ecc key: %@", eccKey);
        ECDH* dh = [ECDH new];
        NSData* agreedValue = [dh agreeWithRemotePublicKey:eccKey];
        
        NSData* innerPacketKey = [SHA256 hashWithData:eccKey];
        NSLog(@"Decrypt key is %@", innerPacketKey);
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
        
        NSLog(@"The crypto checks out, should setup a channel");
        //TODO:  Setup the channel
    } else if([[incomingPacket.json objectForKey:@"type"] isEqualToString:@"line"]) {
        // Process a line packet
    } else {
        NSLog(@"We received an unknown packet type: %@", [incomingPacket.json objectForKey:@"type"]);
        return;
    }
}

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    
}

@end
