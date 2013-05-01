//
//  TDTextDocument.h
//  TextDocument
//
//  Created by Brennan Stehling on 2/4/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kTextDocumentStateDidChangeNotification       @"TextDocumentStateDidChangeNotification"

@protocol TDTextDocumentDelegate;

@interface TDTextDocument : UIDocument

@property (weak, nonatomic) id <TDTextDocumentDelegate> delegate;

@property (readonly) NSDate *createdDate;
@property (readonly) NSDate *modifiedDate;
@property (strong, nonatomic) NSString *text;
@property (readonly) NSString *preview;

+ (TDTextDocument *)createTextDocument;

+ (void)deleteTextDocument:(TDTextDocument *)textDocument;

+ (NSURL *)previewFileURLForFileURL:(NSURL *)fileURL;

- (BOOL)isEmptyTextDocument;

@end

@protocol TDTextDocumentDelegate <NSObject>

- (void)textDocumentContentsUpdated:(TDTextDocument *)textDocument;

@end
