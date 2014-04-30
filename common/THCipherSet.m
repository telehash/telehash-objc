//
//  THCipherSet.m
//  telehash
//
//  Created by Thomas Muldowney on 2/27/14.
//  Copyright (c) 2014 Telehash Foundation. All rights reserved.
//

#import "THCipherSet.h"
#import "THPacket.h"
#import "THIdentity.h"
#import "THLine.h"
#import "THCipherSet2a.h"
#import "THCipherSet3a.h"
#import "CLCLog.h"

@implementation THCipherSet
+(THCipherSet*)cipherSetForOpen:(THPacket *)openPacket
{
    unsigned char* bytes = (unsigned char*)openPacket.body.bytes;
    switch (bytes[0]) {
    case 0x2a:
        return [THCipherSet2a new];
    default:
        return nil;
    }
}

-(THLine*)processOpen:(THPacket*)openPacket switch:(THSwitch*)thSwitch
{
    CLCLogError(@"Not implemented");
    return nil;
}

-(NSString*)identifier
{
    NSAssert(true, @"base class not implemented");
    return nil;
}

-(void)finalizeLineKeys:(THLine *)line
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


