//
//  THAppDelegate.h
//  Telehash Playground
//
//  Created by Thomas Muldowney on 11/15/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <THMesh.h>
#import <E3XChannel.h>

@interface THAppDelegate : NSObject <THSwitchDelegate, THChannelDelegate, NSTableViewDataSource, NSTableViewDelegate> {
    IBOutlet NSTableView* tableView;
    IBOutlet NSTextField* hashnameField;
    IBOutlet NSTextField* addressField;
    IBOutlet NSTextField* portField;
    IBOutlet NSTextField* keyField;
    IBOutlet NSTextField* pathField;
    IBOutlet NSObjectController* objController;
    IBOutlet NSArrayController* channelArrayController;
    THMesh* thSwitch;
}

@property NSString* identityPath;
@property (assign) IBOutlet NSWindow *window;

-(void)channelReady:(E3XChannel *)channel type:(THChannelType)type firstPacket:(THPacket *)packet;
-(BOOL)channel:(E3XChannel*)channel handlePacket:(THPacket *)packet;

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;

-(IBAction)connectToHashname:(id)sender;
-(IBAction)startSwitch:(id)sender;
@end
