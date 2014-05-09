
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
#import "THCipherSet2a.h"
#import "THUnreliableChannel.h"
#import "THReliableChannel.h"
#import "CLCLog.h"
#import "THCipherSet3a.h"

#include <arpa/inet.h>

@interface THPathHandler : NSObject<THChannelDelegate>
@property THLine* line;
@end

@implementation THLine
{
    NSUInteger _nextChannelId;
    NSMutableArray* channelHandlers;
}

-(id)init;
{
    self = [super init];
    if (self) {
        channelHandlers = [NSMutableArray array];
        self.isOpen = NO;
        self.lastActitivy = time(NULL);
    }
    return self;
}

-(void)sendOpen;
{
    THSwitch* defaultSwitch = [THSwitch defaultSwitch];
    THPacket* openPacket = [defaultSwitch generateOpen:self];
    for (THPath* path in self.toIdentity.availablePaths) {
        CLCLogInfo(@"Sending open on %@ to %@", path, self.toIdentity.hashname);
        [path sendPacket:openPacket];
    }
}

-(void)handleOpen:(THPacket *)openPacket
{
    self.outLineId = [openPacket.json objectForKey:@"line"];
    self.createdAt = [[openPacket.json objectForKey:@"at"] unsignedIntegerValue];
    self.lastInActivity = time(NULL);
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
        // Get all our pending reliable channels spun out
        if ([obj class] != [THReliableChannel class]) return;
        THReliableChannel* channel = (THReliableChannel*)obj;
        // If the channel already thinks it's good, we'll just ignore it's state
        if (channel.state == THChannelOpen) return;

        [channel flushOut];
    }];
    
    self.isOpen = YES;
}

-(void)handlePacket:(THPacket *)packet;
{
    self.lastInActivity = time(NULL);
    self.lastActitivy = time(NULL);
    
    [self.cipherSetInfo decryptLinePacket:packet];
    THPacket* innerPacket = [THPacket packetData:packet.body];
    
    if (!innerPacket) {
        CLCLogWarning(@"Unexpected or unparseable inner packet on line from %@", self.toIdentity.hashname);
        return;
    }
    
    innerPacket.returnPath = packet.returnPath;
    //CLCLogInfo(@"Packet is type %@", [innerPacket.json objectForKey:@"type"]);
    CLCLogDebug(@"Line from %@ line id %@ handling %@\n%@", self.toIdentity.hashname, self.outLineId, innerPacket.json, innerPacket.body);
    NSNumber* channelId = [innerPacket.json objectForKey:@"c"];
    if (!channelId) {
        // TODO:  XXX Make this less intrusive logging once we are ready to do something else and understand issues
        CLCLogWarning(@"Why is there a packet with no channel id from %@", self.toIdentity.hashname);
        return;
    }
    NSString* channelType = [innerPacket.json objectForKey:@"type"];
    
    THSwitch* thSwitch = [THSwitch defaultSwitch];
    
    // if the switch is handling it bail
    if ([thSwitch findPendingSeek:innerPacket]) return;
    
    THChannel* channel = [self.toIdentity.channels objectForKey:channelId];
    
    if ([channelType isEqualToString:@"seek"]) {
        // On a seek we send back what we know about
        THPacket* response = [THPacket new];
        [response.json setObject:@(YES) forKey:@"end"];
        [response.json setObject:channelId forKey:@"c"];
        THSwitch* defaultSwitch = [THSwitch defaultSwitch];
		
		THIdentity* identity = [THIdentity identityFromHashname:[innerPacket.json objectForKey:@"seek"]];
        NSArray* seeIdentities = [defaultSwitch.meshBuckets closeInBucket:identity];
		NSMutableArray* sees = [NSMutableArray array];
		
		if (seeIdentities != nil) {
			for (THIdentity* seeIdentity in seeIdentities) {
				[sees addObject:[seeIdentity seekStringForIdentity:identity]];
			}
		}
		
        [response.json setObject:sees forKey:@"see"];
        
        [self sendPacket:response];
    } else if ([channelType isEqualToString:@"link"] && !channel) {
        THSwitch* defaultSwitch = [THSwitch defaultSwitch];
        
        [defaultSwitch.meshBuckets addIdentity:self.toIdentity];
        
        THUnreliableChannel* linkChannel = [[THUnreliableChannel alloc] initToIdentity:self.toIdentity];
        linkChannel.channelId = [innerPacket.json objectForKey:@"c"];
        linkChannel.type = @"link";
        linkChannel.delegate = defaultSwitch.meshBuckets;
        
        THUnreliableChannel* curChannel = (THUnreliableChannel*)[self.toIdentity channelForType:@"link"];
        if (curChannel) {
            [self.toIdentity.channels removeObjectForKey:curChannel.channelId];
        }
        [defaultSwitch openChannel:linkChannel firstPacket:nil];
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
		
		// TODO dan review this flow
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
        // Find the highest from so we can start it up
        // TODO:  XXX Can this become a function?  is it a generic pattern?
        NSDictionary* fromParts = [innerPacket.json objectForKey:@"from"];
        NSString* highestPart = [[fromParts.allKeys sortedArrayUsingSelector:@selector(compare:)] lastObject];
        THCipherSet* cs;
        if ([highestPart isEqualToString:@"3a"]) {
            cs = [[THCipherSet3a alloc] initWithPublicKey:innerPacket.body privateKey:nil];
        } else if ([highestPart isEqualToString:@"2a"]) {
            cs = [[THCipherSet2a alloc] initWithPublicKey:innerPacket.body privateKey:nil];
        }
        THIdentity* peerIdentity = [THIdentity identityFromParts:fromParts key:cs];
        if (!peerIdentity) {
            // We couldn't verify the identity, so shut it down
            THPacket* closePacket = [THPacket new];
            [closePacket.json setObject:@YES forKey:@"end"];
            [closePacket.json setObject:[innerPacket.json objectForKey:@"c"] forKey:@"c"];
            
            [packet.returnPath sendPacket:closePacket];
            return;
        }
        
        // If we already have a line to them, we assume it's dead
        if (peerIdentity.currentLine) {
            // TODO:  This should really try and reuse the line first, then fall back to full redo
            [peerIdentity.channels enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                THChannel* curChannel = (THChannel*)obj;
                curChannel.state = THChannelEnded;
            }];
            [peerIdentity.channels removeAllObjects];
            [peerIdentity.availablePaths removeAllObjects];
            peerIdentity.activePath = nil;
            
            [thSwitch closeLine:peerIdentity.currentLine];
            
            peerIdentity.currentLine = nil;
        }
        
        // Add the available paths
        NSArray* paths = [innerPacket.json objectForKey:@"paths"];
        for (NSDictionary* pathInfo in paths) {
            if ([[pathInfo objectForKey:@"type"] isEqualToString:@"ipv4"]) {
                THIPV4Path* newPath = [[THIPV4Path alloc] initWithTransport:packet.returnPath.transport ip:[pathInfo objectForKey:@"ip"] port:[[pathInfo objectForKey:@"port"] unsignedIntegerValue]];
                [peerIdentity addPath:newPath];
            }
        }
        
        // Add a bridge route
        if ([innerPacket.json objectForKey:@"bridge"]) {
            [peerIdentity addPath:packet.returnPath];
        }
        
        THUnreliableChannel* peerChannel = [[THUnreliableChannel alloc] initToIdentity:self.toIdentity];
        peerChannel.channelId = [innerPacket.json objectForKey:@"c"];
        peerChannel.type = @"connect";
        [thSwitch openChannel:peerChannel firstPacket:nil];
        
		// If we have a pending relay path, we should bail here
		THRelayPath* relayPath = nil;
        for (THPath* path in peerIdentity.availablePaths) {
            if ([path class] == [THRelayPath class]) {
				CLCLogDebug(@"incoming connect found existing relayPath");
				relayPath = (THRelayPath*)path;
			}
        }
		
		if (!relayPath) {
			CLCLogDebug(@"incoming connect creating new relayPath");
			relayPath = [THRelayPath new];
			[peerIdentity.availablePaths addObject:relayPath];
		}
        
		relayPath.relayedPath = packet.returnPath;
		relayPath.transport = packet.returnPath.transport;
		relayPath.peerChannel = peerChannel;
		peerChannel.delegate = relayPath;
		
        if (!peerIdentity.activePath) peerIdentity.activePath = relayPath;
        
        [thSwitch openLine:peerIdentity];
    } else if ([channelType isEqualToString:@"path"] && !channel) {
        [self handlePath:innerPacket];
    } else {
        NSNumber* seq = [innerPacket.json objectForKey:@"seq"];
        // Let the channel instance handle it
        if (channel) {
            if (seq) {
                // This is a reliable channel, let's make sure we're in a good state
                THReliableChannel* reliableChannel = (THReliableChannel*)channel;
                if (seq.unsignedIntegerValue == 0 && [[innerPacket.json objectForKey:@"ack"] unsignedIntegerValue] == 0) {
                    reliableChannel.state = THChannelOpen;
                }
            }
            [channel handlePacket:innerPacket];
        } else {
			// Are we getting a rogue packet from an old session, or something broken?
			if (!channelType && ([innerPacket.json objectForKey:@"end"] || [innerPacket.json objectForKey:@"err"] || [innerPacket.json count] == 1)) {
				CLCLogWarning(@"recieved a spurious packet %@ for a non-existant channel %@, ignoring", innerPacket.json, channelId);
				return;
			}
			
            // See if it's a reliable or unreliable channel
            if (!channelType && ![innerPacket.json objectForKey:@"err"]) {
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
            // Opening state for initial processing
            newChannel.state = THChannelOpening;
            newChannel.type = channelType;
            THSwitch* defaultSwitch = [THSwitch defaultSwitch];
            [self.toIdentity.channels setObject:newChannel forKey:channelId];
            [newChannel handlePacket:innerPacket];
            // Now we're full open and ready to roll
            newChannel.state = THChannelOpen;
            if ([defaultSwitch.delegate respondsToSelector:@selector(channelReady:type:firstPacket:)]) {
                [defaultSwitch.delegate channelReady:newChannel type:newChannelType firstPacket:innerPacket];
            }
        }
        
    }
}

-(void)sendPacket:(THPacket *)packet path:(THPath*)path
{
    self.lastOutActivity = time(NULL);
    CLCLogDebug(@"Sending %@\%@", packet.json, packet.body);
    NSData* innerPacketData = [self.cipherSetInfo encryptLinePacket:packet];
    NSMutableData* linePacketData = [NSMutableData dataWithCapacity:(innerPacketData.length + 16)];
    if (!linePacketData) {
        // TODO:  XXX Figure out why we couldn't encrypt, do we shutdown the line here?
        CLCLogWarning(@"**** We couldn't encrypt a line packet to %@", self.toIdentity.hashname);
        return;
    }
    [linePacketData appendData:[self.outLineId dataFromHexString]];
    [linePacketData appendData:innerPacketData];
    THPacket* lineOutPacket = [THPacket new];
    lineOutPacket.body = linePacketData;
    lineOutPacket.jsonLength = 0;
    
    if (path == nil) path = self.toIdentity.activePath;
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

-(void)negotiatePath
{
    THSwitch* thSwitch = [THSwitch defaultSwitch];

    THPacket* pathPacket = [THPacket new];
    [pathPacket.json setObject:[thSwitch.identity pathInformationTo:self.toIdentity allowLocal:YES] forKey:@"paths"];
    [pathPacket.json setObject:@"path" forKey:@"type"];
    
    NSLog(@"Offering paths %@ to %@", [thSwitch.identity pathInformationTo:self.toIdentity allowLocal:YES], self.toIdentity.hashname);
    
    THPathHandler* handler = [THPathHandler new];
    handler.line = self;
    
    THUnreliableChannel* pathChannel = [[THUnreliableChannel alloc] initToIdentity:self.toIdentity];
    pathChannel.delegate = handler;
    [thSwitch openChannel:pathChannel firstPacket:pathPacket];
    
    [self addChannelHandler:handler];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		CLCLogDebug(@"THLine removing pathChannel %@", pathChannel.channelId);
        [self removeChannelHandler:handler];
        [pathChannel close];
    });
}

-(void)addChannelHandler:(id)handler
{
    [channelHandlers addObject:handler];
}

-(void)removeChannelHandler:(id)handler
{
    [channelHandlers removeObject:handler];
}

-(void)handlePath:(THPacket*)packet
{
    THSwitch* thSwitch = [THSwitch defaultSwitch];
    
    // Add the given paths to the identity
    NSArray* offeredPaths = [packet.json objectForKey:@"paths"];
    if (!offeredPaths) {
        // Send back an error since this should have caught the handler, probably came in after a timeout
        THPacket* errPacket = [THPacket new];
        [errPacket.json setObject:@"Unknown path channel." forKey:@"err"];
        [errPacket.json setObject:[packet.json objectForKey:@"c"] forKey:@"c"];
        
        [self.toIdentity sendPacket:errPacket path:packet.returnPath];
        return;
    }
    
    for (NSDictionary* pathInfo in offeredPaths) {
        if (![[pathInfo objectForKey:@"type"] isEqualToString:@"ipv4"]) continue;
        THIPv4Transport* ipTransport = [thSwitch.transports objectForKey:@"ipv4"];
        if (!ipTransport) continue;
        NSData* address = [THIPV4Path addressTo:[pathInfo objectForKey:@"ip"] port:[[pathInfo objectForKey:@"port"] unsignedIntegerValue]];
        [self.toIdentity addPath:[ipTransport returnPathTo:address]];
    }
    
    THPacket* pathPacket = [THPacket new];
    [pathPacket.json setObject:[packet.json objectForKey:@"c"] forKey:@"c"];
    for (THPath* path in self.toIdentity.availablePaths) {
        if (path.isRelay) continue;
        path.priority = 0;
        NSDictionary* pathInfo = path.information;
        if (pathInfo) {
            [pathPacket.json setObject:pathInfo forKey:@"path"];
        }
        [self sendPacket:pathPacket path:path];
        

    }
    
}
@end

@implementation THPathHandler

-(BOOL)channel:(THChannel *)channel handlePacket:(THPacket *)packet
{
    THSwitch* thSwitch = [THSwitch defaultSwitch];
    NSDictionary* returnPath = [packet.json objectForKey:@"path"];
    
    // See if our switch has this identity, we can learn our public IP this way
    if (![thSwitch.identity pathMatching:returnPath]) {
        if ([[returnPath objectForKey:@"type"] isEqualToString:@"ipv4"]) {
            THIPv4Transport* ipTransport = [thSwitch.transports objectForKey:@"ipv4"];
            if (ipTransport) {
                THIPV4Path* newPath = [[THIPV4Path alloc] initWithTransport:ipTransport ip:[returnPath objectForKey:@"ip"] port:[[returnPath objectForKey:@"port"] unsignedIntegerValue]];
                newPath.available = YES;
                CLCLogInfo(@"Adding a local path: %@", newPath.information);
                [thSwitch.identity addPath:newPath];
            }
        }
    }
    
    // Flag the sending path as alive
    THPath* path = [self.line.toIdentity pathMatching:packet.returnPath.information];
    if (!path) {
        [self.line.toIdentity addPath:packet.returnPath];
        path = packet.returnPath;
    }
    path.available = YES;
    path.priority += 1; // Gets a +1 cause we know it's alive!
    [self.line.toIdentity checkPriorityPath:path];
    
    return YES;
}

-(void)channel:(THChannel *)channel didChangeStateTo:(THChannelState)channelState
{
}

-(void)channel:(THChannel *)channel didFailWithError:(NSError *)error
{
}

@end