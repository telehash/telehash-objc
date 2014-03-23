
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
#import "THCipherSet.h"
#import "THPeerRelay.h"
#import "THPath.h"

#include <arpa/inet.h>

@implementation THLine
{
    NSUInteger _nextChannelId;
}

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
    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
    THPacket* openPacket = [defaultSwitch generateOpen:self];
    [self.activePath sendPacket:openPacket];
}

-(void)handleOpen:(THPacket *)openPacket
{
    self.outLineId = [openPacket.json objectForKey:@"line"];
    self.createdAt = [[openPacket.json objectForKey:@"at"] unsignedIntegerValue];
    self.lastInActivity = time(NULL);
    self.address = openPacket.fromAddress;
}

-(NSUInteger)nextChannelId
{
    return _nextChannelId++;
}

-(void)openLine;
{
    // Do the distance calc and see if we start at 1 or 2
    THSwitch* thSwitch = [THSwitch defaultSwitch];
    if ([self.toIdentity.hashname compare:thSwitch.identity.hashname] == NSOrderedAscending) {
        _nextChannelId = 1;
    } else {
        _nextChannelId = 2;
    }
    [self.cipherSetInfo.cipherSet finalizeLineKeys:self];
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
    [self.cipherSetInfo decryptLinePacket:packet];
    THPacket* innerPacket = [THPacket packetData:packet.body];
    //NSLog(@"Packet is type %@", [innerPacket.json objectForKey:@"type"]);
    NSLog(@"Line %@ line id %@ handling %@", self.toIdentity.hashname, self.outLineId, innerPacket.json);
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
        [connectPacket.json setObject:@"connect" forKey:@"type"];
        [connectPacket.json setObject:[packet.json objectForKey:@"from"] forKey:@"from"];
        NSArray* paths = [packet.json objectForKey:@"paths"];
        if (paths) {
            // XXX FIXME check if we know any other paths
            [connectPacket.json setObject:paths forKey:@"paths"];
        }
        connectPacket.body = packet.body;

        THPeerRelay* relay = [THPeerRelay new];
        
        THUnreliableChannel* connectChannel = [[THUnreliableChannel alloc] initToIdentity:peerLine.toIdentity];
        connectChannel.delegate = relay;
        THUnreliableChannel* peerChannel = [[THUnreliableChannel alloc] initToIdentity:self.toIdentity];
        peerChannel.channelId = [packet.json objectForKey:@"c"];
        peerChannel.delegate = relay;

        relay.connectChannel = connectChannel;
        relay.peerChannel = peerChannel;
        
        [thSwitch openChannel:connectChannel firstPacket:connectPacket];
        // XXX FIXME check the connect channel timeout for going away?
    } else if ([channelType isEqualToString:@"connect"]) {
#if TODO_FIXME
        THIdentity* peerIdentity = [THIdentity identityFromPublicKey:innerPacket.body];
        if (peerIdentity.currentLine) {
            [[THSwitch defaultSwitch] closeLine:peerIdentity.currentLine];
        }
        NSLog(@"Going to connect to %@", peerIdentity.hashname);
        
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
#endif
    } else if ([channelType isEqualToString:@"path"]) {
        THPacket* errPacket = [THPacket new];
        [errPacket.json setObject:@"Path not yet supported." forKey:@"err"];
        [errPacket.json setObject:channelId forKey:@"c"];
        
        [self.toIdentity sendPacket:errPacket];
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
            newChannel.channelId = [NSNumber numberWithUnsignedInteger:self.nextChannelId];
            newChannel.channelIsReady = YES;
            newChannel.type = channelType;
            THSwitch* defaultSwitch = [THSwitch defaultSwitch];
            if ([defaultSwitch.delegate respondsToSelector:@selector(channelReady:type:firstPacket:)]) {
                [defaultSwitch.delegate channelReady:newChannel type:newChannelType firstPacket:innerPacket];
            }
            NSLog(@"Adding a channel");
            [self.toIdentity.channels setObject:newChannel forKey:channelId];
            //[newChannel handlePacket:innerPacket];
        }
        
    }
}

-(void)sendPacket:(THPacket *)packet;
{
    self.lastOutActivity = time(NULL);
    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
    NSData* innerPacketData = [self.cipherSetInfo encryptLinePacket:packet];
    NSMutableData* linePacketData = [NSMutableData dataWithCapacity:(innerPacketData.length + 16)];
    [linePacketData appendData:[self.outLineId dataFromHexString]];
    [linePacketData appendData:innerPacketData];
    THPacket* lineOutPacket = [THPacket new];
    lineOutPacket.body = linePacketData;
    lineOutPacket.jsonLength = 0;
    
    [self.activePath sendPacket:lineOutPacket];
    //[defaultSwitch sendPacket:lineOutPacket toAddress:self.address];
}

-(void)close
{
    [[THSwitch defaultSwitch] closeLine:self];
}
@end
