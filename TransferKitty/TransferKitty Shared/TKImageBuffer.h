#pragma once

#include "TKConfig.h"
#include "TKFormat.h"

#ifdef __OBJC__
#if !TARGET_OS_IOS
#import <AppKit/NSImage.h>
#else
#import <UIKit/UIImage.h>
#endif
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

bool imageBufferEmpty(const ImageBuffer& imgBuffer);

#ifdef __OBJC__
#if !TARGET_OS_IOS
ImageBuffer exposeToImageBuffer(NSImage* objcImage);
#else
ImageBuffer exposeToImageBuffer(UIImage* objcImage);
#endif
#endif // __OBJC__

}
