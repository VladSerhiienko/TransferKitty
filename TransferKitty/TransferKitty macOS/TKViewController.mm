//
//  GameViewController.m
//  TransferKitty macOS
//
//  Created by Vlad Serhiienko on 10/14/19.
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

-(void)setMouseLocation:(NSEvent *)e {
    NSRect  bounds      = [[self view] bounds];
    CGSize  backingSize = [[self view] convertSizeToBacking:bounds.size];
    NSPoint cursorPoint = [e locationInWindow];

    NSPoint relativePoint = cursorPoint;
    relativePoint.x /= bounds.size.width;
    relativePoint.y /= bounds.size.height;
    relativePoint.y = 1.0f - relativePoint.y;

    NSPoint adjustedPoint = relativePoint;
    adjustedPoint.x *= backingSize.width;
    adjustedPoint.y *= backingSize.height;
    
    // NSLog(@"setMouseLocation: cursorPoint = [%f %f]\n", cursorPoint.x, cursorPoint.y);
    // NSLog(@"setMouseLocation: adjustedPoint = [%f %f]\n", adjustedPoint.x, adjustedPoint.y);

    appInput.Analogs[ apemode::platform::kAnalogInput_MouseX ] = adjustedPoint.x;
    appInput.Analogs[ apemode::platform::kAnalogInput_MouseY ] = adjustedPoint.y;
}

-(void)scrollWheel:(NSEvent *)e {
    appInput.Analogs[ apemode::platform::kAnalogInput_MouseHorzScroll ] = e.deltaX * scrollDampingFactor;
    appInput.Analogs[ apemode::platform::kAnalogInput_MouseVertScroll ] = e.deltaY * scrollDampingFactor;
}

-(void)rightMouseDown:(NSEvent *)e {
    [self setMouseLocation:e];
    appInput.Buttons[ 0 ][ apemode::platform::kDigitalInput_Mouse1 ] = true;
}

-(void)rightMouseUp:(NSEvent *)e {
    [self setMouseLocation:e];
    appInput.Buttons[ 0 ][ apemode::platform::kDigitalInput_Mouse1 ] = false;
}

-(void)rightMouseDragged:(NSEvent *)e {
    [self setMouseLocation:e];
}

-(void)mouseDown:(NSEvent *)e {
    [self setMouseLocation:e];
    appInput.Buttons[ 0 ][ apemode::platform::kDigitalInput_Mouse0 ] = true;
}

-(void)mouseUp:(NSEvent *)e {
    [self setMouseLocation:e];
    appInput.Buttons[ 0 ][ apemode::platform::kDigitalInput_Mouse0 ] = false;
}

-(void)mouseDragged:(NSEvent *)e {
    [self setMouseLocation:e];
    didReceiveMouseDrag = true;
}

- (void)viewDidLoad {
    [super viewDidLoad];

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
}

-(int)handleInput:(const apemode::platform::AppInput *)inputState context:(struct nk_context*)contextPtr {
    if (!inputState || !contextPtr) {
        return 0;
    }
    
    nk_input_begin(contextPtr);

    const float mx = inputState->GetAnalogInput(apemode::platform::kAnalogInput_MouseX);
    const float my = inputState->GetAnalogInput(apemode::platform::kAnalogInput_MouseY);

    if (inputState->IsFirstPressed(apemode::platform::kDigitalInput_Mouse0)) {
        auto& mouse = contextPtr->input.mouse;
        mouse.pos.x = mx;
        mouse.pos.y = my;
        mouse.prev.x = mx;
        mouse.prev.y = my;
        mouse.delta.x = 0;
        mouse.delta.y = 0;
        
        nk_input_button(contextPtr, NK_BUTTON_LEFT, mx, my, 1);
        // NSLog(@"nk_input_button: 1, NK_BUTTON_LEFT, [%i %i]", (int)mx, (int)my);

    } else if (inputState->IsFirstReleased(apemode::platform::kDigitalInput_Mouse0)) {
        auto& mouse = contextPtr->input.mouse;
        mouse.pos.x = mx;
        mouse.pos.y = my;
        mouse.prev.x = mx;
        mouse.prev.y = my;
        mouse.delta.x = 0;
        mouse.delta.y = 0;
        
        nk_input_button(contextPtr, NK_BUTTON_LEFT, mx, my, 0);
        // NSLog(@"nk_input_button: 0, NK_BUTTON_LEFT, [%i %i]", (int)mx, (int)my);
    }
    
    if (didReceiveMouseDrag) {
        didReceiveMouseDrag = false;
        
        nk_input_motion(contextPtr, mx, my);
        // NSLog(@"nk_input_motion: [%i %i]", (int)mx, (int)my);
    }
    
    struct nk_vec2 scroll;
    scroll.x = inputState->GetAnalogInput(apemode::platform::kAnalogInput_MouseHorzScroll);
    scroll.y = inputState->GetAnalogInput(apemode::platform::kAnalogInput_MouseVertScroll);
    nk_input_scroll(contextPtr, scroll);

    nk_input_end(contextPtr);
    return 1;
}

-(void)updateInput {
    memcpy( appInput.Buttons[ 1 ], appInput.Buttons[ 0 ], sizeof( appInput.Buttons[ 0 ] ) );
}

- (void)renderer:(nonnull TKNuklearMetalViewDelegate *)renderer currentFrame:(nonnull TKNuklearFrame *)currentFrame {
    [self handleInput:&appInput context:currentFrame.contextPtr];
    [self updateInput];

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
