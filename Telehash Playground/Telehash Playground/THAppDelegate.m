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
#import "THCipherSet2a.h"

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
        //if ([interface isEqualToString:@"lo0"]) return YES;
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
    if ([channel.type isEqualToString:@"ping"]) {
        channel.delegate = self;
        [self channel:channel handlePacket:packet];
    }
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

-(void)thSwitch:(THSwitch *)inSwitch status:(THSwitchStatus)status
{
    NSLog(@"Switch status is now %d", status);
    if (status == THSwitchOnline && !pingChannel) {
#if 0
        if (![inSwitch.identity.hashname isEqualToString:@"ee5dc2630603638dfb980cbe7062378bdc70091947d9fa6dac5cf9b072296aad"]) {

            THPacket* pingPacket = [THPacket new];
            [pingPacket.json setObject:@"ping" forKey:@"type"];
            
            pingChannel = [[THReliableChannel alloc] initToIdentity:[THIdentity identityFromHashname:@"ee5dc2630603638dfb980cbe7062378bdc70091947d9fa6dac5cf9b072296aad"]];
            pingChannel.delegate = self;
            
            [inSwitch openChannel:pingChannel firstPacket:pingPacket];
        }
#endif
    }
}

-(void)channel:(THChannel *)channel didFailWithError:(NSError *)error
{
    NSLog(@"Got an error: %@", error);
}

-(BOOL)channel:(THChannel *)channel handlePacket:(THPacket *)packet
{
    NSLog(@"Handling packet on channel %@ (%@): %@", channel.channelId, channel.type, packet.json);
    if ([channel.type isEqualToString:@"ping"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            THPacket* pingReply = [THPacket new];
            [pingReply.json setObject:@(time(NULL)) forKey:@"at"];
            [channel sendPacket:pingReply];
        });
    }
    return YES;
}
@end
