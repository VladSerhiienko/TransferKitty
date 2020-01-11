#include "TKUIStatePopulator.h"

#include <assert.h>
#include <stdarg.h>
#include <stdio.h>

#include <cmath>
#include <string_view>

#include "TKOptional.h"

namespace tk {
namespace {
const char *kButton0 = "Button0";
const char *kButton1 = "Button1";
const char *kButton2 = "Button2";
const char *kButton3 = "Button3";
const char *kButton4 = "Button4";

nk_rect_t calculateImageFittingRect(nk_vec2_t dims_a, nk_vec2_t dims_b) {
    const float asp_a = dims_a.x / dims_a.y;
    const float asp_b = dims_b.x / dims_b.y;

    nk_rect_t rect = {};
    rect.x = 0;
    rect.y = 0;
    rect.w = 1;
    rect.h = 1;

    if (asp_a >= asp_b) {
        const float s = dims_a.y / dims_b.y;
        const float ww_b = dims_b.x * s;
        const float x_px = (dims_a.x - ww_b);
        const float x_rl = x_px / dims_a.x;
        rect.x = x_rl * 0.5f;
        rect.w -= x_rl;
    } else {
        const float s = dims_a.x / dims_b.x;
        const float hh_b = dims_b.y * s;
        const float y_px = (dims_a.y - hh_b);
        const float y_rl = y_px / dims_a.y;
        rect.y = y_rl * 0.5f;
        rect.h -= y_rl;
    }

    return rect;
}
} // namespace

constexpr float gr = 1.61803398874989484820458683436563811772030917980576;
constexpr float b = 1.0f / (gr + 1.0f);
constexpr float a = 1.0f - b;

bool UIStatePopulator::populate(const tk::IUIState *state,
                                const tk::ITexture &texture,
                                const UIStateViewport &viewport,
                                nk_context *nk) {
    constexpr std::string_view windowName = "UIStatePopulator";
    constexpr std::string_view imageGroupName = "GroupImg";
    constexpr std::string_view textGroupName = "GroupText";

    assert(nk && nk->style.font);
    const float fontHeight = nk->style.font->height;
    const float padding = 4;
    const float imageVerticalPadding = 0.05;
    const float itemHeight = fontHeight * 5 + padding * 5.5;
    const float imageWidth = viewport.width * b; // - paddings/margins

    nk_vec2_t spaceSize = {imageWidth, itemHeight};
    nk_vec2_t imageSize = {float(texture.width()), float(texture.height())};
    nk_rect_t imgBounds = calculateImageFittingRect(spaceSize, imageSize);
    nk_rect_t viewportBounds = nk_rect(viewport.x, viewport.y, viewport.width, viewport.height);
    
    imgBounds.h -= imageVerticalPadding;

    if (nk_begin(nk, windowName.data(), viewportBounds, NK_WINDOW_NO_SCROLLBAR)) {
        nk_layout_row_begin(nk, NK_DYNAMIC, itemHeight, 2);

        nk_layout_row_push(nk, b);
        if (nk_group_begin(nk, imageGroupName.data(), NK_WINDOW_NO_SCROLLBAR)) {
            nk_layout_space_begin(nk, NK_DYNAMIC, itemHeight, 1);
            nk_layout_space_push(nk, imgBounds);
            nk_image(nk, textureImplementationObject<nk_image_t>(&texture));
            nk_layout_space_end(nk);
            nk_group_end(nk);
        }

        nk_layout_row_push(nk, a);
        if (nk_group_begin(nk, textGroupName.data(), NK_WINDOW_NO_SCROLLBAR)) {
            nk_layout_row_dynamic(nk, fontHeight, 1);
            if (nk_button_label(nk, kButton0)) { printf("\"%s\" pressed\n", kButton0); }
            if (nk_button_label(nk, kButton1)) { printf("\"%s\" pressed\n", kButton1); }
            if (nk_button_label(nk, kButton2)) { printf("\"%s\" pressed\n", kButton2); }
            // if (nk_button_label(nk, kButton3)) { printf("\"%s\" pressed\n",
            // kButton3); } if (nk_button_label(nk, kButton4)) { printf("\"%s\"
            // pressed\n", kButton4); }

            static size_t currProgress = 0;
            static size_t maxProgress = 1000;

            nk_progress(nk, &currProgress, maxProgress, 1);
            nk_labelf(nk, NK_TEXT_ALIGN_CENTERED, "%zu/%zu", currProgress, maxProgress);

            ++currProgress;
            currProgress %= maxProgress;

            nk_group_end(nk);
        }

        nk_layout_row_end(nk);

        nk_layout_row_dynamic(nk, fontHeight, 1);
        nk_label(nk, "Logs:", NK_TEXT_ALIGN_LEFT);
        for (size_t i = 0; i < state->debugLogCount(); ++i) {
            nk_label(nk, state->debugLog(i).data, NK_TEXT_ALIGN_LEFT);
        }
    }

    nk_window_set_position(nk, windowName.data(), nk_vec2(viewportBounds.x, viewport.y));
    nk_window_set_size(nk, windowName.data(), nk_vec2(viewportBounds.w, viewportBounds.h));
    nk_end(nk);

    return true;
}
} // namespace tk
