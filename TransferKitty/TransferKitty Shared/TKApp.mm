#import "TKApp.h"

#import "TKNuklearMetalViewDelegate.h"
#import "TKBluetoothCommunicator.h"

#include "AppInput.h"
#include "TKUIStatePopulator.h"

@implementation TKAppInput
-(void)setOpaqueImplementationPtr:(void * _Nonnull)opaqueImplementationPtr {
    _opaqueImplementationPtr = opaqueImplementationPtr;
}
@end

@interface TKApp ( ) < TKNuklearFrameDelegate, TKBluetoothCommunicatorDelegate>
@end

@implementation TKApp {
    MTKView *_view;
    TKNuklearMetalViewDelegate *_renderer;
    TKBluetoothCommunicator* _bt;
    NSArray* _btSharedItems;
    TKAppInput* _input;
    tk::UIStatePopulator populator;
}

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view {
    _view = view;
    
    _renderer = [[TKNuklearMetalViewDelegate alloc] initWithMetalKitView:_view];
    [_renderer mtkView:_view drawableSizeWillChange:_view.drawableSize];
    
    _view.delegate = _renderer;
    _renderer.delegate = self;
    
    _input = [[TKAppInput alloc] init];
    
    return self;
}

-(void)startPeripheralWith:(nonnull NSArray*)sharedItems {
    _btSharedItems = sharedItems;
    _bt = [TKBluetoothCommunicator instance];
    [_bt initPeripheralWithDelegate:self];
    // [_bt startAdvertising];
}

-(void)startCentral {
    _bt = [TKBluetoothCommunicator instance];
    _btSharedItems = nil;
    [_bt initCentralWithDelegate:self];
    // [_bt startDiscoveringDevices];
}

//
// TKNuklearFrameDelegate
//

-(void)handleInput:(nonnull TKNuklearFrame *)frame {
    nk_input_begin(frame.contextPtr);
   [_input setOpaqueImplementationPtr:frame.contextPtr];
   [_inputDelegate app:self input:_input];
   nk_input_end(frame.contextPtr);
}

-(void)renderer:(nonnull TKNuklearRenderer *)renderer shouldUpdateFrame:(nonnull TKNuklearFrame *)frame {
    [self handleInput:frame];

    CGRect viewport = [frame viewport];
    tk::UIStateViewport bounds = {25, 25,
        static_cast<uint32_t>(viewport.size.width - 50),
        static_cast<uint32_t>(viewport.size.height - 50)};

    populator.populate(nullptr, bounds, frame.contextPtr);
}

//
// TKBluetoothCommunicatorDelegate
//

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
