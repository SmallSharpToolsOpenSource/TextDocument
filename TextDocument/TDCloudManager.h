//
//  TDCloudManager.h
//  TextDocument
//
//  Created by Brennan Stehling on 2/12/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TDConstants.h"
#import "SynthesizeSingleton.h"

extern NSString *const TDICloudPreference;

extern NSString *const TDCloudStateUpdatedNotification;
extern NSString *const TDUbiquitousContainerFetchingWillBeginNotification;
extern NSString *const TDUbiquitousContainerFetchingDidEndNotification;

extern NSString *const TDTextDocumentPreviewStateDidChangeNotification;

@interface TDCloudManager : NSObject

SYNTHESIZE_SINGLETON_FOR_HEADER(TDCloudManager);

@property (nonatomic, assign) BOOL isCloudEnabled;
@property (nonatomic, readonly) NSURL *dataDirectoryURL;
@property (nonatomic, readonly) NSURL *documentsDirectoryURL;

- (void)loadTextDocumentsWithCompletionBlock:(void (^)(NSArray *representations, NSError *error))completionBlock;

- (void)generatePreviewFileForFileURL:(NSURL *)fileURL;

@end