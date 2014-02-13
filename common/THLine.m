
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
#import "THRSA.h"
#import "THSwitch.h"
#import "CTRAES256.h"
#import "NSString+HexString.h"
#import "THChannel.h"
#import "THMeshBuckets.h"

#include <arpa/inet.h>

@implementation THLine

-(id)init;
{
    self = [super init];
    if (self) {
        self.isOpen = NO;
        self.lastActitivy = time(NULL);
    }
    return self;
}

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
    self.createdAt = (NSInteger)([now timeIntervalSince1970]) * 1000;
    NSLog(@"Open timestamp is %ld", self.createdAt);
    [innerPacket.json setObject:[NSNumber numberWithInteger:self.createdAt] forKey:@"at"];
    
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
}

-(void)openLine;
{
    
    NSData* sharedSecret = [self.ecdh agreeWithRemotePublicKey:self.remoteECCKey];
    NSMutableData* keyingMaterial = [NSMutableData dataWithLength:32 + sharedSecret.length];
    [keyingMaterial replaceBytesInRange:NSMakeRange(0, sharedSecret.length) withBytes:[sharedSecret bytes] length:sharedSecret.length];
    [keyingMaterial replaceBytesInRange:NSMakeRange(sharedSecret.length, 16) withBytes:[[self.outLineId dataFromHexString] bytes] length:16];
    [keyingMaterial replaceBytesInRange:NSMakeRange(keyingMaterial.length - 16, 16) withBytes:[[self.inLineId dataFromHexString] bytes] length:16];
    self.decryptorKey = [SHA256 hashWithData:keyingMaterial];
    
    [keyingMaterial replaceBytesInRange:NSMakeRange(sharedSecret.length, 16) withBytes:[[self.inLineId dataFromHexString] bytes] length:16];
    [keyingMaterial replaceBytesInRange:NSMakeRange(keyingMaterial.length - 16, 16) withBytes:[[self.outLineId dataFromHexString] bytes] length:16];
    self.encryptorKey = [SHA256 hashWithData:keyingMaterial];
    //NSLog(@"Encryptor key: %@", self.encryptorKey);
    //NSLog(@"Decryptor key: %@", self.decryptorKey);
    
    [self.toIdentity.channels enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSLog(@"Checking %@ as %@", obj, [obj class]);
        // Get all our pending reliable channels spun out
        if ([obj class] != [THReliableChannel class]) return;
        THReliableChannel* channel = (THReliableChannel*)obj;
        // If the channel already thinks it's good, we'll just ignore it's state
        if (channel.channelIsReady) return;

        NSLog(@"Going to flush");
        [channel flushOut];
    }];
    
    self.isOpen = YES;
}

-(void)handlePacket:(THPacket *)packet;
{
    self.lastInActivity = time(NULL);
    self.lastActitivy = time(NULL);
    
    //NSLog(@"Going to handle a packet");
    THPacket* innerPacket = [THPacket packetData:[CTRAES256Decryptor decryptPlaintext:packet.body key:self.decryptorKey iv:[[packet.json objectForKey:@"iv"] dataFromHexString]]];
    //NSLog(@"Packet is type %@", [innerPacket.json objectForKey:@"type"]);
    NSLog(@"Line %@ handling %@", self.toIdentity.hashname, innerPacket.json);
    NSString* channelId = [innerPacket.json objectForKey:@"c"];
    NSString* channelType = [innerPacket.json objectForKey:@"type"];
    
    THSwitch* thSwitch = [THSwitch defaultSwitch];
    
    // if the switch is handling it bail
    if ([thSwitch findPendingSeek:innerPacket]) return;
    
    if ([channelType isEqualToString:@"seek"]) {
        // On a seek we send back what we know about
        THPacket* response = [THPacket new];
        [response.json setObject:@(YES) forKey:@"end"];
        [response.json setObject:channelId forKey:@"c"];
        THSwitch* defaultSwitch = [THSwitch defaultSwitch];
        NSArray* sees = [defaultSwitch.meshBuckets closeInBucket:[THIdentity identityFromHashname:[innerPacket.json objectForKey:@"seek"]]];
        if (sees == nil) {
            sees = [NSArray array];
        }
        [response.json setObject:[sees valueForKey:@"seekString"] forKey:@"see"];
        
        [self sendPacket:response];
    } else if ([channelType isEqualToString:@"link"]) {
        THSwitch* defaultSwitch = [THSwitch defaultSwitch];
        
        [defaultSwitch.meshBuckets addIdentity:self.toIdentity];
        
        THUnreliableChannel* linkChannel = [THUnreliableChannel new];
        linkChannel.toIdentity = self.toIdentity;
        linkChannel.channelId = [innerPacket.json objectForKey:@"c"];
        linkChannel.channelIsReady = YES;
        [linkChannel setState:THChannelOpen];
        
        THUnreliableChannel* curChannel = (THUnreliableChannel*)[self.toIdentity channelForType:@"link"];
        if (curChannel) {
            [self.toIdentity.channels removeObjectForKey:curChannel.channelId];
        }
        [self.toIdentity.channels setObject:linkChannel forKey:linkChannel.channelId];
        linkChannel.delegate = defaultSwitch.meshBuckets;
        [defaultSwitch.meshBuckets channel:linkChannel handlePacket:innerPacket];
    } else if ([channelType isEqualToString:@"peer"]) {
        // TODO:  Check this logic in association with the move to channels on identity
        THLine* peerLine = [thSwitch lineToHashname:[innerPacket.json objectForKey:@"peer"]];
        if (!peerLine) {
            // What? We don't know about this person, bye bye
            return;
        }
        
        THPacket* connectPacket = [THPacket new];
        [connectPacket.json setObject:[[RNG randomBytesOfLength:16] hexString] forKey:@"c"];
        [connectPacket.json setObject:@"connect" forKey:@"type"];
        const struct sockaddr_in* addr = [packet.fromAddress bytes];
        [connectPacket.json setObject:[NSString stringWithUTF8String:inet_ntoa(addr->sin_addr)] forKey:@"ip"];
        [connectPacket.json setObject:[NSNumber numberWithUnsignedInt:addr->sin_port] forKey:@"port"];
        connectPacket.body = [peerLine.toIdentity.rsaKeys DERPublicKey];
        
        [self.toIdentity sendPacket:connectPacket];
    } else if ([channelType isEqualToString:@"connect"]) {
        THIdentity* peerIdentity = [THIdentity identityFromPublicKey:innerPacket.body];
        NSLog(@"Going to connect to %@", peerIdentity.hashname);
        THLine* curLine = [thSwitch lineToHashname:peerIdentity.hashname];
        if (curLine) {
            // We don't need to do anything?
            return;
        }
        
        // Iterate over the paths and find the ipv4
        [[innerPacket.json objectForKey:@"paths"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSDictionary* pathInfo = (NSDictionary*)obj;
            if ([[obj objectForKey:@"type"] isEqualToString:@"ipv4"]) {
                *stop = YES;
                [peerIdentity setIP:[pathInfo objectForKey:@"ip"] port:[[pathInfo objectForKey:@"port"] unsignedIntegerValue]];
            }
        }];
        
        // TODO: This is old and DEPRECATED, to be removed
        if (peerIdentity.address.length == 0) {
            NSString* ip = [innerPacket.json objectForKey:@"ip"];
            NSNumber* port = [innerPacket.json objectForKey:@"port"];
            
            [peerIdentity setIP:ip port:[port unsignedIntegerValue]];
        }
        [thSwitch openLine:peerIdentity];
    } else {
        NSNumber* seq = [innerPacket.json objectForKey:@"seq"];
        // Let the channel instance handle it
        THChannel* channel = [self.toIdentity.channels objectForKey:channelId];
        if (channel) {
            if (seq) {
                // This is a reliable channel, let's make sure we're in a good state
                THReliableChannel* reliableChannel = (THReliableChannel*)channel;
                if (seq.unsignedIntegerValue == 0 && [[innerPacket.json objectForKey:@"ack"] unsignedIntegerValue] == 0) {
                    reliableChannel.channelIsReady = YES;
                    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
                    if ([defaultSwitch.delegate respondsToSelector:@selector(channelReady:type:firstPacket:)]) {
                        [defaultSwitch.delegate channelReady:reliableChannel type:ReliableChannel firstPacket:innerPacket];
                    }
                }
            }
            [channel handlePacket:innerPacket];
        } else {
            // See if it's a reliable or unreliable channel
            if (!channelType) {
                THPacket* errPacket = [THPacket new];
                [errPacket.json setObject:@"Unknown channel packet type." forKey:@"err"];
                [errPacket.json setObject:channelId forKey:@"c"];
                
                [self.toIdentity sendPacket:errPacket];
                return;
            }
            THChannel* newChannel;
            THChannelType newChannelType;
            if (seq && [seq unsignedIntegerValue] == 0) {
                newChannel = [[THReliableChannel alloc] initToIdentity:self.toIdentity];
                newChannelType = ReliableChannel;
            } else {
                newChannel = [[THUnreliableChannel alloc] initToIdentity:self.toIdentity];
                newChannelType = UnreliableChannel;
            }
            newChannel.channelId = channelId;
            THSwitch* defaultSwitch = [THSwitch defaultSwitch];
            if ([defaultSwitch.delegate respondsToSelector:@selector(channelReady:type:firstPacket:)]) {
                [defaultSwitch.delegate channelReady:newChannel type:newChannelType firstPacket:innerPacket];
            }
            newChannel.channelIsReady = YES;
            newChannel.type = channelType;
            NSLog(@"Adding a channel");
            [self.toIdentity.channels setObject:newChannel forKey:channelId];
            //[newChannel handlePacket:innerPacket];
        }
        
    }
}

-(void)sendPacket:(THPacket *)packet;
{
    self.lastOutActivity = time(NULL);
    THPacket* linePacket = [THPacket new];
    [linePacket.json setObject:self.outLineId forKey:@"line"];
    [linePacket.json setObject:@"line" forKey:@"type"];
    NSData* iv = [RNG randomBytesOfLength:16];
    [linePacket.json setObject:[iv hexString] forKey:@"iv"];
    linePacket.body = [packet encode];
    
    NSLog(@"Sending to %@: %@", self.toIdentity.hashname, packet.json);
    
    [linePacket encryptWithKey:self.encryptorKey iv:iv];
    
    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
    [defaultSwitch sendPacket:linePacket toAddress:self.address];
}
@end
