//
//  TDDocumentsViewController.m
//  TextDocument
//
//  Created by Brennan Stehling on 2/4/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "TDDocumentsViewController.h"

#import "TDTextDocument.h"

@interface TDDocumentsViewController ()

@property (strong, nonatomic) NSArray *representations;

@end

@implementation TDDocumentsViewController

#pragma mark - View Lifecycle
#pragma mark -

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
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(textDocumentPreviewDidChangeNotification:)
                                                 name: kTextDocumentStateDidChangeNotification
                                               object: nil];
    
    self.representations = [TDTextDocumentRepresentation loadTextDocuments];
    DebugLog(@"self.representations.count: %i", self.representations.count);
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kTextDocumentStateDidChangeNotification
                                                  object:nil];
}

#pragma mark - Private
#pragma mark -

- (void)refresh {
    DebugLog(@"refresh");
    NSArray *reps = [TDTextDocumentRepresentation loadTextDocuments];
    if ([reps isEqualToArray:self.representations]) {
        self.representations = reps;
        [self.tableView reloadData];
    }
}

#pragma mark - Notifications
#pragma mark -

- (void)textDocumentPreviewDidChangeNotification:(NSNotification *)notification {
    DebugLog(@"Reloading table due to updated preview");
    [self refresh];
}

#pragma mark - User Actions
#pragma mark -

- (IBAction)reloadButtonTapped:(id)sender {
    [self refresh];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
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

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        
        NSAssert(self.representations.count > indexPath.row, @"Invalid State");
        
        DebugLog(@"Deleting %i", indexPath.row);
//        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        
        TDTextDocumentRepresentation *representation = [self.representations objectAtIndex:indexPath.row];
        NSMutableArray *reps = [self.representations mutableCopy];
        [reps removeObjectAtIndex:indexPath.row];
        self.representations = (NSArray *)reps;
        [self.tableView reloadData];
        TDTextDocument *textDocument = [[TDTextDocument alloc] initWithFileURL:representation.url];
        [TDTextDocument deleteTextDocument:textDocument];
    }
}

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
