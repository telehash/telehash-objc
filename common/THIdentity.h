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
@class THCipherSet;
@class THPath;

@interface THIdentity : NSObject

+(id)generateIdentity;
+(id)identityFromParts:(NSDictionary*)parts key:(THCipherSet*)key;
+(id)identityFromHashname:(NSString*)hashname;

-(id)initWithHashname:(NSString*)hashname;
-(id)initWithParts:(NSDictionary*)parts key:(THCipherSet*)key;

@property (readonly) NSString* hashname;
@property NSData* address;
@property THIdentity* via;
@property NSMutableDictionary* channels;
@property THLine* currentLine;
@property NSDictionary* cipherParts;
@property NSDictionary* parts;
@property NSMutableArray* availablePaths;
@property THPath* activePath;
@property BOOL isLocal;

-(void)addCipherSet:(THCipherSet*)cipherSet;
-(void)addPath:(THPath*)path;

// TODO:  Method to create a channel for a type

-(NSInteger)distanceFrom:(THIdentity*)identity;
-(void)setIP:(NSString*)ip port:(NSUInteger)port;

-(void)sendPacket:(THPacket*)packet;
-(void)sendPacket:(THPacket*)packet path:(THPath*)path;
-(NSString*)seekString;

-(THChannel*)channelForType:(NSString*)type;

-(NSArray*)pathInformationTo:(THIdentity*)toIdentity;
-(BOOL)checkForPath:(NSDictionary*)pathInfo;

+(NSString*)hashnameForParts:(NSDictionary*)parts;
@end

/*

TODO: Category for personal identity that allows for listening for a channel type

*/