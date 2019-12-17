#include "TKBlurHash.h"

#include <string.h>
#include <math.h>
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

namespace {
char characters[]="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~";
vec3 multiplyBasisFunction(int xComponent, int yComponent, int width, int height, uint8_t *rgb, size_t bytesPerRow);
char *encode83(int value, int length, char *destination);
int decode83(const uint8_t* str, int from, int to);
int linearTosRGB(float value);
float sRGBToLinear(int value);
float srgbToLinear(int colorEnc);
int linearToSrgb(float value);
int encodeDC(float r, float g, float b);
int encodeAC(float r, float g, float b, float maximumValue);
vec3 decodeDc(int colorEnc);
vec3 decodeAc(int value, float maxAc);
float signPow(float value, float exp);
float signedPow2(float value);
tk::BlurHashImage composeBitmap(int width, int height, int numCompX, int numCompY, std::vector<vec3> colors);
}

tk::BlurHash tk::BlurHashCodec::blurHashForPixels(int xComponents, int yComponents, int width, int height, uint8_t *rgb, size_t bytesPerRow) {
	char buffer[2 + 4 + (9 * 9 - 1) * 2 + 1];

	if(xComponents < 1 || xComponents > 9) return {};
	if(yComponents < 1 || yComponents > 9) return {};

    std::vector<vec3> factors(yComponents * xComponents * 3);
    // float* factors = factorStorage.data()->factors;
    // std::unique_ptr<float[]> factorsStorage;
    // factorsStorage.reset(new float[yComponents * xComponents * 3]);
    // float factors[yComponents][xComponents][3];

	for(int y = 0; y < yComponents; y++) {
		for(int x = 0; x < xComponents; x++) {
			vec3 b = multiplyBasisFunction(x, y, width, height, rgb, bytesPerRow);
            factors[y * xComponents + x] = b;
		}
	}

	float *dc = factors.front().v;
	float *ac = dc + 3;
	int acCount = xComponents * yComponents - 1;
	char *ptr = buffer;

	int sizeFlag = (xComponents - 1) + (yComponents - 1) * 9;
 
    //
    printf("size = %d\n", sizeFlag);
    //

	ptr = encode83(sizeFlag, 1, ptr);

    //
    *ptr = 0;
    printf("size = %s\n", buffer);
    //

	float maximumValue;
	if(acCount > 0) {
		float actualMaximumValue = 0;
		for(int i = 0; i < acCount * 3; i++) {
			actualMaximumValue = fmaxf(fabsf(ac[i]), actualMaximumValue);
		}

		int quantisedMaximumValue = fmaxf(0, fminf(82, floorf(actualMaximumValue * 166 - 0.5)));
		maximumValue = ((float)quantisedMaximumValue + 1) / 166;
		ptr = encode83(quantisedMaximumValue, 1, ptr);
  
        //
        printf("max = %f, enc = %d\n", maximumValue, quantisedMaximumValue);
        //
  
	} else {
		maximumValue = 1;
		ptr = encode83(0, 1, ptr);
	}

    //
    *ptr = 0;
    printf("max = %s\n", buffer);
    //

    int encodedDC = encodeDC(dc[0], dc[1], dc[2]);
    
    //
    printf("enc dc = %d, decoded dc = %f %f %f\n", encodedDC, dc[0], dc[1], dc[2]);
    //
    
	ptr = encode83(encodedDC, 4, ptr);

	for(int i = 0; i < acCount; i++) {
        const float ac0 = ac[i * 3 + 0];
        const float ac1 = ac[i * 3 + 1];
        const float ac2 = ac[i * 3 + 2];
        const int encodedAC = encodeAC(ac0, ac1, ac2, maximumValue);

        //
        printf("enc ac = %d, decoded ac = %f %f %f\n", encodedAC, ac0, ac1, ac2);
        //
        
		ptr = encode83(encodedAC, 2, ptr);
	}

	*ptr = 0;
    
    BlurHash result = {};
    result.buffer.resize(std::distance(buffer, ptr));
    memcpy(result.buffer.data(), buffer, result.buffer.size());
	return result;
}

// https://github.com/woltapp/blurhash/blob/master/Kotlin/lib/src/main/java/com/wolt/blurhashkt/BlurHashDecoder.kt
tk::BlurHashImage tk::BlurHashCodec::imageForBlurHash(const BlurHash& blurHash, int width, int height, float punch) {
    if (blurHash.buffer.size() < 6) {
        return {};
    }

    //
    printf("hash = %s\n", (const char*)blurHash.buffer.data());
    //

    int numCompEnc = decode83(blurHash.buffer.data(), 0, 1);

    //
    printf("size = %d\n", numCompEnc);
    //
    
    int numCompX = (numCompEnc % 9) + 1;
    int numCompY = (numCompEnc / 9) + 1;

    //
    printf("x = %d, y = %d\n", numCompX, numCompY);
    //
    
    if (blurHash.buffer.size() != (4 + 2 * numCompX * numCompY)) {
        return {};
    }
    
    int maxAcEnc = decode83(blurHash.buffer.data(), 1, 2);
    float maxAc = float(maxAcEnc + 1) / 166.0f;

    //
    printf("max = %f, enc = %d\n", maxAc, maxAcEnc);
    //
    
    std::vector<vec3> factors;
    factors.resize(numCompX * numCompY);

    int colorEnc = decode83(blurHash.buffer.data(), 2, 6);
    vec3 pixel = decodeDc(colorEnc);
    factors[0] = pixel;
    
    //
    printf("enc dc = %d, decoded dc = %f %f %f\n", colorEnc, pixel.v[0], pixel.v[1], pixel.v[2]);
    //
    
    
    for (size_t i = 1; i < factors.size(); ++i) {
        int from = int(4 + i * 2);
        int colorEnc = decode83(blurHash.buffer.data(), from, from + 2);
        pixel = decodeAc(colorEnc, maxAc * punch);
        
        //
        printf("enc ac = %d, decoded ac = %f %f %f\n", colorEnc, pixel.v[0], pixel.v[1], pixel.v[2]);
        //
        
        factors[i] = pixel;
    }
    
    return composeBitmap(width, height, numCompX, numCompY, factors);
}

namespace {
vec3 multiplyBasisFunction(int xComponent, int yComponent, int width, int height, uint8_t *rgb, size_t bytesPerRow) {
	float r = 0, g = 0, b = 0;
	float normalization = (xComponent == 0 && yComponent == 0) ? 1 : 2;

	for(int y = 0; y < height; y++) {
		for(int x = 0; x < width; x++) {
			float basis = cosf(M_PI * xComponent * x / width) * cosf(M_PI * yComponent * y / height);
			r += basis * sRGBToLinear(rgb[3 * x + 0 + y * bytesPerRow]);
			g += basis * sRGBToLinear(rgb[3 * x + 1 + y * bytesPerRow]);
			b += basis * sRGBToLinear(rgb[3 * x + 2 + y * bytesPerRow]);
		}
	}

	float scale = normalization / (width * height);

	vec3 result;
	result.v[0] = r * scale;
	result.v[1] = g * scale;
	result.v[2] = b * scale;

	return result;
}

int linearTosRGB(float value) {
	float v = fmaxf(0, fminf(1, value));
	if(v <= 0.0031308) return v * 12.92 * 255 + 0.5;
	else return (1.055 * powf(v, 1 / 2.4) - 0.055) * 255 + 0.5;
}

float sRGBToLinear(int value) {
	float v = (float)value / 255;
	if(v <= 0.04045) return v / 12.92;
	else return powf((v + 0.055) / 1.055, 2.4);
}

int encodeDC(float r, float g, float b) {
	int roundedR = linearTosRGB(r);
	int roundedG = linearTosRGB(g);
	int roundedB = linearTosRGB(b);
	return (roundedR << 16) + (roundedG << 8) + roundedB;
}
    
vec3 decodeDc(int colorEnc) {
    int r = colorEnc >> 16;
    int g = (colorEnc >> 8) & 255;
    int b = colorEnc & 255;
    return vec3{srgbToLinear(r), srgbToLinear(g), srgbToLinear(b)};
}

int encodeAC(float r, float g, float b, float maximumValue) {
	int quantR = fmaxf(0, fminf(18, floorf(signPow(r / maximumValue, 0.5) * 9 + 9.5)));
	int quantG = fmaxf(0, fminf(18, floorf(signPow(g / maximumValue, 0.5) * 9 + 9.5)));
	int quantB = fmaxf(0, fminf(18, floorf(signPow(b / maximumValue, 0.5) * 9 + 9.5)));

	return quantR * 19 * 19 + quantG * 19 + quantB;
}

float signPow(float value, float exp) {
	return copysignf(powf(fabsf(value), exp), value);
}

int charIndex(int c) {
    for (int i = 0; i < (sizeof(characters) - 1); ++i) {
        if (characters[i] == c) { return i; };
    }
    
    return -1;
}

int decode83(const uint8_t* str, int from, int to) {
    /* var result = 0
     * for (i in from until to) {
     *     val index = charMap[str[i]] ?: -1
     *     if (index != -1) {
     *         result = result * 83 + index
     *     }
     * }
     */

    int result = 0;
    for (int i = from; i < to; ++i) { // <=?
        int c = str[i];
        int index = charIndex(c);
        if (index != -1) {
            result = result * 83 + index;
        }
    }
    
    return result;
}

char *encode83(int value, int length, char *destination) {
	int divisor = 1;
	for(int i = 0; i < length - 1; i++) divisor *= 83;

	for(int i = 0; i < length; i++) {
		int digit = (value / divisor) % 83;
		divisor /= 83;
		*destination++ = characters[digit];
	}
	return destination;
}


float srgbToLinear(int colorEnc) {
    float v = float(colorEnc) / 255.0f;
    if (v <= 0.04045f) {
        return (v / 12.92f);
    }
    
    return pow((v + 0.055f) / 1.055f, 2.4f);
}

float signedPow2(float value) {
    return copysignf(powf(value, 2.0f), value);
}
    
vec3 decodeAc(int value, float maxAc) {
    int r = value / (19 * 19);
    int g = (value / 19) % 19;
    int b = value % 19;
    return vec3{
        signedPow2((r - 9) / 9.0f) * maxAc,
        signedPow2((g - 9) / 9.0f) * maxAc,
        signedPow2((b - 9) / 9.0f) * maxAc};
}
    
    
int linearToSrgb(float value) {
    float v = fminf(fmaxf(value, 0), 1);
    // val v = value.coerceIn(0f, 1f);
    
    if (v <= 0.0031308f) {
        return int(v * 12.92f * 255.0f + 0.5f);
    } else {
        return int((1.055f * pow(v, 1 / 2.4f) - 0.055f) * 255.0f + 0.5f);
    }
}


tk::BlurHashImage composeBitmap(int width, int height, int numCompX, int numCompY, std::vector<vec3> colors) {
    tk::BlurHashImage bitmap;
    bitmap.width = width;
    bitmap.height = height;
    bitmap.buffer.resize(width * height);

    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            float r = 0.0f;
            float g = 0.0f;
            float b = 0.0f;
            
            for (int j = 0; j < numCompY; ++j) {
                for (int i = 0; i < numCompX; ++i) {
            
                    float basis = (cos(M_PI * x * i / width) * cos(M_PI * y * j / height));
                    vec3 color = colors[j * numCompX + i];
                    r += color.x * basis;
                    g += color.y * basis;
                    b += color.z * basis;
                }
            }
            
            uint8_t ur = linearToSrgb(r);
            uint8_t ug = linearToSrgb(g);
            uint8_t ub = linearToSrgb(b);
            
            bitmap.buffer[y * width + x] = {ur, ug, ub};
        }
    }
    
    return bitmap;
}
}
