//
//  TDTextDocumentRepresentation.m
//  TextDocument
//
//  Created by Brennan Stehling on 2/4/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "TDTextDocumentRepresentation.h"

#import "TDTextDocument.h"

@implementation TDTextDocumentRepresentation

- (id)initWithFileName:(NSString *)fileName url:(NSURL *)url {
    self = [super init];
    if (self) {
        _fileName = fileName;
        _url = url;
    }
    
    return self;
}

- (BOOL)isEqual:(TDTextDocumentRepresentation*)object {
    return [object isKindOfClass:[TDTextDocumentRepresentation class]] && [_fileName isEqual:object.fileName];
}

- (NSDate *)fileCreationDate {
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self.url path]]) {
        // just return the current date if the file does not exist
        return [NSDate date];
    }
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[self.url path]
                                                                                error:&error];
    if (error != nil) {
        DebugLog(@"Error: %@", error);
        return [NSDate date];
    }
    
    return [attributes fileCreationDate];
}

- (NSDate *)fileModificationDate {
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self.url path]]) {
        // just return the current date if the file does not exist
        return [NSDate date];
    }
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[self.url path]
                                                                                error:&error];
    if (error != nil) {
        DebugLog(@"Error: %@", error);
        return [NSDate date];
    }
    
    return [attributes fileModificationDate];
}

+ (NSArray *)loadTextDocuments {
    DebugLog(@"loadTextDocuments");
    NSMutableArray *representations = [NSMutableArray array];
    
    // iterate over documents and load them into the array
    
    NSURL *dataDirectoryURL = [NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES];
    NSURL *documentsDirectoryURL = [dataDirectoryURL URLByAppendingPathComponent:@"Documents"];
    NSArray *localDocuments = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:documentsDirectoryURL includingPropertiesForKeys:nil options:0 error:nil];
    for (NSURL *documentURL in localDocuments) {
        if ([documentURL.pathExtension isEqualToString:@"textDocument"]) {
            TDTextDocumentRepresentation *representation = [[TDTextDocumentRepresentation alloc] initWithFileName:[[documentURL lastPathComponent] stringByDeletingPathExtension] url:documentURL];
            
            representation.previewURL = [TDTextDocument previewFileURLForFileURL:documentURL];
            
            if (![[NSFileManager defaultManager] fileExistsAtPath:representation.previewURL.path]) {
                [TDTextDocument generatePreviewFileForFileURL:documentURL];
            }
            [representations addObject:representation];
        }
    }
    
    // sort representations by file modified date
    [representations sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        TDTextDocumentRepresentation *rep1 = (TDTextDocumentRepresentation *)obj1;
        TDTextDocumentRepresentation *rep2 = (TDTextDocumentRepresentation *)obj2;
        
        return [[rep2 fileModificationDate] compare:[rep1 fileModificationDate]];
    }];
    
    return representations;
}

@end
