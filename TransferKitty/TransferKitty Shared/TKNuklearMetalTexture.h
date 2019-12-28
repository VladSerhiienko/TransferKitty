#include "TKITexture.h"
#include "TKNuklearConfig.h"
#include "TKOptional.h"

namespace tk {
class MetalTextureBase : public ITexture {
public:
    MetalTextureBase() noexcept;
    ~MetalTextureBase() override;

    virtual void setPlatformTexture(BridgedHandle device, BridgedHandle texture);
    virtual void release();

    BridgedHandle opaquePlatformPtr() const override;
    size_t width() const override;
    size_t height() const override;

protected:
    void destruct();

    BridgedHandle device = nullptr;
    BridgedHandle texture = nullptr;
    size_t textureWidth = 0;
    size_t textureHeight = 0;
};
class NuklearMetalTexture : public MetalTextureBase {
public:
    NuklearMetalTexture() noexcept;
    ~NuklearMetalTexture() override;

    void setPlatformTexture(BridgedHandle device, BridgedHandle texture) override;
    void release() override;

    BridgedHandle opaqueImlementationPtr() const override;

protected:
    void destruct();
    Optional<nk_image_t> nuklearHandle = {};
};
} // namespace tk
