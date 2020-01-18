#import "TKApp.h"

#import "TKBluetoothCommunicator.h"
#import "TKNuklearMetalViewDelegate.h"

#include "AppInput.h"
#include "TKBlurHash.h"
#include "TKDefaultUIState.h"
#include "TKNuklearMetalTexture.h"
#include "TKOptional.h"
#include "TKUIStatePopulator.h"

using tk::setBit;
using tk::isBitSet;
using tk::unsetBit;

@implementation TKAppInput
- (void)setOpaqueImplementationPtr:(void *_Nonnull)opaqueImplementationPtr {
    _opaqueImplementationPtr = opaqueImplementationPtr;
}
@end

@interface TKApp () <TKNuklearFrameDelegate, TKBluetoothCommunicatorDelegate>
@end

@implementation TKApp {
    MTKView *_view;
    TKNuklearMetalViewDelegate *_viewDelegate;
    TKNuklearRenderer *_renderer;
    TKBluetoothCommunicator *_bt;
    NSArray *_btSharedItems;
    TKAppInput *_input;
    tk::UIStatePopulator populator;
    tk::NuklearMetalTexture iconImgTexture;
    tk::NuklearMetalTexture hashedImgTexture;
    tk::DefaultUIState defaultState;
}

- (void)dealloc {
}

- (nullable instancetype)initWithMetalKitView:(nonnull MTKView *)view {
    self = [super init];
    if (!self) { return nil; }

    _view = view;
    _viewDelegate = [[TKNuklearMetalViewDelegate alloc] initWithMetalKitView:_view];
    [_viewDelegate mtkView:_view drawableSizeWillChange:_view.drawableSize];

    _renderer = _viewDelegate.renderer;
    _view.delegate = _viewDelegate;
    _viewDelegate.delegate = self;

    _input = [[TKAppInput alloc] init];

    [self testBlurHash];

    // TODO: This will help avoiding reallocations and bugs with multithreading.
    //       But since we want to support even more devices potentially, must be fixed.
    defaultState._devices.reserve(512);
    defaultState._devices.emplace_back();

    return self;
}

- (void)testBlurHash {
#if !TARGET_OS_IOS
    NSImage *objcIconImg = [NSApp applicationIconImage];
#else
    UIImage *objcIconImg = [UIImage
        imageNamed:[[NSBundle mainBundle].infoDictionary[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"]
                       firstObject]];
#endif

    tk::utilities::ImageBuffer iconImg = tk::utilities::exposeToImageBuffer(objcIconImg);

    tk::blurhash::BlurHash hash = tk::blurhash::BlurHashCodec().encode(8, 8, iconImg);
    NSLog(@"hash = %s\n", (const char *)hash.buffer);

    tk::utilities::ImageBuffer hashedImg = tk::blurhash::BlurHashCodec().decode(hash, 32, 32);
    NSLog(@"img = %s, %zu, %zu\n", (const char *)hashedImg.buffer.data(), hashedImg.width, hashedImg.height);

    id<MTLTexture> iconTexture = [_renderer createTextureWithImage:&iconImg];
    id<MTLTexture> hashedTexture = [_renderer createTextureWithImage:&hashedImg];

    iconImgTexture.setPlatformTexture(tk::boxPlatformObject(_renderer), tk::boxPlatformObject(iconTexture));
    hashedImgTexture.setPlatformTexture(tk::boxPlatformObject(_renderer), tk::boxPlatformObject(hashedTexture));
}

- (void)resetThisDevice {
    defaultState._devices.resize(1);
    auto &thisDevice = defaultState._devices.front();
    thisDevice._name = [[_bt getName] cStringUsingEncoding:NSUTF8StringEncoding];
    thisDevice._model = [[_bt getModel] cStringUsingEncoding:NSUTF8StringEncoding];
    thisDevice._friendlyModel = [[_bt getFriendlyModel] cStringUsingEncoding:NSUTF8StringEncoding];
    thisDevice._uuidString =
        [[NSStringUtilities uuidStringOrEmptyString:[_bt getUUID]] cStringUsingEncoding:NSUTF8StringEncoding];
}

- (void)startPeripheralWith:(nonnull NSArray *)sharedItems {
    _btSharedItems = sharedItems;
    _bt = [TKBluetoothCommunicator instance];
    [_bt initPeripheralWithDelegate:self];
    [self resetThisDevice];
}

- (void)startCentral {
    _bt = [TKBluetoothCommunicator instance];
    _btSharedItems = nil;
    [_bt initCentralWithDelegate:self];
    [self resetThisDevice];
}

//
// TKNuklearFrameDelegate
//

- (void)handleInput:(nonnull TKNuklearFrame *)frame {
    nk_input_begin(frame.contextPtr);
    [_input setOpaqueImplementationPtr:frame.contextPtr];
    [_inputDelegate app:self input:_input];
    nk_input_end(frame.contextPtr);
}

- (void)renderer:(nonnull TKNuklearRenderer *)renderer shouldUpdateFrame:(nonnull TKNuklearFrame *)frame {
    [self handleInput:frame];

    uint32_t debugOffsetX = 0;
    uint32_t debugOffsetY = 50;

    CGRect viewport = [frame viewport];
    tk::UIStateViewport bounds = {debugOffsetX,
                                  debugOffsetY,
                                  static_cast<uint32_t>(viewport.size.width - (debugOffsetX << 1)),
                                  static_cast<uint32_t>(viewport.size.height - (debugOffsetY << 1))};

    populator.populate(&defaultState, hashedImgTexture, bounds, frame.contextPtr);
}

//
// TKBluetoothCommunicatorDelegate
//

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
          didChangeStatusFrom:(TKBluetoothCommunicatorStatusBits)statusBits
                           to:(TKBluetoothCommunicatorStatusBits)currentStatusBits {
    DLOGF(@"%s: %@ > %@",
          TK_FUNC_NAME,
          [NSStringUtilities toDebugString:statusBits],
          [NSStringUtilities toDebugString:currentStatusBits]);

    if (isBitSet(currentStatusBits, TKBluetoothCommunicatorStatusBitCentral)) {
        DLOGF(@"%s: Starting discovering", TK_FUNC_NAME);
        [bluetoothCommunicator startDiscoveringDevices];
    } else if (isBitSet(currentStatusBits, TKBluetoothCommunicatorStatusBitPeripheral) &&
               !isBitSet(currentStatusBits, TKBluetoothCommunicatorStatusBitPublishedService) &&
               !isBitSet(currentStatusBits, TKBluetoothCommunicatorStatusBitPublishingService)) {
        DLOGF(@"%s: Starting publishing", TK_FUNC_NAME);
        [bluetoothCommunicator publishServices];
    } else if (isBitSet(currentStatusBits, TKBluetoothCommunicatorStatusBitPeripheral) &&
               !isBitSet(currentStatusBits, TKBluetoothCommunicatorStatusBitPublishingService) &&
               isBitSet(currentStatusBits, TKBluetoothCommunicatorStatusBitPublishedService)) {
        DLOGF(@"%s: Starting advertising", TK_FUNC_NAME);
        [bluetoothCommunicator startAdvertising];
    }
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
           didConnectToDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF(@"%s", TK_FUNC_NAME);

    defaultState._devices.emplace_back();
    auto &deviceState = defaultState._devices.back();
    deviceState._name = [[device getName] cStringUsingEncoding:NSUTF8StringEncoding];
    deviceState._model = [[device getModel] cStringUsingEncoding:NSUTF8StringEncoding];
    deviceState._friendlyModel = [[device getFriendlyModel] cStringUsingEncoding:NSUTF8StringEncoding];
    deviceState._uuidString =
        [[NSStringUtilities uuidStringOrEmptyString:[device getUUID]] cStringUsingEncoding:NSUTF8StringEncoding];
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
          didDisconnectDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF(@"%s", TK_FUNC_NAME);

    std::string uuidString =
        [[NSStringUtilities uuidStringOrEmptyString:[device getUUID]] cStringUsingEncoding:NSUTF8StringEncoding];

    auto deviceStateIt = std::find_if(
        defaultState._devices.begin() + 1, defaultState._devices.end(), [&uuidString](const tk::IUIDeviceState &state) {
            return strcmp(state.name().data, uuidString.c_str()) == 0;
        });

    if (deviceStateIt != defaultState._devices.end()) { defaultState._devices.erase(deviceStateIt); }
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator didLog:(NSString *)log {
    defaultState._debugLogs.push_back(std::string([log cStringUsingEncoding:NSUTF8StringEncoding]));
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
              didReceiveValue:(NSData *)value
                      orError:(NSError *)error
                   fromDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF(@"%s", TK_FUNC_NAME);
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
         didSubscribeToDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF(@"%s", TK_FUNC_NAME);
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
              didUpdateDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF(@"%s", TK_FUNC_NAME);

    std::string uuidString =
        [[NSStringUtilities uuidStringOrEmptyString:[device getUUID]] cStringUsingEncoding:NSUTF8StringEncoding];
    auto deviceStateIt = std::find_if(
        defaultState._devices.begin() + 1, defaultState._devices.end(), [&uuidString](const tk::IUIDeviceState &state) {
            return strcmp(state.name().data, uuidString.c_str()) == 0;
        });

    if (deviceStateIt != defaultState._devices.end()) {
        deviceStateIt->_name = [[device getName] cStringUsingEncoding:NSUTF8StringEncoding];
        deviceStateIt->_model = [[device getModel] cStringUsingEncoding:NSUTF8StringEncoding];
        deviceStateIt->_friendlyModel = [[device getFriendlyModel] cStringUsingEncoding:NSUTF8StringEncoding];
        deviceStateIt->_uuidString =
            [[NSStringUtilities uuidStringOrEmptyString:[device getUUID]] cStringUsingEncoding:NSUTF8StringEncoding];
    }
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
         didWriteValueOrError:(NSError *)error
                     toDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF(@"%s", TK_FUNC_NAME);
}

@end
