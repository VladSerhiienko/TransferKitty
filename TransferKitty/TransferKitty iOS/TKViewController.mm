//
//  TKViewController.mm
//  TransferKitty iOS
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
- (instancetype)initWithFrame:(CGRect)frameRect device:(nullable id<MTLDevice>)device {
    self = [super initWithFrame:frameRect device:device];
    return self;
}
@end
