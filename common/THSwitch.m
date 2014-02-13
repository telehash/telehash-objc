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
#import "THChannel.h"
#import "RNG.h"
#import "NSData+HexString.h"
#import "THMeshBuckets.h"
#import "THPendingJob.h"
#include <arpa/inet.h>

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
        self.meshBuckets = [THMeshBuckets new];
        self.openLines = [NSMutableDictionary dictionary];
        self.pendingJobs = [NSMutableArray array];
        self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        self.channelQueue = dispatch_queue_create("channelWorkQueue", NULL);
        self.dhtQueue = dispatch_queue_create("dhtWorkQueue", NULL);
    }
    return self;
}

-(void)start;
{
    [self startOnPort:0];
}
-(void)startOnPort:(unsigned short)port
{
    self.meshBuckets.localIdentity = self.identity;
    
    NSError* bindError;
    [self.udpSocket bindToPort:port error:&bindError];
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

-(void)loadSeeds:(NSData *)seedData;
{
    NSError* error;
    NSArray* json = [NSJSONSerialization JSONObjectWithData:seedData options:0 error:&error];
    if (json) {
        [json enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSDictionary* entry = (NSDictionary*)obj;
            NSString* pubKey = [entry objectForKey:@"pubkey"];
            if (!pubKey) return;
            NSData* pubKeyData = [[NSData alloc] initWithBase64EncodedString:pubKey options:0];
            THIdentity* seedIdentity = [THIdentity identityFromPublicKey:pubKeyData];
            [seedIdentity setIP:[entry objectForKey:@"ip"] port:[[entry objectForKey:@"port"] unsignedIntegerValue]];
            
            [self openLine:seedIdentity];
        }];
    }
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

-(THLine*)lineToHashname:(NSString*)hashname;
{
    // XXX: If we don't have a line should we do an open here?
    // XXX: This is a common lookup, should we cache this another way as well?
    NSLog(@"looking for %@", hashname);
    __block THLine* ret = nil;
    [self.openLines enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        THLine* line = (THLine*)obj;
        if ([line.toIdentity.hashname isEqualToString:hashname]) {
            ret = line;
            *stop = YES;
        }
    }];
    NSLog(@"We found line to hashname %@ %@", ret.toIdentity.hashname, ret);
    return ret;
}

-(void)channel:(THChannel*)channel line:(THLine*)line firstPacket:(THPacket*)packet
{
    channel.line = line;
    [channel.toIdentity.channels setObject:channel forKey:channel.channelId];
    channel.state = THChannelOpen;
    channel.channelIsReady = YES;
    [channel sendPacket:packet];
}

-(void)openChannel:(THChannel *)channel firstPacket:(THPacket *)packet;
{
    // Check for an already open lines
    THLine* channelLine = channel.toIdentity.currentLine;
    if (!channelLine) {
        [self.pendingJobs addObject:[THPendingJob pendingJobFor:channel completion:^(id result) {
            [self channel:channel line:(THLine*)result firstPacket:packet];
        }]];
        [self openLine:channel.toIdentity];
    } else {
        [self channel:channel line:channelLine firstPacket:packet];
    }

}

-(void)openLine:(THIdentity *)toIdentity
{
    [self openLine:toIdentity completion:nil];
}

-(void)openLine:(THIdentity *)toIdentity completion:(LineOpenBlock)lineOpenCompletion
{
    if (toIdentity.currentLine) {
        if (lineOpenCompletion) lineOpenCompletion(toIdentity.currentLine);
        return;
    }
    
    // We have everything we need to direct request
    if (toIdentity.address && toIdentity.rsaKeys) {
        THLine* channelLine = [THLine new];
        channelLine.toIdentity = toIdentity;
        channelLine.address = toIdentity.address;
        toIdentity.currentLine = channelLine;
        
        [self.pendingJobs addObject:[THPendingJob pendingJobFor:channelLine completion:^(id result) {
            if (lineOpenCompletion) lineOpenCompletion(channelLine);
        }]];
        
        [channelLine sendOpen];
        return;
    };
    
    // Let's do a peer request
    if (toIdentity.via) {
        THPacket* peerPacket = [THPacket new];
        [peerPacket.json setObject:[[RNG randomBytesOfLength:16] hexString] forKey:@"c"];
        [peerPacket.json setObject:toIdentity.hashname forKey:@"peer"];
        [peerPacket.json setObject:@"peer" forKey:@"type"];
        [peerPacket.json setObject:@YES forKey:@"end"];
        
        [self.udpSocket sendData:[NSData data] toAddress:toIdentity.address withTimeout:-1 tag:0];
        
        // We blind send this and hope for the best!
        THIdentity* viaIdentity = [THIdentity identityFromHashname:toIdentity.via.hashname];
        [viaIdentity sendPacket:peerPacket];
        return;
    }
    
    // Find a way to it from the mesh
    [self.meshBuckets seek:toIdentity completion:^(BOOL found) {
        NSLog(@"Found it: %d", found);
    }];
}
 
-(BOOL)findPendingSeek:(THPacket *)packet;
{
    if ([self.pendingJobs count] == 0) return NO;
    __block BOOL handled = NO;
    // We only handle results, seek requests are in the line
    [self.pendingJobs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        THPendingJob* pendingJob = (THPendingJob*)obj;
        if (pendingJob.type != PendingSeek) return;
        THPacket* pendingPacket = (THPacket*)pendingJob.pending;
        if ([[pendingPacket.json objectForKey:@"c"] isEqualToString:[packet.json objectForKey:@"c"]]) {
            pendingJob.handler(packet);
            *stop = YES;
            handled = YES;
            [self.pendingJobs removeObjectAtIndex:idx];
        }
    }];
    return handled;
}

#pragma region -- UDP Handlers

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    const struct sockaddr_in* addr = [address bytes];
    NSLog(@"Incoming data from %@", [NSString stringWithUTF8String:inet_ntoa(addr->sin_addr)]);
    THPacket* incomingPacket = [THPacket packetData:data];
    incomingPacket.fromAddress = address;
    if (!incomingPacket) {
        NSLog(@"Unexpected or unparseable packet from %@: %@", [NSString stringWithUTF8String:inet_ntoa(addr->sin_addr)], [data base64EncodedStringWithOptions:0]);
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
        }
        
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
        
        THLine* newLine = senderIdentity.currentLine;
        
        // remove any existing lines to this hashname
        if (newLine) {
            [self.meshBuckets removeLine:newLine];
            [self.openLines removeObjectForKey:newLine.inLineId];
        }
        __block THPendingJob* pendingLineJob = nil;
        [self.pendingJobs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            THPendingJob* job = (THPendingJob*)obj;
            if (job.type != PendingLine) return;
            
            THLine* pendingLine = (THLine*)job.pending;
            if ([pendingLine.toIdentity.hashname isEqualToString:senderIdentity.hashname]) {
                pendingLineJob = job;
                *stop = YES;
                [self.pendingJobs removeObjectAtIndex:idx];
            }
        }];
        if (pendingLineJob) {
            newLine = (THLine*)pendingLineJob.pending;
            NSLog(@"Finish open on %@", newLine);
            newLine.outLineId = [innerPacket.json objectForKey:@"line"];
            newLine.remoteECCKey = eccKey;
            newLine.createdAt = [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue];
            newLine.lastInActivity = time(NULL);
            [newLine openLine];

            [self.openLines setObject:newLine forKey:newLine.inLineId];
            
            if ([self.delegate respondsToSelector:@selector(openedLine:)]) {
                [self.delegate openedLine:newLine];
            }
            
            pendingLineJob.handler(newLine);
            
            [self.meshBuckets linkToIdentity:newLine.toIdentity];
        } else {
            
            newLine = [THLine new];
            newLine.lastInActivity = time(NULL);
            newLine.toIdentity = senderIdentity;
            newLine.address = address;
            newLine.outLineId = [innerPacket.json objectForKey:@"line"];
            newLine.remoteECCKey = eccKey;
            newLine.createdAt = [[innerPacket.json objectForKey:@"at"] unsignedIntegerValue];
            
            senderIdentity.currentLine = newLine;
            
            [newLine sendOpen];
            [newLine openLine];
            
            NSLog(@"Line setup for %@", newLine.inLineId);
            
            [self.openLines setObject:newLine forKey:newLine.inLineId];
            if ([self.delegate respondsToSelector:@selector(openedLine:)]) {
                [self.delegate openedLine:newLine];
            }
            
            [self.meshBuckets addIdentity:newLine.toIdentity];
        }
        
        // Check the pending jobs for any lines or channels
        [self.pendingJobs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            THPendingJob* job = (THPendingJob*)obj;
            if (job.type == PendingChannel) {
                THChannel* channel = (THChannel*)job.pending;
                if (![channel.toIdentity.hashname isEqualToString:newLine.toIdentity.hashname]) return;
                [self.pendingJobs removeObjectAtIndex:idx];
                job.handler(newLine);
            } else if (job.type == PendingLine) {
                // TODO:  What is a pending line job?
            }
        }];
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
