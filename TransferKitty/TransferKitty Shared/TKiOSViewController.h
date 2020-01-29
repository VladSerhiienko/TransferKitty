//
//  TKViewController.h
//  TransferKitty iOS
//
//  Created by Vlad Serhiienko on 10/14/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#pragma once
#import <MetalKit/MetalKit.h>
#import <UIKit/UIKit.h>

@interface TKiOSViewController : UIViewController
- (void)prepareViewController;
@end

@interface TKiOSView : MTKView
- (void)setViewController:(TKiOSViewController*)viewController;
@end
