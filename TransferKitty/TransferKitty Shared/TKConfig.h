#pragma once

#include <algorithm>
#include <cassert>
#include <cstdint>
#include <exception>
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

#ifndef TK_ASSERT
#define TK_ASSERT(...) assert(__VA_ARGS__)
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

#ifndef likely
#define likely(x) (x)
#endif

#ifndef unlikely
#define unlikely(x) (x)
#endif

#ifndef TK_PREDICT_TRUE
#define TK_PREDICT_TRUE(x) likely(x)
#define TK_PREDICT_FALSE(x) unlikely(x)
#endif

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

namespace details {
template <typename T = std::exception, typename... Args>
[[noreturn]] constexpr void raiseError(Args &&... args) {
    assert(false);
    throw T(std::forward<Args...>(args...));
}

template <typename T = std::exception, typename... Args>
inline constexpr void raiseErrorIf(const bool shouldRaiseError, Args &&... args) {
    if (TK_PREDICT_FALSE(shouldRaiseError)) { raiseError<T, Args...>(std::forward<Args...>(args...)); }
}
} // namespace details

template <typename T = std::exception, typename V, typename... Args>
inline constexpr V &&passthroughOrRaiseErrorIf(V &&value, const bool shouldRaiseError, Args &&... args) {
    details::raiseErrorIf<T, Args...>(TK_PREDICT_FALSE(shouldRaiseError), std::forward<Args...>(args...));
    return std::forward<V>(value);
}

template <typename T = std::exception, typename V, typename... Args>
inline constexpr V &&passthroughOrRaiseError(V &&value, Args &&... args) {
    details::raiseError<T, Args...>(std::forward<Args...>(args...));
    return std::forward<V>(value);
}

} // namespace tk
