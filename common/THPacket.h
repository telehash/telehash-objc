//
//  THPacket.h
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@class THPath;

@interface THPacket : NSObject

@property (atomic) NSMutableData* raw;
@property (atomic) NSMutableDictionary* json;
@property (atomic) NSData* body;
@property (atomic, assign) unsigned short jsonLength;
@property (atomic, retain) THPath* returnPath;

-(id)init;
-(id)initWithJson:(NSMutableDictionary*)json;

+(id)packetData:(NSData*)packetData;

-(NSData*)encode;

@end
