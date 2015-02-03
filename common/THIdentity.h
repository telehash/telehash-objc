//
//  THIdentity.h
//  telehash
//
//  Created by Thomas Muldowney on 10/5/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "THRSA.h"

@class THPacket;
@class THLine;
@class THChannel;
@class E3XCipherSet;
@class THPath;
@class THRelay;

@interface THIdentity : NSObject

+(id)identityFromParts:(NSDictionary*)parts key:(E3XCipherSet*)key;
+(id)identityFromHashname:(NSString*)hashname;

-(id)initWithHashname:(NSString*)hashname;
-(id)initWithParts:(NSDictionary*)parts key:(E3XCipherSet*)key;

@property (readonly) NSString* hashname;
@property (readonly) BOOL hasLink;
@property BOOL isSeed;
@property BOOL isBridged;
@property NSData* address;
@property NSMutableArray* vias;
@property NSMutableDictionary* channels;
@property THLine* currentLine;
@property NSDictionary* cipherParts;
@property NSDictionary* parts;
@property NSMutableArray* availablePaths;
@property THPath* activePath;
@property BOOL isLocal;
@property NSString* suggestedCipherSet;
@property THRelay* relay;
@property NSArray* availableBridges;

-(void)addCipherSet:(E3XCipherSet*)cipherSet;
-(void)addPath:(THPath*)path;
-(void)checkPriorityPath:(THPath*)path;

-(void)addVia:(THIdentity*)viaIdentity;
-(void)attachSeedVias;
// TODO:  Method to create a channel for a type

-(NSInteger)distanceFrom:(THIdentity*)identity;
-(void)setIP:(NSString*)ip port:(NSUInteger)port;

-(void)sendPacket:(THPacket*)packet;
-(void)sendPacket:(THPacket*)packet path:(THPath*)path;
-(NSString*)seekString;
-(NSString*)seekStringForIdentity:(THIdentity*)identity;

-(THChannel*)channelForType:(NSString*)type;

-(NSArray*)pathInformationTo:(THIdentity *)toIdentity allowLocal:(BOOL)allowLocal;
-(THPath*)pathMatching:(NSDictionary*)pathInfo;

+(NSString*)hashnameForParts:(NSDictionary*)parts;

-(void)closeChannels;
-(void)reset;
@end
