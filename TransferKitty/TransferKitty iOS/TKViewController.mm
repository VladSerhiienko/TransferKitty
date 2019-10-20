//
//  TKViewController.mm
//  TransferKitty iOS
//
//  Created by Vlad Serhiienko on 10/14/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import "TKViewController.h"
#import "TKNuklearMetalViewDelegate.h"

#include "AppInput.h"

struct Tap {
    int state;
    CGPoint location;
    CGPoint velocity;
};

@interface TKViewController ( ) < TKNuklearFrameDelegate > {
    apemode::platform::AppInput appInput;
    float scrollDampingFactor;
    bool didReceiveMouseDrag;
    Tap tap;
    Tap pan;
}
@end

@implementation TKViewController {
    MTKView *_view;
    TKNuklearMetalViewDelegate *_renderer;
    NSArray* _buttonNames;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _view = (MTKView *)self.view;
    _view.device = MTLCreateSystemDefaultDevice();
    _view.backgroundColor = UIColor.blackColor;

    if(!_view.device) {
        NSLog(@"Metal is not supported on this device");
        self.view = [[UIView alloc] initWithFrame:self.view.frame];
        return;
    }

    _renderer = [[TKNuklearMetalViewDelegate alloc] initWithMetalKitView:_view];
    [_renderer mtkView:_view drawableSizeWillChange:_view.drawableSize];

    _view.delegate = _renderer;
    _renderer.delegate = self;
    
    NSMutableArray* arr = [[NSMutableArray alloc] initWithCapacity:128];
    for (int i = 0; i < 128; ++i)
        [arr addObject:[NSString stringWithFormat:@"button[%i]", i]];
    _buttonNames = arr;
    
    tap.state = 0;
    pan.state = 0;
    
    UITapGestureRecognizer* tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    UIPanGestureRecognizer* panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [[self view] addGestureRecognizer:tapGestureRecognizer];
    [[self view] addGestureRecognizer:panGestureRecognizer];
}

-(CGPoint)getLocation:(CGPoint)cursorPoint {
    CGRect bounds = [[self view] bounds];
    CGSize backingSize = _view.drawableSize;

    CGPoint relativePoint = cursorPoint;
    relativePoint.x /= bounds.size.width;
    relativePoint.y /= bounds.size.height;
    // relativePoint.y = 1.0f - relativePoint.y;

    CGPoint adjustedPoint = relativePoint;
    adjustedPoint.x *= backingSize.width;
    adjustedPoint.y *= backingSize.height;
    return adjustedPoint;
}

-(void)handleTap:(id)sender {
    if (UITapGestureRecognizer* tapGestureRecognizer = sender) {
        if (tapGestureRecognizer.state == UIGestureRecognizerStateEnded) {
            tap.state = 1;
            tap.location = [tapGestureRecognizer locationInView:self.view];
            tap.location = [self getLocation:tap.location];

            // NSLog(@"handleTap: [%i %i]\n", (int)tap.location.x, (int)tap.location.y);
            NSLog(@"handleTap: adjusted [%i %i]\n", (int)tap.location.x, (int)tap.location.y);
        }
    }
}

-(void)handlePan:(id)sender {
    if (UIPanGestureRecognizer* panGestureRecognizer = sender) {
        CGPoint transition = [panGestureRecognizer translationInView:self.view];
        CGPoint velocity = [panGestureRecognizer velocityInView:self.view];

        pan.location = transition;
        pan.velocity = velocity;
        
        if (panGestureRecognizer.state == UIGestureRecognizerStateBegan) {
            pan.state = 1;
            NSLog(@"handlePan: UIGestureRecognizerStateBegan\n");
            NSLog(@"handlePan: [%f %f]\n", transition.x, transition.y);
        } else if (panGestureRecognizer.state == UIGestureRecognizerStateEnded) {
            pan.state = 3;
            NSLog(@"handlePan: [%f %f]\n", transition.x, transition.y);
            NSLog(@"handlePan: UIGestureRecognizerStateEnded\n");
        } else {
            pan.state = 2;
            NSLog(@"handlePan: [%f %f]\n", transition.x, transition.y);
        }
    }
}

-(int)handleInput:(const apemode::platform::AppInput *)inputState context:(struct nk_context*)contextPtr {
    if (!inputState || !contextPtr) {
        return 0;
    }
    
    nk_input_begin(contextPtr);

    // const float mx = inputState->GetAnalogInput(apemode::platform::kAnalogInput_MouseX);
    // const float my = inputState->GetAnalogInput(apemode::platform::kAnalogInput_MouseY);

    if (tap.state == 1) {
        tap.state = 2;
        const float mx = tap.location.x;
        const float my = tap.location.y;
        
        auto& mouse = contextPtr->input.mouse;
        mouse.pos.x = mx;
        mouse.pos.y = my;
        mouse.prev.x = mx;
        mouse.prev.y = my;
        mouse.delta.x = 0;
        mouse.delta.y = 0;
        
        nk_input_button(contextPtr, NK_BUTTON_LEFT, mx, my, 1);
        // NSLog(@"nk_input_button: 1, NK_BUTTON_LEFT, [%i %i]", (int)mx, (int)my);

    } else if (tap.state == 2) {
        tap.state = 0;
        const float mx = tap.location.x;
        const float my = tap.location.y;
        
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
    
//    if (didReceiveMouseDrag) {
//        didReceiveMouseDrag = false;
//
//        nk_input_motion(contextPtr, mx, my);
//        // NSLog(@"nk_input_motion: [%i %i]", (int)mx, (int)my);
//    }
//
//    struct nk_vec2 scroll;
//    scroll.x = inputState->GetAnalogInput(apemode::platform::kAnalogInput_MouseHorzScroll);
//    scroll.y = inputState->GetAnalogInput(apemode::platform::kAnalogInput_MouseVertScroll);
//    nk_input_scroll(contextPtr, scroll);

    if (pan.state == 1 || pan.state == 2 || pan.state == 3) {
        
        // auto& mouse = contextPtr->input.mouse;
        // mouse.scroll_delta.x = pan.location.x / 1000.0f;
        // mouse.scroll_delta.y = pan.location.y / 1000.0f;
        struct nk_vec2 scroll;
        scroll.x = pan.velocity.x / 3000.0f;
        scroll.y = pan.velocity.y / 3000.0f;
        nk_input_scroll(contextPtr, scroll);
        
        pan.state = 4;
        // nk_input_scroll(contextPtr, scroll);
    }

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
    
    CGRect viewport = [currentFrame viewport];
    if (nk_begin(ctx, "Demo (macOS)", nk_rect(5, 55, viewport.size.width - 10, viewport.size.height - 55 - 5),
        NK_WINDOW_BORDER|NK_WINDOW_MOVABLE|NK_WINDOW_TITLE)) {

        nk_layout_row_dynamic(ctx, 50, 1);
        
        for (int i = 0; i < 128; ++i) {
            NSString* buttonName = [_buttonNames objectAtIndex:i];
            if (nk_button_label(ctx, [buttonName UTF8String])) {
                NSLog(@"\"%s\" pressed\n", [buttonName UTF8String]);
            }
        }
    }
    
    nk_end(ctx);
    nk_window_set_focus(ctx, "Demo (macOS)");
}

@end
