#pragma once

#include <cstdint>
#include <vector>

#include "TKImageBuffer.h"

namespace tk::blurhash {
using char_t = char;
static constexpr size_t MIN_COMPONENT_COUNT = 1;
static constexpr size_t MAX_COMPONENT_COUNT = 9;
static constexpr size_t MAX_BUFFER_BYTE_SIZE = 2 + 4 + (9 * 9 - 1) * 2 + 1;
static constexpr bool SRGB = true;

struct BlurHash {
    char_t buffer[MAX_BUFFER_BYTE_SIZE] = {0};
    size_t size = 0;
};

class BlurHashCodec {
public:
    BlurHash encode(size_t n_component_x, size_t n_component_y, const tk::utilities::ImageBuffer &image);
    tk::utilities::ImageBuffer decode(const BlurHash &hash, size_t width, size_t height, float punch = 1.0f);
};
} // namespace tk::blurhash
