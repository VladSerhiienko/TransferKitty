#pragma once

#include "TKFormat.h"

#ifdef __OBJC__
#import <AppKit/NSImage.h>
#endif

#include <cstdint>
#include <vector>

namespace tk::utilities {
struct ImageBuffer {
    Format format = TK_FORMAT_UNDEFINED;
    size_t width = 0;
    size_t height = 0;
    size_t stride = 0;
    std::vector<uint8_t> buffer = {};
};

#ifdef __OBJC__
ImageBuffer exposeToImageBuffer(NSImage* objcImage);
#endif

}
