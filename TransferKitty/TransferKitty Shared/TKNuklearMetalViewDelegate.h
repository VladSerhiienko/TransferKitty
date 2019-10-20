//
//  Renderer.h
//  EzriUI Shared
//
//  Created by Vlad Serhiienko on 9/29/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import <MetalKit/MetalKit.h>

#define NK_INCLUDE_FIXED_TYPES
#define NK_INCLUDE_STANDARD_IO
#define NK_INCLUDE_STANDARD_VARARGS
#define NK_INCLUDE_DEFAULT_ALLOCATOR
#define NK_INCLUDE_VERTEX_BUFFER_OUTPUT
#define NK_INCLUDE_FONT_BAKING
#define NK_INCLUDE_DEFAULT_FONT
#include "nuklear.h"

#ifndef outptr
#define outptr _Nonnull
#endif
#ifndef outptr_opt
#define outptr_opt _Nullable
#endif

typedef NS_ENUM(NSUInteger, TKNuklearBuiltinColorTheme) {
    TKNuklearColorBuiltinThemeBlack = 0,
    TKNuklearColorBuiltinThemeWhite,
    TKNuklearColorBuiltinThemeRed,
    TKNuklearColorBuiltinThemeBlue,
    TKNuklearColorBuiltinThemeDark
};

@interface TKNuklearFrame : NSObject
@property (nonatomic, readonly) struct nk_context* outptr contextPtr;
@property (nonatomic, readonly) struct nk_convert_config* outptr convertConfigPtr;
@property (nonatomic, readonly) CGRect viewport;
@property (nonatomic, readwrite) CGSize viewportScale;
@end

@protocol TKNuklearFrameDelegate;

@interface TKNuklearRenderer : NSObject
@property (nonatomic, readonly) id<MTLDevice> outptr device;
@property (nonatomic, readwrite) id<TKNuklearFrameDelegate> outptr delegate;

-(nullable instancetype)initWithMetalDevice:(nonnull id<MTLDevice>)device
                           colorPixelFormat:(MTLPixelFormat)colorPixelFormat
                    depthStencilPixelFormat:(MTLPixelFormat)depthStencilPixelFormat
                                sampleCount:(NSUInteger)sampleCount;

- (void)drawNextFrameToRenderPass:(nonnull MTLRenderPassDescriptor*)renderPassDescriptor
                    commandBuffer:(nonnull id<MTLCommandBuffer>)commandBuffer
                     drawableSize:(CGSize)drawableSize;

-(void)deinit;
@end

@interface TKNuklearMetalViewDelegate : NSObject <MTKViewDelegate>
@property (nonatomic, readonly) id<MTLDevice> outptr_opt device;
@property (nonatomic, readwrite) id<TKNuklearFrameDelegate> outptr delegate;
-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
-(void)deinit;
@end

@protocol TKNuklearFrameDelegate <NSObject>
- (void)renderer:(nonnull TKNuklearRenderer*)renderer
    currentFrame:(nonnull TKNuklearFrame*)currentFrame;
@end
