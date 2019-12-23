#pragma once

#include "TKITexture.h"
#include "TKIUIState.h"
#include "TKNuklearConfig.h"

namespace tk {

struct UIStateViewport {
    uint32_t x = 0, y = 0, width = 0, height = 0;
};

class UIStatePopulator {
public:
    virtual bool populate(const tk::IUIState *state,
                          const tk::ITexture &texture,
                          const UIStateViewport &viewport,
                          nk_context *nk);
};

} // namespace tk
