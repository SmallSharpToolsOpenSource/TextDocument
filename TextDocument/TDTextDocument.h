//
//  TDTextDocument.h
//  TextDocument
//
//  Created by Brennan Stehling on 2/4/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol TDTextDocumentDelegate;

@interface TDTextDocument : UIDocument

@property (weak, nonatomic) id <TDTextDocumentDelegate> delegate;

@property (readonly) NSDate *createdDate;
@property (readonly) NSDate *modifiedDate;
@property (strong, nonatomic) NSString *text;
@property (readonly) NSString *preview;

+ (TDTextDocument *)createEmptyDocument;

+ (NSURL *)previewFileURLForFileURL:(NSURL *)fileURL;

+ (void)generatePreviewFileForFileURL:(NSURL *)fileURL;

@end

@protocol TDTextDocumentDelegate <NSObject>

- (void)textDocumentContentsUpdated:(TDTextDocument *)textDocument;

@end
