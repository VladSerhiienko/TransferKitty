//
//  TKViewController.h
//  TransferKitty macOS
//
//  Created by Vlad Serhiienko on 10/14/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

@interface TKViewController : NSViewController
@end

@interface TKView : MTKView
- (void)setViewController:(TKViewController*)viewController;
@end
