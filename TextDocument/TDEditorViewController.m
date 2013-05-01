//
//  TDEditorViewController.m
//  TextDocument
//
//  Created by Brennan Stehling on 3/15/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "TDEditorViewController.h"

//#import <Cocoa/Cocoa.h>

//#import <objc/message.h>

#import "TDTextDocumentRepresentation.h"
#import "TDTextDocument.h"

@interface TDEditorViewController () <TDTextDocumentDelegate, UITextViewDelegate>

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIButton *undoButton;
@property (weak, nonatomic) IBOutlet UIButton *redoButton;
@property (weak, nonatomic) IBOutlet UIView *keyboardView;

@property (strong, nonatomic) TDTextDocument *currentTextDocument;
@property (strong, nonatomic) NSUndoManager *undoManager;

@end

@implementation TDEditorViewController

@synthesize undoManager = _undoManager;

#pragma mark - View Lifecycle
#pragma mark -

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    // clear out the text from the Storyboard
    self.textView.text = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    NSAssert(self.delegate != nil, @"Delegate must be defined");
    NSAssert(self.currentTextDocument != nil, @"Current text document must be defined");
    
    // set the height for the keyboard
    [self.textView becomeFirstResponder];
    
//    if (self.navigationController.navigationItem.leftBarButtonItem != nil) {
//        DebugLog(@"Setting action for back button to backButtonTapped:");
//        [self.navigationController.navigationItem.leftBarButtonItem setAction:@selector(backButtonTapped:)];
//    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self spelunkView:self.navigationController.view withLevel:1];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // TODO if the contents of the text view and document are empty then delete the document
    if (self.currentTextDocument != nil && !self.currentTextDocument.documentState == UIDocumentStateClosed) {
        [self closeDocument:self.currentTextDocument withCompletionHandler:nil];
    }
}

#pragma mark - Public
#pragma mark -

- (void)changeTextDocument:(TDTextDocument *)textDocument {
    NSAssert(textDocument != nil, @"Text document must be defined");
    if ([self.currentTextDocument isEqual:textDocument]) {
        // do nothing
        return;
    }
    
    if (self.currentTextDocument != nil && !self.currentTextDocument.documentState == UIDocumentStateClosed) {
        TDTextDocument *textDocumentToClose = self.currentTextDocument;
        self.currentTextDocument = nil;
        [self closeDocument:textDocumentToClose withCompletionHandler:^{
            [self openTextDocument:textDocument];
        }];
    }
    else {
        [self openTextDocument:textDocument];
    }
}

#pragma mark - Private
#pragma mark -

- (void)openTextDocument:(TDTextDocument *)textDocument {
    DebugLog(@"%@", NSStringFromSelector(_cmd));
    
    NSAssert([self respondsToSelector:@selector(setUndoManager:)], @"Property must be set");
    
    NSUndoManager *undoManager = [[NSUndoManager alloc] init];
    [self setUndoManager:undoManager];
    [self.undoManager setLevelsOfUndo:50];
    [self updateButtons];
    
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

- (void)closeDocument:(TDTextDocument *)textDocument withCompletionHandler:(void (^)())completionHandler {
    DebugLog(@"%@", NSStringFromSelector(_cmd));
    
    [self.currentTextDocument updateChangeCount:UIDocumentChangeDone];
    [self.undoManager removeAllActions];
    
    if (self.currentTextDocument.documentState == UIDocumentStateClosed) {
        // already closed
        return;
    }
    
    self.textView.userInteractionEnabled = NO;
    if (self.currentTextDocument == nil && completionHandler != nil) {
        completionHandler();
    }
    else {
        [textDocument closeWithCompletionHandler:^(BOOL success) {
            if (success) {
                if (textDocument != nil && [textDocument isEmptyTextDocument]) {
                    [TDTextDocument deleteTextDocument:textDocument];
                }
                
                self.textView.text = nil;
            }
            else {
                DebugLog(@"Error: Failed to close document successfully");
            }
            
            if ([self.delegate respondsToSelector:@selector(textEditor:didCloseTextDocument:)]) {
                [self.delegate textEditor:self didCloseTextDocument:textDocument];
            }
            
            if (completionHandler != nil) {
                completionHandler();
            }
        }];
    }
}

- (void)changeText:(NSString *)text {
    DebugLog(@"%@ (%@)", NSStringFromSelector(_cmd), text);
//    self.textView.text = text;
//    self.currentTextDocument.text = text;
    
    NSString *currentText = self.currentTextDocument.text;
    
//    if ([self.undoManager isUndoing]) {
//        DebugLog(@"Undoing");
//    }
//    if ([self.undoManager isRedoing]) {
//        DebugLog(@"Redoing");
//    }
    
    if (currentText != text) {
//        DebugLog(@"registering to undo: %@", text);
//        DebugLog(@"registering undo action");
        [self.undoManager registerUndoWithTarget:self selector:@selector(changeText:) object:currentText];
        self.currentTextDocument.text = text;
        if (self.textView.text != text) {
            self.textView.text = text;
        }
//            [self.currentTextDocument updateChangeCount:UIDocumentChangeDone];
        
        [self updateButtons];
    }
}

- (void)updateButtons {
    self.undoButton.enabled = self.undoManager.canUndo;
    self.redoButton.enabled = self.undoManager.canRedo;
}

//- (void)logUndoManager {
//    id v1, v2;
//    object_getInstanceVariable(self.undoManager, "_undoStack", &v1);
//    object_getInstanceVariable(self.undoManager, "_redoStack", &v2);
//    
//    DebugLog(@"undo: %i: %@", [v1 count], v1);
//    DebugLog(@"redo: %i: %@", [v2 count], v2);
//}

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

- (void)spelunkView:(UIView *)aView withLevel:(int)level {
	for (UIView *subview in [aView subviews]) {
        CGRect frame = subview.frame;
        DebugLog(@"%i) %@,%i : %f,%f %f,%f", level, [subview class], subview.tag,
                 frame.origin.x, frame.origin.y,
                 frame.size.width, frame.size.height);
        
        if ([subview respondsToSelector:@selector(text)]) {
            NSString *text = (NSString *)[subview performSelector:@selector(text)];
            DebugLog(@"text: %@", text);
        }
        
        if ([subview respondsToSelector:@selector(font)]) {
            UIFont *font = (UIFont *)[subview performSelector:@selector(font)];
            DebugLog(@"font: %@", font);
        }
        
        [self spelunkView:subview withLevel:level+1];
	}
}

- (void)spelunkViewController:(UIViewController *)aVC withLevel:(int)level {
    if (level == 0){
        DebugLog(@"Spelunking a view controller");
    }
    
    if (aVC == nil) {
        return;
    }
    
    if (self.tabBarController.moreNavigationController == aVC) {
        DebugLog(@"### More Navigation Controller ###");
    }
    
    if ([aVC isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tc = (UITabBarController *)aVC;
        DebugLog(@"%i: UITabBarController: (%i)", level, tc.viewControllers.count);
        for (UIViewController *vc in tc.viewControllers) {
            [self spelunkViewController:vc withLevel:level+1];
        }
    }
    else if ([aVC isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nc = (UINavigationController *)aVC;
        DebugLog(@"%i: UINavigationController: (%i)", level, nc.viewControllers.count);
        for (UIViewController *vc in nc.viewControllers) {
            [self spelunkViewController:vc withLevel:level+1];
        }
    }
    else {
        DebugLog(@"%i: %@ (%@)", level, aVC, [aVC class]);
    }
}

#pragma mark - User Actions
#pragma mark -

- (IBAction)backButtonTapped:(id)sender {
    DebugLog(@"%@", NSStringFromSelector(_cmd));
    [self closeDocument:self.currentTextDocument withCompletionHandler:nil];
}

- (IBAction)undoButtonTapped:(id)sender {
    DebugLog(@"%@", NSStringFromSelector(_cmd));
    
    DebugLog(@"can undo: %@", self.undoManager.canUndo ? @"YES" : @"NO");
    
    [self.undoManager undo];
    [self updateButtons];
}

- (IBAction)redoButtonTapped:(id)sender {
    DebugLog(@"%@", NSStringFromSelector(_cmd));
    
    DebugLog(@"can redo: %@", self.undoManager.canRedo ? @"YES" : @"NO");
    
    [self.undoManager redo];
    [self updateButtons];
}

//- (IBAction)newButtonTapped:(id)sender {
//    
//    if (self.currentTextDocument != nil && !self.currentTextDocument.documentState == UIDocumentStateClosed) {
//        [self closeDocumentWithCompletionHandler:^{
//            [self createNewDocument];
//        }];
//    }
//    else {
//        [self createNewDocument];
//    }
//}
//
//- (IBAction)documentsButtonTapped:(id)sender {
//    [self closeDocumentWithCompletionHandler:^{
//        [self performSegueWithIdentifier:@"HomeToDocuments" sender:self];
//    }];
//}

#pragma mark - UITextViewDelegate
#pragma mark -

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView {
    return self.currentTextDocument != nil;
}

- (void)textViewDidChange:(UITextView *)textView {
    DebugLog(@"%@", NSStringFromSelector(_cmd));
    
    if (self.currentTextDocument != nil) {
        [self changeText:textView.text];
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
