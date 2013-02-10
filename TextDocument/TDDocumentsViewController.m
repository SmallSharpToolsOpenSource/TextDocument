//
//  TDDocumentsViewController.m
//  TextDocument
//
//  Created by Brennan Stehling on 2/4/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "TDDocumentsViewController.h"

@interface TDDocumentsViewController ()

@property (strong, nonatomic) NSArray *representations;

@end

@implementation TDDocumentsViewController

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.representations = [TDTextDocumentRepresentation loadTextDocuments];
    DebugLog(@"self.representations.count: %i", self.representations.count);
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    DebugLog(@"self.representations.count: %i", self.representations.count);
    return self.representations.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"TextCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSAssert(cell != nil, @"Invalid State");
    
    NSAssert(self.representations.count > indexPath.row, @"Invalid State");
    TDTextDocumentRepresentation *representation = [self.representations objectAtIndex:indexPath.row];
    
    // set a placeholder value until the preview is loaded
    cell.textLabel.text = [[representation.url lastPathComponent] stringByDeletingPathExtension];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[representation.previewURL path]]) {
        NSString *preview = [NSString stringWithContentsOfFile:[representation.previewURL path]
                                                      encoding:NSUTF8StringEncoding
                                                         error:NULL];
        
        if (preview != nil && ![@"" isEqualToString:preview]) {
            cell.textLabel.text = preview;
        }
    }
    else {
        DebugLog(@"Preview file does not exist!");
    }
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

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

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(self.representations.count > indexPath.row, @"Invalid State");
    NSAssert(self.delegate != nil, @"Invalid State");
    
    if ([self.delegate respondsToSelector:@selector(textDocumentsViewController:didChangeTextDocument:)]) {
        TDTextDocumentRepresentation *representation = [self.representations objectAtIndex:indexPath.row];
        DebugLog(@"Changing text document to %@", [[representation.url lastPathComponent] stringByDeletingPathExtension]);
        [self.delegate textDocumentsViewController:self didChangeTextDocument:representation];
    }
    
    [self.navigationController popViewControllerAnimated:TRUE];
}

@end
