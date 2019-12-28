//
//  TKViewController.h
//  TransferKitty macOS
//
//  Created by Vlad Serhiienko on 10/14/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

@interface TKMacOSViewController : NSViewController
- (void)prepareViewController;
@end

@interface TKMacOSView : MTKView
- (void)setViewController:(TKMacOSViewController*)viewController;
@end
