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


typedef enum {
    PendingIdentity,
    PendingLine,
    PendingChannel,
    PendingPacket
} THPendingJobType;

typedef void(^PendingJobBlock)(id result);

@interface THPendingJob : NSObject
@property THPendingJobType type;
@property id pending;
@property (copy) PendingJobBlock handler;
+(id)pendingJobFor:(id)pendingItem completion:(PendingJobBlock)onCompletion;
@end

@implementation THPendingJob
+(id)pendingJobFor:(id)pendingItem completion:(PendingJobBlock)onCompletion;
{
    THPendingJob* pendingJob = [THPendingJob new];
    Class itemClass = [pendingItem class];
    if (itemClass == [THIdentity class]) pendingJob.type = PendingIdentity;
    if (itemClass == [THLine class]) pendingJob.type = PendingLine;
    if ([itemClass superclass] == [THChannel class]) pendingJob.type = PendingChannel;
    if (itemClass == [THPacket class]) pendingJob.type = PendingPacket;
    pendingJob.pending = pendingItem;
    pendingJob.handler = onCompletion;
    
    return pendingJob;
}
@end

@interface THSwitch()

@property NSMutableArray* pendingJobs;
@property NSMutableDictionary* pendingLines;
@property NSMutableArray* pendingChannels;
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
        self.pendingLines = [NSMutableDictionary dictionary];
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

// TODO:  Consider if this arg should be THIdentity
-(NSArray*)seek:(NSString *)hashname;
{
    NSMutableArray* entries = [NSMutableArray array];
    [self.openLines enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        THLine* line = (THLine*)obj;
        [entries addObject:line];
        /*
        if ([line.toIdentity.hashname isEqualToString:hashname]) {
            [entries addObject:line];
        }
        */
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
    NSLog(@"We found %@", ret);
    return ret;
}

-(void)openChannel:(THChannel *)channel firstPacket:(THPacket *)packet;
{
    // Check for an already open lines
    THLine* channelLine = [self lineToHashname:channel.toIdentity.hashname];
    if (!channelLine) {
        [self.pendingChannels addObject:channel];
        [self openLine:channel.toIdentity];
        return;
    }
    channel.channelIsReady = YES;
    channel.line = channelLine;
    [channelLine.channels setObject:channel forKey:channel.channelId];
    [channel sendPacket:packet];
}

-(void)openLine:(THIdentity *)toIdentity;
{
    // We have everything we need to direct request
    if (toIdentity.address && toIdentity.rsaKeys) {
        THLine* channelLine = [THLine new];
        channelLine.toIdentity = toIdentity;
        channelLine.address = toIdentity.address;
        
        [self.pendingLines setObject:channelLine forKey:toIdentity.hashname];
        
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
        THLine* viaLine = [self lineToHashname:toIdentity.via.hashname];
        [viaLine sendPacket:peerPacket];
        return;
    }
    
    NSArray* nearby = [self seek:toIdentity.hashname];
    
    // TODO: parallize x3
    [nearby enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        THLine* nearLine = (THLine*)obj;
        // Send each nearby a seek packet for toIdentity
        THPacket* seekPacket = [THPacket new];
        [seekPacket.json setObject:[[RNG randomBytesOfLength:16] hexString] forKey:@"c"];
        [seekPacket.json setObject:@"seek" forKey:@"type"];
        [seekPacket.json setObject:toIdentity.hashname forKey:@"seek"];
        
        __block BOOL foundIt = NO;
        NSInteger curDistance = [self.identity distanceFrom:toIdentity];
        [self.pendingJobs addObject:[THPendingJob pendingJobFor:seekPacket completion:^(id result) {
            if (foundIt) return;
            THPacket* response = (THPacket*)result;
            NSArray* sees = [response.json objectForKey:@"see"];
            [sees enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSString* seeString = (NSString*)obj;
                NSArray* seeParts = [seeString componentsSeparatedByString:@","];
                if ([[seeParts objectAtIndex:0] isEqualToString:toIdentity.hashname]) {
                    // this is it!
                    toIdentity.via = nearLine.toIdentity;
                    if (seeParts.count > 1) {
                        [toIdentity setIP:[seeParts objectAtIndex:1] port:[[seeParts objectAtIndex:2] integerValue]];
                    }
                    [self openLine:toIdentity];
                    foundIt = YES;
                    // Remove pending identity job
                }
                
                // Check that we're moving forward
                THIdentity* nearIdentity = [THIdentity identityFromHashname:[seeParts objectAtIndex:0]];
                NSInteger distance = [self.identity distanceFrom:nearIdentity];
                NSLog(@"Step distance is %d", distance);
            }];
        }]];
        
        [nearLine sendPacket:seekPacket];
    }];
    /*
    channelLine = [THLine new];
    channelLine.toIdentity = channel.toIdentity;
    channelLine.address = channel.toIdentity.address;
    
    [self.pendingLines setObject:channelLine forKey:channel.toIdentity.hashname];
    
    [channelLine sendOpen];
    */
}

-(BOOL)findPendingJob:(THPacket *)packet;
{
    if ([self.pendingJobs count] == 0) return NO;
    __block BOOL handled = NO;
    // We only handle results, seek requests are in the line
    [self.pendingJobs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        THPendingJob* pendingJob = (THPendingJob*)obj;
        if (pendingJob.type == PendingPacket) {
            THPacket* pendingPacket = (THPacket*)pendingJob.pending;
            if ([[pendingPacket.json objectForKey:@"c"] isEqualToString:[packet.json objectForKey:@"c"]]) {
                pendingJob.handler(packet);
                *stop = YES;
                handled = YES;
                [self.pendingJobs removeObjectAtIndex:idx];
            }
        }
    }];
    return handled;
}

#pragma region -- UDP Handlers

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    THPacket* incomingPacket = [THPacket packetData:data];
    incomingPacket.fromAddress = address;
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

        NSLog(@"Finding line for  %@ in %@", senderIdentity.hashname, self.openLines);
        THLine* newLine = [self lineToHashname:senderIdentity.hashname];
        // remove any existing lines to this hashname
        if (newLine) {
            [self.openLines removeObjectForKey:newLine.inLineId];
        }
        newLine = [self.pendingLines objectForKey:senderIdentity.hashname];
        if (newLine) {
            NSLog(@"Finish open on %@", newLine);
            newLine.outLineId = [innerPacket.json objectForKey:@"line"];
            newLine.remoteECCKey = eccKey;
            [newLine openLine];
            
            [self.pendingLines removeObjectForKey:senderIdentity.hashname];
            [self.openLines setObject:newLine forKey:newLine.inLineId];
            
            if ([self.delegate respondsToSelector:@selector(openedLine:)]) {
                [self.delegate openedLine:newLine];
            }
        } else {
            
            newLine = [THLine new];
            newLine.toIdentity = senderIdentity;
            newLine.address = address;
            newLine.outLineId = [innerPacket.json objectForKey:@"line"];
            newLine.remoteECCKey = eccKey;
            
            [newLine sendOpen];
            [newLine openLine];
            
            NSLog(@"Line setup for %@", newLine.inLineId);
            
            [self.openLines setObject:newLine forKey:newLine.inLineId];
            if ([self.delegate respondsToSelector:@selector(openedLine:)]) {
                [self.delegate openedLine:newLine];
            }
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
