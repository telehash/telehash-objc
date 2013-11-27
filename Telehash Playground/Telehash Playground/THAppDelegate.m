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

@implementation THAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    thSwitch = [THSwitch defaultSwitch];
    thSwitch.delegate = self;
    thSwitch.identity = [THIdentity identityFromPublicKey:@"/tmp/telehash/server.pder" privateKey:@"/tmp/telehash/server.der"];
    NSLog(@"Hashname: %@", [thSwitch.identity hashname]);
    [thSwitch startOnPort:42424];
}

-(void)channelReady:(THChannel *)channel type:(THChannelType)type firstPacket:(THPacket *)packet;
{
    NSLog(@"Channel is ready");
    NSLog(@"First packet is %@", packet.json);
    
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
