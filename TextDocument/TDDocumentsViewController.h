//
//  TDDocumentsViewController.h
//  TextDocument
//
//  Created by Brennan Stehling on 2/4/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "TDTextDocument.h"
#import "TDTextDocumentRepresentation.h"

@protocol TDDocumentsViewControllerDelegate;

@interface TDDocumentsViewController : UITableViewController

@property (weak, nonatomic) id <TDDocumentsViewControllerDelegate> delegate;

@end

@protocol TDDocumentsViewControllerDelegate <NSObject>

- (void)textDocumentsViewController:(TDDocumentsViewController *)documentsViewController didChangeTextDocument:(TDTextDocumentRepresentation *)representation;

@end
