//
//  THDetailViewController.h
//  thFieldTest
//
//  Created by Thomas Muldowney on 12/9/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface THDetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) id detailItem;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@end
