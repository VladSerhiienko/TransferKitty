#pragma once

#include "TKConfig.h"

namespace tk {

template <typename T>
class Span {
public:
    static constexpr size_t npos = ~(size_t(0));
    static constexpr Span make_empty() { return Span{}; }

    constexpr Span(T* array, size_t length) noexcept : array(array), length(length) {
        TK_ASSERT(array || !length && "Caught an invalid empty state.");
    }

    template <size_t N>
    constexpr Span(T (&a)[N]) noexcept : Span(a, N) {}
    constexpr Span() noexcept : Span(nullptr, 0) {}
    constexpr Span(Span&& rhs) noexcept : Span(rhs.array, rhs.length) { rhs = make_empty(); }
    constexpr Span(const Span& rhs) noexcept : Span(rhs.array, rhs.length) {}

    constexpr Span& operator=(Span&& rhs) noexcept {
        array = rhs.array;
        length = rhs.length;
        rhs = make_empty();
    }

    constexpr Span& operator=(const Span& rhs) noexcept {
        array = rhs.array;
        length = rhs.length;
    }

    constexpr const void* address() const noexcept { return array; }
    constexpr size_t byte_size() const noexcept { return sizeof(T) * length; }
    constexpr bool empty() const noexcept { return 0 == length; }

    template <typename U = T>
    constexpr U* data() const noexcept {
        return reinterpret_cast<U*>(array);
    }
    template <typename U = T>
    constexpr size_t size() const noexcept {
        return byte_size() / sizeof(U);
    }

    constexpr T& operator[](size_t i) const noexcept {
        TK_ASSERT(size() > i);
        return *(data() + i);
    }

    constexpr T& at(size_t i) const {
        return passthroughOrRaiseErrorIf(*(data() + i), TK_PREDICT_FALSE(i >= size()), "Caught out of range error.");
    }

    constexpr Span subspan(size_t subspan_position = 0, size_t subspan_length = npos) const {
        return TK_PREDICT_TRUE(subspan_position <= size())
                   ? (Span(data() + subspan_position,
                           (subspan_length == npos)
                               ? (size() - subspan_position)
                               : passthroughOrRaiseErrorIf(subspan_length,
                                                           subspan_length >= (size() - subspan_position),
                                                           "Caught out of range error.")))
                   : make_empty();
    }

    constexpr Span first(size_t subspan_length) const { return subspan(0, subspan_length); }
    constexpr Span last(size_t subspan_length) const { return subspan(size() - subspan_length, subspan_length); }

    template <typename U>
    Span<U> reinterpret() const {
        return Span<U>(data<U>(), size<U>());
    }

private:
    T* array = nullptr;
    size_t length = 0;
};

template <typename U, typename V>
constexpr bool spansReferenceEqualRange(const Span<U>& lhs, const Span<V>& rhs) {
    return (lhs.address() == rhs.address()) && (lhs.size() == rhs.size());
}

template <typename U, typename V>
constexpr bool operator==(const Span<U>& lhs, const Span<V>& rhs) {
    return spansReferenceEqualRange(lhs, rhs);
}
template <typename U, typename V>
constexpr bool operator!=(const Span<U>& lhs, const Span<V>& rhs) {
    return !spansReferenceEqualRange(lhs, rhs);
}

} // namespace tk
