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
#import <THCipherSet.h>
#import <NSData+HexString.h>
#import <THPath.h>
#import <THTransport.h>

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
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Go" style:UIBarButtonItemStylePlain target:self action:@selector(doStuff)];

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
    
    // Insert code here to initialize your application
    thSwitch = [THSwitch defaultSwitch];
    thSwitch.delegate = self;
    THIdentity* baseIdentity = [THIdentity new];
    THCipherSet2a* cs2a = [[THCipherSet2a alloc] initWithPublicKeyPath:pubPath privateKeyPath:privPath];
    if (!cs2a) {
        cs2a = [THCipherSet2a new];
        [cs2a generateKeys];
        [cs2a.rsaKeys savePublicKey:pubPath privateKey:privPath];
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
        NSLog(@"Offered interface %@", interface);
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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)openedLine:(THLine *)line
{
    [self.tableView reloadData];
}

-(void)channelReady:(THChannel *)channel type:(THChannelType)type firstPacket:(THPacket *)packet
{
    [self.tableView reloadData];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return thSwitch.openLines.count;
}

-(NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSMutableArray *keys = [[thSwitch.openLines allKeys] mutableCopy];
    [keys sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return [keys objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSMutableArray *keys = [[thSwitch.openLines allKeys] mutableCopy];
    [keys sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString* key = [keys objectAtIndex:section];
    THLine* line = [thSwitch.openLines objectForKey:key];
    return line.toIdentity.channels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    NSMutableArray *keys = [[thSwitch.openLines allKeys] mutableCopy];
    [keys sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString* key = [keys objectAtIndex:indexPath.section];
    THLine* line = [thSwitch.openLines objectForKey:key];
    keys = [[line.toIdentity.channels allKeys] mutableCopy];
    [keys sortUsingSelector:@selector(compare:)];
    THChannel* channel = [line.toIdentity.channels objectForKey:[keys objectAtIndex:indexPath.row]];
    cell.textLabel.text = [NSString stringWithFormat:@"Channel - %@ - %@", channel.type, channel.channelId];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
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
    NSMutableArray *keys = [[thSwitch.openLines allKeys] mutableCopy];
    [keys sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSString* key = [keys objectAtIndex:indexPath.section];
    THLine* line = [thSwitch.openLines objectForKey:key];
    keys = [[line.toIdentity.channels allKeys] mutableCopy];
    [keys sortUsingSelector:@selector(compare:)];
    THChannel* channel = [line.toIdentity.channels objectForKey:[keys objectAtIndex:indexPath.row]];
    
    self.detailViewController.detailItem = channel;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        NSMutableArray *keys = [[thSwitch.openLines allKeys] mutableCopy];
        [keys sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        NSString* key = [keys objectAtIndex:indexPath.section];
        THLine* line = [thSwitch.openLines objectForKey:key];
        keys = [[line.toIdentity.channels allKeys] mutableCopy];
        [keys sortUsingSelector:@selector(compare:)];
        THChannel* channel = [line.toIdentity.channels objectForKey:[keys objectAtIndex:indexPath.row]];

        [[segue destinationViewController] setDetailItem:channel];
    }
}

-(void)doStuff
{
    [self.tableView reloadData];
    //[thSwitch openLine:[THIdentity identityFromHashname:@"580154007d7c0c925735e62354eb54fd7f12245a1e7755905960478c537c1144"]];
}

@end
