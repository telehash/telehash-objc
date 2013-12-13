//
//  THMasterViewController.h
//  thFieldTest
//
//  Created by Thomas Muldowney on 12/9/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <THSwitch.h>
#import <THChannel.h>

@class THDetailViewController;

@interface THMasterViewController : UITableViewController<THSwitchDelegate, THChannelDelegate> {
    THSwitch* thSwitch;
}

@property (strong, nonatomic) THDetailViewController *detailViewController;

@end
