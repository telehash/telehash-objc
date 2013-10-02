//
//  THPacket.h
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface THPacket : NSObject

@property (atomic) NSMutableData* raw;
@property (atomic) NSMutableDictionary* json;
@property (atomic) NSMutableData* body;

-(void)parse;

@end
