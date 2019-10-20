//
//  Nuklear.metal
//  EzriUI
//
//  Created by Vlad Serhiienko on 9/29/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

typedef struct {
    float2 position [[attribute(0)]];
    float2 uv       [[attribute(1)]];
    float4 color    [[attribute(2)]];
} NkVertex;

typedef struct {
    float4 position [[position]];
    float2 uv;
    float4 color;
} NkColorInOut;

typedef struct {
    matrix_float4x4 proj;
} NkUniforms;

vertex NkColorInOut nkVertexShader(
    NkVertex in             [[ stage_in ]],
    constant NkUniforms & u [[ buffer(1) ]]) {

    float4 position = float4(in.position, 0.0, 1.0);
    
    NkColorInOut out;
    out.position = u.proj * position;
    out.uv = in.uv;
    out.color = in.color;
    return out;
}

fragment float4 nkFragmentShader(
    NkColorInOut in      [[ stage_in ]],
    texture2d<half> font [[ texture(0) ]]) {
    
    constexpr sampler fontSampler(mip_filter::linear,
                                  mag_filter::linear,
                                  min_filter::linear);
    
    half4 colorSample = font.sample(fontSampler, in.uv);
    return float4(colorSample) * in.color;
}
