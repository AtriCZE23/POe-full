﻿using PoeHUD.Hud.Settings;
using SharpDX;

namespace PoeHUD.Hud.AdvancedTooltip
{
    public sealed class ItemModsSettings : SettingsBase
    {
        public ItemModsSettings()
        {
            Enable = false;
            ModTextSize = new RangeNode<int>(13, 10, 50);
            BackgroundColor = new ColorBGRA(0, 0, 0, 220);
            PrefixColor = new ColorBGRA(136, 136, 255, 255);
            SuffixColor = new ColorBGRA(0, 206, 209, 255);
            T1Color = new ColorBGRA(255, 0, 255, 255);
            T2Color = new ColorBGRA(255, 255, 0, 255);
            T3Color = new ColorBGRA(0, 255, 0, 255);
        }

        public RangeNode<int> ModTextSize { get; set; }
        public ColorNode BackgroundColor { get; set; }
        public ColorNode PrefixColor { get; set; }
        public ColorNode SuffixColor { get; set; }
        public ColorNode T1Color { get; set; }
        public ColorNode T2Color { get; set; }
        public ColorNode T3Color { get; set; }
    }
}