//
//  TDDocumentsViewController.m
//  TextDocument
//
//  Created by Brennan Stehling on 2/4/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "TDDocumentsViewController.h"

#import "TDTextDocument.h"
#import "TDTextDocumentRepresentation.h"
#import "TDEditorViewController.h"
#import "TDCloudManager.h"

@interface TDDocumentsViewController () <UITableViewDataSource, UITableViewDelegate, TDEditorDelegate>

@property (strong, nonatomic) NSMetadataQuery *query;
@property (strong, nonatomic) NSArray *representations;

@property (strong, nonatomic) TDTextDocument *selectedTextDocument;

@end

@implementation TDDocumentsViewController

#pragma mark - View Lifecycle
#pragma mark -

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:TDTextDocumentPreviewStateDidChangeNotification
                                                  object:nil];
}

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
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textDocumentPreviewDidChangeNotification:)
                                                 name:TDTextDocumentPreviewStateDidChangeNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([@"DocumentsToEditor" isEqualToString:segue.identifier]) {
        NSAssert([segue.destinationViewController isKindOfClass:[TDEditorViewController class]], @"Invalid Destination Class");
        NSAssert(self.selectedTextDocument != nil, @"Selected document must be defined");
        TDEditorViewController *vc = (TDEditorViewController *)segue.destinationViewController;
        vc.delegate = self;
        [vc changeTextDocument:self.selectedTextDocument];
    }
}

#pragma mark - User Actions
#pragma mark -

- (IBAction)newButtonTapped:(id)sender {
    TDTextDocument *textDocument = [TDTextDocument createTextDocument];
    textDocument.text = @"";
    self.selectedTextDocument = textDocument;
    [self performSegueWithIdentifier:@"DocumentsToEditor" sender:self];
}

#pragma mark - Private
#pragma mark -

- (void)updateCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    NSAssert(self.representations.count > indexPath.row, @"Invalid State");
    TDTextDocumentRepresentation *representation = [self.representations objectAtIndex:indexPath.row];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[representation.previewURL path]]) {
        NSString *preview = [NSString stringWithContentsOfFile:[representation.previewURL path]
                                                      encoding:NSUTF8StringEncoding
                                                         error:NULL];
        
        if (preview != nil && ![@"" isEqualToString:preview]) {
            DebugLog(@"Setting preview: %@ (%i)", preview, indexPath.row);
            cell.textLabel.text = preview;
            [cell.textLabel setNeedsDisplay];
        }
        else {
            cell.textLabel.text = @"Loading...";
        }
    }
    else {
        DebugLog(@"Preview file does not exist!");
        cell.textLabel.text = @"Loading...";
    }
}

- (void)refresh {
    DebugLog(@"%@", NSStringFromSelector(_cmd));
    
    DebugLog(@"Loading Documents - BEFORE");
    [[TDCloudManager sharedInstance] loadTextDocumentsWithCompletionBlock:^(NSArray *representations, NSError *error) {
        DebugLog(@"%@", NSStringFromSelector(_cmd));
        
        DebugLog(@"Loading Documents - CALLBACK");
        if (![representations isEqualToArray:self.representations]) {
            self.representations = representations;
            DebugLog(@"Reloading!");
            [self.tableView reloadData];
        }
        else {
            DebugLog(@"Not Reloading!");
        }
    }];
    
    DebugLog(@"Loading Documents - AFTER");
}

#pragma mark - Notifications
#pragma mark -

- (void)textDocumentPreviewDidChangeNotification:(NSNotification *)notification {
    DebugLog(@"%@", NSStringFromSelector(_cmd));

    for (NSIndexPath *indexPath in self.tableView.indexPathsForVisibleRows) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        [self updateCell:cell atIndexPath:indexPath];
    }
}

#pragma mark - UITableViewDataSource
#pragma mark -

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return self.representations.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"TextCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSAssert(cell != nil, @"Invalid State");
    
    [self updateCell:cell atIndexPath:indexPath];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        
        NSAssert(self.representations.count > indexPath.row, @"Invalid State");
        
        DebugLog(@"Deleting %i", indexPath.row);
        
        TDTextDocumentRepresentation *representation = [self.representations objectAtIndex:indexPath.row];
        NSMutableArray *reps = [self.representations mutableCopy];
        [reps removeObjectAtIndex:indexPath.row];
        self.representations = (NSArray *)reps;
        DebugLog(@"Reloading!");
        [self.tableView reloadData];
        TDTextDocument *textDocument = [[TDTextDocument alloc] initWithFileURL:representation.url];
        [TDTextDocument deleteTextDocument:textDocument];
    }
}

#pragma mark - UITableViewDelegate
#pragma mark -

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(self.representations.count > indexPath.row, @"Invalid State");
    
    TDTextDocumentRepresentation *representation = [self.representations objectAtIndex:indexPath.row];
    TDTextDocument *textDocument = [[TDTextDocument alloc] initWithFileURL:representation.url];
    self.selectedTextDocument = textDocument;
    
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self.tableView deselectRowAtIndexPath:indexPath animated:TRUE];
    });
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath {
    cell.textLabel.text = @"N/A";
}

#pragma mark - TDEditorDelegate
#pragma mark -

- (void)textEditor:(TDEditorViewController *)textEditor didCloseTextDocument:(TDTextDocument *)textDocument {
    DebugLog(@"%@", NSStringFromSelector(_cmd));
    
    [[TDCloudManager sharedInstance] generatePreviewFileForFileURL:textDocument.fileURL];
    
    [self.tableView reloadData];
    
    // TODO restore
    
//    NSUInteger row = 0;
//    
//    DebugLog(@"Looking for %@", [textDocument.fileURL lastPathComponent]);
//    for (TDTextDocumentRepresentation *representation in self.representations) {
//        DebugLog(@"URL: %@", [representation.url lastPathComponent]);
//        if ([textDocument.fileURL isEqual:representation.url]) {
//            DebugLog(@"Match!");
//            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
//            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
//            DebugLog(@"Refreshing row: %i", row);
//            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
//            cell.textLabel.text = textDocument.preview;
//            break;
//        }
//        row++;
//    }
}

@end
