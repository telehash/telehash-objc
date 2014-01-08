//
//  THMasterViewController.m
//  thFieldTest
//
//  Created by Thomas Muldowney on 12/9/13.
//  Copyright (c) 2013 Telehash Foundation. All rights reserved.
//

#import "THMasterViewController.h"

#import "THDetailViewController.h"

#import <THIdentity.h>

@interface THMasterViewController () {
    NSMutableArray *_objects;
}
@end

@implementation THMasterViewController

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.leftBarButtonItem = self.editButtonItem;

    /*
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
    self.navigationItem.rightBarButtonItem = addButton;
    self.detailViewController = (THDetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    */
    
    thSwitch = [THSwitch defaultSwitch];
    
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [searchPaths objectAtIndex:0];
    
    NSString* pubPath = [NSString stringWithFormat:@"%@/pubkey.der", documentPath];
    NSString* privPath = [NSString stringWithFormat:@"%@/privkey.der", documentPath];
    
    THIdentity* ourIdentity = nil;
    ourIdentity = [THIdentity identityFromPublicFile:pubPath privateFile:privPath];
    if (!ourIdentity) {
        ourIdentity = [THIdentity generateIdentity];

        [ourIdentity.rsaKeys savePublicKey:pubPath privateKey:privPath];
    }
    
#if 0
    NSMutableDictionary* secQuery = [NSMutableDictionary dictionary];
    [secQuery setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
    NSData* secItem = [NSData dataWithBytes:kKeychainItemIdentifier length:strlen((const char*)kKeychainItemIdentifier)];
    [secQuery setObject:secItem forKey:(__bridge id)kSecAttrApplicationTag];
    [secQuery setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    [secQuery setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
    
    CFDictionaryRef outRef = NULL;
    SecItemCopyMatching((__bridge_retained CFDictionaryRef)(secQuery), (CFTypeRef*)&outRef);
    
    THIdentity* ourIdentity = nil;
    if (outRef == nil) {
        ourIdentity = [THIdentity generateIdentity];
        
        NSMutableDictionary* saveQuery = [NSMutableDictionary dictionary];
        [queryPublicKey setObject:secItem forKey:(__bridge id)kSecAttrApplicationTag];
        [saveQuery setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
        [saveQuery setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        [keyPairAttr setObject:[NSNumber numberWithInt:2048] forKey:(__bridge id)kSecAttrKeySizeInBits];

    } else {
        NSDictionary* outKeyAttrs = (__bridge_transfer NSDictionary*)outRef;
    }
#endif
    
    thSwitch.identity = ourIdentity;
    thSwitch.delegate = self;
    
    [thSwitch startOnPort:42424];
    NSLog(@"Online as %@", ourIdentity.hashname);
    
    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"seeds" ofType:@"json"];
    NSData* seedData = [NSData dataWithContentsOfFile:filePath];
    if (seedData) [thSwitch loadSeeds:seedData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)insertNewObject:(id)sender
{
    if (!_objects) {
        _objects = [[NSMutableArray alloc] init];
    }
    [_objects insertObject:[NSDate date] atIndex:0];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

-(void)openedLine:(THLine *)line
{
    if (!_objects) {
        _objects = [[NSMutableArray alloc] init];
    }
    [_objects addObject:line.toIdentity.hashname];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(_objects.count - 1) inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _objects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

    NSDate *object = _objects[indexPath.row];
    cell.textLabel.text = [object description];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_objects removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }
}

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        NSDate *object = _objects[indexPath.row];
        self.detailViewController.detailItem = object;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        NSDate *object = _objects[indexPath.row];
        [[segue destinationViewController] setDetailItem:object];
    }
}

@end
