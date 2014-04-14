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
#import "NSData+HexString.h"
#import "THTransport.h"
#import "THPath.h"
#import "THChannel.h"

#include <arpa/inet.h>

#define SERVER_TEST 0

@interface THAppDelegate () {
    NSString* startChannelId;
    THReliableChannel* pingChannel;
}
@end

@implementation THAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [tableView setDataSource:self];
    self.identityPath = @"/tmp/telehash2";
}

-(void)startSwitch:(id)sender
{
    // Insert code here to initialize your application
    thSwitch = [THSwitch defaultSwitch];
    thSwitch.delegate = self;
    THIdentity* baseIdentity = [THIdentity new];
    self.identityPath = pathField.stringValue;
    THCipherSet2a* cs2a = [[THCipherSet2a alloc] initWithPublicKeyPath:[NSString stringWithFormat:@"%@/server.pder", self.identityPath] privateKeyPath:[NSString stringWithFormat:@"%@/server.der", self.identityPath]];
    if (!cs2a) {
        /*
        NSFileManager* fm = [NSFileManager defaultManager];
        NSError* err;
        [fm createDirectoryAtPath:@"/tmp/telehash" withIntermediateDirectories:NO attributes:nil error:&err];
        */
        cs2a = [THCipherSet2a new];
        [cs2a generateKeys];
        [cs2a.rsaKeys savePublicKey:[NSString stringWithFormat:@"%@/server.pder", self.identityPath] privateKey:[NSString stringWithFormat:@"%@/server.der", self.identityPath]];
    }
    [baseIdentity addCipherSet:cs2a];
    NSLog(@"2a fingerprint %@", [cs2a.fingerprint hexString]);
    thSwitch.identity = baseIdentity;
    NSLog(@"Hashname: %@", [thSwitch.identity hashname]);
    THIPv4Transport* ipTransport = [THIPv4Transport new];
    ipTransport.priority = 1;
    [thSwitch addTransport:ipTransport];
    ipTransport.delegate = thSwitch;
    NSArray* paths = [ipTransport gatherAvailableInterfacesApprovedBy:^BOOL(NSString *interface) {
        if ([interface isEqualToString:@"lo0"]) return YES;
        if ([interface isEqualToString:@"en0"]) return YES;
        return NO;
    }];
    for (THIPV4Path* ipPath in paths) {
        [baseIdentity addPath:ipPath];
    }
    
    [thSwitch start];
    
    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"seeds" ofType:@"json"];
    NSData* seedData = [NSData dataWithContentsOfFile:filePath];
    if (seedData) [thSwitch loadSeeds:seedData];
    
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
#if 0
    if (status == THSwitchOnline && !pingChannel) {
        THPacket* crapPacket = [THPacket new];
        [crapPacket.json setObject:@"ping" forKey:@"type"];
        
        pingChannel = [[THReliableChannel alloc] initToIdentity:[THIdentity identityFromHashname:@"d3da6b886d827dd221f80ffefba99e800e0ce6d3b51f4eedb5373c9bbf9e5956"]];
        pingChannel.delegate = self;
        
        [thSwitch openChannel:pingChannel firstPacket:crapPacket];
    }
#endif
}

-(void)channel:(THChannel *)channel didFailWithError:(NSError *)error
{
    NSLog(@"Got an error: %@", error);
}
@end
