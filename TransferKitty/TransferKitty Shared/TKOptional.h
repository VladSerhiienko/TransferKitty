#pragma once

#include "TKConfig.h"

namespace tk {

constexpr size_t DefaultAlignment = sizeof(void*) << 1;

template <size_t Length, size_t Alignment = DefaultAlignment>
struct AlignedStorage {
    alignas(Alignment) uint8_t data[Length];
};

template <typename T>
class Optional {
    static constexpr size_t Size = sizeof(T);
    static constexpr size_t Alignment = alignof(T);
    T* ptr = nullptr;
    AlignedStorage<Size, Alignment> storage = {};

public:
    Optional() = default;
    Optional(const T& rhs) { initialize(rhs); }
    Optional(T&& rhs) { initialize(std::forward<T>(rhs)); }
    ~Optional() { deinitialize(); }

    Optional(const Optional& rhs) {
        if (rhs.initialized()) { initialize(*rhs.get()); }
    }

    Optional(Optional&& rhs) {
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
