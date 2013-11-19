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

#if 0
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
#endif

-(void)testPacketCreation
{
    THPacket* pkt = [THPacket new];
    [pkt.json setObject:@"open" forKey:@"type"];
    [pkt.json setObject:@"1234567890" forKey:@"iv"];
    pkt.body = [NSData dataWithBytes:"\x00\x01\x02\x03\x04" length:5];
    
    THPacket* parsedPacket = [THPacket packetData:[pkt encode]];
    XCTAssertNotNil(parsedPacket, @"Packet was parsed");
    XCTAssertEqualObjects(@"open", [parsedPacket.json objectForKey:@"type"], @"JSON has an open");
    XCTAssertEqualObjects(@"1234567890", [parsedPacket.json objectForKey:@"iv"], @"JSON has an iv");
}

-(void)testIdentityDistance
{
    THIdentity* origin = [THIdentity new];
    [origin setValue:@"736711cf55ff95fa967aa980855a0ee9f7af47d6287374a8cd65e1a36171ef08" forKey:@"_hashnameCache"];
    
    THIdentity* remote = [THIdentity new];
    [remote setValue:@"73654507a9fd1202c6a9381b626d1903a36eafe8a6240bcc726fc668a35d6268" forKey:@"_hashnameCache"];
    XCTAssert([origin distanceFrom:remote] == 241, @"Distance should be 241 got %ld", [origin distanceFrom:remote]);
    
    [remote setValue:@"7362651360238f87de3d943c9ea2749f5e0d4e7ef7afd82f65ffa6480796f0e6" forKey:@"_hashnameCache"];
    XCTAssert([origin distanceFrom:remote] == 242, @"Distance should be 242");
    
    [remote setValue:@"7d906fbc8d5bead0d62ed50b8ec988eae541afb5d2d6bd7bd3d0c8c0e250185e" forKey:@"_hashnameCache"];
    XCTAssert([origin distanceFrom:remote] == 251, @"Distance should be 251");
    
    [remote setValue:@"1fc84a5a1c35aac15d4014cceb77e6630dda153723b33c7805092f198277e99e" forKey:@"_hashnameCache"];
    XCTAssert([origin distanceFrom:remote] == 254, @"Distance should be 254");
    
    [remote setValue:@"f7689fe81620568fc72030e7946a8ad86b4a700a190760b6bec6074a9661284d" forKey:@"_hashnameCache"];
    XCTAssert([origin distanceFrom:remote] == 255, @"Distance should be 255");
    
    [remote setValue:@"736711cf55ff95fa967aa980855a0ee9f7af47d6287374a8cd65e1a36171ef08" forKey:@"_hashnameCache"];
    XCTAssert([origin distanceFrom:remote] == 0, @"Distance should be 0 got %ld", [origin distanceFrom:remote]);
}

@end
