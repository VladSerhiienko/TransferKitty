#pragma once

#include <cassert>
#include <cstdint>
#include <type_traits>
#include <utility>

#include "TKDebug.h"

#ifndef TK_FUNC_NAME
#define TK_FUNC_NAME __PRETTY_FUNCTION__
#endif

#ifndef outptr
#define outptr _Nonnull
#endif
#ifndef outptr_opt
#define outptr_opt _Nullable
#endif

#ifndef TK_STATIC_ASSERT
#ifndef static_assert
#include <AssertMacros.h>
#define TK_STATIC_ASSERT(condition) __Check_Compile_Time(condition)
#define TK_STATIC_ASSERT_MSG(condition, ...) __Check_Compile_Time(condition)
#else
#define TK_STATIC_ASSERT(condition) static_assert(condition, "")
#define TK_STATIC_ASSERT_MSG(condition, msg) static_assert(condition, msg)
#endif
#endif

#define TK_REDUNDANT(...) __VA_ARGS__

namespace tk {
namespace {
template <typename T>
constexpr void zeroMemory(T &obj) {
    TK_STATIC_ASSERT((std::is_pod_v<T>));
    for (size_t i = 0; i < sizeof(obj); ++i) { reinterpret_cast<uint8_t *>(&obj)[i] = 0; }
} // zeroMemory
template <typename T>
constexpr void swap(T &a, T &b) {
    std::swap(a, b);
} // swap

typedef void *BridgedHandle;
#ifdef __OBJC__
template <typename T>
inline T bridgePlatformObject(BridgedHandle boxed) {
    return (__bridge T)boxed;
}
template <typename T>
inline BridgedHandle boxPlatformObject(T *platformObj) {
    return (__bridge BridgedHandle)platformObj;
}
#endif

} // namespace
} // namespace tk
