//
//  telehashTests.m
//  telehashTests
//
//  Created by Thomas Muldowney on 9/30/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "THPacket.h"
#import "THSwitch.h"
#import "THIdentity.h"

@interface telehashTests : XCTestCase

@end

@implementation telehashTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

-(void)testPacketParsing
{
    NSURL* fileURL = [[NSURL alloc] initFileURLWithPath:@"telehashTests/test.pkt"];
    THPacket* pkt = [THPacket packetData:[NSData dataWithContentsOfURL:fileURL]];
    
    XCTAssertEqualObjects([pkt.json objectForKey:@"line"], @"abcdef1234567890abcedf1234567890", @"line was incorrect");
    XCTAssertEqualObjects(pkt.body, [NSData dataWithBytes:"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f" length:16], @"body was incorrect");
}

-(void)testSwitch
{
    THSwitch* thSwitch = [THSwitch defaultSwitch];
    thSwitch.identity = [THIdentity identityFromPublicKey:@"telehashTests/server.pder" privateKey:@"telehashTests/server.der"];
    /*
    [thSwitch onChannel:^(THChannel* channel, THIdentity* from){
        NSLog(@"We do stuff");
    }];
    */
    [thSwitch start];
}

@end
