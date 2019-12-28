#include "TKBlurHash.h"

#include <cassert>
#include <cmath>
#include <cstring>
#include <memory>
#include <vector>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

struct vec3 {
    union {
        struct {
            float x;
            float y;
            float z;
        };

        float v[3] = {0};
    };
};

static_assert(sizeof(vec3) == 3 * sizeof(float), "Size mismatch.");

struct u8vec4 {
    union {
        struct {
            uint8_t x;
            uint8_t y;
            uint8_t z;
            uint8_t w;
        };

        uint8_t v[4] = {0};
    };
};

static_assert(sizeof(u8vec4) == 4, "Size mismatch.");

template <typename T, size_t MaxRows, size_t MaxColumns>
struct stack_matrix {
    size_t n_rows = 0;
    size_t n_columns = 0;
    T elements[MaxRows * MaxColumns];

    constexpr T &at(const size_t x, const size_t y) { return elements[y * n_columns + x]; }
    constexpr const T &at(const size_t x, const size_t y) const { return elements[y * n_columns + x]; }
};

using factor_stack_matrix = stack_matrix<vec3, tk::blurhash::MAX_COMPONENT_COUNT, tk::blurhash::MAX_COMPONENT_COUNT>;

namespace {
char characters[] =
    "0123456789"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz"
    "#$%*+,-.:;=?@[]^_{|}~";

vec3 multiplyBasisFunction(size_t n_components_x, size_t n_components_y, const tk::utilities::ImageBuffer &image);
char *encode83(int value, int length, char *destination);
int decode83(const char *str, int from, int to);
int linearTosRGB(float value);
float sRGBToLinear(int value);
int encodeDC(float r, float g, float b);
int encodeAC(float r, float g, float b, float maximumValue);
vec3 decodeDC(int colorEnc);
vec3 decodeAC(int value, float maxAc);
float signedSqrt(float value);
float signedSqr(float value);

// clang-format off
tk::utilities::ImageBuffer composeBitmap(
    size_t width, size_t height,
    size_t numCompX, size_t numCompY,
    const factor_stack_matrix &factors);
// clang-format on

} // namespace

tk::blurhash::BlurHash tk::blurhash::BlurHashCodec::encode(size_t n_component_x,
                                                           size_t n_component_y,
                                                           const tk::utilities::ImageBuffer &image) {
    BlurHash result = {};

    if (n_component_x < MIN_COMPONENT_COUNT || n_component_x > MAX_COMPONENT_COUNT) { return {}; }
    if (n_component_y < MIN_COMPONENT_COUNT || n_component_y > MAX_COMPONENT_COUNT) { return {}; }

    factor_stack_matrix factors{n_component_y, n_component_x};

    for (uint8_t y = 0; y < n_component_y; y++) {
        for (uint8_t x = 0; x < n_component_x; x++) {
            const vec3 b = multiplyBasisFunction(x, y, image);
            factors.at(x, y) = b;

            //
            // printf("factors[%d %d] = %f %f %f\n", x, y, b.x, b.y, b.z);
            //
        }
    }

    float *dc = factors.elements[0].v;
    float *ac = dc + 3;
    int ac_count = int(n_component_x * n_component_y - 1);
    char *ptr = result.buffer;

    int encoded_components = int((n_component_x - 1) + (n_component_y - 1) * MAX_COMPONENT_COUNT);

    //
    // printf("size = %d\n", encoded_components);
    //

    ptr = encode83(encoded_components, 1, ptr);

    //
    // printf("size = %s\n", result.buffer);
    //

    float max_value;
    if (ac_count > 0) {
        float actual_max_value = 0;
        for (int i = 0; i < ac_count * 3; i++) { actual_max_value = fmaxf(fabsf(ac[i]), actual_max_value); }

        int quantised_max_value = fmaxf(0, fminf(82, floorf(actual_max_value * 166 - 0.5)));
        max_value = ((float)quantised_max_value + 1) / 166;
        ptr = encode83(quantised_max_value, 1, ptr);

        //
        // printf("max = %f, enc = %d\n", maximumValue, quantisedMaximumValue);
        //

    } else {
        max_value = 1;
        ptr = encode83(0, 1, ptr);
    }

    //
    // printf("max = %s\n", result.buffer);
    //

    int encoded_dc = encodeDC(dc[0], dc[1], dc[2]);

    //
    // printf("enc dc = %d, decoded dc = %f %f %f\n", encodedDC, dc[0], dc[1],
    // dc[2]);
    //

    ptr = encode83(encoded_dc, 4, ptr);

    for (int i = 0; i < ac_count; i++) {
        const float ac0 = ac[i * 3 + 0];
        const float ac1 = ac[i * 3 + 1];
        const float ac2 = ac[i * 3 + 2];
        const int encoded_ac = encodeAC(ac0, ac1, ac2, max_value);

        //
        // printf("enc ac = %d, decoded ac = %f %f %f\n", encodedAC, ac0, ac1,
        // ac2);
        //

        ptr = encode83(encoded_ac, 2, ptr);
    }

    *ptr = 0;
    result.size = std::distance(result.buffer, ptr);
    return result;
}

// https://github.com/woltapp/blurhash/blob/master/Kotlin/lib/src/main/java/com/wolt/blurhashkt/BlurHashDecoder.kt
tk::utilities::ImageBuffer tk::blurhash::BlurHashCodec::decode(const BlurHash &hash,
                                                               size_t width,
                                                               size_t height,
                                                               float punch) {
    if (hash.size < 6) { return {}; }

    //
    // printf("hash = %s\n", hash.buffer);
    //

    int n_components_encoded = decode83(hash.buffer, 0, 1);

    //
    // printf("size = %d\n", numCompEnc);
    //

    size_t n_components_x = (n_components_encoded % MAX_COMPONENT_COUNT) + 1;
    size_t n_components_y = (n_components_encoded / MAX_COMPONENT_COUNT) + 1;

    //
    // printf("x = %d, y = %d\n", numCompX, numCompY);
    //

    if (hash.size != (4 + 2 * n_components_x * n_components_y)) { return {}; }

    int max_ac_encoded = decode83(hash.buffer, 1, 2);
    float mac_ac = float(max_ac_encoded + 1) / 166.0f;

    //
    // printf("max = %f, enc = %d\n", maxAc, maxAcEnc);
    //

    factor_stack_matrix factors{n_components_y, n_components_x};

    int encoded_dc = decode83(hash.buffer, 2, 6);
    vec3 decoded_dc = decodeDC(encoded_dc);
    factors.at(0, 0) = decoded_dc;

    //
    // printf("enc dc = %d, decoded dc = %f %f %f\n", colorEnc, pixel.v[0],
    // pixel.v[1], pixel.v[2]);
    //

    size_t ac_count = n_components_x * n_components_y - 1;
    vec3 *ac_ptr = (&factors.at(0, 0)) + 1;

    uint8_t buffer_char_index = 1;
    for (uint32_t ac_index = 0; ac_index < ac_count; ac_index++) {
        const uint8_t from = 4 + buffer_char_index * 2;
        const uint8_t to = from + 2;
        ++buffer_char_index;

        int encoded_ac = decode83(hash.buffer, from, to);
        vec3 decoded_ac = decodeAC(encoded_ac, mac_ac * punch);

        //
        // printf("enc ac = %d, decoded ac = %f %f %f\n", colorEnc, pixel.v[0],
        // pixel.v[1], pixel.v[2]);
        //

        *ac_ptr = decoded_ac;
        ++ac_ptr;
    }

    return composeBitmap(width, height, n_components_x, n_components_y, factors);
}

namespace {
vec3 multiplyBasisFunction(size_t n_components_x, size_t n_components_y, const tk::utilities::ImageBuffer &image) {
    float r = 0, g = 0, b = 0;
    float normalization = (n_components_x == 0 && n_components_y == 0) ? 1 : 2;

    const size_t px = tk::formatSize(image.format);

    for (size_t y = 0; y < image.height; y++) {
        for (size_t x = 0; x < image.width; x++) {
            float basis =
                cosf(M_PI * n_components_x * x / image.width) * cosf(M_PI * n_components_y * y / image.height);
            r += basis * sRGBToLinear(image.buffer[y * image.stride + px * x + 0]);
            g += basis * sRGBToLinear(image.buffer[y * image.stride + px * x + 1]);
            b += basis * sRGBToLinear(image.buffer[y * image.stride + px * x + 2]);
        }
    }

    float scale = normalization / (image.width * image.height);

    vec3 result;
    result.v[0] = r * scale;
    result.v[1] = g * scale;
    result.v[2] = b * scale;

    return result;
}

float signedSqrt(float value) { return copysignf(sqrtf(fabsf(value)), value); }
float signedSqr(float value) { return copysignf(value * value, value); }

int linearTosRGB(float value) {
    // assert(value >= 0.0f && value <= 1.0f);
    float v = fmaxf(0.0f, fminf(1.0f, value));

    if constexpr (tk::blurhash::SRGB) {
        if (v <= 0.0031308) {
            return int(v * 12.92f * 255.0f + 0.5f);
        } else {
            return int((1.055f * powf(v, 1.0f / 2.4f) - 0.055) * 255.0f + 0.5f);
        }
    }

    return int(v * 255.0f);
}

float sRGBToLinear(int srgb) {
    assert(srgb <= 255);
    float v = (float)srgb / 255.0f;
    if constexpr (tk::blurhash::SRGB) {
        if (v <= 0.04045f) {
            return v / 12.92f;
        } else {
            return powf((v + 0.055f) / 1.055f, 2.4f);
        }
    }
    return v;
}

int encodeDC(float r, float g, float b) {
    int roundedR = linearTosRGB(r);
    int roundedG = linearTosRGB(g);
    int roundedB = linearTosRGB(b);
    return (roundedR << 16) + (roundedG << 8) + roundedB;
}

vec3 decodeDC(int encoded_factors) {
    int r = encoded_factors >> 16;
    int g = (encoded_factors >> 8) & 255;
    int b = encoded_factors & 255;
    return vec3{sRGBToLinear(r), sRGBToLinear(g), sRGBToLinear(b)};
}

int encodeAC(float r, float g, float b, float max_value) {
    const int quantR = static_cast<int>(fmaxf(0, fminf(18, floorf(signedSqrt(r / max_value) * 9.0f + 9.5f))));
    const int quantG = static_cast<int>(fmaxf(0, fminf(18, floorf(signedSqrt(g / max_value) * 9.0f + 9.5f))));
    const int quantB = static_cast<int>(fmaxf(0, fminf(18, floorf(signedSqrt(b / max_value) * 9.0f + 9.5f))));
    return quantR * 19 * 19 + quantG * 19 + quantB;
}

vec3 decodeAC(int value, float max_ac) {
    int r = value / (19 * 19);
    int g = (value / 19) % 19;
    int b = value % 19;
    return vec3{signedSqr(float(r - 9) / 9.0f) * max_ac,
                signedSqr(float(g - 9) / 9.0f) * max_ac,
                signedSqr(float(b - 9) / 9.0f) * max_ac};
}

int charIndex(int c) {
    for (int i = 0; i < (sizeof(characters) - 1); ++i) {
        if (characters[i] == c) { return i; };
    }

    return -1;
}

int decode83(const char *str, int from, int to) {
    int result = 0;
    for (int i = from; i < to; ++i) {
        int c = str[i];
        int index = charIndex(c);
        if (index != -1) { result = result * 83 + index; }
    }

    return result;
}

char *encode83(int value, int length, char *destination) {
    int divisor = 1;
    for (int i = 0; i < length - 1; i++) { divisor *= 83; }

    for (int i = 0; i < length; i++) {
        int digit = (value / divisor) % 83;
        divisor /= 83;
        *destination++ = characters[digit];
    }

    return destination;
}

tk::utilities::ImageBuffer composeBitmap(
    size_t width, size_t height, size_t n_components_x, size_t n_components_y, const factor_stack_matrix &factors) {
    static constexpr bool sRGB = tk::blurhash::SRGB;

    tk::utilities::ImageBuffer bitmap;
    bitmap.width = width;
    bitmap.height = height;
    bitmap.format = sRGB ? tk::TK_FORMAT_R8G8B8A8_SRGB : tk::TK_FORMAT_R8G8B8A8_UNORM;
    bitmap.stride = width * tk::formatSize(bitmap.format);
    bitmap.buffer.resize(width * height * tk::formatSize(bitmap.format));

    const size_t px = tk::formatSize(bitmap.format);
    for (size_t y = 0; y < height; ++y) {
        for (size_t x = 0; x < width; ++x) {
            float r = 0.0f;
            float g = 0.0f;
            float b = 0.0f;

            for (size_t j = 0; j < n_components_y; ++j) {
                for (size_t i = 0; i < n_components_x; ++i) {
                    float basis = (cos(M_PI * x * i / width) * cos(M_PI * y * j / height));
                    vec3 factors_ij = factors.at(i, j);
                    r += factors_ij.x * basis;
                    g += factors_ij.y * basis;
                    b += factors_ij.z * basis;
                }
            }

            const uint8_t ur = linearTosRGB(r);
            const uint8_t ug = linearTosRGB(g);
            const uint8_t ub = linearTosRGB(b);

            bitmap.buffer[y * bitmap.stride + x * px + 0] = ur;
            bitmap.buffer[y * bitmap.stride + x * px + 1] = ug;
            bitmap.buffer[y * bitmap.stride + x * px + 2] = ub;
            bitmap.buffer[y * bitmap.stride + x * px + 3] = 255;

            //
            // printf("[%d, %d] = %f %f %f -> %d %d %d\n", x, y, r, g, b, ur,
            // ug, ub);
            //
        }
    }

    return bitmap;
}
} // namespace
