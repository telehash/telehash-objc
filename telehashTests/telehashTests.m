//
//  telehashTests.m
//  telehashTests
//
//  Created by Thomas Muldowney on 9/30/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "THPacket.h"

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
    THPacket* pkt = [THPacket new];
    pkt.raw = [NSMutableData data];
    [pkt parse];
    
}

@end
