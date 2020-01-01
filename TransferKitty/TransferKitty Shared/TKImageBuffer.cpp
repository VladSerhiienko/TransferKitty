#include "TKImageBuffer.h"

#include <cassert>

#include "TKSpan.h"

namespace tk::utilities {
bool imageBufferEmpty(const ImageBuffer& imgBuffer) {
    // clang-format off
    return (TK_FORMAT_UNDEFINED == imgBuffer.format) &&
           !imgBuffer.width &&
           !imgBuffer.height &&
           !imgBuffer.stride &&
           imgBuffer.buffer.empty();
    // clang-format on
}
} // namespace tk::utilities

#ifdef __OBJC__
#import <MetalKit/MetalKit.h>

namespace tk::utilities {
ImageBuffer makeImageBufferFrom(
    const size_t width, const size_t height, const Format format, const size_t bytesPerRow, const uint8_t* pixels) {
    if (!pixels || !width || !height || (format == TK_FORMAT_UNDEFINED) || !bytesPerRow) {
        assert(false);
        return {};
    }

    const size_t bytesPerPixel = formatSize(format);
    if (!bytesPerPixel || (bytesPerRow < (width * bytesPerPixel))) {
        assert(false);
        return {};
    }

    ImageBuffer image;
    image.width = width;
    image.height = height;
    image.format = format;
    image.stride = width * bytesPerPixel;
    image.buffer.resize(height * image.stride);

    if (image.stride == bytesPerRow) {
        memcpy(image.buffer.data(), pixels, image.buffer.size());
        return image;
    }

    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            const size_t srcPixelIndex = y * bytesPerRow + x * bytesPerPixel;
            const size_t dstPixelIndex = y * image.stride + x * bytesPerPixel;

            switch (format) {
                case TK_FORMAT_R8G8B8A8_UNORM:
                case TK_FORMAT_R8G8B8A8_SRGB: {
                    Span src = Span(&pixels[srcPixelIndex], bytesPerPixel).reinterpret<const uint32_t>();
                    Span dst = Span(&image.buffer[dstPixelIndex], bytesPerPixel).reinterpret<uint32_t>();
                    dst[0] = src[0];
                } break;
                default: {
                    assert(false);
                } break;
            }
        }
    }

    return image;
}

#if !TARGET_OS_IOS
ImageBuffer exposeToImageBuffer(NSImage* objcImage) {
    if (!objcImage) { return {}; }

    NSSize imageSize = objcImage.size;
    NSRect imageRect = NSMakeRect(0, 0, imageSize.width, imageSize.height);

    // Create a context to hold the image data.
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGContextRef context = CGBitmapContextCreate(
        NULL, imageSize.width, imageSize.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);

    // Wrap graphics context.
    NSGraphicsContext* restoreGraphicsContext = [NSGraphicsContext currentContext];
    NSGraphicsContext* imageGraphicsContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];

    // Make our bitmap context current and render the NSImage into it.
    [NSGraphicsContext setCurrentContext:imageGraphicsContext];
    [objcImage drawInRect:imageRect];
    [NSGraphicsContext setCurrentContext:restoreGraphicsContext];

    size_t width = CGBitmapContextGetWidth(context);
    size_t height = CGBitmapContextGetHeight(context);
    const uint8_t* pixels = (const uint8_t*)CGBitmapContextGetData(context);

    const Format format = TK_FORMAT_R8G8B8A8_UNORM;
    const size_t stride = width * formatSize(format);
    return makeImageBufferFrom(width, height, format, stride, pixels);
}

#else // TARGET_OS_IOS

constexpr Format deduceFormat(OSType pixelFormatType) {
    if (pixelFormatType == kCVPixelFormatType_32RGBA) { return TK_FORMAT_R8G8B8A8_UNORM; }
    return TK_FORMAT_UNDEFINED;
}

ImageBuffer exposeToImageBuffer(CGImageRef cgImage) {
    CGImagePixelFormatInfo pixelFormatInfo = CGImageGetPixelFormatInfo(cgImage);
    if ((pixelFormatInfo & kCGImagePixelFormatMask) != 0) { return {}; }

    NSUInteger bitsPerPixel = CGImageGetBitsPerPixel(cgImage);
    NSUInteger bitsPerComponent = CGImageGetBitsPerComponent(cgImage);
    if (!isFormatSupported(bitsPerPixel, bitsPerComponent)) { return {}; }

    CGDataProviderRef provider = CGImageGetDataProvider(cgImage);
    if (!provider) { return {}; }

    CFDataRef data = CGDataProviderCopyData(provider);
    if (!data) { return {}; }

    const uint8_t* bytes = CFDataGetBytePtr(data);
    if (!bytes) { return {}; }

    NSUInteger width = CGImageGetWidth(cgImage);
    NSUInteger height = CGImageGetHeight(cgImage);
    NSUInteger stride = CGImageGetBytesPerRow(cgImage);
    if (!width || !height || !stride) { return {}; }

    Format format = tk::deduceFormat(bitsPerPixel, bitsPerComponent);
    TK_ASSERT(format != TK_FORMAT_UNDEFINED);
    return makeImageBufferFrom(width, height, format, stride, bytes);
}

ImageBuffer exposeToImageBuffer(CVPixelBufferRef pixelBuffer) {
    OSType pixelFormatType = CVPixelBufferGetPixelFormatType(pixelBuffer);
    Format format = deduceFormat(pixelFormatType);
    if (format == TK_FORMAT_UNDEFINED) { return {}; }

    NSUInteger width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
    NSUInteger height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    NSUInteger stride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    if (!width || !height || !stride) { return {}; }

    switch (CVReturn lockResult = CVPixelBufferLockBaseAddress(pixelBuffer, 0)) {
        case kCVReturnSuccess: {
            void* address = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
            TK_ASSERT(address);
            return makeImageBufferFrom(width, height, format, stride, (const uint8_t*)address);
        } break;
        default: {
            TK_ASSERT(false);
        } break;
    }

    return {};
}

ImageBuffer exposeToImageBuffer(CIImage* ciImage) {
    if (CGImageRef cgImage = ciImage.CGImage) { return exposeToImageBuffer(cgImage); }
    if (CVPixelBufferRef pixelBuffer = ciImage.pixelBuffer) { return exposeToImageBuffer(pixelBuffer); }
    return ImageBuffer{};
}

ImageBuffer exposeToImageBuffer(UIImage* objcImage) {
    if (!objcImage) {
        return {};
    } else if (CGImageRef cgImage = objcImage.CGImage) {
        return exposeToImageBuffer(cgImage);
    } else if (CIImage* ciImage = objcImage.CIImage) {
        return exposeToImageBuffer(ciImage);
    }

    return {};
}

#endif // __OBJC__
} // namespace tk::utilities

#endif // __OBJC__
