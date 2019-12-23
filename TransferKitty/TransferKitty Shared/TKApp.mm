#import "TKApp.h"

#import "TKBluetoothCommunicator.h"
#import "TKNuklearMetalViewDelegate.h"

#include "AppInput.h"
#include "TKBlurHash.h"
#include "TKITexture.h"
#include "TKOptional.h"
#include "TKUIStatePopulator.h"

namespace tk {
namespace {
class Texture : public tk::ITexture {
    TKNuklearRenderer *device = nil;
    id<MTLTexture> texture = nil;
    tk::TOptional<nk_image_t> handle = {};

    void destruct() {
        if (!device) {
            return;
        }
        [device releaseRetainedObject:texture];
    }

public:
    Texture() = default;
    ~Texture() {
        destruct();
    }

    void release() {
        destruct();
        texture = nil;
        handle.deinitialize();
    }

    void setPlatformTexture(TKNuklearRenderer *device,
                            id<MTLTexture> platformTexture) {
        if (!device) {
            return;
        }
        if (!platformTexture) {
            return;
        }
        texture = platformTexture;
        handle.initialize(nk_image_ptr((__bridge void *)texture));
    }

    const void *opaquePlatformPtr() const override {
        return texture ? (__bridge void *)texture : nullptr;
    }
    const void *opaqueImlementationPtr() const override {
        return handle.get();
    }
    size_t width() const override {
        return texture ? texture.width : 0;
    }
    size_t height() const override {
        return texture ? texture.height : 0;
    }
};
}

template <>
id<MTLTexture> texturePlatformObject<id<MTLTexture>>(const ITexture *texture) {
    const void *opaquePlatformPtr =
        texture ? texture->opaquePlatformPtr() : nullptr;
    return opaquePlatformPtr ? (__bridge id<MTLTexture>)opaquePlatformPtr : nil;
}

template <>
nk_image_t textureImplementationObject(const ITexture *texture) {
    const void *opaqueImlementationPtr =
        texture ? texture->opaqueImlementationPtr() : nullptr;
    if (opaqueImlementationPtr) {
        return *(nk_image_t *)(opaqueImlementationPtr);
    }
    return nk_image_t{};
}
}

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
    tk::Texture iconImgTexture;
    tk::Texture hashedImgTexture;
}

- (void)dealloc {
}

- (nullable instancetype)initWithMetalKitView:(nonnull MTKView *)view {
    self = [super init];
    if (!self) {
        return nil;
    }

    _view = view;
    _viewDelegate =
        [[TKNuklearMetalViewDelegate alloc] initWithMetalKitView:_view];
    [_viewDelegate mtkView:_view drawableSizeWillChange:_view.drawableSize];

    _renderer = _viewDelegate.renderer;
    _view.delegate = _viewDelegate;
    _viewDelegate.delegate = self;

    _input = [[TKAppInput alloc] init];

    [self testBlurHash];
    return self;
}

- (void)testBlurHash {
    NSImage *objcIconImg = [NSApp applicationIconImage];
    tk::utilities::ImageBuffer iconImg =
        tk::utilities::exposeToImageBuffer(objcIconImg);

    tk::blurhash::BlurHash hash =
        tk::blurhash::BlurHashCodec().encode(8, 8, iconImg);
    NSLog(@"hash = %s\n", (const char *)hash.buffer);

    tk::utilities::ImageBuffer hashedImg =
        tk::blurhash::BlurHashCodec().decode(hash, 32, 32);
    NSLog(@"img = %s, %zu, %zu\n",
          (const char *)hashedImg.buffer.data(),
          hashedImg.width,
          hashedImg.height);

    id<MTLTexture> iconTexture = [_renderer createTextureWithImage:&iconImg];
    id<MTLTexture> hashedTexture =
        [_renderer createTextureWithImage:&hashedImg];

    iconImgTexture.setPlatformTexture(_renderer, iconTexture);
    hashedImgTexture.setPlatformTexture(_renderer, hashedTexture);
}

- (void)startPeripheralWith:(nonnull NSArray *)sharedItems {
    _btSharedItems = sharedItems;
    _bt = [TKBluetoothCommunicator instance];
    [_bt initPeripheralWithDelegate:self];
    // [_bt startAdvertising];
}

- (void)startCentral {
    _bt = [TKBluetoothCommunicator instance];
    _btSharedItems = nil;
    [_bt initCentralWithDelegate:self];
    // [_bt startDiscoveringDevices];
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

- (void)renderer:(nonnull TKNuklearRenderer *)renderer
    shouldUpdateFrame:(nonnull TKNuklearFrame *)frame {
    [self handleInput:frame];

    CGRect viewport = [frame viewport];
    tk::UIStateViewport bounds = {
        25,
        25,
        static_cast<uint32_t>(viewport.size.width - 50),
        static_cast<uint32_t>(viewport.size.height - 50)};

    populator.populate(nullptr, hashedImgTexture, bounds, frame.contextPtr);
}

//
// TKBluetoothCommunicatorDelegate
//

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
          didChangeStatusFrom:(TKBluetoothCommunicatorStatusBits)statusBits
                           to:(TKBluetoothCommunicatorStatusBits)
                                  currentStatusBits {
    DLOGF(@"%s", TK_FUNC_NAME);
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
           didConnectToDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF(@"%s", TK_FUNC_NAME);
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
          didDisconnectDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF(@"%s", TK_FUNC_NAME);
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
                       didLog:(NSString *)log {
    DLOGF(@"%s", TK_FUNC_NAME);
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
}

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
         didWriteValueOrError:(NSError *)error
                     toDevice:(TKBluetoothCommunicatorDevice *)device {
    DLOGF(@"%s", TK_FUNC_NAME);
}

@end
