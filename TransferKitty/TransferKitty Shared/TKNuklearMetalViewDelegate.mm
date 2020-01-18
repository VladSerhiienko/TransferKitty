//
//  Renderer.m
//  EzriUI Shared
//
//  Created by Vlad Serhiienko on 9/29/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#include <chrono>
#include <cstdint>

#define NK_POINTER_TYPE uintptr_t
//#define NK_SIZE_TYPE size_t
#define NK_IMPLEMENTATION
#import "TKNuklearMetalViewDelegate.h"

#import <ModelIO/ModelIO.h>
#import <simd/simd.h>

static const NSUInteger FrameCount = 3;

struct Stopwatch {
    inline void Start();
    inline double GetElapsedSeconds() const;
    std::chrono::high_resolution_clock::time_point StartTimePoint;
};

void Stopwatch::Start() {
    using namespace std::chrono;
    StartTimePoint = high_resolution_clock::now();
}

double Stopwatch::GetElapsedSeconds() const {
    using namespace std::chrono;
    const high_resolution_clock::time_point currentTimePoint = high_resolution_clock::now();
    const duration<double> time_span = duration_cast<duration<double>>(currentTimePoint - StartTimePoint);
    return time_span.count();
}

typedef struct EUINuklearState {
    struct nk_buffer _cmdBuffer;
    struct nk_font_atlas _fontAtlas;
    struct nk_font *_Nullable _fontPtr;
    struct nk_draw_null_texture _drawNullTexture;
    struct nk_draw_vertex_layout_element _vertexLayout[4];
    CGRect _viewport;
    CGSize _viewportScale;
    struct nk_vec2 _scroll;
} EUINuklearState;

@interface TKNuklearFrame ()
@property(nonatomic, readwrite) struct nk_context *outptr contextPtr;
@property(nonatomic, readwrite) struct nk_convert_config *outptr convertConfigPtr;
@property(nonatomic, readwrite) CGRect viewport;
@end

@implementation TKNuklearFrame {
    // struct nk_context _context;
    // struct nk_convert_config _convertConfig;
    // CGRect _viewport;
    // CGSize _viewportScale;
    id<MTLBuffer> _uniformBuffer;
    id<MTLBuffer> _vertexBuffer;
    id<MTLBuffer> _indexBuffer;
    // struct nk_context *_contextPtr;
    // struct nk_convert_config *_convertConfigPtr;
}

//-(instancetype)init {
//    _contextPtr = &_context;
//    _convertConfigPtr = &_convertConfig;
//    return self;
//}

// - (void)setViewport:(CGRect)viewport { _viewport = viewport; }

- (void)uniformBuffer:(id<MTLBuffer>)buffer {
    _uniformBuffer = buffer;
}
- (void)vertexBuffer:(id<MTLBuffer>)buffer {
    _vertexBuffer = buffer;
}
- (void)indexBuffer:(id<MTLBuffer>)buffer {
    _indexBuffer = buffer;
}

- (id<MTLBuffer>)uniformBuffer {
    return _uniformBuffer;
}
- (id<MTLBuffer>)vertexBuffer {
    return _vertexBuffer;
}
- (id<MTLBuffer>)indexBuffer {
    return _indexBuffer;
}

@end

void nuklearClipboardPaste(nk_handle usr, struct nk_text_edit *edit);
void nuklearClipboardCopy(nk_handle usr, const char *text, int len);
void nuklearSetTheme(struct nk_context *ctx, enum TKNuklearBuiltinColorTheme theme);
const void *getFontBytes(void);
const size_t getFontByteLength(void);

@implementation TKNuklearRenderer {
    id<MTLDevice> _device;
    id<TKNuklearFrameDelegate> _frameDelegate;

    struct nk_context _context;
    struct nk_convert_config _convertConfig;
    TKNuklearFrame *_frame[FrameCount];
    struct EUINuklearState _nuklear;

    NSUInteger _bufferMaxSize;
    NSUInteger _uniformBufferIndex;
    NSUInteger _vertexBufferIndex;

    id<MTLRenderPipelineState> _pipelineState;
    id<MTLDepthStencilState> _depthState;
    id<MTLTexture> _fontTexture;

    NSUInteger _frameIndex;
    matrix_float4x4 _orthoMatrix;

    NSMutableArray *_retainedList;
}

//
// Properties
//

- (id<MTLDevice>)device {
    return _device;
}
- (void)setDelegate:(nonnull id<TKNuklearFrameDelegate>)delegate {
    _frameDelegate = delegate;
}
- (id<TKNuklearFrameDelegate>)delegate {
    return _frameDelegate;
}

- (nullable instancetype)initWithMetalDevice:(nonnull id<MTLDevice>)device
                            colorPixelFormat:(MTLPixelFormat)colorPixelFormat
                     depthStencilPixelFormat:(MTLPixelFormat)depthStencilPixelFormat
                                 sampleCount:(NSUInteger)sampleCount {
    self = [super init];
    if (!self) { return nil; }

    _retainedList = [[NSMutableArray alloc] init];

    _device = device;
    _nuklear._viewport.origin = CGPointZero;
    _nuklear._viewportScale = CGSizeMake(1, 1);

    _vertexBufferIndex = 0;
    _uniformBufferIndex = 1;
    _bufferMaxSize = 65536 * 4;

    for (NSUInteger i = 0; i < FrameCount; i++) {
        TKNuklearFrame *currentFrame = [[TKNuklearFrame alloc] init];
        [currentFrame setContextPtr:&_context];
        [currentFrame setConvertConfigPtr:&_convertConfig];
        [currentFrame setViewportScale:_nuklear._viewportScale];
        _frame[i] = currentFrame;
    }

    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    MTLVertexAttributeDescriptor *positionAttributeDesc = vertexDescriptor.attributes[0];
    MTLVertexAttributeDescriptor *uvAttributeDesc = vertexDescriptor.attributes[1];
    MTLVertexAttributeDescriptor *colorAttributeDesc = vertexDescriptor.attributes[2];
    positionAttributeDesc.bufferIndex = _vertexBufferIndex;
    positionAttributeDesc.offset = 0;
    positionAttributeDesc.format = MTLVertexFormatFloat2;
    uvAttributeDesc.bufferIndex = _vertexBufferIndex;
    uvAttributeDesc.offset = 8;
    uvAttributeDesc.format = MTLVertexFormatFloat2;
    colorAttributeDesc.bufferIndex = _vertexBufferIndex;
    colorAttributeDesc.offset = 16;
    colorAttributeDesc.format = MTLVertexFormatUChar4Normalized;

    MTLVertexBufferLayoutDescriptor *layout = vertexDescriptor.layouts[_vertexBufferIndex];
    layout.stride = 20;
    layout.stepRate = 1;
    layout.stepFunction = MTLVertexStepFunctionPerVertex;

    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"nkVertexShader"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"nkFragmentShader"];

    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"MyPipeline";
    pipelineStateDescriptor.sampleCount = sampleCount;
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor;
    pipelineStateDescriptor.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
    pipelineStateDescriptor.depthAttachmentPixelFormat = depthStencilPixelFormat;
    pipelineStateDescriptor.stencilAttachmentPixelFormat = depthStencilPixelFormat;

    MTLRenderPipelineColorAttachmentDescriptor *colorAttachment = pipelineStateDescriptor.colorAttachments[0];
    colorAttachment.pixelFormat = colorPixelFormat;
    colorAttachment.blendingEnabled = YES;
    colorAttachment.sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    colorAttachment.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    colorAttachment.rgbBlendOperation = MTLBlendOperationAdd;
    colorAttachment.sourceAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    colorAttachment.destinationAlphaBlendFactor = MTLBlendFactorZero;
    colorAttachment.writeMask = MTLColorWriteMaskAll;

    NSError *error = NULL;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if (!_pipelineState) {
        NSLog(@"Failed to created pipeline state, error=\"%@\"", error);
        return nil;
    }

    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.label = @"DepthStencil";
    depthStateDesc.depthCompareFunction = MTLCompareFunctionAlways;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];

    _nuklear._vertexLayout[0] = {NK_VERTEX_POSITION, NK_FORMAT_FLOAT, 0};
    _nuklear._vertexLayout[1] = {NK_VERTEX_TEXCOORD, NK_FORMAT_FLOAT, 8};
    _nuklear._vertexLayout[2] = {NK_VERTEX_COLOR, NK_FORMAT_R8G8B8A8, 16};
    _nuklear._vertexLayout[3] = {NK_VERTEX_LAYOUT_END};

    for (NSUInteger i = 0; i < FrameCount; i++) {
        TKNuklearFrame *currentFrame = _frame[i];
        [currentFrame uniformBuffer:[_device newBufferWithLength:sizeof(matrix_float4x4)
                                                         options:MTLResourceStorageModeShared]];
        [currentFrame vertexBuffer:[_device newBufferWithLength:_bufferMaxSize options:MTLResourceStorageModeShared]];
        [currentFrame indexBuffer:[_device newBufferWithLength:_bufferMaxSize options:MTLResourceStorageModeShared]];

        [currentFrame uniformBuffer].label = [@"UniformBuffer" stringByAppendingFormat:@"[Frame=%u]", (uint32_t)i];
        [currentFrame vertexBuffer].label = [@"VertexBuffer" stringByAppendingFormat:@"[Frame=%u]", (uint32_t)i];
        [currentFrame indexBuffer].label = [@"IndexBuffer" stringByAppendingFormat:@"[Frame=%u]", (uint32_t)i];

        if (i == 0) {
            nk_init_default(currentFrame.contextPtr, 0);
            currentFrame.contextPtr->clip.copy = nuklearClipboardCopy;
            currentFrame.contextPtr->clip.paste = nuklearClipboardPaste;
            currentFrame.contextPtr->clip.userdata = nk_handle_ptr((void *)CFBridgingRetain(self));

            NK_MEMSET(currentFrame.convertConfigPtr, 0, sizeof(nk_convert_config));
            currentFrame.convertConfigPtr->global_alpha = 1.0f;
            currentFrame.convertConfigPtr->line_AA = NK_ANTI_ALIASING_ON;
            currentFrame.convertConfigPtr->shape_AA = NK_ANTI_ALIASING_ON;
            currentFrame.convertConfigPtr->circle_segment_count = 22;
            currentFrame.convertConfigPtr->arc_segment_count = 22;
            currentFrame.convertConfigPtr->curve_segment_count = 22;
        }
    }

    nk_buffer_init_default(&_nuklear._cmdBuffer);
    nk_font_atlas_init_default(&_nuklear._fontAtlas);
    nk_font_atlas_begin(&_nuklear._fontAtlas);

    _nuklear._fontPtr =
        nk_font_atlas_add_from_memory(&_nuklear._fontAtlas, (void *)getFontBytes(), getFontByteLength(), 12, 0);

    int imageWidth, imageHeight, imageBytesPerRow;
    const void *imageBytes = nk_font_atlas_bake(&_nuklear._fontAtlas, &imageWidth, &imageHeight, NK_FONT_ATLAS_RGBA32);
    imageBytesPerRow = imageWidth * 4;

    // Indicate that each pixel has a blue, green, red, and alpha channel,
    // where each channel is an 8-bit unsigned normalized value
    // (i.e. 0 maps to 0.0 and 255 maps to 1.0).
    // Set the pixel dimensions of the texture
    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    textureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
    textureDescriptor.width = imageWidth;
    textureDescriptor.height = imageHeight;

    // Create the texture from the device by using the descriptor
    _fontTexture = [_device newTextureWithDescriptor:textureDescriptor];
    [_fontTexture replaceRegion:MTLRegionMake2D(0, 0, imageWidth, imageHeight)
                    mipmapLevel:0
                      withBytes:imageBytes
                    bytesPerRow:imageBytesPerRow];

    nk_font_atlas_end(
        &_nuklear._fontAtlas, nk_handle_ptr((void *)CFBridgingRetain(_fontTexture)), &_nuklear._drawNullTexture);

    for (NSUInteger i = 0; i < FrameCount; ++i) {
        TKNuklearFrame *currentFrame = _frame[i];
        if (i == 0) {
            nuklearSetTheme(currentFrame.contextPtr, TKNuklearColorBuiltinThemeRed);
            if (_nuklear._fontAtlas.default_font) {
                nk_style_set_font(currentFrame.contextPtr, &_nuklear._fontAtlas.default_font->handle);
            }

            currentFrame.contextPtr->style.font = &_nuklear._fontPtr->handle;
            _nuklear._fontAtlas.default_font = _nuklear._fontPtr;
            nk_style_set_font(currentFrame.contextPtr, &_nuklear._fontPtr->handle);
        }
    }

    return self;
}

- (nullable id<MTLTexture>)createTextureWithImage:(nullable tk::utilities::ImageBuffer *)image {
    if (!image) { return nil; }

    MTLPixelFormat pixelFormat;
    switch (image->format) {
        case tk::TK_FORMAT_R8G8B8A8_UNORM:
            pixelFormat = MTLPixelFormatRGBA8Unorm;
            break;
        case tk::TK_FORMAT_R8G8B8A8_SRGB:
            pixelFormat = MTLPixelFormatRGBA8Unorm_sRGB;
            break;
        default:
            return nil;
    }

    return [self createTextureWithFormat:pixelFormat
                                   width:image->width
                                  height:image->height
                             bytesPerRow:image->stride
                                   bytes:image->buffer.data()];
}

- (void)releaseRetainedObject:(nullable id)retainedObject {
    if (!retainedObject) { return; }

    // https://developer.apple.com/documentation/foundation/nsmutablearray/1410689-removeobject?language=objc
    [_retainedList removeObject:retainedObject];
}

- (nullable id<MTLTexture>)createTextureWithFormat:(MTLPixelFormat)format
                                             width:(NSUInteger)width
                                            height:(NSUInteger)height
                                       bytesPerRow:(NSUInteger)bytesPerRow
                                             bytes:(nullable const void *)bytes {
    if (format == MTLPixelFormatInvalid || !width || !height || !bytesPerRow) { return nil; }

    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    textureDescriptor.pixelFormat = format;
    textureDescriptor.width = width;
    textureDescriptor.height = height;

    // Create the texture from the device by using the descriptor
    id<MTLTexture> texture = [_device newTextureWithDescriptor:textureDescriptor];
    if (bytes) {
        [texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
                   mipmapLevel:0
                     withBytes:bytes
                   bytesPerRow:bytesPerRow];
    }

    [_retainedList addObject:texture];
    return texture;
}

- (void)deinit {
    for (NSUInteger i = 0; i < FrameCount; i++) {
        TKNuklearFrame *currentFrame = _frame[i];
        CFBridgingRelease(currentFrame.contextPtr->clip.userdata.ptr);
        currentFrame.contextPtr->clip.userdata = nk_handle_ptr(nullptr);
    }

    CFBridgingRelease(_nuklear._fontPtr->texture.ptr);
    _nuklear._fontPtr->texture = nk_handle_ptr(nullptr);
}

- (TKNuklearFrame *)advanceFrameIndex {
    _frameIndex = (_frameIndex + 1) % FrameCount;
    return _frame[_frameIndex];
}

- (void)uploadFrameBuffers:(TKNuklearFrame *)currentFrame {
    currentFrame.convertConfigPtr->null = _nuklear._drawNullTexture;
    currentFrame.convertConfigPtr->vertex_layout = _nuklear._vertexLayout;
    currentFrame.convertConfigPtr->vertex_size = 20;
    currentFrame.convertConfigPtr->vertex_alignment = NK_ALIGNOF(matrix_float4x4);

    /* setup buffers to load vertices and elements */
    struct nk_buffer vbuf, ebuf;
    nk_buffer_init_fixed(&vbuf, [currentFrame vertexBuffer].contents, _bufferMaxSize);
    nk_buffer_init_fixed(&ebuf, [currentFrame indexBuffer].contents, _bufferMaxSize);
    nk_convert(currentFrame.contextPtr, &_nuklear._cmdBuffer, &vbuf, &ebuf, currentFrame.convertConfigPtr);

    matrix_float4x4 *projectionMatrix = (matrix_float4x4 *)[currentFrame uniformBuffer].contents;
    *projectionMatrix = _orthoMatrix;
}

- (void)appendDebugOverlay:(TKNuklearFrame *)currentFrame {
    struct nk_context *ctx = currentFrame.contextPtr;

    const CGFloat width = _nuklear._viewport.size.width;
    const CGFloat height = _nuklear._viewport.size.height;

    if (nk_begin(ctx, "DebugOverlay", nk_rect(width - 300, height - 55, 295, 50), NK_WINDOW_NO_SCROLLBAR)) {
        nk_layout_row_dynamic(ctx, 50, 1);
        nk_labelf(ctx, NK_TEXT_CENTERED, "%u x %u", (uint32_t)width, (uint32_t)height);
    }
    nk_end(ctx);
}

// Respond to drawable size or orientation changes here
- (void)updateFrameViewport:(TKNuklearFrame *)currentFrame drawableSize:(CGSize)drawableSize {
    _nuklear._viewport.size = drawableSize;
    [currentFrame setViewport:_nuklear._viewport];

    float ortho[4][4] = {
        {2.0f, 0.0f, 0.0f, 0.0f}, {0.0f, -2.0f, 0.0f, 0.0f}, {0.0f, 0.0f, -1.0f, 0.0f}, {-1.0f, 1.0f, 0.0f, 1.0f}};

    ortho[0][0] /= (float)drawableSize.width;
    ortho[1][1] /= (float)drawableSize.height;

    static_assert(sizeof(_orthoMatrix) == sizeof(ortho), "Caught size mismatch.");
    memcpy(&_orthoMatrix, ortho, sizeof(ortho));
}

- (void)drawNextFrameToRenderPass:(nonnull MTLRenderPassDescriptor *)renderPassDescriptor
                    commandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer
                     drawableSize:(CGSize)drawableSize {
    TKNuklearFrame *currentFrame = [self advanceFrameIndex];
    [self updateFrameViewport:currentFrame drawableSize:drawableSize];

    [_frameDelegate renderer:self shouldUpdateFrame:currentFrame];

    [self appendDebugOverlay:currentFrame];
    [self uploadFrameBuffers:currentFrame];

    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    if (!renderEncoder) { return; }

    renderEncoder.label = @"MyRenderEncoder";
    [renderEncoder pushDebugGroup:[NSString stringWithUTF8String:__PRETTY_FUNCTION__]];

    [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
    [renderEncoder setCullMode:MTLCullModeNone];
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setDepthStencilState:_depthState];

    [renderEncoder setVertexBuffer:[currentFrame uniformBuffer] offset:0 atIndex:_uniformBufferIndex];
    [renderEncoder setVertexBuffer:[currentFrame vertexBuffer] offset:0 atIndex:_vertexBufferIndex];

    MTLViewport viewport;
    viewport.originX = _nuklear._viewport.origin.x;
    viewport.originY = _nuklear._viewport.origin.y;
    viewport.width = _nuklear._viewport.size.width * _nuklear._viewportScale.width;
    viewport.height = _nuklear._viewport.size.height * _nuklear._viewportScale.height;
    viewport.znear = 0.0f;
    viewport.zfar = 1.0f;

    [renderEncoder setViewport:viewport];

    NSUInteger indexOffset = 0;
    const struct nk_draw_command *cmd = NULL;
    nk_draw_foreach(cmd, currentFrame.contextPtr, &_nuklear._cmdBuffer) {
        if (!cmd->elem_count) { continue; }

        CGRect sr;
        sr.origin.x = cmd->clip_rect.x * _nuklear._viewportScale.width;
        sr.origin.y = cmd->clip_rect.y * _nuklear._viewportScale.height;
        sr.size.width = cmd->clip_rect.w * _nuklear._viewportScale.width;
        sr.size.height = cmd->clip_rect.h * _nuklear._viewportScale.height;
        sr.origin.x = NK_CLAMP(0, sr.origin.x, _nuklear._viewport.size.width);
        sr.origin.y = NK_CLAMP(0, sr.origin.y, _nuklear._viewport.size.height);
        sr.size.width = NK_CLAMP(0, sr.size.width, _nuklear._viewport.size.width - sr.origin.x - 2);
        sr.size.height = NK_CLAMP(0, sr.size.height, _nuklear._viewport.size.height - sr.origin.y - 2);

        MTLScissorRect scissorRect;
        scissorRect.x = (NSUInteger)sr.origin.x;
        scissorRect.y = (NSUInteger)sr.origin.y;
        scissorRect.width = (NSUInteger)sr.size.width;
        scissorRect.height = (NSUInteger)sr.size.height;

        [renderEncoder setScissorRect:scissorRect];

        void *textureHandle = cmd->texture.ptr;
        id<MTLTexture> fragmentTextureId = (__bridge id<MTLTexture>)(textureHandle);
        [renderEncoder setFragmentTexture:fragmentTextureId atIndex:0];

        [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                  indexCount:cmd->elem_count
                                   indexType:MTLIndexTypeUInt16
                                 indexBuffer:[currentFrame indexBuffer]
                           indexBufferOffset:indexOffset];

        indexOffset += cmd->elem_count * sizeof(uint16_t);
    }

    nk_clear(currentFrame.contextPtr);

    [renderEncoder popDebugGroup];
    [renderEncoder endEncoding];
}

@end

@implementation TKNuklearMetalViewDelegate {
    MTKView *_view;
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    dispatch_semaphore_t _commandCompletionSemaphore;
    TKNuklearRenderer *_renderer;
}

- (void)setDelegate:(nonnull id<TKNuklearFrameDelegate>)delegate {
    [_renderer setDelegate:delegate];
}
- (id<TKNuklearFrameDelegate>)delegate {
    return [_renderer delegate];
}

- (void)deinit {
    [_renderer deinit];
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view {
    self = [super init];

    // TODO: Why do we check for self?
    if (self) {
        _view = view;
        _device = view.device;
        _commandQueue = [_device newCommandQueue];

        // https://developer.apple.com/documentation/metal/synchronization/synchronizing_cpu_and_gpu_work?language=objc
        _commandCompletionSemaphore = dispatch_semaphore_create(FrameCount);

        view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
        view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
        view.sampleCount = 1;

        _renderer = [[TKNuklearRenderer alloc] initWithMetalDevice:_device
                                                  colorPixelFormat:view.colorPixelFormat
                                           depthStencilPixelFormat:view.depthStencilPixelFormat
                                                       sampleCount:view.sampleCount];
    }

    return self;
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    // https://developer.apple.com/documentation/metal/synchronization/synchronizing_cpu_and_gpu_work?language=objc
    dispatch_semaphore_wait(_commandCompletionSemaphore, DISPATCH_TIME_FOREVER);

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    __block dispatch_semaphore_t block_semaphore = _commandCompletionSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
      // https://developer.apple.com/documentation/metal/synchronization/synchronizing_cpu_and_gpu_work?language=objc
      dispatch_semaphore_signal(block_semaphore);
    }];

    [_renderer drawNextFrameToRenderPass:view.currentRenderPassDescriptor
                           commandBuffer:commandBuffer
                            drawableSize:view.drawableSize];
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    /// Respond to drawable size or orientation changes here
    NSLog(@"%s: view.drawableSize = {%f %f}", __PRETTY_FUNCTION__, view.drawableSize.width, view.drawableSize.height);
}

@end

void nuklearClipboardPaste(nk_handle usr, struct nk_text_edit *edit) {
    //    const char *text = glfwGetClipboardString( nk_apemode_global_state.win
    //    ); if ( text )
    //        nk_textedit_paste( edit, text, nk_strlen( text ) );
    //    (void) usr;
}

void nuklearClipboardCopy(nk_handle usr, const char *text, int len) {
    //    char *str = 0;
    //    (void) usr;
    //    if ( !len )
    //        return;
    //    str = (char *) malloc( (size_t) len + 1 );
    //    if ( !str )
    //        return;
    //    memcpy( str, text, (size_t) len );
    //    str[ len ] = '\0';
    //    glfwSetClipboardString( nk_apemode_global_state.win, str );
    //    free( str );
}

#include "droidsans.ttf.h"

const void *getFontBytes() { return s_droidSansTtf; }
const size_t getFontByteLength() { return sizeof(s_droidSansTtf); }

void nuklearSetTheme(struct nk_context *ctx, enum TKNuklearBuiltinColorTheme theme) {
    struct nk_color table[NK_COLOR_COUNT];
    if (theme == TKNuklearColorBuiltinThemeWhite) {
        table[NK_COLOR_TEXT] = nk_rgba(70, 70, 70, 255);
        table[NK_COLOR_WINDOW] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_HEADER] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_BORDER] = nk_rgba(0, 0, 0, 255);
        table[NK_COLOR_BUTTON] = nk_rgba(185, 185, 185, 255);
        table[NK_COLOR_BUTTON_HOVER] = nk_rgba(170, 170, 170, 255);
        table[NK_COLOR_BUTTON_ACTIVE] = nk_rgba(160, 160, 160, 255);
        table[NK_COLOR_TOGGLE] = nk_rgba(150, 150, 150, 255);
        table[NK_COLOR_TOGGLE_HOVER] = nk_rgba(120, 120, 120, 255);
        table[NK_COLOR_TOGGLE_CURSOR] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_SELECT] = nk_rgba(190, 190, 190, 255);
        table[NK_COLOR_SELECT_ACTIVE] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_SLIDER] = nk_rgba(190, 190, 190, 255);
        table[NK_COLOR_SLIDER_CURSOR] = nk_rgba(80, 80, 80, 255);
        table[NK_COLOR_SLIDER_CURSOR_HOVER] = nk_rgba(70, 70, 70, 255);
        table[NK_COLOR_SLIDER_CURSOR_ACTIVE] = nk_rgba(60, 60, 60, 255);
        table[NK_COLOR_PROPERTY] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_EDIT] = nk_rgba(150, 150, 150, 255);
        table[NK_COLOR_EDIT_CURSOR] = nk_rgba(0, 0, 0, 255);
        table[NK_COLOR_COMBO] = nk_rgba(175, 175, 175, 255);
        table[NK_COLOR_CHART] = nk_rgba(160, 160, 160, 255);
        table[NK_COLOR_CHART_COLOR] = nk_rgba(45, 45, 45, 255);
        table[NK_COLOR_CHART_COLOR_HIGHLIGHT] = nk_rgba(255, 0, 0, 255);
        table[NK_COLOR_SCROLLBAR] = nk_rgba(180, 180, 180, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR] = nk_rgba(140, 140, 140, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_HOVER] = nk_rgba(150, 150, 150, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_ACTIVE] = nk_rgba(160, 160, 160, 255);
        table[NK_COLOR_TAB_HEADER] = nk_rgba(180, 180, 180, 255);
        nk_style_from_table(ctx, table);
    } else if (theme == TKNuklearColorBuiltinThemeRed) {
        table[NK_COLOR_TEXT] = nk_rgba(190, 190, 190, 255);
        table[NK_COLOR_WINDOW] = nk_rgba(30, 33, 40, 215);
        table[NK_COLOR_HEADER] = nk_rgba(181, 45, 69, 220);
        table[NK_COLOR_BORDER] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_BUTTON] = nk_rgba(181, 45, 69, 255);
        table[NK_COLOR_BUTTON_HOVER] = nk_rgba(181, 45, 69, 255); // 195, 55, 75, 255 ); // 190, 50, 70, 255 );
        table[NK_COLOR_BUTTON_ACTIVE] = nk_rgba(195, 55, 75, 255);
        table[NK_COLOR_TOGGLE] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_TOGGLE_HOVER] = nk_rgba(45, 60, 60, 255);
        table[NK_COLOR_TOGGLE_CURSOR] = nk_rgba(181, 45, 69, 255);
        table[NK_COLOR_SELECT] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_SELECT_ACTIVE] = nk_rgba(181, 45, 69, 255);
        table[NK_COLOR_SLIDER] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_SLIDER_CURSOR] = nk_rgba(181, 45, 69, 255);
        table[NK_COLOR_SLIDER_CURSOR_HOVER] = nk_rgba(186, 50, 74, 255);
        table[NK_COLOR_SLIDER_CURSOR_ACTIVE] = nk_rgba(191, 55, 79, 255);
        table[NK_COLOR_PROPERTY] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_EDIT] = nk_rgba(51, 55, 67, 225);
        table[NK_COLOR_EDIT_CURSOR] = nk_rgba(190, 190, 190, 255);
        table[NK_COLOR_COMBO] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_CHART] = nk_rgba(51, 55, 67, 255);
        table[NK_COLOR_CHART_COLOR] = nk_rgba(170, 40, 60, 255);
        table[NK_COLOR_CHART_COLOR_HIGHLIGHT] = nk_rgba(255, 0, 0, 255);
        table[NK_COLOR_SCROLLBAR] = nk_rgba(30, 33, 40, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR] = nk_rgba(64, 84, 95, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_HOVER] = nk_rgba(70, 90, 100, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_ACTIVE] = nk_rgba(75, 95, 105, 255);
        table[NK_COLOR_TAB_HEADER] = nk_rgba(181, 45, 69, 220);
        nk_style_from_table(ctx, table);
    } else if (theme == TKNuklearColorBuiltinThemeBlue) {
        table[NK_COLOR_TEXT] = nk_rgba(20, 20, 20, 255);
        table[NK_COLOR_WINDOW] = nk_rgba(202, 212, 214, 215);
        table[NK_COLOR_HEADER] = nk_rgba(137, 182, 224, 220);
        table[NK_COLOR_BORDER] = nk_rgba(140, 159, 173, 255);
        table[NK_COLOR_BUTTON] = nk_rgba(137, 182, 224, 255);
        table[NK_COLOR_BUTTON_HOVER] = nk_rgba(142, 187, 229, 255);
        table[NK_COLOR_BUTTON_ACTIVE] = nk_rgba(147, 192, 234, 255);
        table[NK_COLOR_TOGGLE] = nk_rgba(177, 210, 210, 255);
        table[NK_COLOR_TOGGLE_HOVER] = nk_rgba(182, 215, 215, 255);
        table[NK_COLOR_TOGGLE_CURSOR] = nk_rgba(137, 182, 224, 255);
        table[NK_COLOR_SELECT] = nk_rgba(177, 210, 210, 255);
        table[NK_COLOR_SELECT_ACTIVE] = nk_rgba(137, 182, 224, 255);
        table[NK_COLOR_SLIDER] = nk_rgba(177, 210, 210, 255);
        table[NK_COLOR_SLIDER_CURSOR] = nk_rgba(137, 182, 224, 245);
        table[NK_COLOR_SLIDER_CURSOR_HOVER] = nk_rgba(142, 188, 229, 255);
        table[NK_COLOR_SLIDER_CURSOR_ACTIVE] = nk_rgba(147, 193, 234, 255);
        table[NK_COLOR_PROPERTY] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_EDIT] = nk_rgba(210, 210, 210, 225);
        table[NK_COLOR_EDIT_CURSOR] = nk_rgba(20, 20, 20, 255);
        table[NK_COLOR_COMBO] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_CHART] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_CHART_COLOR] = nk_rgba(137, 182, 224, 255);
        table[NK_COLOR_CHART_COLOR_HIGHLIGHT] = nk_rgba(255, 0, 0, 255);
        table[NK_COLOR_SCROLLBAR] = nk_rgba(190, 200, 200, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR] = nk_rgba(64, 84, 95, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_HOVER] = nk_rgba(70, 90, 100, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_ACTIVE] = nk_rgba(75, 95, 105, 255);
        table[NK_COLOR_TAB_HEADER] = nk_rgba(156, 193, 220, 255);
        nk_style_from_table(ctx, table);
    } else if (theme == TKNuklearColorBuiltinThemeDark) {
        table[NK_COLOR_TEXT] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_WINDOW] = nk_rgba(57, 67, 71, 215);
        table[NK_COLOR_HEADER] = nk_rgba(51, 51, 56, 220);
        table[NK_COLOR_BORDER] = nk_rgba(46, 46, 46, 255);
        table[NK_COLOR_BUTTON] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_BUTTON_HOVER] = nk_rgba(58, 93, 121, 255);
        table[NK_COLOR_BUTTON_ACTIVE] = nk_rgba(63, 98, 126, 255);
        table[NK_COLOR_TOGGLE] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_TOGGLE_HOVER] = nk_rgba(45, 53, 56, 255);
        table[NK_COLOR_TOGGLE_CURSOR] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_SELECT] = nk_rgba(57, 67, 61, 255);
        table[NK_COLOR_SELECT_ACTIVE] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_SLIDER] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_SLIDER_CURSOR] = nk_rgba(48, 83, 111, 245);
        table[NK_COLOR_SLIDER_CURSOR_HOVER] = nk_rgba(53, 88, 116, 255);
        table[NK_COLOR_SLIDER_CURSOR_ACTIVE] = nk_rgba(58, 93, 121, 255);
        table[NK_COLOR_PROPERTY] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_EDIT] = nk_rgba(50, 58, 61, 225);
        table[NK_COLOR_EDIT_CURSOR] = nk_rgba(210, 210, 210, 255);
        table[NK_COLOR_COMBO] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_CHART] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_CHART_COLOR] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_CHART_COLOR_HIGHLIGHT] = nk_rgba(255, 0, 0, 255);
        table[NK_COLOR_SCROLLBAR] = nk_rgba(50, 58, 61, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR] = nk_rgba(48, 83, 111, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_HOVER] = nk_rgba(53, 88, 116, 255);
        table[NK_COLOR_SCROLLBAR_CURSOR_ACTIVE] = nk_rgba(58, 93, 121, 255);
        table[NK_COLOR_TAB_HEADER] = nk_rgba(48, 83, 111, 255);
        nk_style_from_table(ctx, table);
    } else {
        nk_style_default(ctx);
    }
}
