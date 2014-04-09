
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
    if ([self.toIdentity.activePath class] == [THRelayPath class]){
        self.activePath = self.toIdentity.activePath;
    } else {
        self.activePath = [openPacket.path returnPathTo:openPacket.fromAddress];
    }
}

-(NSUInteger)nextChannelId
{
    return _nextChannelId+=2;
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
        if (channel.state == THChannelOpen) return;

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
    NSLog(@"Line from %@ line id %@ handling %@\n%@", self.toIdentity.hashname, self.outLineId, innerPacket.json, innerPacket.body);
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
        [connectPacket.json setObject:self.toIdentity.parts forKey:@"from"];
        NSArray* paths = [innerPacket.json objectForKey:@"paths"];
        if (paths) {
            // XXX FIXME check if we know any other paths
            [connectPacket.json setObject:paths forKey:@"paths"];
        }
        connectPacket.body = innerPacket.body;

        THPeerRelay* relay = [THPeerRelay new];
        
        THUnreliableChannel* connectChannel = [[THUnreliableChannel alloc] initToIdentity:peerLine.toIdentity];
        connectChannel.delegate = relay;
        THUnreliableChannel* peerChannel = [[THUnreliableChannel alloc] initToIdentity:self.toIdentity];
        peerChannel.channelId = [innerPacket.json objectForKey:@"c"];
        peerChannel.delegate = relay;
        [thSwitch openChannel:peerChannel firstPacket:nil];

        relay.connectChannel = connectChannel;
        relay.peerChannel = peerChannel;
        
        [thSwitch openChannel:connectChannel firstPacket:connectPacket];
        // XXX FIXME TODO: check the connect channel timeout for going away?
    } else if ([channelType isEqualToString:@"connect"]) {
        // XXX FIXME TODO: Find the correct cipher set here
        THCipherSet2a* cs = [[THCipherSet2a alloc] initWithPublicKey:innerPacket.body privateKey:nil];
        THIdentity* peerIdentity = [THIdentity identityFromParts:[innerPacket.json objectForKey:@"from"] key:cs];
        if (!peerIdentity) {
            // We couldn't verify the identity, so shut it down
            THPacket* closePacket = [THPacket new];
            [closePacket.json setObject:@YES forKey:@"end"];
            [closePacket.json setObject:[innerPacket.json objectForKey:@"c"] forKey:@"c"];
            
            THPath* returnPath = [packet.path returnPathTo:packet.fromAddress];
            [returnPath sendPacket:closePacket];
            return;
        }
        
        THUnreliableChannel* peerChannel = [[THUnreliableChannel alloc] initToIdentity:self.toIdentity];
        peerChannel.channelId = [innerPacket.json objectForKey:@"c"];
        [thSwitch openChannel:peerChannel firstPacket:nil];
        
        THRelayPath* relayPath = [THRelayPath new];
        relayPath.peerChannel = peerChannel;
        relayPath.delegate = thSwitch;
        peerChannel.delegate = relayPath;
        
        [peerIdentity.availablePaths addObject:relayPath];
        peerIdentity.activePath = relayPath;
        
        [thSwitch openLine:peerIdentity];
    } else if ([channelType isEqualToString:@"path"]) {
        THPacket* pathPacket = [THPacket new];
        [pathPacket.json setObject:[thSwitch.identity pathInformation] forKey:@"paths"];
        [pathPacket.json setObject:@"path" forKey:@"type"];
        [pathPacket.json setObject:@YES forKey:@"end"];
        [pathPacket.json setObject:[innerPacket.json objectForKey:@"c"] forKey:@"c"];
        NSDictionary* returnPathInfo = [packet.path informationTo:packet.fromAddress];
        if (returnPathInfo) {
            [pathPacket.json setObject:[packet.path informationTo:packet.fromAddress] forKey:@"path"];
        }
        
        [self.toIdentity sendPacket:pathPacket path:[packet.path returnPathTo:packet.fromAddress]];
    } else {
        NSNumber* seq = [innerPacket.json objectForKey:@"seq"];
        // Let the channel instance handle it
        THChannel* channel = [self.toIdentity.channels objectForKey:channelId];
        if (channel) {
            if (seq) {
                // This is a reliable channel, let's make sure we're in a good state
                THReliableChannel* reliableChannel = (THReliableChannel*)channel;
                if (seq.unsignedIntegerValue == 0 && [[innerPacket.json objectForKey:@"ack"] unsignedIntegerValue] == 0) {
                    [reliableChannel setState:THChannelOpen];
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
            [newChannel setState:THChannelOpen];
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

-(void)sendPacket:(THPacket *)packet path:(THPath*)path
{
    self.lastOutActivity = time(NULL);
    NSLog(@"Sending %@\%@", packet.json, packet.body);
    NSData* innerPacketData = [self.cipherSetInfo encryptLinePacket:packet];
    NSMutableData* linePacketData = [NSMutableData dataWithCapacity:(innerPacketData.length + 16)];
    [linePacketData appendData:[self.outLineId dataFromHexString]];
    [linePacketData appendData:innerPacketData];
    THPacket* lineOutPacket = [THPacket new];
    lineOutPacket.body = linePacketData;
    lineOutPacket.jsonLength = 0;
    
    if (path == nil) path = self.activePath;
    [path sendPacket:lineOutPacket];
}

-(void)sendPacket:(THPacket *)packet;
{
    [self sendPacket:packet path:nil];
}

-(void)close
{
    [[THSwitch defaultSwitch] closeLine:self];
}
@end
