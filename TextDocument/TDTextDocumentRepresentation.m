//
//  TDTextDocumentRepresentation.m
//  TextDocument
//
//  Created by Brennan Stehling on 2/4/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "TDTextDocumentRepresentation.h"

#import "TDTextDocument.h"
#import "TDCloudManager.h"

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

@end
