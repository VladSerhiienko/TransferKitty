//
//  ShareViewController.m
//  TransferKitty ShareExtension macOS
//
//  Created by Vladyslav Serhiienko on 11/2/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import "TKViewController.h"

@implementation TKViewController
- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [self prepareViewController];
}

- (NSString *)nibName {
    return @"Main";
}
@end

@implementation TKView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    return self;
}
@end
