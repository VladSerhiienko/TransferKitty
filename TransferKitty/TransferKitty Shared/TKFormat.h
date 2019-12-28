#pragma once
#include <cstdint>

namespace tk {
enum Format {
    TK_FORMAT_UNDEFINED = 0,
    TK_FORMAT_R8G8B8A8_UNORM,
    TK_FORMAT_R8G8B8A8_SRGB,
};
namespace {
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
} // namespace
} // namespace tk
