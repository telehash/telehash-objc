//
//  THMasterViewController.h
//  thFieldTest
//
//  Created by Thomas Muldowney on 12/9/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <THMesh.h>
#import <E3XChannel.h>

@class THDetailViewController;

@interface THMasterViewController : UITableViewController<THMeshDelegate, E3XChannelDelegate> {
    THMesh* thSwitch;
}

@property (strong, nonatomic) THDetailViewController *detailViewController;

@end
