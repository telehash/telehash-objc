//
//  telehashTests.m
//  telehashTests
//
//  Created by Thomas Muldowney on 9/30/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "THPacket.h"
#import "THMesh.h"
#import "THLink.h"
#import "THPacketBuffer.h"
#import "E3XCipherSet.h"
#import "THPath.h"
#import "E3XReliableChannel.h"
#import "E3XChannel.h"
#include <arpa/inet.h>

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

-(void)testOpenPacketParsing
{
    // Ensure we can process open packets which have a length of 1 and a leading bye of the body
    NSURL* fileURL = [[NSURL alloc] initFileURLWithPath:@"telehashTests/open.pkt"];
    THPacket* openPkt = [THPacket packetData:[NSData dataWithContentsOfURL:fileURL]];
    
    XCTAssert(openPkt.jsonLength == 1, @"JSON length was not 1");
    XCTAssertEqualObjects(openPkt.body, [NSData dataWithBytes:"\xff\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f" length:17], @"body was incorrect");
}

-(void)testHashname
{
    /* XXX TODO:  Rewrite this for the new hashnames
    THIdentity* identity = [THIdentity new];
    NSURL* pubURL = [[NSURL alloc] initFileURLWithPath:@"telehashTests/server.pder"];
    NSData* serverPub = [NSData dataWithContentsOfURL:pubURL];
    NSURL* privURL = [[NSURL alloc] initFileURLWithPath:@"telehashTests/server.der"];
    NSData* serverPriv = [NSData dataWithContentsOfURL:privURL];
    THCipherSet2a* cs2a = [[THCipherSet2a alloc] initWithPublicKey:serverPub privateKey:serverPriv];
    [identity.cipherParts setValue:cs2a forKey:@"2a"];
    
    XCTAssertEqualObjects(@"50a5d0d0e00080edf6cdf98eae2fc38196890e6c443e3d268b5963cf0052a900", identity.hashname, @"Hashname incorrect");
    */
}

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
    THLink* origin = [THLink new];
    [origin setValue:@"736711cf55ff95fa967aa980855a0ee9f7af47d6287374a8cd65e1a36171ef08" forKey:@"_hashnameCache"];
    
    THLink* remote = [THLink new];
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

-(void)testPacketBuffer;
{
    THPacketBuffer* buffer = [THPacketBuffer new];
    
    THPacket* packet = [THPacket new];
    [packet.json setObject:@0 forKey:@"seq"];
    
    [buffer push:packet];
    XCTAssertEqual([buffer length], 1UL, @"Buffer length is 1");
    
    // Ensure we can't push the same seq twice
    [buffer push:packet];
    XCTAssertEqual([buffer length], 1UL, @"Buffer length is 1");
    
    [buffer pop];
    XCTAssertEqual([buffer length], 0UL, @"Buffer is empty");
    
    packet = [THPacket new];
    [packet.json setObject:@1 forKey:@"seq"];
    [buffer push:packet];
    packet = [THPacket new];
    [packet.json setObject:@3 forKey:@"seq"];
    [buffer push:packet];
    packet = [THPacket new];
    [packet.json setObject:@2 forKey:@"seq"];
    [buffer push:packet];
    
    XCTAssertEqual([buffer length], 3UL, @"Buffer is length 3");
    
    [buffer clearThrough:2];
    XCTAssertEqual([buffer length], 1UL, @"Buffer length is 1");
}

-(void)testPacketBufferMissing;
{
    THPacketBuffer* buffer = [THPacketBuffer new];
    
    THPacket* packet = [THPacket new];
    [packet.json setObject:@0 forKey:@"seq"];
    
    [buffer push:packet];
    
    packet = [THPacket new];
    [packet.json setObject:@1 forKey:@"seq"];
    
    [buffer push:packet];
    
    XCTAssertNil([buffer missingSeqFrom:0], @"Missing should be nil");
    
    packet = [THPacket new];
    [packet.json setObject:@4 forKey:@"seq"];
    
    [buffer push:packet];
    NSArray* missing = [buffer missingSeqFrom:0];
    XCTAssertEqual(missing.count, 2UL, @"Missing should have two entries");
    XCTAssertEqualObjects(missing, (@[ @2U, @3U ]), @"Missing should have entries of 3 and 4");
    
    packet = [THPacket new];
    [packet.json setObject:@3 forKey:@"seq"];
    [buffer push:packet];
    
    missing = [buffer missingSeqFrom:0];
    XCTAssertEqualObjects(missing, (@[ @2U ]), @"Missing should have one entry of 2");
    
    packet = [THPacket new];
    [packet.json setObject:@2 forKey:@"seq"];
    [buffer push:packet];
    
    XCTAssertNil([buffer missingSeqFrom:0], @"Missing shoudl be nil");
    
    [buffer clearThrough:4];
    packet = [THPacket new];
    [packet.json setObject:@2 forKey:@"seq"];
    [buffer push:packet];
    
    XCTAssertEqualObjects([buffer missingSeqFrom:0], (@[@0U, @1U]), @"Missing should have 0, 1");
    
    packet = [THPacket new];
    [packet.json setObject:@1 forKey:@"seq"];
    [buffer push:packet];
    
    NSLog(@"%@", [buffer missingSeqFrom:0]);
}

-(void)testReliableChannelSeq
{
    THLink* testIdentity = [THLink identityFromHashname:@"abcdef1234567890abcdef1234567890"];
    E3XReliableChannel* testChannel = [[E3XReliableChannel alloc] initToIdentity:testIdentity];
    testChannel.channelId = @42;
    
    THPacket* testPacket = [THPacket new];
    [testPacket.json setObject:@1 forKey:@"seq"];
    
    [testChannel handlePacket:testPacket];
}

@end
