//
//  SHA256.h
//  telehash
//
//  Created by Thomas Muldowney on 10/2/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SHA256 : NSObject
-(void)updateWithData:(NSData*)data;
-(NSData*)finalize;
@end
