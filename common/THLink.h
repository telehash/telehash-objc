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
@class E3XExchange;
@class E3XChannel;
@class E3XCipherSet;
@class THPath;
@class THRelay;

@interface THLink : NSObject

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
@property E3XExchange* currentLine;
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

-(void)addVia:(THLink*)viaIdentity;
-(void)attachSeedVias;
// TODO:  Method to create a channel for a type

-(NSInteger)distanceFrom:(THLink*)identity;
-(void)setIP:(NSString*)ip port:(NSUInteger)port;

-(void)sendPacket:(THPacket*)packet;
-(void)sendPacket:(THPacket*)packet path:(THPath*)path;
-(NSString*)seekString;
-(NSString*)seekStringForIdentity:(THLink*)identity;

-(E3XChannel*)channelForType:(NSString*)type;

-(NSArray*)pathInformationTo:(THLink *)toIdentity allowLocal:(BOOL)allowLocal;
-(THPath*)pathMatching:(NSDictionary*)pathInfo;

+(NSString*)hashnameForParts:(NSDictionary*)parts;

-(void)closeChannels;
-(void)reset;
@end
