#include "TKImageBuffer.h"

#ifdef __OBJC__
#import <MetalKit/MetalKit.h>
#endif // __OBJC__

namespace tk::utilities {
#ifdef __OBJC__
ImageBuffer exposeToImageBuffer(NSImage* objcImage) {
    if (!objcImage) { return {}; }

    NSSize imageSize = objcImage.size;
    NSRect imageRect = NSMakeRect(0, 0, imageSize.width, imageSize.height);

    // Create a context to hold the image data.
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGContextRef context = CGBitmapContextCreate(
        NULL, imageSize.width, imageSize.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);

    // Wrap graphics context.
    NSGraphicsContext* graphicsContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];

    // Make our bitmap context current and render the NSImage into it.
    [NSGraphicsContext setCurrentContext:graphicsContext];
    [objcImage drawInRect:imageRect];

    size_t width = CGBitmapContextGetWidth(context);
    size_t height = CGBitmapContextGetHeight(context);
    uint32_t* pixel = (uint32_t*)CGBitmapContextGetData(context);

    tk::utilities::ImageBuffer image;
    image.width = width;
    image.height = height;
    image.format = TK_FORMAT_R8G8B8A8_UNORM;
    image.stride = width * formatSize(image.format);
    image.buffer.resize(height * image.stride);

    for (uint32_t y = 0; y < height; y++) {
        for (uint32_t x = 0; x < width; x++) {
            const uint32_t rgba = *pixel;

            // Extract colour components
            const uint8_t red = (rgba & 0x000000ff) >> 0;
            const uint8_t green = (rgba & 0x0000ff00) >> 8;
            const uint8_t blue = (rgba & 0x00ff0000) >> 16;

            image.buffer[y * width * 4 + x * 4 + 0] = red;
            image.buffer[y * width * 4 + x * 4 + 1] = green;
            image.buffer[y * width * 4 + x * 4 + 2] = blue;
            image.buffer[y * width * 4 + x * 4 + 3] = 255;
            pixel++;
        }
    }

    return image;
} // imageFromNSImage
#endif // __OBJC__
} // namespace tk::utilities
