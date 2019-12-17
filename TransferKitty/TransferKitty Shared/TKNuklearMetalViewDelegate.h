//
//  Renderer.h
//  EzriUI Shared
//
//  Created by Vlad Serhiienko on 9/29/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import <MetalKit/MetalKit.h>
#include "TKNuklearConfig.h"
#include "TKConfig.h"

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
    shouldUpdateFrame:(nonnull TKNuklearFrame*)currentFrame;
@end
