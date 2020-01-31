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
#import "TKExtensionContextUtils.h"

@interface TKiOSViewController : UIViewController
- (void)prepareViewController;
- (void)prepareViewControllerWithAttachmentContext:(nonnull TKAttachmentContext *)attachmentContext;
@end

@interface TKiOSView : MTKView
- (void)setViewController:(nonnull TKiOSViewController *)viewController;
@end
