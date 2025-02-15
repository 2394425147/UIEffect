﻿using UnityEngine.Rendering;

namespace Coffee.UIEffects
{
    public enum ToneFilter
    {
        None = 0,
        Grayscale = 1,
        Sepia = 2,
        Negative = 3,
        Retro = 4,
        Posterize = 5
    }

    public enum ColorFilter
    {
        None = 0,
        Multiply = 1,
        Additive = 2,
        Subtractive = 3,
        Replace = 4,
        MultiplyLuminance = 5,
        MultiplyAdditive = 6,
        HsvModifier = 7,
        Contrast = 8
    }

    public enum SamplingFilter
    {
        None = 0,
        BlurFast = 1,
        BlurMedium = 2,
        BlurDetail = 3,
        Pixelation = 4,
        RgbShift = 5,
        EdgeLuminance = 6,
        EdgeAlpha = 7
    }

    public enum TransitionFilter
    {
        None = 0,
        Fade = 1,
        Cutoff = 2,
        Dissolve = 3,
        Shiny = 4,
        Mask = 5,
        Melt = 6,
        Burn = 7
    }

    public enum BlendType
    {
        Custom,
        AlphaBlend,
        Multiply,
        Additive,
        SoftAdditive,
        MultiplyAdditive
    }

    public enum TargetMode
    {
        None = 0,
        Hue = 1,
        Luminance = 2
    }

    public enum ShadowMode
    {
        None = 0,
        Shadow,
        Shadow3,
        Outline,
        Outline8,
        Mirror
    }

    public enum GradationMode
    {
        None = 0,
        Horizontal,
        HorizontalGradient,
        Vertical,
        VerticalGradient,
        RadialFast,
        RadialDetail,
        DiagonalToRightBottom,
        DiagonalToLeftBottom,
        Angle,
        AngleGradient
    }

    internal static class BlendTypeConverter
    {
        public static (BlendMode, BlendMode) Convert(this (BlendType type, BlendMode src, BlendMode dst) self)
        {
            return self.type switch
            {
                BlendType.AlphaBlend => (BlendMode.One, BlendMode.OneMinusSrcAlpha),
                BlendType.Multiply => (BlendMode.DstColor, BlendMode.OneMinusSrcAlpha),
                BlendType.Additive => (BlendMode.One, BlendMode.One),
                BlendType.SoftAdditive => (BlendMode.OneMinusDstColor, BlendMode.One),
                BlendType.MultiplyAdditive => (BlendMode.DstColor, BlendMode.One),
                _ => (self.src, self.dst)
            };
        }

        public static BlendType Convert(this (BlendMode src, BlendMode dst) self)
        {
            return self switch
            {
                (BlendMode.One, BlendMode.OneMinusSrcAlpha) => BlendType.AlphaBlend,
                (BlendMode.DstColor, BlendMode.OneMinusSrcAlpha) => BlendType.Multiply,
                (BlendMode.One, BlendMode.One) => BlendType.Additive,
                (BlendMode.OneMinusDstColor, BlendMode.One) => BlendType.SoftAdditive,
                (BlendMode.DstColor, BlendMode.One) => BlendType.MultiplyAdditive,
                _ => BlendType.Custom
            };
        }
    }
}
