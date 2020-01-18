#include "TKNuklearMetalTexture.h"
#import "TKNuklearMetalViewDelegate.h"

namespace tk {
namespace {
// clang-format off
inline TKNuklearRenderer* getPlatformDevice(BridgedHandle device) { return unboxPlatformObject<TKNuklearRenderer*>(device); }
inline id<MTLTexture> getPlatformTexture(BridgedHandle texture) { return unboxPlatformObject<id<MTLTexture>>(texture); }
// clang-format on
}

MetalTextureBase::MetalTextureBase() noexcept = default;
MetalTextureBase::~MetalTextureBase() { destruct(); }

void MetalTextureBase::release() { destruct(); }

void MetalTextureBase::destruct() {
    if (!device) { return; }

    TKNuklearRenderer *platformDevice = getPlatformDevice(device);
    id<MTLTexture> platformTexture = getPlatformTexture(texture);
    [platformDevice releaseRetainedObject:platformTexture];
    platformTexture = nil;
}

void MetalTextureBase::setPlatformTexture(BridgedHandle boxedDevice, BridgedHandle boxedTexture) {
    if (!boxedDevice) { return; }
    if (!boxedTexture) { return; }

    texture = boxedTexture;

    id<MTLTexture> platformTexture = getPlatformTexture(boxedTexture);
    textureWidth = platformTexture.width;
    textureHeight = platformTexture.height;
}

BridgedHandle MetalTextureBase::opaquePlatformPtr() const { return texture; }
size_t MetalTextureBase::width() const { return textureWidth; }
size_t MetalTextureBase::height() const { return textureHeight; }

template <>
id<MTLTexture> texturePlatformObject<id<MTLTexture>>(const ITexture *texture) {
    BridgedHandle boxed = texture ? texture->opaquePlatformPtr() : nullptr;
    return boxed ? getPlatformTexture(boxed) : nil;
}

template <>
nk_image_t textureImplementationObject(const ITexture *texture) {
    BridgedHandle boxed = texture ? texture->opaqueImlementationPtr() : nullptr;
    if (boxed) { return *(const nk_image_t *)(boxed); }
    return nk_image_t{};
}

NuklearMetalTexture::NuklearMetalTexture() noexcept = default;
NuklearMetalTexture::~NuklearMetalTexture() { destruct(); }
BridgedHandle NuklearMetalTexture::opaqueImlementationPtr() const { return nuklearHandle.get(); }

void NuklearMetalTexture::setPlatformTexture(BridgedHandle boxedDevice, BridgedHandle boxedTexture) {
    MetalTextureBase::setPlatformTexture(boxedDevice, boxedTexture);

    if (!boxedTexture) { return; }
    nuklearHandle.initialize(nk_image_ptr(boxedTexture));
}

void NuklearMetalTexture::destruct() { nuklearHandle.deinitialize(); }

void NuklearMetalTexture::release() {
    MetalTextureBase::release();
    destruct();
}
}
