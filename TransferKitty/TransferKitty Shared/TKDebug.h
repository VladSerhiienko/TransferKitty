#pragma once

#ifndef TK_DEBUG
#ifdef DEBUG
#define TK_DEBUG 1
#else // DEBUG
#define TK_DEBUG 0
#endif // DEBUG
#endif // TK_DEBUG

#ifdef __OBJC__
#import <Foundation/Foundation.h>

@protocol TKDebugLogger <NSObject>
- (void)debugObject:(NSObject *)debugObject didLog:(NSString *)log;
@end

@interface TKDebug : NSObject
+ (void)addDebugLogger:(id<TKDebugLogger>)debugLogger;
+ (void)logf:(NSString *)format, ...;
+ (void)log:(NSString *)msg;
// clang-format off
+ (void)checkf:(bool)condition file:(NSString *)file line:(int)line tag:(NSString *)tag format:(NSString *)format, ...;
+ (void)check:(bool)condition file:(NSString *)file line:(int)line tag:(NSString *)tag msg:(NSString *)msg;
+ (void)dcheckf:(bool)condition file:(const char *)file line:(int)line tag:(const char *)tag format:(const char *)format, ...;
+ (void)dcheck:(bool)condition file:(const char *)file line:(int)line tag:(const char *)tag msg:(const char *)msg;
// clang-format on
@end

#define DCHECKF(condition, format, ...) \
    [TKDebug dcheckf:(condition) file:__FILE__ line:__LINE__ tag:__PRETTY_FUNCTION__ msg:format, __VA_ARGS__]
#define DCHECK(condition) \
    [TKDebug dcheck:(condition) file:__FILE__ line:__LINE__ tag:__PRETTY_FUNCTION__ msg:#condition]
#define DLOGF(format, ...) [TKDebug logf:format, __VA_ARGS__]
#define DLOG(log) [TKDebug log:log]

#endif // __OBJC__
