//
//  TDEditorViewController.h
//  TextDocument
//
//  Created by Brennan Stehling on 3/15/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TDTextDocument;

@protocol TDEditorDelegate;

@interface TDEditorViewController : UIViewController

@property (assign, nonatomic) id<TDEditorDelegate>delegate;

- (void)changeTextDocument:(TDTextDocument *)textDocument;

@end

@protocol TDEditorDelegate <NSObject>

- (void)textEditor:(TDEditorViewController *)textEditor didCloseTextDocument:(TDTextDocument *)textDocument;

@end