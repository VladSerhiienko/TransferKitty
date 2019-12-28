//
//  GameViewController.m
//  TransferKitty macOS
//
//  Created by Vlad Serhiienko on 10/14/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import "TKViewController.h"

@implementation TKViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    [self prepareViewController];
}
@end

@implementation TKView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    return self;
}
@end
