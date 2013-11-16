//
//  THAppDelegate.h
//  Telehash Playground
//
//  Created by Thomas Muldowney on 11/15/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class THSwitch;

@interface THAppDelegate : NSObject <NSApplicationDelegate> {
    THSwitch* thSwitch;
}

@property (assign) IBOutlet NSWindow *window;

@end
