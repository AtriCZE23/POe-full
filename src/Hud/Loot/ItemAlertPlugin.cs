using Antlr4.Runtime;
using PoeFilterParser;
using PoeFilterParser.Model;
using PoeHUD.Controllers;
using PoeHUD.Framework;
using PoeHUD.Framework.Helpers;
using PoeHUD.Hud.Settings;
using PoeHUD.Hud.UI;
using PoeHUD.Models;
using PoeHUD.Models.Enums;
using PoeHUD.Models.Interfaces;
using PoeHUD.Poe;
using PoeHUD.Poe.Components;
using PoeHUD.Poe.Elements;
using PoeHUD.Poe.RemoteMemoryObjects;
using SharpDX;
using SharpDX.Direct3D9;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Windows.Forms;

namespace PoeHUD.Hud.Loot
{
    public class ItemAlertPlugin : SizedPluginWithMapIcons<ItemAlertSettings>
    {
        private readonly HashSet<long> playedSoundsCache;
        private readonly Dictionary<EntityWrapper, AlertDrawStyle> currentAlerts;
        private readonly HashSet<CraftingBase> craftingBases;
        private readonly HashSet<string> currencyNames;
        private Dictionary<long, LabelOnGround> currentLabels;
        public static PoeFilterVisitor visitor;
        public static bool holdKey;
        private readonly SettingsHub settingsHub;

        public ItemAlertPlugin(GameController gameController, Graphics graphics, ItemAlertSettings settings, SettingsHub settingsHub)
            : base(gameController, graphics, settings)
        {
            this.settingsHub = settingsHub;
            playedSoundsCache = new HashSet<long>();
            currentAlerts = new Dictionary<EntityWrapper, AlertDrawStyle>();
            currentLabels = new Dictionary<long, LabelOnGround>();
            currencyNames = LoadCurrency();
            craftingBases = LoadCraftingBases();
            GameController.Area.AreaChange += OnAreaChange;
            PoeFilterInit(settings.FilePath);
            settings.FilePath.OnFileChanged += () => PoeFilterInit(settings.FilePath);
        }

        private void PoeFilterInit(string path)
        {
            try
            {
                if (!string.IsNullOrEmpty(path))
                {
                    DebugPlug.DebugPlugin.LogMsg("Loading the Filter File", 4);
                    using (var fileStream = new StreamReader(path))
                    {
                        var input = new AntlrInputStream(fileStream.ReadToEnd());
                        var lexer = new PoeFilterLexer(input);
                        var tokens = new CommonTokenStream(lexer);
                        var parser = new PoeFilterParser.Model.PoeFilterParser(tokens);
                        parser.RemoveErrorListeners();
                        parser.AddErrorListener(new ErrorListener());
                        var tree = parser.main();
                        visitor = new PoeFilterVisitor(tree, GameController, Settings);
                    }
                }
                else
                {
                    Settings.ShouldUseFilterFile.Value = false;
                }
            }
            catch (SyntaxErrorException ex)
            {
                Settings.FilePath.Value = string.Empty;
                Settings.ShouldUseFilterFile.Value = false;
                MessageBox.Show($"Line: {ex.Line}:{ex.CharPositionInLine}, " +
                                $"{ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                visitor = null;
            }
            catch (Exception ex)
            {
                Settings.FilePath.Value = string.Empty;
                Settings.ShouldUseFilterFile.Value = false;
                MessageBox.Show(ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        public override void Dispose()
        {
            GameController.Area.AreaChange -= OnAreaChange;
        }

        public override void Render()
        {
            if (!holdKey && WinApi.IsKeyDown(Keys.F10))
            {
                holdKey = true;
                Settings.Enable.Value = !Settings.Enable.Value;
                SettingsHub.Save(settingsHub);
            }
            else if (holdKey && !WinApi.IsKeyDown(Keys.F10))
            {
                holdKey = false;
            }
            if (!Settings.Enable) { return; }

            if (Settings.Enable)
            {
                var pos = GameController.Player.GetComponent<Positioned>();

                var playerPos = pos.GridPos;
                var position = StartDrawPointFunc();
                const int BOTTOM_MARGIN = 2;
                var shouldUpdate = false;

                var validAlerts = currentAlerts.ToList().Where(
                    x => x.Key != null && x.Key.Address != 0 && x.Key.IsValid);

                foreach (KeyValuePair<EntityWrapper, AlertDrawStyle> kv in validAlerts)
                {
                    if (string.IsNullOrEmpty(kv.Value.Text))
                        continue;

                    LabelOnGround entityLabel;
                    if (!currentLabels.TryGetValue(kv.Key.Address, out entityLabel))
                    {
                        shouldUpdate = true;
                    }
                    else
                    {
                        if (Settings.BorderSettings.Enable)
                            DrawBorder(entityLabel);

                        if (Settings.ShowText)
                        {
                            if (entityLabel.CanPickUp || entityLabel.MaxTimeForPickUp.TotalSeconds == 0)
                            {
                                position = DrawText(playerPos, position, BOTTOM_MARGIN, kv, kv.Value.Text);
                            }
                            else if (!Settings.HideOthers)
                            {
                                // get current values
                                Color TextColor = kv.Value.TextColor;
                                Color BorderColor = kv.Value.BorderColor;
                                Color BackgroundColor = kv.Value.BackgroundColor;

                                if (Settings.DimOtherByPercentToggle)
                                {
                                    // edit values to new ones
                                    double ReduceByPercent = (double)Settings.DimOtherByPercent / 100;

                                    TextColor = ReduceNumbers(TextColor, ReduceByPercent);
                                    BorderColor = ReduceNumbers(BorderColor, ReduceByPercent);
                                    BackgroundColor = ReduceNumbers(BackgroundColor, ReduceByPercent);

                                    // backgrounds with low alpha start to look a little strange when dark so im adding an alpha threshold
                                    if (BackgroundColor.A < 210)
                                        BackgroundColor.A = 210;
                                }

                                // Complete new KeyValuePair with new stuff
                                AlertDrawStyle ModifiedDrawStyle = new AlertDrawStyle(kv.Value.Text, TextColor, kv.Value.BorderWidth, BorderColor, BackgroundColor, kv.Value.IconIndex);
                                KeyValuePair<EntityWrapper, AlertDrawStyle> NewKV = new KeyValuePair<EntityWrapper, AlertDrawStyle>(kv.Key, ModifiedDrawStyle);

                                position = DrawText(playerPos, position, BOTTOM_MARGIN, NewKV, kv.Value.Text);
                            }
                        }
                    }
                }
                Size = new Size2F(0, position.Y); //bug absent width

                if (shouldUpdate)
                {
                    currentLabels = GameController.Game.IngameState.IngameUi.ItemsOnGroundLabels
                        .GroupBy(y => y.ItemOnGround.Address).ToDictionary(y => y.Key, y => y.First());
                }
            }
        }

        private Color ReduceNumbers(Color oldColor, double percent)
        {
            Color newColor = oldColor;

            newColor.R = (byte)((double)oldColor.R - ((double)oldColor.R * percent));
            newColor.G = (byte)((double)oldColor.G - ((double)oldColor.G * percent));
            newColor.B = (byte)((double)oldColor.B - ((double)oldColor.B * percent));
            newColor.A = (byte)((double)oldColor.A - (((double)oldColor.A / 10) * percent));

            return newColor;
        }

        private Vector2 DrawText(Vector2 playerPos, Vector2 position, int BOTTOM_MARGIN,
            KeyValuePair<EntityWrapper, AlertDrawStyle> kv, string text)
        {
            var padding = new Vector2(5, 2);
            Vector2 delta = kv.Key.GetComponent<Positioned>().GridPos - playerPos;
            Vector2 itemSize = DrawItem(kv.Value, delta, position, padding, text);
            if (itemSize != new Vector2())
            {
                position.Y += itemSize.Y + BOTTOM_MARGIN;
            }
            return position;
        }

        protected override void OnEntityAdded(EntityWrapper entity)
        {
            if (Settings.Enable && entity != null && !GameController.Area.CurrentArea.IsTown
                && !currentAlerts.ContainsKey(entity) && entity.HasComponent<WorldItem>())
            {

                IEntity item = entity.GetComponent<WorldItem>().ItemEntity;

                if (Settings.ShouldUseFilterFile && !string.IsNullOrEmpty(Settings.FilePath))
                {
                    var result = visitor.Visit(item);
                    if (result != null)
                    {
                        AlertDrawStyle drawStyle = result;
                        PrepareForDrawingAndPlaySound(entity, drawStyle);
                    }
                }
                else
                {
                    ItemUsefulProperties props = initItem(item);
                    if (props == null)
                        return;

                    if (props.ShouldAlert(currencyNames, Settings))
                    {
                        AlertDrawStyle drawStyle = props.GetDrawStyle();
                        PrepareForDrawingAndPlaySound(entity, drawStyle);
                    }
                    Settings.ShouldUseFilterFile.Value = false;
                }
            }
        }

        private void PrepareForDrawingAndPlaySound(EntityWrapper entity, AlertDrawStyle drawStyle)
        {
            currentAlerts.Add(entity, drawStyle);
            CurrentIcons[entity] = new MapIcon(entity, new HudTexture("currency.png", Settings.LootIconBorderColor ? drawStyle.BorderColor : drawStyle.TextColor), () => Settings.ShowItemOnMap, Settings.LootIcon);

            if (Settings.PlaySound && !playedSoundsCache.Contains(entity.Id))
            {
                playedSoundsCache.Add(entity.Id);
                Sounds.AlertSound.Play(Settings.SoundVolume);
            }
        }

        protected override void OnEntityRemoved(EntityWrapper entity)
        {
            base.OnEntityRemoved(entity);
            currentAlerts.Remove(entity);
            currentLabels.Remove(entity.Address);
        }

        private static HashSet<CraftingBase> LoadCraftingBases()
        {
            if (!File.Exists("config/crafting_bases.txt"))
            {
                return new HashSet<CraftingBase>();
            }
            var hashSet = new HashSet<CraftingBase>();
            var parseErrors = new List<string>();
            string[] array = File.ReadAllLines("config/crafting_bases.txt");
            foreach (string text in array.Select(x => x.Trim()).Where(x => !string.IsNullOrWhiteSpace(x) && !x.StartsWith("#")))
            {
                string[] parts = text.Split(',');
                string itemName = parts[0].Trim();

                var item = new CraftingBase { Name = itemName };

                int tmpVal;
                if (parts.Length > 1 && int.TryParse(parts[1], out tmpVal))
                {
                    item.MinItemLevel = tmpVal;
                }

                if (parts.Length > 2 && int.TryParse(parts[2], out tmpVal))
                {
                    item.MinQuality = tmpVal;
                }

                const int RARITY_POSITION = 3;
                if (parts.Length > RARITY_POSITION)
                {
                    item.Rarities = new ItemRarity[parts.Length - 3];
                    for (int i = RARITY_POSITION; i < parts.Length; i++)
                    {
                        if (item.Rarities != null && !Enum.TryParse(parts[i], true, out item.Rarities[i - RARITY_POSITION]))
                        {
                            parseErrors.Add("Incorrect rarity definition at line: " + text);
                            item.Rarities = null;
                        }
                    }
                }

                if (!hashSet.Add(item))
                {
                    parseErrors.Add("Duplicate definition for item was ignored: " + text);
                }
            }

            if (parseErrors.Any())
            {
                throw new Exception("Error parsing config/crafting_bases.txt\r\n" + string.Join(Environment.NewLine, parseErrors));
            }

            return hashSet;
        }

        private static HashSet<string> LoadCurrency()
        {
            if (!File.Exists("config/currency.txt"))
            {
                return null;
            }
            var hashSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            string[] lines = File.ReadAllLines("config/currency.txt");
            lines.Where(x => !string.IsNullOrWhiteSpace(x) && !x.StartsWith("#")).ForEach(x => hashSet.Add(x.Trim().ToLowerInvariant()));
            return hashSet;
        }

        private void DrawBorder(LabelOnGround entityLabel)
        {
            IngameUIElements ui = GameController.Game.IngameState.IngameUi;
            if (entityLabel.IsVisible)
            {
                RectangleF rect = entityLabel.Label.GetClientRect();
                if ((ui.OpenLeftPanel.IsVisible && ui.OpenLeftPanel.GetClientRect().Intersects(rect)) ||
                    (ui.OpenRightPanel.IsVisible && ui.OpenRightPanel.GetClientRect().Intersects(rect)))
                    return;


                ColorNode borderColor = Settings.BorderSettings.BorderColor;
                if (!entityLabel.CanPickUp)
                {
                    borderColor = Settings.BorderSettings.NotMyItemBorderColor;
                    TimeSpan timeLeft = entityLabel.TimeLeft;
                    if (Settings.BorderSettings.ShowTimer && timeLeft.TotalMilliseconds > 0)
                    {
                        borderColor = Settings.BorderSettings.CantPickUpBorderColor;
                        Graphics.DrawText(timeLeft.ToString(@"mm\:ss"), Settings.BorderSettings.TimerTextSize, rect.TopRight.Translate(4, 0));
                    }
                }
                Graphics.DrawFrame(rect, Settings.BorderSettings.BorderWidth, borderColor);
            }
        }

        private Vector2 DrawItem(AlertDrawStyle drawStyle, Vector2 delta, Vector2 position, Vector2 padding, string text)
        {
            padding.X -= drawStyle.BorderWidth;
            padding.Y -= drawStyle.BorderWidth;
            double phi;
            double distance = delta.GetPolarCoordinates(out phi);
            float compassOffset = Settings.TextSize + 8;
            Vector2 textPos = position.Translate(-padding.X - compassOffset, padding.Y);
            Size2 textSize = Graphics.DrawText(text, Settings.TextSize, textPos, drawStyle.TextColor, FontDrawFlags.Right);
            if (textSize == new Size2()) { return new Vector2(); }
            int iconSize = drawStyle.IconIndex >= 0 ? textSize.Height : 0;
            float fullHeight = textSize.Height + 2 * padding.Y + 2 * drawStyle.BorderWidth;
            float fullWidth = textSize.Width + 2 * padding.X + iconSize + 2 * drawStyle.BorderWidth + compassOffset;
            var boxRect = new RectangleF(position.X - fullWidth, position.Y, fullWidth - compassOffset, fullHeight);
            Graphics.DrawBox(boxRect, drawStyle.BackgroundColor);

            RectangleF rectUV = GetDirectionsUV(phi, distance);
            var rectangleF = new RectangleF(position.X - padding.X - compassOffset + 6, position.Y + padding.Y,
                textSize.Height, textSize.Height);
            Graphics.DrawImage("directions.png", rectangleF, rectUV);

            if (iconSize > 0)
            {
                const float ICONS_IN_SPRITE = 4;
                var iconPos = new RectangleF(textPos.X - iconSize - textSize.Width, textPos.Y, iconSize, iconSize);
                float iconX = drawStyle.IconIndex / ICONS_IN_SPRITE;
                var uv = new RectangleF(iconX, 0, (drawStyle.IconIndex + 1) / ICONS_IN_SPRITE - iconX, 1);
                Graphics.DrawImage("item_icons.png", iconPos, uv);
            }
            if (drawStyle.BorderWidth > 0)
            {
                Graphics.DrawFrame(boxRect, drawStyle.BorderWidth, drawStyle.BorderColor);
            }
            return new Vector2(fullWidth, fullHeight);
        }

        private ItemUsefulProperties initItem(IEntity item)
        {
            BaseItemType bit = GameController.Files.BaseItemTypes.Translate(item.Path);
            if (bit == null)
                return null;

            string name = bit.BaseName;
            CraftingBase craftingBase = new CraftingBase();
            if (Settings.Crafting)
            {
                foreach (CraftingBase cb in craftingBases
                    .Where(cb => cb.Name
                    .Equals(name, StringComparison.InvariantCultureIgnoreCase) || new Regex(cb.Name)
                    .Match(name).Success))
                {
                    craftingBase = cb;
                    break;
                }
            }

            return new ItemUsefulProperties(name, item, craftingBase);
        }

        private string GetItemName(KeyValuePair<EntityWrapper, AlertDrawStyle> kv)
        {
            var itemEntity = kv.Key.GetComponent<WorldItem>().ItemEntity;

            var labelForEntity = GameController.EntityListWrapper.GetLabelForEntity(itemEntity);
            if (labelForEntity == null)
            {
                if (!itemEntity.IsValid)
                {
                    return null;
                }
                labelForEntity = kv.Value.Text;
            }

            return labelForEntity;
        }

        private void OnAreaChange(AreaController area)
        {
            playedSoundsCache.Clear();
            currentLabels.Clear();
            currentAlerts.Clear();
            CurrentIcons.Clear();
        }
    }
}