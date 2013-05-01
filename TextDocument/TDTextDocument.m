//
//  TDTextDocument.m
//  TextDocument
//
//  Created by Brennan Stehling on 2/4/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "TDTextDocument.h"

#import "TDCloudManager.h"

#define kText               @"text"
#define kPreview            @"preview"

#pragma mark - Class Extension
#pragma mark -

@interface TDTextDocument ()

@property (strong, nonatomic) NSFileWrapper *fileWrapper;
@property (strong, nonatomic) NSMutableDictionary *dictionary;

@end

@implementation TDTextDocument

#pragma mark - Properties
#pragma mark -

- (void)setText:(NSString *)text {
    if (![text isEqualToString:_text]) {
        _text = text;
        
        // hold onto the text as a properties and place in file wrapper so it goes to disk
        
        NSFileWrapper *existingFileWrapper = [[_fileWrapper fileWrappers] valueForKey:kText];
        if (existingFileWrapper != nil) {
            [_fileWrapper removeFileWrapper:existingFileWrapper];
        }
        
        NSData *data = [_text dataUsingEncoding:NSUTF8StringEncoding];
        NSFileWrapper *newFileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:data];
        newFileWrapper.preferredFilename = kText;
        [_fileWrapper addFileWrapper:newFileWrapper];
    }
}

- (NSString *)preview {
    NSString *preview = @"";
    
    if (_text.length > 30) {
        preview = [_text substringToIndex:30];
    }
    else {
        preview = [_text copy];
    }
    
    // strip newline characters
    preview = [[preview componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];

    if (preview == nil || [@"" isEqualToString:preview]) {
        preview = @"Empty Document";
    }

    return preview;
}

#pragma mark - Public Implementation
#pragma mark -

+ (TDTextDocument *)createTextDocument {
    NSURL *documentsDirectoryURL = [[TDCloudManager sharedInstance] documentsDirectoryURL];
    
    NSString *filename = [NSString stringWithFormat:@"%@.textDocument", [[NSUUID UUID] UUIDString]];
    NSURL *fileURL = [documentsDirectoryURL URLByAppendingPathComponent:filename];
    TDTextDocument *document = [[TDTextDocument alloc] initWithFileURL:fileURL];
    
    [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kTextDocumentStateDidChangeNotification
                                                            object:nil];
    }];
    
    return document;
}

+ (void)deleteTextDocument:(TDTextDocument *)textDocument {
    NSURL *previewFileURL = [TDTextDocument previewFileURLForFileURL:textDocument.fileURL];
    
    NSError *fileCoordinatorError = nil;
    
    DebugLog(@"Deleting file: %@", textDocument.fileURL);
    
    // delete text document
    [[[NSFileCoordinator alloc] initWithFilePresenter:nil] coordinateWritingItemAtURL:textDocument.fileURL options:NSFileCoordinatorWritingForDeleting error:&fileCoordinatorError byAccessor:^(NSURL *newURL) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] removeItemAtURL:newURL error:&error]) {
            DebugLog(@"Error: %@", error);
        }
        
        DebugLog(@"Deleted document");
        [[NSNotificationCenter defaultCenter] postNotificationName:kTextDocumentStateDidChangeNotification
                                                            object:nil];
    }];

    if (fileCoordinatorError != nil) {
        DebugLog(@"Error: %@", fileCoordinatorError);
        fileCoordinatorError = nil;
    }
    
    // delete preview document
    [[[NSFileCoordinator alloc] initWithFilePresenter:nil] coordinateWritingItemAtURL:previewFileURL options:NSFileCoordinatorWritingForDeleting error:&fileCoordinatorError byAccessor:^(NSURL *newURL) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] removeItemAtURL:newURL error:&error]) {
            DebugLog(@"Error: %@", error);
        }
        
        // delete preview document
    }];

    
    if (fileCoordinatorError != nil) {
        DebugLog(@"Error: %@", fileCoordinatorError);
        fileCoordinatorError = nil;
    }
}

+ (NSURL *)previewFileURLForFileURL:(NSURL *)fileURL {
    // don't store the preview in the ubiquitous directory
    
    NSString *cacheDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSURL *cacheURL = [NSURL fileURLWithPath:cacheDirectory isDirectory:YES];
    NSURL *previewsURL = [cacheURL URLByAppendingPathComponent:@"Previews"];
    
    // ensure Previews directory exists
    BOOL isDirectory = TRUE;
    if (![[NSFileManager defaultManager] fileExistsAtPath:previewsURL.path isDirectory:&isDirectory]) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:previewsURL.path withIntermediateDirectories:TRUE attributes:nil error:&error]) {
            DebugLog(@"Error: %@", error);
        }
    }
    
    NSString *filename = [NSString stringWithFormat:@"%@.%@", [fileURL lastPathComponent], kPreview];
    DebugLog(@"filename: %@", filename);
    return [previewsURL URLByAppendingPathComponent:filename];
}

- (BOOL)isEmptyTextDocument {
    return (self.text == nil || [@"" isEqualToString:self.text]);
}

#pragma mark - Basic Reading and Writing
#pragma mark -

- (void)setupEmptyDocument {
    _dictionary = [NSMutableDictionary dictionary];
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_dictionary];
    NSFileWrapper *dictFile = [[NSFileWrapper alloc] initRegularFileWithContents:data];
    dictFile.preferredFilename = @"dictionary";
    _fileWrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{@"dictionary" : dictFile}];
}

#pragma mark - UIDocument Support
#pragma mark -

- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError {
    DebugLog(@"%@ (%@)", NSStringFromSelector(_cmd), [self.fileURL lastPathComponent]);
    
    // WARNING: Contents may not be downloaded yet
    // http://stackoverflow.com/questions/10743517/exc-bad-access-using-icloud-on-multiple-devices
    
    NSNumber *isInCloud = nil;
    
    if ([self.fileURL getResourceValue:&isInCloud forKey:NSURLIsUbiquitousItemKey error:nil]) {
        DebugLog(@"isInCloud: %@", [isInCloud boolValue] ? @"YES" : @"NO");
        if ([isInCloud boolValue]) {
            NSNumber *isDownloaded = nil;
            if ([self.fileURL getResourceValue:&isDownloaded forKey:NSURLUbiquitousItemIsDownloadedKey error:nil]) {
                DebugLog(@"isDownloaded: %@", [isDownloaded boolValue] ? @"YES" : @"NO");
                if (![isDownloaded boolValue]) {
                    // TODO start the download
                }
            }
        }
    }
    
    if (contents) {
        _fileWrapper = contents;
        
        NSFileWrapper *dictionaryFileWrapper = [[_fileWrapper fileWrappers] valueForKey:@"dictionary"];
        DebugLog(@"dictionaryFileWrapper: %@", dictionaryFileWrapper);
        if (dictionaryFileWrapper) {
            NSData *data = [dictionaryFileWrapper regularFileContents];
            if (data) {
                _dictionary = [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
            }
        }
        if (!_dictionary) {
            _dictionary = [NSMutableDictionary dictionary];
        }
        
        // load the text file
        NSFileWrapper *textFileWrapper = [[_fileWrapper fileWrappers] valueForKey:kText];
        if (textFileWrapper) {
            NSData *fileData = [textFileWrapper regularFileContents];
            self.text = fileData && [fileData length] > 0 ? [NSString stringWithUTF8String:[fileData bytes]] : @"";
        }
        else {
            self.text = @"";
        }
    }
    else {
        [self setupEmptyDocument];
    }
    
    if ([_delegate respondsToSelector:@selector(textDocumentContentsUpdated:)]) {
        [_delegate textDocumentContentsUpdated:self];
    }
    
    return YES;
}

- (id)contentsForType:(NSString *)typeName error:(NSError **)outError {
    DebugLog(@"%@", NSStringFromSelector(_cmd));
    if (!_fileWrapper) {
        [self setupEmptyDocument];
    }
    
    return [[NSFileWrapper alloc] initDirectoryWithFileWrappers:_fileWrapper.fileWrappers];
}

- (BOOL)writeContents:(id)contents andAttributes:(NSDictionary *)additionalFileAttributes safelyToURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)saveOperation error:(NSError *__autoreleasing *)outError {
    DebugLog(@"%@ (%@)", NSStringFromSelector(_cmd), [url lastPathComponent]);
    // If the superclass succeeds in writing out the document, we can write our preview out here as well.
    // This method is invoked on a background queue inside a file coordination block, so writing is safe.
    
//    DebugLog(@"Writing: %@", [self.fileURL lastPathComponent]);
//    DebugLog(@"Text: %@", self.text);
//    DebugLog(@"Preview: %@", self.preview);
    
    BOOL success = [super writeContents:contents andAttributes:additionalFileAttributes safelyToURL:url forSaveOperation:saveOperation error:outError];
    
    if (!success) {
        DebugLog(@"Error while writing");
    }
    
    return success;
}

@end
