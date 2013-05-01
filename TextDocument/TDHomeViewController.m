//
//  TDHomeViewController.m
//  TextDocument
//
//  Created by Brennan Stehling on 2/4/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "TDHomeViewController.h"

#import "TDCloudManager.h"
#import "TDDocumentsViewController.h"
#import "TDTextDocumentRepresentation.h"
#import "TDTextDocument.h"

@interface TDHomeViewController () <TDTextDocumentDelegate, UITextViewDelegate>

- (IBAction)newButtonTapped:(id)sender;
- (IBAction)documentsButtonTapped:(id)sender;

@property (strong, nonatomic) TDTextDocument *currentTextDocument;

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UIView *keyboardView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *keyboardViewHeightConstraint;

@end

@implementation TDHomeViewController

#pragma mark - View Lifecycle
#pragma mark -

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    // clear out the text from the Storyboard
    self.textView.text = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    CGFloat textViewHeight = CGRectGetHeight(self.view.frame) - self.keyboardViewHeightConstraint.constant;
    
    // set the height for the keyboard
    self.textViewHeightConstraint.constant = textViewHeight;
    
//    if (self.currentTextDocument == nil) {
//        [[TDCloudManager sharedInstance] loadTextDocumentsWithCompletionBlock:^(NSArray *representations, NSError *error) {
//            if (representations.count > 0) {
//                DebugLog(@"Opening first document");
//                TDTextDocumentRepresentation *representation = [representations objectAtIndex:0];
//                [self openRepresentation:representation];
//            }
//            else {
//                self.textView.userInteractionEnabled = NO;
//                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"No Documents"
//                                                                    message:@"Please tap New to create a new document."
//                                                                   delegate:nil
//                                                          cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
//                                                          otherButtonTitles:nil];
//                [alertView show];
//            }
//        }];
//    }
//    
//    [self.textView becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // TODO if the contents of the text view and document are empty then delete the document
    if (self.currentTextDocument != nil && !self.currentTextDocument.documentState == UIDocumentStateClosed) {
        [self closeDocumentWithCompletionHandler:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
//    if ([@"HomeToDocuments" isEqualToString:segue.identifier]) {
//        NSAssert([segue.destinationViewController isKindOfClass:[TDDocumentsViewController class]], @"Invalid State");
//        TDDocumentsViewController *documentsViewController = (TDDocumentsViewController *)segue.destinationViewController;
//        documentsViewController.delegate = self;
//    }
}

#pragma mark - Private
#pragma mark -

- (void)openRepresentation:(TDTextDocumentRepresentation *)representation {
    self.textView.text = nil;
    DebugLog(@"Opening %@", [[representation.url lastPathComponent] stringByDeletingPathExtension]);
    TDTextDocument *textDocument = [[TDTextDocument alloc] initWithFileURL:representation.url];
    [self openTextDocument:textDocument];
}

- (void)openTextDocument:(TDTextDocument *)textDocument {
    self.currentTextDocument = textDocument;
    [textDocument openWithCompletionHandler:^(BOOL success) {
        if (success) {
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentStateChangedNotification:) name:UIDocumentStateChangedNotification object:textDocument];
            
            DebugLog(@"Set text: %@", [[self.currentTextDocument.text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "]);
            
            self.textView.text = self.currentTextDocument.text;
            self.textView.userInteractionEnabled = YES;
        }
    }];
}

- (void)createNewDocument {
    DebugLog(@"Creating empty document");
    TDTextDocument *textDocument = [TDTextDocument createTextDocument];
    textDocument.text = @"";
    self.currentTextDocument = textDocument;
    self.textView.text = textDocument.text;
    self.textView.userInteractionEnabled = YES;
    [self.textView becomeFirstResponder];
}

- (void)closeDocumentWithCompletionHandler:(void (^)())completionHandler {
    DebugLog(@"closeDocumentWithCompletionHandler");
    self.textView.userInteractionEnabled = NO;
    if (self.currentTextDocument == nil && completionHandler != nil) {
        completionHandler();
    }
    else {
        [self.currentTextDocument closeWithCompletionHandler:^(BOOL success) {
            if (success) {
                if (self.currentTextDocument != nil && [self.currentTextDocument isEmptyTextDocument]) {
                    [TDTextDocument deleteTextDocument:self.currentTextDocument];
                }

                self.textView.text = nil;
                self.currentTextDocument = nil;
            }
            else {
                DebugLog(@"Error: Failed to close document successfully");
            }
            
            if (completionHandler != nil) {
                completionHandler();
            }
        }];
    }
}

- (void)documentStateChangedNotification:(NSNotification *)notification {
    UIDocumentState state = self.currentTextDocument.documentState;
    
    if (state & UIDocumentStateEditingDisabled) {
        DebugLog(@"Document Editing is Disabled");
        self.textView.userInteractionEnabled = NO;
    }
    else {
        DebugLog(@"Document Editing is Enabled");
        self.textView.userInteractionEnabled = YES;
    }
    
    if (state & UIDocumentStateInConflict) {
        DebugLog(@"Document State is Conflicted");
    }
}

#pragma mark - User Actions
#pragma mark -

- (IBAction)newButtonTapped:(id)sender {
    if (self.currentTextDocument != nil && !self.currentTextDocument.documentState == UIDocumentStateClosed) {
        [self closeDocumentWithCompletionHandler:^{
            [self createNewDocument];
        }];
    }
    else {
        [self createNewDocument];
    }
}

- (IBAction)documentsButtonTapped:(id)sender {
    [self closeDocumentWithCompletionHandler:^{
        [self performSegueWithIdentifier:@"HomeToDocuments" sender:self];
    }];
}

#pragma mark - UITextViewDelegate
#pragma mark -

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView {
    return self.currentTextDocument != nil;
}

- (void)textViewDidChange:(UITextView *)textView {
    if (self.currentTextDocument != nil) {
        self.currentTextDocument.text = self.textView.text;
        [self.currentTextDocument updateChangeCount:UIDocumentChangeDone];
    }
}

//#pragma mark - TDDocumentsViewControllerDelegate
//#pragma mark -
//
//- (void)textDocumentsViewController:(TDDocumentsViewController *)documentsViewController didChangeTextDocument:(TDTextDocumentRepresentation *)representation {
//    DebugLog(@"didChangeTextDocument: %@", [[representation.url lastPathComponent] stringByDeletingPathExtension]);
//    
//    [self openRepresentation:representation];
//}

#pragma mark - TDTextDocumentDelegate
#pragma mark -

- (void)textDocumentContentsUpdated:(TDTextDocument *)textDocument {
    if ([self.currentTextDocument isEqual:textDocument]) {
        self.textView.text = textDocument.text;
    }
    else {
        DebugLog(@"The updated text document is not the current document.");
    }
}

@end
