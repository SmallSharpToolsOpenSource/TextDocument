//
//  TDTextDocumentRepresentation.h
//  TextDocument
//
//  Created by Brennan Stehling on 2/4/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TDTextDocumentRepresentation : NSObject

@property (nonatomic, readonly) NSString* fileName;
@property (nonatomic, readonly) NSURL* url;
@property (nonatomic, retain) NSURL* previewURL;

- (id)initWithFileName:(NSString*)fileName url:(NSURL*)url;

+ (NSArray *)loadTextDocuments;

@end
