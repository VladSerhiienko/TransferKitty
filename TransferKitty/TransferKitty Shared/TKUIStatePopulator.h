#pragma once

#include "TKNuklearConfig.h"
#include "TKIUIState.h"

namespace tk {

struct UIStateViewport {
    uint32_t x = 0, y = 0, width = 0, height = 0;
};

class UIStatePopulator {
public:
    virtual bool populate(const tk::IUIState* state,
                          const UIStateViewport& viewport,
                          nk_context* nk);
};

}
