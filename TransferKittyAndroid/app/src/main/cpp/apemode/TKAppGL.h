#pragma once
#include "NvAppBase/gl/TKSampleAppGL.h"

namespace apemode {
class TKAppGL : public TKSampleAppGL {
public:
    TKAppGL();
    virtual ~TKAppGL();

    void initRendering() override;
    void shutdownRendering() override;
    void draw() override;
    void reshape(int32_t width, int32_t height) override;
    void configurationCallback(NvGLConfiguration &config) override;

    bool handlePointerInput(NvInputDeviceType::Enum device,
                            NvPointerActionType::Enum action,
                            uint32_t modifiers,
                            int32_t count,
                            NvPointerEvent *points,
                            int64_t timestamp = 0) override;

    bool handleKeyInput(uint32_t code, NvKeyActionType::Enum action) override;
    bool handleCharacterInput(uint8_t c) override;
    bool handleGamepadChanged(uint32_t changedPadFlags) override;
    bool handleGamepadButtonChanged(uint32_t button, bool down) override;
    void setPlatformContext(NvPlatformContext *platform) override;

    void *mNk = nullptr;
};
} // namespace apemode
