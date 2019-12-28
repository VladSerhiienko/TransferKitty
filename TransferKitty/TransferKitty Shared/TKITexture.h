#pragma once
#include "TKConfig.h"

namespace tk {
class ITexture {
public:
    virtual ~ITexture() = default;
    virtual BridgedHandle opaquePlatformPtr() const = 0;
    virtual BridgedHandle opaqueImlementationPtr() const = 0;
    virtual size_t width() const = 0;
    virtual size_t height() const = 0;
};

template <typename T>
T texturePlatformObject(const ITexture* texture);
template <typename T>
T textureImplementationObject(const ITexture* texture);

} // namespace tk
