
#include <stdio.h>
#include <assert.h>
#include <stdarg.h>

#include "TKUIStatePopulator.h"

namespace tk {
namespace {
const char* kButton0 = "Button0";
const char* kButton1 = "Button1";
const char* kButton2 = "Button2";
const char* kButton3 = "Button3";
}

bool UIStatePopulator::populate(const tk::IUIState *state,
                                const UIStateViewport& viewport,
                                nk_context *nk) {
    
    assert(nk && nk->style.font);
    if (nk_begin(nk, "UIStatePopulator", nk_rect(viewport.x, viewport.y, viewport.width,viewport.height),
        NK_WINDOW_BORDER|NK_WINDOW_MOVABLE|NK_WINDOW_SCALABLE|
        NK_WINDOW_CLOSABLE|NK_WINDOW_MINIMIZABLE|NK_WINDOW_TITLE)) {

        nk_layout_row_dynamic(nk, nk->style.font->height, 1);
        
        if (nk_button_label(nk, kButton0)) { printf("\"%s\" pressed\n", kButton0); }
        if (nk_button_label(nk, kButton1)) { printf("\"%s\" pressed\n", kButton1); }
        if (nk_button_label(nk, kButton2)) { printf("\"%s\" pressed\n", kButton2); }
        if (nk_button_label(nk, kButton3)) { printf("\"%s\" pressed\n", kButton3); }
    }
    
    nk_end(nk);
    return true;
}
}
