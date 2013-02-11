//
//  TDTextDocument.m
//  TextDocument
//
//  Created by Brennan Stehling on 2/4/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "TDTextDocument.h"

#define kText               @"text"
#define kPreview            @"preview"

#pragma mark - Class Extension
#pragma mark -

@interface TDTextDocument ()

@property (strong, nonatomic) NSFileWrapper *fileWrapper;
@property (strong, nonatomic) NSMutableDictionary *dictionary;

//@property (readonly) NSURL *previewFileURL;

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

//- (NSURL *)previewFileURL {
//    NSURL *tempDirectoryURL = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:@"Previews"];
//    NSString *previewFileName = [[[self.fileURL lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:kPreview];
//    NSURL *previewFileURL = [tempDirectoryURL URLByAppendingPathComponent:previewFileName];
//    
//    DebugLog(@"previewFileURL: %@", previewFileURL);
//    
//    return previewFileURL;
//}

- (NSString *)preview {
    NSString *preview = @"";
    
    if (_text.length > 15) {
        preview = [_text substringToIndex:15];
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

#pragma mark - Creation
#pragma mark -

+ (TDTextDocument *)createEmptyDocument {
    NSURL *dataDirectoryURL = [NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES];
    NSURL *documentsDirectoryURL = [dataDirectoryURL URLByAppendingPathComponent:@"Documents"];
    
    NSString *filename = [NSString stringWithFormat:@"%@.textDocument", [[NSUUID UUID] UUIDString]];
    DebugLog(@"createEmptyDocument: %@", filename);
    NSURL *fileURL = [documentsDirectoryURL URLByAppendingPathComponent:filename];
    TDTextDocument *document = [[TDTextDocument alloc] initWithFileURL:fileURL];
    
    [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:nil];
    
    return document;
}

#pragma mark - Implementation
#pragma mark -

+ (NSURL *)previewFileURLForFileURL:(NSURL *)fileURL {
    NSURL *tempDirectoryURL = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:@"Previews"];
    
    // TODO ensure Previews temp directory exists
    
    BOOL isDirectory = TRUE;
    if (![[NSFileManager defaultManager] fileExistsAtPath:tempDirectoryURL.path isDirectory:&isDirectory]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:tempDirectoryURL.path withIntermediateDirectories:TRUE attributes:nil error:&error];
        if (error != nil) {
            DebugLog(@"Error: %@", error);
        }
    }
    
    NSString *previewFileName = [[[fileURL lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:kPreview];
    NSURL *previewFileURL = [tempDirectoryURL URLByAppendingPathComponent:previewFileName];
    
    DebugLog(@"previewFileURL: %@", previewFileURL);
    
    return previewFileURL;
}

+ (void)generatePreviewFileForFileURL:(NSURL *)fileURL {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
       TDTextDocument *textDocument = [[TDTextDocument alloc] initWithFileURL:fileURL];
       [textDocument openWithCompletionHandler:^(BOOL success) {
           if (success) {
               NSString *preview = textDocument.preview;
               
               NSURL *previewFileURL = [TDTextDocument previewFileURLForFileURL:fileURL];
               DebugLog(@"Preparing to Write Preview '%@' to %@", preview, [previewFileURL lastPathComponent]);
               [[[NSFileCoordinator alloc] initWithFilePresenter:nil] coordinateWritingItemAtURL:previewFileURL options:0 error:nil byAccessor:^(NSURL *writingURL) {
                   DebugLog(@"Writing Preview: %@ to %@", preview, writingURL);
//                   [[preview dataUsingEncoding:NSUTF8StringEncoding] writeToURL:writingURL atomically:YES];
                   
                   NSError *error = nil;
                   [[preview dataUsingEncoding:NSUTF8StringEncoding] writeToFile:writingURL.path options:NSDataWritingAtomic error:&error];
                   if (error != nil) {
                       DebugLog(@"Error: %@", error);
                   }
               }];
               
               [textDocument closeWithCompletionHandler:nil];
           }
       }];
   });
}

#pragma mark - Basic Reading and Writing
#pragma mark -

- (void)setupEmptyDocument {
    _dictionary = [NSMutableDictionary dictionary];
    
    NSFileWrapper *dictFile = [[NSFileWrapper alloc] initRegularFileWithContents:[NSKeyedArchiver archivedDataWithRootObject:_dictionary]];
    dictFile.preferredFilename = @"dictionary";
    _fileWrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{@"dictionary" : dictFile}];
}

#pragma mark - UIDocument Support
#pragma mark -

- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError {
    
    DebugLog(@"Loading %@", [self.fileURL lastPathComponent]);
    
    if (contents) {
        _fileWrapper = contents;
        _dictionary = [[NSKeyedUnarchiver unarchiveObjectWithData:[[[_fileWrapper fileWrappers] valueForKey:@"dictionary"] regularFileContents]] mutableCopy];
        if (!_dictionary) {
            _dictionary = [NSMutableDictionary dictionary];
        }
        
        // load the text file
        NSFileWrapper *textFileWrapper = [[_fileWrapper fileWrappers] valueForKey:kText];
        NSData *fileData = [textFileWrapper regularFileContents];
        self.text = [fileData length] > 0 ? [NSString stringWithUTF8String:[fileData bytes]] : @"";
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
    if (!_fileWrapper) {
        [self setupEmptyDocument];
    }
    
    return [[NSFileWrapper alloc] initDirectoryWithFileWrappers:_fileWrapper.fileWrappers];
}

- (BOOL)writeContents:(id)contents andAttributes:(NSDictionary *)additionalFileAttributes safelyToURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)saveOperation error:(NSError *__autoreleasing *)outError {
    // If the superclass succeeds in writing out the document, we can write our preview out here as well.
    // This method is invoked on a background queue inside a file coordination block, so writing is safe.
    
    NSString *preview = self.preview;
    
    DebugLog(@"Writing: %@", [self.fileURL lastPathComponent]);
    DebugLog(@"Text: %@", self.text);
    DebugLog(@"Preview: %@", preview);
    
    BOOL success = [super writeContents:contents andAttributes:additionalFileAttributes safelyToURL:url forSaveOperation:saveOperation error:outError];

    // save the preview
    if (success) {
        [TDTextDocument generatePreviewFileForFileURL:self.fileURL];
//            [[preview dataUsingEncoding:NSUTF8StringEncoding] writeToURL:previewFileURL atomically:YES];
    }
    else {
        DebugLog(@"Error while writing");
    }
    
    return success;
}

@end
