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

@interface THIdentity : NSObject

+(id)generateIdentity;
+(id)identityFromHashname:(NSString*)hashname;
+(id)identityFromPublicFile:(NSString*)publicKeyPath privateFile:(NSString*)privateKeyPath;
+(id)identityFromPublicKey:(NSData *)publicKey privateKey:(NSData *)privateKey;
+(id)identityFromPublicKey:(NSData*)key;
// Keys, hashname, address

-(id)initWithHashname:(NSString*)hashname;
-(id)initWithPublicKeyPath:(NSString*)publicKeyPath privateKey:(NSString*)privateKeyPath;
-(id)initWithPublicKey:(NSData *)publicKey privateKey:(NSData *)privateKey;

@property RSA* rsaKeys;
@property (readonly) NSString* hashname;
@property NSData* address;
@property THIdentity* via;
@property NSMutableDictionary* channels;
@property THLine* currentLine;

// TODO:  Method to create a channel for a type

-(void)processOpenPacket:(THPacket*)openPacket innerPacket:(THPacket *)innerPacket;
-(NSInteger)distanceFrom:(THIdentity*)identity;
-(void)setIP:(NSString*)ip port:(NSUInteger)port;

-(void)sendPacket:(THPacket*)packet;
-(NSString*)seekString;

-(THChannel*)channelForType:(NSString*)type;

@end

/*

TODO: Category for personal identity that allows for listening for a channel type

*/