//
//  THAppDelegate.m
//  Telehash Playground
//
//  Created by Thomas Muldowney on 11/15/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THAppDelegate.h"
#import "THSwitch.h"
#import "THIdentity.h"

@implementation THAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    thSwitch = [THSwitch defaultSwitch];
    thSwitch.identity = [THIdentity identityFromPublicKey:@"/tmp/telehash/server.pder" privateKey:@"/tmp/telehash/server.der"];
    NSLog(@"Hashname: %@", [thSwitch.identity hashname]);
    [thSwitch start];
}

@end
