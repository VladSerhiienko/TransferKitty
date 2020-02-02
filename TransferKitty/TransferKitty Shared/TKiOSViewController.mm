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

@interface TKiOSViewController () <TKAppInputDelegate, TKAttachmentContextDelegate>
@end

struct Tap {
    int state;
    CGPoint location;
    CGPoint velocity;
};

@implementation TKiOSViewController {
    TKApp *_app;
    TKAttachmentContext *_attachmentContext;
    TKiOSView *_view;
    apemode::platform::AppInput appInput;
    Tap _tap;
    Tap _pan;
}

- (void)prepareViewAndApp {
    // DLOGF(@"%s", TK_FUNC_NAME);

    DCHECK(!_view && !_app);
    if (_view && _app) {
        // DLOGF(@"%s: already prepared.", TK_FUNC_NAME);
        return;
    }

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

    _tap.state = 0;
    _pan.state = 0;

    UITapGestureRecognizer *tapGestureRecognizer =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    UIPanGestureRecognizer *panGestureRecognizer =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [[self view] addGestureRecognizer:tapGestureRecognizer];
    [[self view] addGestureRecognizer:panGestureRecognizer];
}

- (void)prepareViewControllerWithAttachmentContext:(nonnull TKAttachmentContext *)attachmentContext {
    // DLOGF(@"%s", TK_FUNC_NAME);

    _attachmentContext = attachmentContext;
    [self prepareViewAndApp];

    DCHECK(_app);
    [_app startPeripheralWithAttachmentContext:attachmentContext];
}

- (void)prepareViewController {
    // DLOGF(@"%s", TK_FUNC_NAME);

    _attachmentContext = nil;
    [self prepareViewAndApp];

    DCHECK(_app);
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
            _tap.state = 1;
            _tap.location = [tapGestureRecognizer locationInView:self.view];
            _tap.location = [self getLocation:_tap.location];

            // NSLog(@"handleTap: [%i %i]\n", (int)tap.location.x, (int)tap.location.y);
            NSLog(@"handleTap: adjusted [%i %i]\n", (int)_tap.location.x, (int)_tap.location.y);
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

        _pan.location = translation;
        _pan.velocity = velocity;

        if (panGestureRecognizer.state == UIGestureRecognizerStateBegan) {
            _pan.state = 1;
            NSLog(@"handlePan: UIGestureRecognizerStateBegan\n");
        } else if (panGestureRecognizer.state == UIGestureRecognizerStateEnded) {
            _pan.state = 3;
            NSLog(@"handlePan: UIGestureRecognizerStateEnded\n");
        } else {
            _pan.state = 2;
            NSLog(@"handlePan: [%f %f]\n", translation.x, translation.y);
        }
    }
}

- (void)app:(nonnull TKApp *)app input:(nonnull TKAppInput *)input {
    nk_context *contextPtr = (nk_context *)input.opaqueImplementationPtr;
    if (!contextPtr) { return; }

    if (_tap.state == 1) {
        _tap.state = 2;
        const float mx = _tap.location.x;
        const float my = _tap.location.y;

        auto &mouse = contextPtr->input.mouse;
        mouse.pos.x = mx;
        mouse.pos.y = my;
        mouse.prev.x = mx;
        mouse.prev.y = my;
        mouse.delta.x = 0;
        mouse.delta.y = 0;

        nk_input_button(contextPtr, NK_BUTTON_LEFT, mx, my, 1);
        // NSLog(@"nk_input_button: 1, NK_BUTTON_LEFT, [%i %i]", (int)mx, (int)my);

    } else if (_tap.state == 2) {
        _tap.state = 0;
        const float mx = _tap.location.x;
        const float my = _tap.location.y;

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

    if (abs(_pan.velocity.x) > 0.001 || abs(_pan.velocity.y) > 0.001) {
        struct nk_vec2 scroll;
        scroll.x = _pan.velocity.x / 3000.0f;
        scroll.y = _pan.velocity.y / 3000.0f;
        nk_input_scroll(contextPtr, scroll);

        _pan.velocity.x /= 1.25;
        _pan.velocity.y /= 1.25;

        if (abs(_pan.velocity.x) < 0.001) { _pan.velocity.x = 0; }
        if (abs(_pan.velocity.y) < 0.001) { _pan.velocity.y = 0; }
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
