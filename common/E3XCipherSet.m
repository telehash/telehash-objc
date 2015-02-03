//
//  THCipherSet.m
//  telehash
//
//  Created by Thomas Muldowney on 2/27/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "E3XCipherSet.h"
#import "THPacket.h"
#import "THLink.h"
#import "E3XExchange.h"
#import "E3XCipherSet2a.h"
#import "E3XCipherSet3a.h"
#import "CLCLog.h"

@implementation E3XCipherSet
+(E3XCipherSet*)cipherSetForOpen:(THPacket *)openPacket
{
    unsigned char* bytes = (unsigned char*)openPacket.body.bytes;
    switch (bytes[0]) {
    case 0x2a:
        return [E3XCipherSet2a new];
    case 0x3a:
        return [E3XCipherSet3a new];
    default:
        return nil;
    }
}

-(E3XExchange*)processOpen:(THPacket*)openPacket switch:(THMesh*)thSwitch
{
    CLCLogError(@"Not implemented");
    return nil;
}

-(NSString*)identifier
{
    NSAssert(true, @"base class not implemented");
    return nil;
}

-(void)finalizeLineKeys:(E3XExchange *)line
{
    CLCLogError(@"Not implemented THCipherSet finalizeKeys");
}
@end

@implementation THCipherSetLineInfo
-(NSData*)encryptLinePacket:(THPacket*)packet
{
    CLCLogError(@"Not implemented THCipherSetLineInfo encryptLinePacket:");
    return nil;
}

-(void)decryptLinePacket:(THPacket *)packet
{
    CLCLogError(@"Not implemented THCipherSetLineInfo decryptLinePacket:");
}
@end


