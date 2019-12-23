#pragma once

namespace tk {
enum Format {
    TK_FORMAT_UNDEFINED = 0,
    TK_FORMAT_R8G8B8A8_UNORM,
    TK_FORMAT_R8G8B8A8_SRGB,
};
static constexpr unsigned formatSize(const Format format) {
    switch (format) {
        case TK_FORMAT_R8G8B8A8_UNORM: return 4;
        case TK_FORMAT_R8G8B8A8_SRGB:  return 4;
        default:                       return 0;
    }
}
}
