//
//  ShareViewController.m
//  TransferKitty macOS ShareExtension
//
//  Created by Vladyslav Serhiienko on 11/2/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import "TKViewController.h"
#import "TKNuklearMetalViewDelegate.h"
#include "AppInput.h"

@interface TKViewController ( ) < TKNuklearFrameDelegate > {
    apemode::platform::AppInput appInput;
    float scrollDampingFactor;
    bool didReceiveMouseDrag;
}
@end

@implementation TKViewController {
    MTKView *_view;
    TKNuklearMetalViewDelegate *_renderer;
}

- (NSString *)nibName {
    return @"TKViewController";
}

- (void)loadView {
    [super loadView];

    _view = (MTKView *)self.view;
    _view.device = MTLCreateSystemDefaultDevice();

    if(!_view.device) {
        NSLog(@"Metal is not supported on this device");
        self.view = [[NSView alloc] initWithFrame:self.view.frame];
        return;
    }
    
    _renderer = [[TKNuklearMetalViewDelegate alloc] initWithMetalKitView:_view];
    [_renderer mtkView:_view drawableSizeWillChange:_view.drawableSize];

    _view.delegate = _renderer;
    _renderer.delegate = self;

    didReceiveMouseDrag = false;
    scrollDampingFactor = 0.1f;
    
    [[_view window] makeFirstResponder:self];
    
    // Insert code here to customize the view
    NSExtensionItem *item = self.extensionContext.inputItems.firstObject;
    NSLog(@"Attachments = %@", item.attachments);
}

- (void)renderer:(nonnull TKNuklearRenderer *)renderer currentFrame:(nonnull TKNuklearFrame *)currentFrame {
    struct nk_context* ctx = currentFrame.contextPtr;
    if (nk_begin(ctx, "Demo (macOS)", nk_rect(50, 100, 500, 800),
        NK_WINDOW_BORDER|NK_WINDOW_MOVABLE|NK_WINDOW_SCALABLE|
        NK_WINDOW_CLOSABLE|NK_WINDOW_MINIMIZABLE|NK_WINDOW_TITLE)) {

        nk_layout_row_dynamic(ctx, 50, 1);
        
        for (int i = 0; i < 128; ++i) {
            if (nk_button_label(ctx, [[NSString stringWithFormat:@"button[%i]", i] UTF8String])) {
                NSLog(@"\"%s\" pressed\n", [[NSString stringWithFormat:@"button[%i]", i] UTF8String]);
            }
        }
    }
    
    nk_end(ctx);
}

@end

