//
//  TDAppDelegate.m
//  TextDocument
//
//  Created by Brennan Stehling on 2/4/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "TDAppDelegate.h"

#import "TDCloudManager.h"

@implementation TDAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // nil value is returned when iCloud is disabled or the user is logged out
        id ubiquityIdentityToken = [[NSFileManager defaultManager] ubiquityIdentityToken];
        DebugLog(@"ubiquityIdentityToken: %@", ubiquityIdentityToken);
    });
    
    dispatch_async (dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // get the ubiquity container URL
        NSURL *containerURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
        DebugLog(@"containerURL: %@", containerURL);
    });
    
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        NSURL *cloudURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
//        NSAssert(cloudURL != nil, @"Cloud URL must be defined. Ensure entitlements are set properly.");
//        DebugLog(@"Cloud URL: %@", cloudURL);
//    });
    
    return YES;
}

@end
