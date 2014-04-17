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
#import "NSString+HexString.h"
#import "THLine.h"
#import "THChannel.h"
#import "THMeshBuckets.h"
#import "THPendingJob.h"
#import "THCipherSet.h"
#import "NSData+HexString.h"
#import "THCipherSet.h"
#import "THTransport.h"
#import "THPath.h"

@interface THSwitch()

@end

@implementation THSwitch
{
    THIdentity* _identity;
}

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
        self.meshBuckets.localSwitch = self;
        self.openLines = [NSMutableDictionary dictionary];
        self.pendingJobs = [NSMutableArray array];
        self.transports = [NSMutableArray array];
        self.status = THSWitchOffline;
    }
    return self;
}

-(void)setIdentity:(THIdentity *)identity
{
    _identity = identity;
    self.meshBuckets.localIdentity = identity;
}

-(THIdentity*)identity
{
    return _identity;
}

-(void)start
{
    self.meshBuckets.localIdentity = self.identity;
    // XXX TODO FIXME For each path start it
    for (THTransport* transport in self.transports) {
        [transport start];
    }
    [self updateStatus:THSwitchListening];
}

-(void)addTransport:(THTransport *)transport
{
    [self.transports addObject:transport];
}

-(void)loadSeeds:(NSData *)seedData;
{
    NSError* error;
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:seedData options:0 error:&error];
    if (!json) return;

    [json enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSDictionary* entry = (NSDictionary*)obj;
        NSArray* paths = [entry objectForKey:@"paths"];
        NSDictionary* parts = [entry objectForKey:@"parts"];
        NSDictionary* keys = [entry objectForKey:@"keys"];
        NSData* keyData = [[NSData alloc] initWithBase64EncodedString:[keys objectForKey:@"2a"] options:0];
        THCipherSet2a* cs = [[THCipherSet2a alloc] initWithPublicKey:keyData privateKey:nil];
        THIdentity* seedIdentity = [THIdentity identityFromParts:parts key:cs];
        for (NSDictionary* path in paths) {
            if ([[path objectForKey:@"type"] isEqualToString:@"ipv4"]) {
                NSUInteger idx = [self.transports indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                    THTransport* transport = (THTransport*)obj;
                    return [transport.typeName isEqualToString:@"ipv4"];
                }];
                if (idx == NSNotFound) continue;
                THTransport* transport = [self.transports objectAtIndex:idx];
                NSData* address = [THIPV4Path addressTo:[path objectForKey:@"ip"] port:[[path objectForKey:@"port"] unsignedIntegerValue]];
                [seedIdentity addPath:[transport returnPathTo:address]];
                //seedIdentity.activePath = [transport returnPathTo:address];
            }
        }
        
        if (seedIdentity) [self openLine:seedIdentity];
    }];
}

-(THLine*)lineToHashname:(NSString*)hashname;
{
    // XXX: If we don't have a line should we do an open here?
    // XXX: This is a common lookup, should we cache this another way as well?
    //NSLog(@"looking for %@", hashname);
    __block THLine* ret = nil;
    [self.openLines enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        THLine* line = (THLine*)obj;
        if ([line.toIdentity.hashname isEqualToString:hashname]) {
            ret = line;
            *stop = YES;
        }
    }];
    //NSLog(@"We found line to hashname %@ %@", ret.toIdentity.hashname, ret);
    return ret;
}

-(void)channel:(THChannel*)channel line:(THLine*)line firstPacket:(THPacket*)packet
{
    channel.line = line;
    if (!channel.channelId || [channel.channelId isEqualToNumber:@0]) {
        channel.channelId = [NSNumber numberWithUnsignedInteger:line.nextChannelId];
    }
    [channel.toIdentity.channels setObject:channel forKey:channel.channelId];
    channel.state = THChannelOpen;
    if (packet) [channel sendPacket:packet];
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
        if (lineOpenCompletion) lineOpenCompletion(toIdentity);
        return;
    }

    [self.pendingJobs addObject:[THPendingJob pendingJobFor:toIdentity completion:^(id result) {
        if (lineOpenCompletion) lineOpenCompletion(toIdentity);
    }]];
    

    // We have everything we need to direct request
    if (toIdentity.availablePaths.count > 0 && [toIdentity.cipherParts objectForKey:@"2a"]) {
        THLine* channelLine = [THLine new];
        channelLine.toIdentity = toIdentity;
        channelLine.activePath = toIdentity.activePath;
        toIdentity.currentLine = channelLine;
        
        [channelLine sendOpen];
        return;
    };
    
    // Let's do a peer request
    if (toIdentity.via) {
        THIdentity* viaIdentity = [THIdentity identityFromHashname:toIdentity.via.hashname];
        
        THUnreliableChannel* peerChannel = [[THUnreliableChannel alloc] initToIdentity:viaIdentity];
        [self openChannel:peerChannel firstPacket:nil];
        
        THPacket* peerPacket = [THPacket new];
        [peerPacket.json setObject:[NSNumber numberWithUnsignedInteger:viaIdentity.currentLine.nextChannelId] forKey:@"c"];
        [peerPacket.json setObject:toIdentity.hashname forKey:@"peer"];
        [peerPacket.json setObject:@"peer" forKey:@"type"];
        [peerPacket.json setObject:peerChannel.channelId forKey:@"c"];
        THCipherSet2a* cs = [self.identity.cipherParts objectForKey:@"2a"];
        peerPacket.body = cs.rsaKeys.DERPublicKey;
        
        THRelayPath* relayPath = [THRelayPath new];
        relayPath.peerChannel = peerChannel;
        relayPath.transport = viaIdentity.activePath.transport;
        relayPath.relayedPath = viaIdentity.activePath;
        peerChannel.delegate = relayPath;
        peerChannel.type = @"peer";
        
        [toIdentity addPath:relayPath];
        toIdentity.activePath = relayPath;
        
        // XXX FIXME TODO:  Hole punch packet on paths [self.udpSocket sendData:[NSData data] toAddress:toIdentity.address withTimeout:-1 tag:0];
        
        // We blind send this and hope for the best!
        [viaIdentity sendPacket:peerPacket];
        
        return;
    }
    
    // Find a way to it from the mesh
    [self.meshBuckets seek:toIdentity completion:^(BOOL found) {
        if (found) {
            [self openLine:toIdentity completion:lineOpenCompletion];
        } else {
            if (lineOpenCompletion) lineOpenCompletion(nil);
        }
    }];
}

-(void)closeLine:(THLine *)line
{
    if (line.toIdentity.currentLine == line) {
        line.toIdentity.currentLine = nil;
        [line.toIdentity.channels removeAllObjects];
    }
    if (line.inLineId) [self.openLines removeObjectForKey:line.inLineId];
    [self.meshBuckets removeLine:line];
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

-(void)processOpen:(THPacket*)incomingPacket
{
    NSLog(@"Processing an open from %@", incomingPacket.returnPath);
    THCipherSet* cipherSet = [self.identity.cipherParts objectForKey:[[incomingPacket.body subdataWithRange:NSMakeRange(0, 1)] hexString]];
    if (!cipherSet) {
        NSLog(@"Invalid cipher set requested %@", [[incomingPacket.body subdataWithRange:NSMakeRange(0, 1)] hexString]);
        return;
    }
    THLine* newLine = [cipherSet processOpen:incomingPacket];
    if (!newLine) {
        NSLog(@"Unable to process open packet");
        return;
    }
    
    // Add the incoming path to the
    if (newLine.toIdentity.availablePaths.count == 0) {
        [newLine.toIdentity addPath:incomingPacket.returnPath];
    }
    newLine.toIdentity.activePath = incomingPacket.returnPath;
    
    // remove any existing lines to this hashname
    [self.meshBuckets removeLine:newLine];
    if (newLine.inLineId) [self.openLines removeObjectForKey:newLine.inLineId];
    
    __block THPendingJob* pendingLineJob = nil;
    [self.pendingJobs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        THPendingJob* job = (THPendingJob*)obj;
        if (job.type != PendingIdentity) return;
        
        THIdentity* pendingIdentity = (THIdentity*)job.pending;
        if ([pendingIdentity.hashname isEqualToString:newLine.toIdentity.hashname]) {
            pendingLineJob = job;
            *stop = YES;
            [self.pendingJobs removeObjectAtIndex:idx];
        }
    }];
    if (pendingLineJob && newLine.inLineId) {
        THIdentity* pendingIdentity = (THIdentity*)pendingLineJob.pending;
        newLine = pendingIdentity.currentLine;
        NSLog(@"Finish open on %@", newLine);
        [newLine openLine];
        
        [self.openLines setObject:newLine forKey:newLine.inLineId];
        
        if ([self.delegate respondsToSelector:@selector(openedLine:)]) {
            [self.delegate openedLine:newLine];
        }
        
        if (pendingLineJob) pendingLineJob.handler(newLine);
        
        [self.meshBuckets linkToIdentity:newLine.toIdentity];
        [newLine negotiatePath];
    } else {
        [newLine sendOpen];
        [newLine openLine];
        
        NSLog(@"Line setup for %@", newLine.inLineId);
        
        [self.openLines setObject:newLine forKey:newLine.inLineId];
        if ([self.delegate respondsToSelector:@selector(openedLine:)]) {
            [self.delegate openedLine:newLine];
        }
        
        if (pendingLineJob) pendingLineJob.handler(newLine);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            THChannel* linkChannel = [newLine.toIdentity channelForType:@"link"];
            if (!linkChannel) {
                [self.meshBuckets linkToIdentity:newLine.toIdentity];
            }
        });
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
}

-(void)updateStatus:(THSwitchStatus)status
{
    if (status != self.status) {
        self.status = status;
        if ([self.delegate respondsToSelector:@selector(thSwitch:status:)]) {
            [self.delegate thSwitch:self status:self.status];
        }
    }
}

-(THPacket*)generateOpen:(THLine *)toLine
{
    // Find our highest matching cipher set
    NSMutableSet* ourIDs = [NSMutableSet setWithArray:[self.identity.cipherParts allKeys]];
    [ourIDs intersectSet:[NSSet setWithArray:[toLine.toIdentity.cipherParts allKeys]]];
    if (ourIDs.count <= 0) {
        NSLog(@"Unable to find a matching csid for open.");
        return nil;
    }
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:NO];
    NSArray* sortedCSIds = [ourIDs sortedArrayUsingDescriptors:@[sort]];
    THCipherSet* cs = [self.identity.cipherParts objectForKey:[sortedCSIds objectAtIndex:0]];
    return [cs generateOpen:toLine from:self.identity];
}

-(void)transport:(THTransport *)transport handlePacket:(THPacket *)packet
{
    if (packet.jsonLength == 1) {
        [self processOpen:packet];
    } else if(packet.jsonLength == 0) {
        // Validate the line id then process it
        NSString* lineId = [[packet.body subdataWithRange:NSMakeRange(0, 16)] hexString];
        //NSLog(@"Received a line packet for %@", lineId);
        // Process a line packet
        THLine* line = [self.openLines objectForKey:lineId];
        // If there is no line to handle this dump it
        if (line == nil) {
            return;
        }
        [line handlePacket:packet];
    } else {
        NSLog(@"Dropping an unknown packet");
    }

}

-(void)transportDidChangeActive:(THTransport *)transport;
{
    NSUInteger availableCount = [[self.transports indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        THTransport* transport = (THTransport*)obj;
        return transport.available;
    }] count];
    if (availableCount <= 0) {
        NSLog(@"Oh no, we're offline!");
        // XXX TODO:  What to do?
    }
}

@end
