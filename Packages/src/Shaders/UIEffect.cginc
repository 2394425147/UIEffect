#ifndef UI_EFFECT_INCLUDED
#define UI_EFFECT_INCLUDED

uniform float4 _MainTex_TexelSize;
uniform float _ToneIntensity;
uniform half4 _ColorValue;
uniform float _ColorIntensity;
uniform float _SamplingIntensity;
uniform sampler2D _TransitionTex;
uniform float4 _TransitionTex_ST;
uniform float _TransitionRate;
uniform int _TransitionReverse;
uniform half4 _TransitionColor;
uniform float _TransitionSoftness;
uniform float _TransitionWidth;
uniform fixed4 _TargetColor;
uniform float _TargetRange;
uniform float _TargetSoftness;

// For performance reasons, limit the sampling of blur in TextMeshPro.
#ifdef UIEFFECT_TEXTMESHPRO
#ifdef SAMPLING_BLUR_MEDIUM
        #undef SAMPLING_BLUR_MEDIUM
        #define SAMPLING_BLUR_FAST 1
#endif
#ifdef SAMPLING_BLUR_DETAIL
        #undef SAMPLING_BLUR_DETAIL
        #define SAMPLING_BLUR_FAST 1
#endif
#endif

#define TONE_NONE (!TONE_GRAYSCALE && !TONE_SEPIA && !TONE_NEGATIVE && !TONE_RETRO && !TONE_POSTERIZE)
#define COLOR_NONE (!COLOR_MULTIPLY && !COLOR_ADDITIVE && !COLOR_SUBTRACTIVE && !COLOR_REPLACE && !COLOR_MULTIPLY_LUMINANCE && !COLOR_MULTIPLY_ADDITIVE && !COLOR_HSV_MODIFIER && !COLOR_CONTRAST)
#define SAMPLING_NONE (!SAMPLING_BLUR_FAST && !SAMPLING_BLUR_MEDIUM && !SAMPLING_BLUR_DETAIL && !SAMPLING_PIXELATION && !SAMPLING_RGB_SHIFT && !SAMPLING_EDGE)
#define TRANSITION_NONE (!TRANSITION_FADE && !TRANSITION_CUTOFF && !TRANSITION_DISSOLVE && !TRANSITION_SHINY && !TRANSITION_MASK && !TRANSITION_MELT && !TRANSITION_BURN)
#define TRANSITION_COLOR_NONE (!TRANSITION_COLOR_MULTIPLY && !TRANSITION_COLOR_ADDITIVE && !TRANSITION_COLOR_SUBTRACTIVE && !TRANSITION_COLOR_REPLACE && !TRANSITION_COLOR_MULTIPLY_LUMINANCE && !TRANSITION_COLOR_MULTIPLY_ADDITIVE && !TRANSITION_COLOR_HSV_MODIFIER && !TRANSITION_COLOR_CONTRAST)
#define TARGET_NONE (!TARGET_HUE && !TARGET_LUMINANCE)

#define UIEFFECT_SAMPLE(uv) uieffect_frag(uv)
#define UIEFFECT_SAMPLE_CLAMP(uv, uvMask) uieffect_frag(uv) \
    * step(uvMask.x, uv.x) * step(uv.x, uvMask.z) \
    * step(uvMask.y, uv.y) * step(uv.y, uvMask.w)

float3 rgb_to_hsv(float3 c)
{
    const float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    const float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    const float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    const float d = q.x - min(q.w, q.y);
    const float e = 1.0e-4;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 hsv_to_rgb(float3 c)
{
    const float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    const float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

float inv_lerp(const float from, const float to, const float value)
{
    return saturate(max(0, value - from) / max(0.001, to - from));
}

float transition_alpha(float2 uvLocal)
{
    #if TRANSITION_NONE
    return 1;
    #endif

    const float2 uv = uvLocal * _TransitionTex_ST.xy + _TransitionTex_ST.zw;
    const float alpha = tex2D(_TransitionTex, uv).a;
    return (1 - alpha) * _TransitionReverse + alpha * (1 - _TransitionReverse);
}


half get_target_rate(const half3 color)
{
    #if TARGET_NONE
    return 1;
    #endif

    if (1 <= _TargetRange) return 1;
    if (_TargetRange <= 0) return 0;

    half diff = 0;
    #if TARGET_HUE // Target.Hue
    {
        const half value = rgb_to_hsv(color).x;
        const half target = rgb_to_hsv(_TargetColor).x;
        diff = abs(target - value);
        diff = min(diff, 1 - diff);
    }
    #elif TARGET_LUMINANCE // Target.Luminance
    {
        const half value = Luminance(color);
        const half target = Luminance(_TargetColor);
        diff = abs(target - value);
    }
    #endif

    return 1 - inv_lerp(_TargetRange * (1 - _TargetSoftness), _TargetRange, diff);
}

half4 apply_tone_filter(half4 color)
{
    #if TONE_GRAYSCALE // Tone.Grayscale
    color.rgb = lerp(color.rgb, Luminance(color.rgb), _ToneIntensity);
    #elif TONE_SEPIA // Tone.Sepia
    color.rgb = lerp(color.rgb, Luminance(color.rgb) * half3(1.07, 0.74, 0.43), _ToneIntensity);
    #elif TONE_NEGATIVE // Tone.Negative
    color.rgb = lerp(color.rgb, (1 - color.rgb) * color.a, _ToneIntensity);
    #elif TONE_RETRO // Tone.Retro
    const fixed l = Luminance(color.rgb);
    const fixed r0 = step(l, 0.25);
    const fixed r1 = step(l, 0.5);
    const fixed r2 = step(l, 0.75);
    const fixed3 retro = fixed3(0.06, 0.22, 0.06) * r0 // 0.0-0.25: (15, 56, 15)
        + fixed3(0.19, 0.38, 0.19) * (1 - r0) * r1 // 0.25-0.5: (48, 98, 48)
        + fixed3(0.54, 0.67, 0.06) * (1 - r1) * r2 // 0.5-0.75: (139, 172, 15)
        + fixed3(0.60, 0.74, 0.06) * (1 - r2); // 0.75-1.0: (155, 188, 15)
    color.rgb = lerp(color.rgb, retro * color.a, _ToneIntensity);
    #elif TONE_POSTERIZE // Tone.Posterize
    const half3 hsv = rgb_to_hsv(color.rgb);
    const int div = round(lerp(48, 4, _ToneIntensity) / 2) * 2;
    color.rgb = hsv_to_rgb((floor(hsv * div) + 0.5) / div) * color.a;
    #endif

    return color;
}

half4 apply_color_filter(half4 color, const half4 factor, const float intensity)
{
    const half4 inColor = color;
    #if COLOR_NONE // Color.None
    {
        return color;
    }
    #elif COLOR_MULTIPLY // Color.Multiply
    {
        color.rgb = color.rgb * factor.rgb;
    }
    #elif COLOR_ADDITIVE // Color.Additive
    {
        color.rgb = color.rgb + factor.rgb * color.a;
    }
    #elif COLOR_SUBTRACTIVE // Color.Subtractive
    {
        color.rgb = color.rgb - factor.rgb * color.a;
    }
    #elif COLOR_REPLACE // Color.Replace
    {
        color.rgb = factor.rgb * color.a;
    }
    #elif COLOR_MULTIPLY_LUMINANCE // Color.MultiplyLuminance
    {
        color.rgb = (1 + Luminance(color.rgb)) * factor.rgb / 2 * color.a;
    }
    #elif COLOR_MULTIPLY_ADDITIVE // Color.MultiplyAdditive
    {
        color.rgb = color.rgb * (1 + factor.rgb);
    }
    #elif COLOR_HSV_MODIFIER // Color.HsvModifier
    {
        const float3 hsv = rgb_to_hsv(color.rgb);
        color.rgb = hsv_to_rgb(hsv + factor.rgb) * color.a * factor.a;
        color.a = color.a * factor.a;
    }
    #elif COLOR_CONTRAST // Color.Contrast
    {
        color.rgb = ((color.rgb - 0.5) * (factor.r + 1) + 0.5 + factor.g * 1.5) * color.a * factor.a;
        color.a = color.a * factor.a;
    }
    #endif
    return lerp(inColor, color, intensity);
}


half4 apply_transition_color_filter(half4 color, const half4 factor, const float intensity)
{
    const half4 inColor = color;
    #if TRANSITION_COLOR_NONE // Color.None
    {
        return color;
    }
    #elif TRANSITION_COLOR_MULTIPLY // Color.Multiply
    {
        color.rgb = color.rgb * factor.rgb;
    }
    #elif TRANSITION_COLOR_ADDITIVE // Color.Additive
    {
        color.rgb = color.rgb + factor.rgb * color.a;
    }
    #elif TRANSITION_COLOR_SUBTRACTIVE // Color.Subtractive
    {
        color.rgb = color.rgb - factor.rgb * color.a;
    }
    #elif TRANSITION_COLOR_REPLACE // Color.Replace
    {
        color.rgb = factor.rgb * color.a;
    }
    #elif TRANSITION_COLOR_MULTIPLY_LUMINANCE // Color.MultiplyLuminance
    {
        color.rgb = (1 + Luminance(color.rgb)) * factor.rgb / 2 * color.a;
    }
    #elif TRANSITION_COLOR_MULTIPLY_ADDITIVE // Color.MultiplyAdditive
    {
        color.rgb = color.rgb * (1 + factor.rgb);
    }
    #elif TRANSITION_COLOR_HSV_MODIFIER // Color.HsvModifier
    {
        const float3 hsv = rgb_to_hsv(color.rgb);
        color.rgb = hsv_to_rgb(hsv + factor.rgb) * color.a * factor.a;
        color.a = color.a * factor.a;
    }
    #elif TRANSITION_COLOR_CONTRAST // Color.Contrast
    {
        color.rgb = ((color.rgb - 0.5) * (factor.r + 1) + 0.5 + factor.g * 1.5) * color.a * factor.a;
        color.a = color.a * factor.a;
    }
    #endif
    return lerp(inColor, color, intensity);
}

half4 apply_sampling_filter(float2 uv, const float4 uvMask, const float2 uvLocal)
{
    #if SAMPLING_BLUR_FAST || SAMPLING_BLUR_MEDIUM || SAMPLING_BLUR_DETAIL
    {
        if (0 < _SamplingIntensity && -4 < uvLocal.x + uvLocal.y)
        {
    #if SAMPLING_BLUR_FAST
            const int KERNEL_SIZE = 5;
            const float KERNEL_[5] = {0.2486, 0.7046, 1.0, 0.7046, 0.2486};
    #elif SAMPLING_BLUR_MEDIUM
            const int KERNEL_SIZE = 9;
            const float KERNEL_[9] = { 0.0438, 0.1719, 0.4566, 0.8204, 1.0, 0.8204, 0.4566, 0.1719, 0.0438};
    #elif SAMPLING_BLUR_DETAIL
            const int KERNEL_SIZE = 13;
            const float KERNEL_[13] = { 0.0438, 0.1138, 0.2486, 0.4566, 0.7046, 0.9141, 1.0, 0.9141, 0.7046, 0.4566, 0.2486, 0.1138, 0.0438};
    #endif

            float4 o = 0;
            float sum = 0;
            float2 shift = 0;
            const half2 blur = _MainTex_TexelSize.xy * _SamplingIntensity * 2;
            for (int x = 0; x < KERNEL_SIZE; x++)
            {
                shift.x = blur.x * (float(x) - KERNEL_SIZE / 2);
                for (int y = 0; y < KERNEL_SIZE; y++)
                {
                    shift.y = blur.y * (float(y) - KERNEL_SIZE / 2);
                    const float2 bluredUv = uv + shift;
                    const float weight = KERNEL_[x] * KERNEL_[y]
                        * step(uvMask.x, bluredUv.x) * step(bluredUv.x, uvMask.z)
                        * step(uvMask.y, bluredUv.y) * step(bluredUv.y, uvMask.w);
                    o += UIEFFECT_SAMPLE(bluredUv) * weight;
                    sum += weight;
                }
            }

            return 0 < sum ? o / sum : 0;
        }
    }
    #endif

    return UIEFFECT_SAMPLE_CLAMP(uv, uvMask);
}

float2 move_transition_filter(const float4 uvMask, const float alpha)
{
    // Transition.Melt/Burn
    #if !TRANSITION_MELT && !TRANSITION_BURN
    {
        return 0;
    }
    #endif

    const float factor = alpha - _TransitionRate * (1 + _TransitionWidth * 1.5) + _TransitionWidth;
    const float band = max(0, _TransitionWidth - factor);

    #if TRANSITION_MELT
    {
        return float2(0, +band * band * (uvMask.w - uvMask.y) / max(0.01, _TransitionWidth));
    }
    #elif TRANSITION_BURN
    {
        return float2(0, -band * band * (uvMask.w - uvMask.y) / max(0.01, _TransitionWidth));
    }
    #endif

    return 0;
}

half4 apply_transition_filter(half4 color, const float alpha)
{
    #if TRANSITION_FADE  // Transition.Fade
    {
        color *= saturate(alpha + 1 - _TransitionRate * 2);
    }
    #elif TRANSITION_CUTOFF  // Transition.Cutoff
    {
        color *= step(0.001, color.a * alpha - _TransitionRate);
    }
    // Transition.Dissolve/Shiny/ShinyOnly/Melt
    #elif TRANSITION_DISSOLVE || TRANSITION_SHINY || TRANSITION_MASK || TRANSITION_MELT || TRANSITION_BURN
    {
        const float factor = alpha - _TransitionRate * (1 + _TransitionWidth) + _TransitionWidth;
        const float softness = max(0.0001, _TransitionWidth * _TransitionSoftness);
        // const fixed bandLerp = step(factor, color.a) * saturate((_TransitionWidth - factor) * 1 / softness);
        const fixed bandLerp = saturate((_TransitionWidth - factor) * 1 / softness);
        const fixed softLerp = saturate(factor * 2 / softness);
        half4 bandColor = apply_transition_color_filter(half4(color.rgb, 1), half4(_TransitionColor.rgb, 1),
                                                        _TransitionColor.a);
        // bandColor.a *= color.a;
        bandColor *= color.a;

        #if TRANSITION_MELT
        {
            color = lerp(color, bandColor, bandLerp);
            // return color * color.a;
            return color;
        }
        #elif TRANSITION_BURN
        {
            color = lerp(color, bandColor, bandLerp * 1.25);
            color.a *= 1 - inv_lerp(0.85, 1.0, bandLerp * 1.25);
            color.rgb *= (1 - inv_lerp(0.85, 1.0, bandLerp * 1.3)) * color.a;
            return color;
        }
        #endif

        color.rgb = lerp(color.rgb, bandColor, bandLerp * softLerp);

        #if TRANSITION_DISSOLVE
        {
            color *= softLerp;
        }
        #elif TRANSITION_MASK
        {
            color *= bandLerp * softLerp;
        }
        #endif
    }
    #endif

    return color;
}

half to_value(float4 c)
{
    #if SAMPLING_EDGE_LUMINANCE
    return Luminance(c) * c.a;
    #elif SAMPLING_EDGE_ALPHA
    return c.a;
    #endif
    return 0;
}

half4 uieffect_internal(float2 uv, const float4 uvMask, const float2 uvLocal)
{
    const half alpha = transition_alpha(uvLocal);
    uv += move_transition_filter(uvMask, alpha);
    half4 color = apply_sampling_filter(uv, uvMask, uvLocal);
    color = apply_tone_filter(color);
    color = apply_transition_filter(color, alpha);

    if (-4 <= uvLocal.x + uvLocal.y)
    {
        color = apply_color_filter(color, _ColorValue, _ColorIntensity);
    }

    return color;
}

half4 uieffect(float2 uv, const float4 uvMask, const float2 uvLocal)
{
    const fixed4 origin = UIEFFECT_SAMPLE_CLAMP(uv, uvMask);
    const half rate = get_target_rate(origin);

    // Sampling.Pixelation
    #if SAMPLING_PIXELATION
    {
        const half2 pixelSize = max(2, (1 - lerp(0.5, 0.95, _SamplingIntensity)) * _MainTex_TexelSize.zw);
        uv = round(uv * pixelSize) / pixelSize;
    }
    // Sampling.RgbShift
    #elif SAMPLING_RGB_SHIFT
    {
        const half2 offset = half2(_SamplingIntensity * _MainTex_TexelSize.x * 20, 0);
        const half2 r = uieffect_internal(uv + offset, uvMask, uvLocal).ra;
        const half2 g = uieffect_internal(uv, uvMask, uvLocal).ga;
        const half2 b = uieffect_internal(uv - offset, uvMask, uvLocal).ba;
        return half4(r.x * r.y, g.x * g.y, b.x * b.y, (r.y + g.y + b.y) / 3);
    }
    // Sampling.EdgeLuminance/EdgeAlpha
    #elif SAMPLING_EDGE_LUMINANCE || SAMPLING_EDGE_ALPHA
    {
        // Pixel size
        const float dx = _MainTex_TexelSize.x;
        const float dy = _MainTex_TexelSize.y;

        // Pixel values around the current pixel (3x3, 8 neighbors)
        const float2 uv00 = uv + half2(-dx, -dy);
        const half v00 = to_value(UIEFFECT_SAMPLE_CLAMP(uv00, uvMask));
        const float2 uv01 = uv + half2(-dx, 0.0);
        const half v01 = to_value(UIEFFECT_SAMPLE_CLAMP(uv01, uvMask));
        const float2 uv02 = uv + half2(-dx, +dy);
        const half v02 = to_value(UIEFFECT_SAMPLE_CLAMP(uv02, uvMask));
        const float2 uv10 = uv + half2(0.0, -dy);
        const half v10 = to_value(UIEFFECT_SAMPLE_CLAMP(uv10, uvMask));
        const float2 uv12 = uv + half2(0.0, +dy);
        const half v12 = to_value(UIEFFECT_SAMPLE_CLAMP(uv12, uvMask));
        const float2 uv20 = uv + half2(+dx, -dy);
        const half v20 = to_value(UIEFFECT_SAMPLE_CLAMP(uv20, uvMask));
        const float2 uv21 = uv + half2(+dx, 0.0);
        const half v21 = to_value(UIEFFECT_SAMPLE_CLAMP(uv21, uvMask));
        const float2 uv22 = uv + half2(+dx, +dy);
        const half v22 = to_value(UIEFFECT_SAMPLE_CLAMP(uv22, uvMask));

        // Apply Sobel operator
        half sobel_h = v00 * -1.0 + v01 * -2.0 + v02 * -1.0 + v20 * 1.0 + v21 * 2.0 + v22 * 1.0;
        half sobel_v = v00 * -1.0 + v10 * -2.0 + v20 * -1.0 + v02 * 1.0 + v12 * 2.0 + v22 * 1.0;

        const half sobel = sqrt(sobel_h * sobel_h + sobel_v * sobel_v) * _SamplingIntensity;
        return lerp(0, uieffect_internal(uv, uvMask, uvLocal), inv_lerp(0.5, 1, sobel));
    }
    #endif

    return lerp(origin, uieffect_internal(uv, uvMask, uvLocal), rate);
}

#endif // UI_EFFECT_INCLUDED