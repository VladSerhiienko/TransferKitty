//
//  ShareViewController.m
//  TransferKitty ShareExtension macOS
//
//  Created by Vladyslav Serhiienko on 11/2/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import "TKViewController.h"
#import "TKNuklearMetalViewDelegate.h"
#import "TKBluetoothCommunicator.h"
#include "AppInput.h"

@interface TKViewController ( ) < TKNuklearFrameDelegate, TKBluetoothCommunicatorDelegate > {
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
    return @"Main";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // TODO: Load resources without touching a view.
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    // Insert code here to customize the view
    NSExtensionItem *item = self.extensionContext.inputItems.firstObject;
    NSLog(@"Attachments = %@", item.attachments);

    _view = (MTKView *)self.view;
    
    if (!_view.device) {
        _view.device = MTLCreateSystemDefaultDevice();
    }

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

//- (IBAction)send:(id)sender {
//    NSExtensionItem *outputItem = [[NSExtensionItem alloc] init];
//    // Complete implementation by setting the appropriate value on the output item
//    
//    NSArray *outputItems = @[outputItem];
//    [self.extensionContext completeRequestReturningItems:outputItems completionHandler:nil];
//}
//
//- (IBAction)cancel:(id)sender {
//    NSError *cancelError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
//    [self.extensionContext cancelRequestWithError:cancelError];
//}

- (void)renderer:(nonnull TKNuklearMetalViewDelegate *)renderer currentFrame:(nonnull TKNuklearFrame *)currentFrame {
    // [self handleInput:&appInput context:currentFrame.contextPtr];
    // [self updateInput];

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

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator didChangeStatus:(TKBluetoothCommunicatorStatusBits)statusBits {
    DLOGF( @"%s", TK_FUNC_NAME );
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator didConnectToDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF( @"%s", TK_FUNC_NAME );
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator didDisconnectDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF( @"%s", TK_FUNC_NAME );
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator didLog:(NSString *)log {
    DLOGF( @"%s", TK_FUNC_NAME );
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator didReceiveValue:(NSData *)value orError:(NSError *)error fromDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF( @"%s", TK_FUNC_NAME );
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator didSubscribeToDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF( @"%s", TK_FUNC_NAME );
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator didUpdateDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF( @"%s", TK_FUNC_NAME );
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator didWriteValueOrError:(NSError *)error toDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF( @"%s", TK_FUNC_NAME );
}

@end

