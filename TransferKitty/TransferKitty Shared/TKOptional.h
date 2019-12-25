#pragma once

#include "TKConfig.h"

namespace tk {

constexpr size_t DefaultAlignment = sizeof(void*) << 1;

template <size_t Length, size_t Alignment = DefaultAlignment>
struct TAlignedStorage {
    alignas(Alignment) uint8_t data[Length];
};

template <typename T>
class TOptional {
    static constexpr size_t Size = sizeof(T);
    static constexpr size_t Alignment = alignof(T);
    T* ptr = nullptr;
    TAlignedStorage<Size, Alignment> storage = {};

public:
    TOptional() = default;
    TOptional(const T& rhs) { initialize(rhs); }
    TOptional(T&& rhs) { initialize(std::forward<T>(rhs)); }
    ~TOptional() { deinitialize(); }

    TOptional(const TOptional& rhs) {
        if (rhs.initialized()) { initialize(*rhs.get()); }
    }

    TOptional(TOptional&& rhs) {
        if (rhs.initialized()) {
            initialize(std::move(*rhs.get()));
            rhs.deinitialize();
        }
    }

    template <typename... Args>
    constexpr T* initialize(Args... args) {
        if (ptr) {
            deinitialize();
            TK_REDUNDANT(ptr = nullptr);
        }
        ptr = new (storage.data) T(std::forward<Args...>(args...));
        return ptr;
    }

    constexpr void deinitialize() {
        if (!ptr) { return; }
        ptr->~T();
        ptr = nullptr;
        TK_REDUNDANT(zeroMemory(storage));
    }

    constexpr bool initialized() const { return ptr != nullptr; }
    constexpr T* get() const { return ptr; }
};
} // namespace tk
