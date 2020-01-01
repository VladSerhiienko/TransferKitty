#pragma once
#include "TKConfig.h"

namespace tk {
enum Format {
    TK_FORMAT_UNDEFINED = 0,
    TK_FORMAT_R8G8B8A8_UNORM,
    TK_FORMAT_R8G8B8A8_SRGB,
};

constexpr uint32_t formatSize(const Format format) {
    switch (format) {
        case TK_FORMAT_R8G8B8A8_UNORM:
            return 4;
        case TK_FORMAT_R8G8B8A8_SRGB:
            return 4;
        default:
            return 0;
    }
}

constexpr bool isFormatSupported(const size_t bitsPerPixel, const size_t bitsPerComponent) {
    return (bitsPerComponent == 8) && (bitsPerPixel == (8 * formatSize(TK_FORMAT_R8G8B8A8_UNORM)) ||
                                       bitsPerPixel == (8 * formatSize(TK_FORMAT_R8G8B8A8_SRGB)));
}

constexpr Format deduceFormat(size_t bitsPerPixel, size_t bitsPerComponent) {
    TK_ASSERT(isFormatSupported(bitsPerPixel, bitsPerComponent));
    if ((bitsPerComponent == 8) && (bitsPerPixel == (8 * formatSize(TK_FORMAT_R8G8B8A8_UNORM)))) {
        return TK_FORMAT_R8G8B8A8_UNORM;
    }
    return TK_FORMAT_UNDEFINED;
}
} // namespace tk
