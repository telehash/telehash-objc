//
//  THAppDelegate.m
//  Telehash Playground
//
//  Created by Thomas Muldowney on 11/15/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THAppDelegate.h"
#import "THIdentity.h"
#import <THPacket.h>
#import "THSwitch.h"

#include <arpa/inet.h>

#define SERVER_TEST 0

@interface THAppDelegate () {
    NSString* startChannelId;
}
@end

@implementation THAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [tableView setDataSource:self];
    
    // Insert code here to initialize your application
    thSwitch = [THSwitch defaultSwitch];
    thSwitch.delegate = self;
    thSwitch.identity = [THIdentity identityFromPublicKey:@"/tmp/telehash/server.pder" privateKey:@"/tmp/telehash/server.der"];
    NSLog(@"Hashname: %@", [thSwitch.identity hashname]);
    [thSwitch start];
    
    [thSwitch loadSeeds:[NSData dataWithContentsOfFile:@"/tmp/telehash/seeds.json"]];
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [thSwitch.openLines count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
{
    NSArray* keys = [thSwitch.openLines allKeys];
    THLine* line = [thSwitch.openLines objectForKey:[keys objectAtIndex:rowIndex]];
    return line.toIdentity.hashname;
}


-(void)openedLine:(THLine *)line;
{
    [tableView reloadData];
    
#if SERVER_TEST == 0
    THIdentity* identity = [THIdentity identityFromPublicKey:[NSData dataWithContentsOfFile:@"/tmp/telehash/chat.pder"]];
    //[identity setIP:@"127.0.0.1" port:42424];
    THReliableChannel* channel = [[THReliableChannel alloc] initToIdentity:identity];
    startChannelId = channel.channelId;
    channel.delegate = self;
    
    THPacket* packet = [THPacket new];
    [packet.json setObject:@"_members" forKey:@"type"];
    [packet.json setObject:@{ @"room": @"testRoom" } forKey:@"_"];
    [packet.json setObject:@YES forKey:@"end"];
    
    [thSwitch openChannel:channel firstPacket:packet];
#endif

}

-(void)channelReady:(THChannel *)channel type:(THChannelType)type firstPacket:(THPacket *)packet;
{
    NSLog(@"Channel is ready");
    NSLog(@"First packet is %@", packet.json);
    
#if SERVER_TEST
    NSString* packetType = [packet.json objectForKey:@"type"];
    if ([packetType isEqualToString:@"_members"]) {
        THSwitch* defaultSwitch = [THSwitch defaultSwitch];
        THPacket* respPacket = [THPacket new];
        [respPacket.json setObject:@{@"members":@[defaultSwitch.identity.hashname, channel.line.toIdentity.hashname]} forKey:@"_"];
        [respPacket.json setObject:@"_members" forKey:@"type"];
        [respPacket.json setObject:@YES forKey:@"end"];
        
        [channel sendPacket:respPacket];
    } else if ([packetType isEqualToString:@"_chat"]) {
        THPacket* joinPacket = [THPacket new];
        [joinPacket.json setObject:@{@"nick":@"temasObjc"} forKey:@"_"];
        [channel sendPacket:joinPacket];
        channel.delegate = self;
    } else {
        NSLog(@"We're in the other generic handler now.  What do?");
    }
#else
    if ([channel.channelId isEqualToString:startChannelId]) {
        THReliableChannel* newChannel = [[THReliableChannel alloc] initToIdentity:channel.toIdentity];
        newChannel.delegate = self;
        
        THPacket* outPacket = [THPacket new];
        [outPacket.json setObject:@"_chat" forKey:@"type"];
        [outPacket.json setObject:@{ @"room": @"testRoom" } forKey:@"_"];
        
        [thSwitch openChannel:newChannel firstPacket:outPacket];
    }
#endif
}

-(BOOL)channel:(THChannel*)channel handlePacket:(THPacket *)packet;
{
    NSLog(@"We're in the app: %@", packet.json);
    THPacket* msgPacket = [THPacket new];
    [msgPacket.json setObject:@{ @"message" : @"test", @"id" : @123123123123123 } forKey:@"_"];
    [channel sendPacket:msgPacket];
    return YES;
}
@end
