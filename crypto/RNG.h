//
//  RNG.h
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RNG : NSObject
+(NSData*)randomBytesOfLength:(unsigned long)length;
+(void)randomBytesIn:(void*)destination length:(unsigned long)length;
@end
