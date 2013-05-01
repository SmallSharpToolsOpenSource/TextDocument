//
//  TDCloudManager.m
//  TextDocument
//
//  Created by Brennan Stehling on 2/12/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "TDCloudManager.h"

#import <Security/Security.h>

#import "TDTextDocument.h"
#import "TDTextDocumentRepresentation.h"

NSString *const TDICloudPreference = @"com.smallsharptools.ICloudPreference";

NSString *const TDCloudStateUpdatedNotification = @"ICloudStateUpdatedNotification";
NSString *const TDUbiquitousContainerFetchingWillBeginNotification = @"UbiquitousContainerFetchingWillBeginNotification";
NSString *const TDUbiquitousContainerFetchingDidEndNotification = @"UbiquitousContainerFetchingDidEndNotification";

NSString *const TDTextDocumentPreviewStateDidChangeNotification = @"DocumentPreviewStateDidChangeNotification";

#pragma mark -  Class Extension
#pragma mark -

@interface TDCloudManager ()

@property (strong, nonatomic) NSMetadataQuery *query;

// observers are retained by the system
@property (assign, nonatomic) id metadataQueryDidFinishGatheringObserver;
@property (assign, nonatomic) id metadataQueryDidUpdateObserver;

@end

@implementation TDCloudManager

SYNTHESIZE_SINGLETON_FOR_CLASS(TDCloudManager);

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.metadataQueryDidFinishGatheringObserver
                                                    name:NSMetadataQueryDidFinishGatheringNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self.metadataQueryDidUpdateObserver
                                                    name:NSMetadataQueryDidUpdateNotification
                                                  object:nil];
}

- (id)init {
    if ((self = [super init])) {
        // restore the user preference for iCloud
        NSString *pref = [[NSUserDefaults standardUserDefaults] objectForKey:TDICloudPreference];
        _isCloudEnabled = [@"YES" isEqualToString:pref];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ubiquityIdentityDidChangeNotification:) name:NSUbiquityIdentityDidChangeNotification object:nil];
        [self updateFileStorageContainerURL:nil];
    }
    
    return self;
}

- (void)setIsCloudEnabled:(BOOL)isCloudEnabled {
    // Asynchronously update our data directory URL and documents directory URL
    // If we're enabling cloud storage, we move any local documents into the cloud container after the URLs are updated.
    
    DebugLog(@"isCloudEnabled: %@", isCloudEnabled ? @"TRUE" : @"FALSE");
    
    if (isCloudEnabled != _isCloudEnabled) {
        _isCloudEnabled = isCloudEnabled;
        
        // store it preference
        [[NSUserDefaults standardUserDefaults] setValue:isCloudEnabled ? @"YES" :@"NO" forKey:TDICloudPreference];
        
        NSURL *oldDataDirectoryURL = [self dataDirectoryURL];
        NSURL *oldDocumentsDirectoryURL = [self documentsDirectoryURL];
        [self updateFileStorageContainerURL:^(void) {
            if (isCloudEnabled) {
                // Now move any existing local documents into iCloud.
                NSArray *localDocuments = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:oldDocumentsDirectoryURL includingPropertiesForKeys:nil options:0 error:nil];
                NSArray *localPreviews = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:oldDataDirectoryURL includingPropertiesForKeys:nil options:0 error:nil];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                    NSFileManager *fileManager = [[NSFileManager alloc] init];
                    NSURL *newDataDirectoryURL = [self dataDirectoryURL];
                    NSURL *newDocumentsDirectoryURL = [self documentsDirectoryURL];
                    
                    DebugLog(@"newDataDirectoryURL: %@", newDataDirectoryURL);
                    DebugLog(@"newDocumentsDirectoryURL: %@", newDocumentsDirectoryURL);
                    
                    DebugLog(@"There are %i local documents to migrate to the cloud.", localDocuments.count);
                    for (NSURL *documentURL in localDocuments) {
                        if ([[documentURL pathExtension] isEqualToString:@"textDocument"]) {
                            NSURL *destinationURL = [newDocumentsDirectoryURL URLByAppendingPathComponent:[documentURL lastPathComponent]];
                            NSError *error = nil;
                            BOOL success = [fileManager setUbiquitous:YES itemAtURL:documentURL destinationURL:destinationURL error:&error];
                            if (!success && error) {
                                DebugLog(@"Error: %@", error);
                                DebugLog(@"documentURL: %@", documentURL);
                                DebugLog(@"destinationURL: %@", destinationURL);
                            }
                        }
                    }
                    
                    for (NSURL *previewURL in localPreviews) {
                        if ([[previewURL pathExtension] isEqualToString:@"preview"]) {
                            NSURL *destinationURL = [newDataDirectoryURL URLByAppendingPathComponent:[previewURL lastPathComponent]];
                            [fileManager setUbiquitous:YES itemAtURL:previewURL destinationURL:destinationURL error:nil];
                        }
                    }
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:TDCloudStateUpdatedNotification object:nil];
                });
            }
            else {
                [[NSNotificationCenter defaultCenter] postNotificationName:TDCloudStateUpdatedNotification object:nil];
            }
        }];
    }
}

- (NSURL*)documentsDirectoryURL {
    return [_dataDirectoryURL URLByAppendingPathComponent:@"Documents"];
}

- (void)updateFileStorageContainerURL:(void (^)(void))completionHandler {
    // Perform the asynchronous update of the data directory and document directory URLs
    
    @synchronized (self) {
        _dataDirectoryURL = nil;
        if (self.isCloudEnabled) {
            [[NSNotificationCenter defaultCenter] postNotificationName:TDUbiquitousContainerFetchingWillBeginNotification object:nil];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                _dataDirectoryURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:[self ubiquityContainerID]];
                DebugLog(@"_dataDirectoryURL: %@", _dataDirectoryURL);
                dispatch_sync(dispatch_get_main_queue(), ^(void) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:TDUbiquitousContainerFetchingDidEndNotification object:nil];
                    
                    if (completionHandler) {
                        completionHandler();
                    }
                });
            });
        }
        else {
            _dataDirectoryURL = [NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES];
        }
    }
}

- (void)ubiquityIdentityDidChangeNotification:(NSNotification*)notification {
    DebugLog(@"%@", NSStringFromSelector(_cmd));
    // Broadcast our own notification for iCloud state changes that other parts of our application can use and know the CloudManager has updated itself for the new state when they receive the notication.
    
    if ([[NSFileManager defaultManager] ubiquityIdentityToken]) {
        if (self.isCloudEnabled) {
            // If we're using iCloud already and we moved to a new token, broadcast a state change for that
            [[NSNotificationCenter defaultCenter] postNotificationName:TDCloudStateUpdatedNotification object:nil];
        }
    }
    else {
        // If there is no tken now, set our state to NO, which will broadcast a state change if we were using iCloud
        self.isCloudEnabled = NO;
    }
}

- (void)loadTextDocumentsWithCompletionBlock:(void (^)(NSArray *representations, NSError *error))completionBlock {
    if ([[TDCloudManager sharedInstance] isCloudEnabled]) {
        [self loadCloudTextDocumentsWithCompletionBlock:completionBlock];
    }
    else {
        [self loadLocalTextDocumentsWithCompletionBlock:completionBlock];
    }
}

- (void)loadCloudTextDocumentsWithCompletionBlock:(void (^)(NSArray *representations, NSError *error))completionBlock {
    DebugLog(@"%@", NSStringFromSelector(_cmd));
    
    [_query stopQuery];
    
    if (_query) {
        [_query startQuery];
    }
    else {
        _query = [[NSMetadataQuery alloc] init];
        [_query setSearchScopes:@[NSMetadataQueryUbiquitousDocumentsScope, NSMetadataQueryUbiquitousDataScope]];
        [_query setPredicate:[NSPredicate predicateWithFormat:@"%K LIKE '*.textDocument'", NSMetadataItemFSNameKey]];
        
        void (^fileListReceived)(NSNotification *notification) =  ^void (NSNotification *notification) {
            DebugLog(@"%@", NSStringFromSelector(_cmd));
            
            NSMutableArray *representations = [NSMutableArray array];
            NSArray *results = [_query results];
            
            DebugLog(@"Results: %i", results.count);
            
            for (NSMetadataItem *result in results) {
                NSURL *documentURL = [result valueForAttribute:NSMetadataItemURLKey];
                NSString *documentName = [result valueForAttribute:NSMetadataItemDisplayNameKey];
                
                DebugLog(@"documentURL: %@", [documentURL lastPathComponent]);
                
                if ([[documentURL pathExtension] isEqualToString:@"textDocument"]) {
                    TDTextDocumentRepresentation *representation = [[TDTextDocumentRepresentation alloc] initWithFileName:documentName url:documentURL];
                    representation.previewURL = [TDTextDocument previewFileURLForFileURL:documentURL];
                    [self generatePreviewFileForFileURL:documentURL];
                    [representations addObject:representation];
                }
            }
            
            // sort representations by file modified date
            [representations sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                TDTextDocumentRepresentation *rep1 = (TDTextDocumentRepresentation *)obj1;
                TDTextDocumentRepresentation *rep2 = (TDTextDocumentRepresentation *)obj2;
                
                return [[rep2 fileModificationDate] compare:[rep1 fileModificationDate]];
            }];
            
            completionBlock(representations, nil);
        };
        self.metadataQueryDidFinishGatheringObserver = [[NSNotificationCenter defaultCenter]
                                                        addObserverForName:NSMetadataQueryDidFinishGatheringNotification
                                                        object:_query
                                                        queue:[NSOperationQueue mainQueue]
                                                        usingBlock:fileListReceived];
        self.metadataQueryDidUpdateObserver = [[NSNotificationCenter defaultCenter]
                                               addObserverForName:NSMetadataQueryDidUpdateNotification
                                               object:_query
                                               queue:[NSOperationQueue mainQueue]
                                               usingBlock:fileListReceived];
        
        NSAssert([NSThread isMainThread], @"Must be main thread");
        dispatch_async(dispatch_get_main_queue(), ^{
            [_query startQuery];
            DebugLog(@"Gathering meta data with query");
        });
    }
}

- (void)loadLocalTextDocumentsWithCompletionBlock:(void (^)(NSArray *representations, NSError *error))completionBlock {
    DebugLog(@"%@", NSStringFromSelector(_cmd));
    
    NSMutableArray *representations = [NSMutableArray array];
    
    // iterate over documents and load them into the array
    NSURL *documentsDirectoryURL = [[TDCloudManager sharedInstance] documentsDirectoryURL];
    NSArray *localDocuments = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:documentsDirectoryURL includingPropertiesForKeys:nil options:0 error:nil];
    for (NSURL *documentURL in localDocuments) {
        if ([documentURL.pathExtension isEqualToString:@"textDocument"]) {
            TDTextDocumentRepresentation *representation = [[TDTextDocumentRepresentation alloc] initWithFileName:[[documentURL lastPathComponent] stringByDeletingPathExtension] url:documentURL];
            representation.previewURL = [TDTextDocument previewFileURLForFileURL:documentURL];
            [self generatePreviewFileForFileURL:documentURL];
            [representations addObject:representation];
        }
    }
    
    // sort representations by file modified date
    [representations sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        TDTextDocumentRepresentation *rep1 = (TDTextDocumentRepresentation *)obj1;
        TDTextDocumentRepresentation *rep2 = (TDTextDocumentRepresentation *)obj2;
        
        return [[rep2 fileModificationDate] compare:[rep1 fileModificationDate]];
    }];
    
    completionBlock(representations, nil);
}

- (void)generatePreviewFileForFileURL:(NSURL *)fileURL {
    DebugLog(@"%@", NSStringFromSelector(_cmd));
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
        TDTextDocument *textDocument = [[TDTextDocument alloc] initWithFileURL:fileURL];
        [textDocument openWithCompletionHandler:^(BOOL success) {
            if (success) {
                NSString *preview = [textDocument.preview copy];
                [textDocument closeWithCompletionHandler:nil];
                NSURL *previewFileURL = [TDTextDocument previewFileURLForFileURL:fileURL];
//                BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[previewFileURL path]];
//                
//                // check if the preview file is current with the source file
//                NSDate *fileDate = [self fileModificationDate:fileURL];
//                NSDate *previewDate = [self fileModificationDate:previewFileURL];
//                
//                DebugLog(@"fileDate: %@", fileDate);
//                DebugLog(@"previewDate: %@", previewDate);
                
//                if (!exists || [self isDate:fileDate afterOtherDate:previewDate]) {
                    DebugLog(@"Generating preview: %@ (%@)", preview, previewFileURL);
                    
                    NSAssert(preview && preview.length, @"Invalid State");
                    
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [[[NSFileCoordinator alloc] initWithFilePresenter:nil] coordinateWritingItemAtURL:previewFileURL options:0 error:nil byAccessor:^(NSURL *writingURL) {
                            NSError *error = nil;
                            if (![[preview dataUsingEncoding:NSUTF8StringEncoding] writeToFile:writingURL.path options:NSDataWritingAtomic error:&error]) {
                                DebugLog(@"Error: %@", error);
                            }
                            [[NSNotificationCenter defaultCenter] postNotificationName:TDTextDocumentPreviewStateDidChangeNotification object:nil];
                        }];
                    });
//                }
//                else {
//                    DebugLog(@"Preview is current");
//                }
            }
            
        }];
    }
}

- (NSDate *)fileModificationDate:(NSURL *)url {
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
        // just return the current date if the file does not exist
        return [NSDate date];
    }
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[url path]
                                                                                error:&error];
    if (error != nil) {
        DebugLog(@"Error: %@", error);
        return [NSDate distantPast];
    }
    
    return [attributes fileModificationDate];
}

- (BOOL)isDate:(NSDate *)date afterOtherDate:(NSDate *)otherDate {
	return ([date compare:otherDate] > 0);
}

#pragma mark - Private Methods
#pragma mark -

- (NSString *)ubiquityContainerID {
    // gather the Team ID using Security
    NSDictionary *query = @{(__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrAccount : @"bundleSeedID",
                            (__bridge id)kSecAttrService : @"",
                            (__bridge id)kSecReturnAttributes : (id)kCFBooleanTrue};
    
    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound) {
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    }
    if (status != errSecSuccess) return nil;
    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge id)kSecAttrAccessGroup];
    NSArray *components = [accessGroup componentsSeparatedByString:@"."];
    NSString *bundleSeedID = [[components objectEnumerator] nextObject];
    CFRelease(result);
    
    return [NSString stringWithFormat:@"%@.com.SmallSharpTools.TextDocument", bundleSeedID];
}

@end
