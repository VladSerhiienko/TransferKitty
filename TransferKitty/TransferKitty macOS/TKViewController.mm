//
//  GameViewController.m
//  TransferKitty macOS
//
//  Created by Vlad Serhiienko on 10/14/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import "TKViewController.h"
#import "TKNuklearMetalViewDelegate.h"
#import "TKBluetoothCommunicator.h"
#import "TKApp.h"

#include "AppInput.h"
#include "TKUIStatePopulator.h"
#include "TKBlurHash.h"

#import <Cocoa/Cocoa.h>

#define kRedChannel     0
#define kGreenChannel   1
#define kBlueChannel    2

@interface TKViewController () <TKAppInputDelegate>
@end

@implementation TKViewController {
    TKApp* _app;
    MTKView *_view;
    apemode::platform::AppInput appInput;
    tk::UIStatePopulator populator;
    float scrollDampingFactor;
    bool didReceiveMouseDrag;
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

-(void)testBlurHash {
    NSImage* image = [NSApp applicationIconImage];
    NSSize imageSize = image.size;
    NSRect imageRect = NSMakeRect(0, 0, imageSize.width, imageSize.height);

    // Create a context to hold the image data

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);

    CGContextRef ctx = CGBitmapContextCreate(NULL,
                                             imageSize.width,
                                             imageSize.height,
                                             8,
                                             0,
                                             colorSpace,
                                             kCGImageAlphaPremultipliedLast);

    // Wrap graphics context

    NSGraphicsContext* gctx = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];

    // Make our bitmap context current and render the NSImage into it

    [NSGraphicsContext setCurrentContext:gctx];
    [image drawInRect:imageRect];
    
    size_t width = CGBitmapContextGetWidth(ctx);
    size_t height = CGBitmapContextGetHeight(ctx);
    uint32_t* pixel = (uint32_t*)CGBitmapContextGetData(ctx);

    std::vector<uint8_t> imageBytes(width * height * 3);
    for (unsigned y = 0; y < height; y++) {
        for (unsigned x = 0; x < width; x++) {
            const uint32_t rgba = *pixel;

            // Extract colour components
            const uint8_t red   = (rgba & 0x000000ff) >> 0;
            const uint8_t green = (rgba & 0x0000ff00) >> 8;
            const uint8_t blue  = (rgba & 0x00ff0000) >> 16;
            
            imageBytes[y * width * 3 + x * 3 + 0] = red;
            imageBytes[y * width * 3 + x * 3 + 1] = green;
            imageBytes[y * width * 3 + x * 3 + 2] = blue;
            pixel++;
        }
    }
    
    tk::BlurHash hash = tk::BlurHashCodec().blurHashForPixels(3, 3, (int)width, (int)height, imageBytes.data(), width * 3);
    NSLog(@"hash = %s\n", (const char*)hash.buffer.data());
    
    tk::BlurHashImage hashedImg = tk::BlurHashCodec().imageForBlurHash(hash, 32, 32);
    NSLog(@"img = %s, %zu, %zu\n", (const char*)hashedImg.buffer.data(), hashedImg.width, hashedImg.height);
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self testBlurHash];

    didReceiveMouseDrag = false;
    scrollDampingFactor = 0.1f;

    _view = (MTKView *)self.view;
    _view.device = MTLCreateSystemDefaultDevice();
    
    _app = [[TKApp alloc] initWithMetalKitView:_view];
    _app.inputDelegate = self;
    
    [[_view window] makeFirstResponder:self];
    [_app startCentral];
}

- (void)app:(nonnull TKApp *)app input:(nonnull TKAppInput *)input {
    nk_context* contextPtr = (nk_context*)input.opaqueImplementationPtr;
    if (!contextPtr) { return; }

    const float mx = appInput.GetAnalogInput(apemode::platform::kAnalogInput_MouseX);
    const float my = appInput.GetAnalogInput(apemode::platform::kAnalogInput_MouseY);

    if (appInput.IsFirstPressed(apemode::platform::kDigitalInput_Mouse0)) {
        auto& mouse = contextPtr->input.mouse;
        mouse.pos.x = mx;
        mouse.pos.y = my;
        mouse.prev.x = mx;
        mouse.prev.y = my;
        mouse.delta.x = 0;
        mouse.delta.y = 0;
        
        nk_input_button(contextPtr, NK_BUTTON_LEFT, mx, my, 1);
        // NSLog(@"nk_input_button: 1, NK_BUTTON_LEFT, [%i %i]", (int)mx, (int)my);

    } else if (appInput.IsFirstReleased(apemode::platform::kDigitalInput_Mouse0)) {
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
    scroll.x = appInput.GetAnalogInput(apemode::platform::kAnalogInput_MouseHorzScroll);
    scroll.y = appInput.GetAnalogInput(apemode::platform::kAnalogInput_MouseVertScroll);
    nk_input_scroll(contextPtr, scroll);

    memcpy( appInput.Buttons[ 1 ], appInput.Buttons[ 0 ], sizeof( appInput.Buttons[ 0 ] ) );
}

@end
