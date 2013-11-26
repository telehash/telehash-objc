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

-(THPacket*)channelReady:(THChannel *)channel type:(THChannelType)type firstPacket:(THPacket *)packet;
{
    NSLog(@"Channel is ready");
    NSLog(@"First packet is %@", packet.json);
    
    THPacket* respPacket = [THPacket new];
    [respPacket.json setObject:@{@"room":@"temas"} forKey:@"_"];
    [respPacket.json setObject:@"_members" forKey:@"type"];
    return respPacket;
}

-(BOOL)channel:(THChannel*)channel handlePacket:(THPacket *)packet;
{
    NSLog(@"We're in the app: %@", packet.json);
    return YES;
}
@end
