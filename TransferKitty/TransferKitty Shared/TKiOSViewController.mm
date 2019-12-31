//
//  TKViewController.mm
//  TransferKitty iOS
//
//  Created by Vlad Serhiienko on 10/14/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import "TKiOSViewController.h"
#import "TKApp.h"
#import "TKBluetoothCommunicator.h"
#import "TKNuklearMetalViewDelegate.h"

#include "AppInput.h"
#include "TKUIStatePopulator.h"

@interface TKiOSViewController () <TKAppInputDelegate>
@end

struct Tap {
    int state;
    CGPoint location;
    CGPoint velocity;
};

@implementation TKiOSViewController {
    TKApp *_app;
    TKiOSView *_view;
    apemode::platform::AppInput appInput;
    Tap tap;
    Tap pan;
}

- (void)prepareViewController {
    // Insert code here to customize the view
    NSExtensionItem *item = self.extensionContext.inputItems.firstObject;
    NSLog(@"Attachments = %@", item.attachments);

    _view = (TKiOSView *)self.view;
    [_view setViewController:self];

    if (!_view.device) { _view.device = MTLCreateSystemDefaultDevice(); }

    if (!_view.device) {
        NSLog(@"Metal is not supported on this device");
        return;
    }

    _view.backgroundColor = UIColor.blackColor;

    _app = [[TKApp alloc] initWithMetalKitView:_view];
    _app.inputDelegate = self;

    tap.state = 0;
    pan.state = 0;

    UITapGestureRecognizer *tapGestureRecognizer =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    UIPanGestureRecognizer *panGestureRecognizer =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [[self view] addGestureRecognizer:tapGestureRecognizer];
    [[self view] addGestureRecognizer:panGestureRecognizer];

    [_app startCentral];
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (CGPoint)getLocation:(CGPoint)cursorPoint {
    CGRect bounds = [[self view] bounds];
    CGSize backingSize = _view.drawableSize;

    CGPoint relativePoint = cursorPoint;
    relativePoint.x /= bounds.size.width;
    relativePoint.y /= bounds.size.height;

    CGPoint adjustedPoint = relativePoint;
    adjustedPoint.x *= backingSize.width;
    adjustedPoint.y *= backingSize.height;
    return adjustedPoint;
}

- (void)handleTap:(id)sender {
    if (UITapGestureRecognizer *tapGestureRecognizer = sender) {
        if (tapGestureRecognizer.state == UIGestureRecognizerStateEnded) {
            tap.state = 1;
            tap.location = [tapGestureRecognizer locationInView:self.view];
            tap.location = [self getLocation:tap.location];

            // NSLog(@"handleTap: [%i %i]\n", (int)tap.location.x, (int)tap.location.y);
            NSLog(@"handleTap: adjusted [%i %i]\n", (int)tap.location.x, (int)tap.location.y);
        }
    }
}

- (void)handlePan:(id)sender {
    if (UIPanGestureRecognizer *panGestureRecognizer = sender) {
        CGPoint translation = [panGestureRecognizer translationInView:self.view];
        CGPoint velocity = [panGestureRecognizer velocityInView:self.view];

        NSLog(@"handlePan: velocity [%f %f]\n", velocity.x, velocity.y);
        NSLog(@"handlePan: translation [%f %f]\n", translation.x, translation.y);
        NSLog(@"handlePan: state %i\n", (int32_t)panGestureRecognizer.state);

        pan.location = translation;
        pan.velocity = velocity;

        if (panGestureRecognizer.state == UIGestureRecognizerStateBegan) {
            pan.state = 1;
            NSLog(@"handlePan: UIGestureRecognizerStateBegan\n");
        } else if (panGestureRecognizer.state == UIGestureRecognizerStateEnded) {
            pan.state = 3;
            NSLog(@"handlePan: UIGestureRecognizerStateEnded\n");
        } else {
            pan.state = 2;
            NSLog(@"handlePan: [%f %f]\n", translation.x, translation.y);
        }
    }
}

- (void)app:(nonnull TKApp *)app input:(nonnull TKAppInput *)input {
    nk_context *contextPtr = (nk_context *)input.opaqueImplementationPtr;
    if (!contextPtr) { return; }

    if (tap.state == 1) {
        tap.state = 2;
        const float mx = tap.location.x;
        const float my = tap.location.y;

        auto &mouse = contextPtr->input.mouse;
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

        auto &mouse = contextPtr->input.mouse;
        mouse.pos.x = mx;
        mouse.pos.y = my;
        mouse.prev.x = mx;
        mouse.prev.y = my;
        mouse.delta.x = 0;
        mouse.delta.y = 0;

        nk_input_button(contextPtr, NK_BUTTON_LEFT, mx, my, 0);
        // NSLog(@"nk_input_button: 0, NK_BUTTON_LEFT, [%i %i]", (int)mx, (int)my);
    }

    if (abs(pan.velocity.x) > 0.001 || abs(pan.velocity.y) > 0.001) {
        struct nk_vec2 scroll;
        scroll.x = pan.velocity.x / 3000.0f;
        scroll.y = pan.velocity.y / 3000.0f;
        nk_input_scroll(contextPtr, scroll);

        pan.velocity.x /= 1.25;
        pan.velocity.y /= 1.25;

        if (abs(pan.velocity.x) < 0.001) { pan.velocity.x = 0; }
        if (abs(pan.velocity.y) < 0.001) { pan.velocity.y = 0; }
    }
}
@end

@implementation TKiOSView {
    TKiOSViewController *_viewController;
}

// clang-format off
- (void)setViewController:(TKiOSViewController *)viewController { _viewController = viewController; }
// clang-format on

- (instancetype)initWithFrame:(CGRect)frameRect device:(nullable id<MTLDevice>)device {
    self = [super initWithFrame:frameRect device:device];
    return self;
}
@end
