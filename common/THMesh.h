//
//  THSwitch.h
//  telehash
//
//  Created by Thomas Muldowney on 10/3/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "THTransport.h"

@class THLink;
@class E3XChannel;
@class THPacket;
@class E3XExchange;
@class THTransport;

typedef enum {
    ReliableChannel,
    UnreliableChannel
} THChannelType;

typedef enum {
    THSWitchOffline,
    THSwitchListening,
    THSwitchOnline
} THSwitchStatus;

typedef void(^LineOpenBlock)(THLink*);

@class THMesh;

@protocol THSwitchDelegate <NSObject>

-(void)openedLine:(E3XExchange*)line;
-(void)channelReady:(E3XChannel*)channel type:(THChannelType)type firstPacket:(THPacket*)packet;
-(void)thSwitch:(THMesh*)thSwitch status:(THSwitchStatus)status;

@end

@interface THMesh : NSObject <THTransportDelegate>

+(id)defaultSwitch;

@property NSMutableDictionary* openLines;
@property NSMutableArray* pendingJobs;
@property THLink* identity;
@property id<THSwitchDelegate> delegate;
@property THSwitchStatus status;
@property NSMutableDictionary* transports;
@property NSMutableArray* potentialBridges;

+(id)THSWitchWithIdentity:(THLink*)identity;

-(void)start;
-(void)addTransport:(THTransport*)transport;
-(E3XExchange*)lineToHashname:(NSString*)hashname;
-(void)openChannel:(E3XChannel*)channel firstPacket:(THPacket*)packet;
/// Open a line to the given identity
// The identity can be either a complete identity (RSA keys and address filled in) or
// just a hashname.  The switch will do everything it can to open the line.
// The completion block is optional.
-(void)openLine:(THLink*)toIdentity completion:(LineOpenBlock)lineOpenCompletion;
-(void)openLine:(THLink*)toIdentity;
-(void)closeLine:(E3XExchange*)line;
-(void)loadSeeds:(NSData*)seedData;
-(void)updateStatus:(THSwitchStatus)status;
-(THPacket*)generateOpen:(E3XExchange*)toLine;
-(void)handlePacket:(THPacket*)packet;

-(void)transport:(THTransport *)transport handlePacket:(THPacket *)packet;
-(void)transportDidChangeActive:(THTransport *)transport;

// This is an internal handling hack
-(BOOL)findPendingSeek:(THPacket*)packet;
@end
