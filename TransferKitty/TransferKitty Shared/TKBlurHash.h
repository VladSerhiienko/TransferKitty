#pragma once

#include <cstdint>
#include <vector>

namespace tk {

struct BlurHash {
    std::vector<uint8_t> buffer = {};
};

struct BlurHashPixel {
    uint8_t r = 0;
    uint8_t g = 0;
    uint8_t b = 0;
    uint8_t a = 1;
};

struct BlurHashImage {
    std::vector<BlurHashPixel> buffer = {};
    size_t width = 0;
    size_t height = 0;
};

class BlurHashCodec {
public:
    BlurHash blurHashForPixels(int xComponents, int yComponents, int width, int height, uint8_t *rgb, size_t bytesPerRow);
    BlurHashImage imageForBlurHash(const BlurHash& hash, int width, int height, float punch = 1.0f);
};
}
