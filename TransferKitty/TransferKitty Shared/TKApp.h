#pragma once

#import <CoreFoundation/CoreFoundation.h>
#import <MetalKit/MetalKit.h>

#include "TKConfig.h"

@protocol TKAppInputDelegate;

@interface TKApp : NSObject
@property(nonatomic, readwrite) id<TKAppInputDelegate> outptr inputDelegate;
- (nullable instancetype)initWithMetalKitView:(nonnull MTKView *)view;
- (void)startPeripheralWith:(nonnull NSArray *)sharedItems;
- (void)startCentral;
@end

@interface TKAppInput : NSObject
@property(nonatomic, readonly) void *outptr opaqueImplementationPtr;
@end

@protocol TKAppInputDelegate <NSObject>
- (void)app:(nonnull TKApp *)app input:(nonnull TKAppInput *)input;
@end
