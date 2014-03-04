//
//  THCipherSet.h
//  telehash
//
//  Created by Thomas Muldowney on 2/27/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@class THPacket;
@class THSwitch;
@class THLine;

@interface THCipherSet : NSObject
+(THCipherSet*)cipherSetForOpen:(THPacket*)openPacket;
-(THLine*)processOpen:(THPacket*)openPacket switch:(THSwitch*)thSwitch;
@end

@interface THCipherSet2a : THCipherSet
-(THLine*)processOpen:(THPacket*)openPacket switch:(THSwitch*)thSwitch;
@end