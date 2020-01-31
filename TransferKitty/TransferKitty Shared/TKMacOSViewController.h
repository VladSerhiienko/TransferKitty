//
//  TKViewController.h
//  TransferKitty macOS
//
//  Created by Vlad Serhiienko on 10/14/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#pragma once
#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
#import "TKExtensionContextUtils.h"

@interface TKMacOSViewController : NSViewController
- (void)prepareViewController;
- (void)prepareViewControllerWithAttachmentContext:(nonnull TKAttachmentContext *)attachmentContext;
@end

@interface TKMacOSView : MTKView
- (void)setViewController:(nonnull TKMacOSViewController *)viewController;
@end
