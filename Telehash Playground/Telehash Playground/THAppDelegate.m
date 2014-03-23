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
#import "THCipherSet.h"
#import "NSData+Hexstring.h"

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
    THIdentity* baseIdentity = [THIdentity new];
    THCipherSet2a* cs2a = [[THCipherSet2a alloc] initWithPublicKeyPath:@"/tmp/telehash/server.pder" privateKeyPath:@"/tmp/telehash/server.der"];
    if (!cs2a) {
        NSFileManager* fm = [NSFileManager defaultManager];
        NSError* err;
        [fm createDirectoryAtPath:@"/tmp/telehash" withIntermediateDirectories:NO attributes:nil error:&err];
        THCipherSet2a* cs2a = [THCipherSet2a new];
        [cs2a generateKeys];
        [cs2a.rsaKeys savePublicKey:@"/tmp/telehash/server.pder" privateKey:@"/tmp/telehash/server.der"];
    }
    [baseIdentity addCipherSet:cs2a];
    NSLog(@"2a fingerprint %@", [cs2a.fingerprint hexString]);
    thSwitch.identity = baseIdentity;
    NSLog(@"Hashname: %@", [thSwitch.identity hashname]);
    THIPV4Path* ipPath = [THIPV4Path new];
    [baseIdentity addPath:ipPath];
    [ipPath startOnPort:42424];
    
    //[thSwitch loadSeeds:[NSData dataWithContentsOfFile:@"/tmp/telehash/seeds.json"]];
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
}

-(void)channelReady:(THChannel *)channel type:(THChannelType)type firstPacket:(THPacket *)packet;
{
    NSLog(@"Channel is ready");
    NSLog(@"First packet is %@", packet.json);
    return;
}

-(IBAction)connectToHashname:(id)sender
{
    THIdentity* connectToIdentity;
    NSString* key = [keyField stringValue];
    if (key.length > 0) {
/*
        NSData* keyData = [[NSData alloc] initWithBase64EncodedString:key options:0];
        connectToIdentity = [THIdentity identityFromPublicKey:keyData];
        NSString* address = [addressField stringValue];
        NSInteger port = [portField integerValue];
        if (address && port > 0) {
            [connectToIdentity setIP:address port:port];
        }
*/
    } else {
        connectToIdentity = [THIdentity identityFromHashname:[hashnameField stringValue]];
    }
    if (connectToIdentity) {
        [thSwitch openLine:connectToIdentity completion:^(THIdentity* openIdentity) {
            NSLog(@"We're in the app and connected to %@", connectToIdentity.hashname);
        }];
    }
}

-(void)thSwitch:(THSwitch *)thSwitch status:(THSwitchStatus)status
{
    NSLog(@"Switch status is now %d", status);
}
@end
