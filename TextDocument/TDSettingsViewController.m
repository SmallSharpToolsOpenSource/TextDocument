//
//  TDSettingsViewController.m
//  TextDocument
//
//  Created by Brennan Stehling on 2/12/13.
//  Copyright (c) 2013 SmallSharpTools LLC. All rights reserved.
//

#import "TDSettingsViewController.h"

#import "TDCloudManager.h"

#define kIndexLocal         0
#define kIndexiCloud        1

@interface TDSettingsViewController ()

@property (weak, nonatomic) IBOutlet UISegmentedControl *cloudSegmentedControl;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@end

@implementation TDSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.statusLabel.text = @"";
}

- (void)viewWillAppear:(BOOL)animated {
    BOOL isCloudEnabled = [[TDCloudManager sharedInstance] isCloudEnabled];
    self.cloudSegmentedControl.selectedSegmentIndex = isCloudEnabled ? kIndexiCloud : kIndexLocal;
}

- (IBAction)cloudValueChanged:(id)sender {
    DebugLog(@"index: %i", self.cloudSegmentedControl.selectedSegmentIndex);
    DebugLog(@"kIndexLocal: %i", kIndexLocal);
    DebugLog(@"kIndexiCloud: %i", kIndexiCloud);
    
    if (self.cloudSegmentedControl.selectedSegmentIndex == kIndexLocal) {
        DebugLog(@"Local");
        [[TDCloudManager sharedInstance] setIsCloudEnabled:FALSE];
    }
    else if (self.cloudSegmentedControl.selectedSegmentIndex == kIndexiCloud) {
        DebugLog(@"iCloud");
        [[TDCloudManager sharedInstance] setIsCloudEnabled:TRUE];
    }
}

@end
