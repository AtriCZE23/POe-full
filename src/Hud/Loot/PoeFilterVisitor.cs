﻿using Antlr4.Runtime;
using Antlr4.Runtime.Tree;
using PoeFilterParser.Model;
using PoeHUD.Controllers;
using PoeHUD.Models.Enums;
using PoeHUD.Models.Interfaces;
using PoeHUD.Poe.Components;
using SharpDX;
using System;
using System.Collections.Generic;
using System.Linq;

namespace PoeHUD.Hud.Loot
{
	public class PoeFilterVisitor : PoeFilterBaseVisitor<AlertDrawStyle>
	{
		private readonly GameController gameController;
		private readonly IParseTree tree;
		private readonly ItemAlertSettings settings;
		private IEntity entity;

		public PoeFilterVisitor(IParseTree tree, GameController gameController, ItemAlertSettings settings)
		{
			this.tree = tree;
			this.gameController = gameController;
			this.settings = settings;
		}

		public AlertDrawStyle Visit(IEntity entity)
		{
			this.entity = entity;
			return base.Visit(tree);
		}

		public override AlertDrawStyle VisitMain(PoeFilterParser.Model.PoeFilterParser.MainContext context)
		{
			if (entity == null || gameController == null || gameController.Files == null || gameController.Files.BaseItemTypes == null)
				return null;
			var filterEnabled = settings.WithBorder || settings.WithSound;
			var baseItemType = gameController.Files.BaseItemTypes.Translate(entity.Path);
			if (baseItemType == null)
				return null;
			var basename = baseItemType.BaseName;
			var dropLevel = baseItemType.DropLevel;
			Models.ItemClass tmp;
			string className;
			if (gameController.Files.ItemClasses.contents.TryGetValue(baseItemType.ClassName, out tmp))
				className = tmp.ClassName;
			else
				className = baseItemType.ClassName;
			var itemBase = entity.GetComponent<Base>();
			var width = baseItemType.Width;
			var height = baseItemType.Height;
			var blocks = context.block();
			var mods = entity.GetComponent<Mods>();
			var isSkillHGem = entity.HasComponent<SkillGem>();
			var SkillGemLevel = isSkillHGem ? entity.GetComponent<SkillGem>().GemLevel : 0;
			var isMap = entity.HasComponent<Map>();
			var stackSize = entity.GetComponent<Stack>().Size;
			var MapTier = 0;
            var isSynthesized = mods.Synthesised;
            var isFractured = mods.FracturedMods > 0;
            var anyEnchantment = false;

			var isShapedMap = false;
			var isElderMap = false;
			if (isMap)
			{
				MapTier = entity.GetComponent<Map>().Tier;
				foreach (var mod in mods.ItemMods)
					if (mod.Name == "MapElder")
						isElderMap = (mod.Value1 == 1);
					else if (mod.Name == "MapShaped")
						isShapedMap = (mod.Value1 == 1);
			}

			List<string> explicitMods = new List<string>();
			foreach (var mod in mods.ItemMods)
			{
				explicitMods.Add(mod.Name);
			}

			var itemRarity = mods.ItemRarity;
			var quality = 0;
			if (entity.HasComponent<Quality>()) { quality = entity.GetComponent<Quality>().ItemQuality; }
			var text = string.Concat(quality > 0 ? "Superior " : string.Empty, basename);
			var sockets = entity.GetComponent<Sockets>();
			var numberOfSockets = sockets.NumberOfSockets;
			var largestLinkSize = sockets.LargestLinkSize;
			var socketGroup = sockets.SocketGroup;
			var path = entity.Path;

			Color defaultTextColor;
			//if (basename.Contains("Portal") || basename.Contains("Wisdom")) { return null; }
			if (basename.Contains("Scroll")) { return null; }
			if (path.Contains("Currency")) { defaultTextColor = HudSkin.CurrencyColor; }
			else if (path.Contains("DivinationCards")) { defaultTextColor = HudSkin.DivinationCardColor; }
			else if (path.Contains("Talismans")) { defaultTextColor = HudSkin.TalismanColor; }
			else if (isSkillHGem) { defaultTextColor = HudSkin.SkillGemColor; }
			else defaultTextColor = AlertDrawStyle.GetTextColorByRarity(itemRarity);
			var defaultBorderWidth = isMap || path.Contains("VaalFragment") ? 1 : 0;

			foreach (var block in blocks)
			{
				var isShow = block.visibility().SHOW() != null;
				var itemLevelCondition = true;
				var dropLevelCondition = true;
				var poeClassCondition = true;
				var poeBaseTypeCondition = true;
				var poeRarityCondition = true;
				var poeQualityCondition = true;
				var poeWidthCondition = true;
				var poeHeightCondition = true;
				var poeSocketsCondition = true;
				var poeLinkedSocketsCondition = true;
				var poeSocketGroupCondition = true;
				var poeIdentifiedCondition = true;
				var poeCorruptedCondition = true;
				var poeElderCondition = true;
				var poeShaperCondition = true;
				var poeShapedMapCondition = true;
				var poeElderMapCondition = true;
				var backgroundColor = AlertDrawStyle.DefaultBackgroundColor;
				var borderColor = Color.White;
				var textColor = defaultTextColor;
				var borderWidth = defaultBorderWidth;
				var sound = -1;
				var statements = block.statement();
				var poeGemLevelCondition = true;
				var poeStackSizeCondition = true;
				var poeHasExplicitModCondition = true;
				var poeMapTierCondition = true;
                var poeSynthesizedCondition = true;
                var poeFracturedCondition = true;
                var poeAnyEnchantmentCondition = true;
                var poeHasEnchantmentCondition = true;

				foreach (var statement in statements)
				{
					var poeItemLevelContext = statement.poeItemLevel();
					if (poeItemLevelContext != null)
					{
						itemLevelCondition &= CalculateDigitsCondition(poeItemLevelContext.compareOpNullable(),
							poeItemLevelContext.digitsParams(), mods.ItemLevel);
					}
                    else {
						var poeDropLevelContext = statement.poeDropLevel();
						if (poeDropLevelContext != null)
						{
							dropLevelCondition &= CalculateDigitsCondition(poeDropLevelContext.compareOpNullable(),
								poeDropLevelContext.digitsParams(), dropLevel);
						}
                        else {
							var poeClassContext = statement.poeClass();
							if (poeClassContext != null)
							{
								poeClassCondition = poeClassContext.@params()
									.strValue().Any(y => className.Contains(GetRawText(y)));
							}
                            else {
								var poeBaseTypeContext = statement.poeBaseType();
								if (poeBaseTypeContext != null)
								{
									poeBaseTypeCondition = poeBaseTypeContext.@params()
										.strValue().Any(y => basename.Contains(GetRawText(y)));
								}
                                else {
									var poeRarityContext = statement.poeRarity();
									if (poeRarityContext != null)
									{
										var compareFunc = OpConvertor(poeRarityContext.compareOpNullable());
										poeRarityCondition &= poeRarityContext.rariryParams().rarityValue().Any(y =>
										{
											ItemRarity poeItemRarity;
											Enum.TryParse(GetRawText(y), true, out poeItemRarity);
											return compareFunc((int)itemRarity, (int)poeItemRarity);
										});
									}
                                    else {
										var poeQualityContext = statement.poeQuality();
										if (poeQualityContext != null)
										{
											poeQualityCondition &= CalculateDigitsCondition(poeQualityContext.compareOpNullable(),
												poeQualityContext.digitsParams(), quality);
										}
                                        else {
											var poeWidthContext = statement.poeWidth();
											if (poeWidthContext != null)
											{
												poeWidthCondition &= CalculateDigitsCondition(poeWidthContext.compareOpNullable(),
													poeWidthContext.digitsParams(), width);
											}
                                            else {
												var poeHeightContext = statement.poeHeight();
												if (poeHeightContext != null)
												{
													poeHeightCondition &= CalculateDigitsCondition(poeHeightContext.compareOpNullable(),
														poeHeightContext.digitsParams(), height);
												}
                                                else {
													var poeSocketsContext = statement.poeSockets();
													if (poeSocketsContext != null)
													{
														poeSocketsCondition &= CalculateDigitsCondition(poeSocketsContext.compareOpNullable(),
															poeSocketsContext.digitsParams(), numberOfSockets);
													}
                                                    else {
														var poeLinkedSocketsContext = statement.poeLinkedSockets();
														if (poeLinkedSocketsContext != null)
														{
															poeLinkedSocketsCondition &= CalculateDigitsCondition(poeLinkedSocketsContext.compareOpNullable(),
																poeLinkedSocketsContext.digitsParams(), largestLinkSize);
														}
                                                        else {
															var poeSocketGroupContext = statement.poeSocketGroup();
															if (poeSocketGroupContext != null)
															{
																poeSocketGroupCondition &= poeSocketGroupContext.socketParams()
																	.socketValue().Any(y =>
																	{
																		var poeSocketGroup = GetRawText(y);
																		return IsContainSocketGroup(socketGroup, poeSocketGroup);
																	});
															}
                                                            else {
																var poeBackgroundColorContext = statement.poeBackgroundColor();
																if (poeBackgroundColorContext != null)
																{
																	backgroundColor = ToColor(poeBackgroundColorContext.color());
																}
                                                                else {
																	var poeBorderColorContext = statement.poeBorderColor();
																	if (poeBorderColorContext != null)
																	{
																		borderColor = ToColor(poeBorderColorContext.color()); borderWidth = borderColor.A == 0 ? 0 : 1;
																	}
                                                                    else {
																		var poeTextColorContext = statement.poeTextColor();
																		if (poeTextColorContext != null)
																		{
																			textColor = ToColor(poeTextColorContext.color());
																		}
                                                                        else {
																			var poeAlertSoundContext = statement.poeAlertSound();
																			if (poeAlertSoundContext != null)
																			{
																				try
																				{
																					sound = Convert.ToInt32(poeAlertSoundContext.soundId().GetText());
																				}
																				catch (Exception)
																				{
																					sound = 1;
																				}
																			}
                                                                            else {
																				var poeIdentifiedContext = statement.poeIdentified();
																				if (poeIdentifiedContext != null)
																				{
																					var valFromFilter = Convert.ToBoolean(poeIdentifiedContext.Boolean().GetText());
																					poeIdentifiedCondition &= itemRarity != ItemRarity.Normal ?
																						valFromFilter == mods.Identified
																							: valFromFilter == false;
																				}
                                                                                else {
																					var poeCorruptedContext = statement.poeCorrupted();
																					if (poeCorruptedContext != null)
																					{
																						poeCorruptedCondition &= itemBase.isCorrupted == Convert.ToBoolean(poeCorruptedContext.Boolean().GetText());
																					}
                                                                                    else {
																						var poeElderContext = statement.poeElderItem();
                                                                                        if(poeElderContext != null)
																						{
																							poeElderCondition &= itemBase.isElder == Convert.ToBoolean(poeElderContext.Boolean().GetText());
																						}
                                                                                        else {
																							var poeShaperContext = statement.poeShaperItem();
                                                                                            if(poeShaperContext != null)
																							{
																								poeShaperCondition &= itemBase.isShaper == Convert.ToBoolean(poeShaperContext.Boolean().GetText());
																							}
                                                                                            else {
																								var poeShapedMapContext = statement.poeShapedMap();
                                                                                                if(poeShapedMapContext != null)
																								{
																									poeShapedMapCondition &= isShapedMap == Convert.ToBoolean(poeShapedMapContext.Boolean().GetText());
																								}
                                                                                                else {
																									var poeElderMapContext = statement.poeElderMap();
																									if (poeElderMapContext != null)
																									{
																										poeElderMapCondition &= isElderMap == Convert.ToBoolean(poeElderMapContext.Boolean().GetText());
																									}
																									else
																									{
																										var poeStackSizeContext = statement.poeStackSize();
																										if (poeStackSizeContext != null)
																										{
																											poeStackSizeCondition &= CalculateDigitsCondition(poeStackSizeContext.compareOpNullable(),
																												poeStackSizeContext.digitsParams(), stackSize);
																										}
																										else
																										{
																											var poeExplicitModContext = statement.poeHasExplicitMod();
                                                                                                            if (poeExplicitModContext != null)
                                                                                                            {
                                                                                                                poeHasExplicitModCondition &= poeExplicitModContext.@params()
                                                                                                                    .strValue().Any(y => explicitMods.Contains(GetRawText(y)));
                                                                                                            }
                                                                                                            else
                                                                                                            {
                                                                                                                var poeGemSkillContext = statement.poeGemLevel();
                                                                                                                if (poeGemSkillContext != null)
                                                                                                                {
                                                                                                                    poeGemLevelCondition &= CalculateDigitsCondition(poeGemSkillContext.compareOpNullable(),
                                                                                                                        poeGemSkillContext.digitsParams(), SkillGemLevel);
                                                                                                                }
                                                                                                                else
                                                                                                                {
                                                                                                                    var poeMapTierContext = statement.poeMapTier();
                                                                                                                    if (poeMapTierContext != null)
                                                                                                                    {
                                                                                                                        poeMapTierCondition &= CalculateDigitsCondition(poeMapTierContext.compareOpNullable(),
                                                                                                                            poeMapTierContext.digitsParams(), MapTier);
                                                                                                                    }
                                                                                                                    else
                                                                                                                    {
                                                                                                                        var poeIsSynthesizedContext = statement.poeSynthesisedItem();
                                                                                                                        if (poeIsSynthesizedContext != null)
                                                                                                                        {
                                                                                                                            poeSynthesizedCondition &= isSynthesized == Convert.ToBoolean(poeIsSynthesizedContext.Boolean().GetText());
                                                                                                                        }
                                                                                                                        else
                                                                                                                        {
                                                                                                                            var poeIsFracturedContext = statement.poeFracturedItem();
                                                                                                                            if (poeIsFracturedContext != null)
                                                                                                                            {
                                                                                                                                poeFracturedCondition &= isFractured == Convert.ToBoolean(poeIsFracturedContext.Boolean().GetText());
                                                                                                                            }
                                                                                                                            else
                                                                                                                            {
                                                                                                                                var poeAnyEnchantmentContext = statement.poeAnyEnchantment();
                                                                                                                                if (poeAnyEnchantmentContext != null)
                                                                                                                                {
                                                                                                                                    poeAnyEnchantmentCondition &= anyEnchantment == Convert.ToBoolean(poeAnyEnchantmentContext.Boolean().GetText());
                                                                                                                                }
                                                                                                                                else
                                                                                                                                {
                                                                                                                                    var poeHasEnchantmentContext = statement.poeHasEnchantment();
                                                                                                                                    if (poeHasEnchantmentContext != null)
                                                                                                                                    {
                                                                                                                                        poeHasEnchantmentCondition = poeBaseTypeContext.@params()
                                                                                                                                            .strValue().Any(y => explicitMods.Contains(GetRawText(y)));
                                                                                                                                    }
                                                                                                                                }
                                                                                                                            }
                                                                                                                        }
                                                                                                                    }
                                                                                                                }
                                                                                                            }
																										}
																									}
																								}
																							}
																						}
																					}
																				}
																			}
																		}
																	}
																}
															}
														}
													}
												}
											}
										}
									}
								}
							}
						}
					}
				}

				if (itemLevelCondition && dropLevelCondition && poeClassCondition && poeBaseTypeCondition
					&& poeRarityCondition && poeQualityCondition && poeWidthCondition && poeHeightCondition
					&& poeSocketsCondition && poeLinkedSocketsCondition && poeSocketGroupCondition && poeIdentifiedCondition
					&& poeCorruptedCondition && poeElderCondition && poeShaperCondition && poeShapedMapCondition
					&& poeElderMapCondition && poeStackSizeCondition && poeHasExplicitModCondition && poeGemLevelCondition
					&& poeMapTierCondition && poeSynthesizedCondition && poeFracturedCondition && poeAnyEnchantmentCondition
                    && poeHasEnchantmentCondition)
				{
					if (!isShow || (filterEnabled && !(settings.WithBorder && borderWidth > 0 || settings.WithSound && sound >= 0)))
						return null;

					int iconIndex;
					if (largestLinkSize == 6) { iconIndex = 3; }
					else if (numberOfSockets == 6) { iconIndex = 0; }
					else if (IsContainSocketGroup(socketGroup, "RGB")) { iconIndex = 1; }
					else iconIndex = -1;
					return new AlertDrawStyle(text, textColor, borderWidth, borderColor, backgroundColor, iconIndex);
				}
			}
			return null;
		}

		private string GetRawText(ParserRuleContext context)
		{
			return context.GetText().Trim('"');
		}

		private bool CalculateDigitsCondition(
			PoeFilterParser.Model.PoeFilterParser.CompareOpNullableContext compareOpNullable,
			PoeFilterParser.Model.PoeFilterParser.DigitsParamsContext digitsParams, int value)
		{
			var compareFunc = OpConvertor(compareOpNullable);
			return digitsParams.DIGITS().Any(y =>
			{
				var poeValue = Convert.ToInt32(y.GetText());
				return compareFunc(value, poeValue);
			});
		}

		private bool IsContainSocketGroup(List<string> socketGroup, string str)
		{
			str = string.Concat(str.OrderBy(y => y)); return
				socketGroup.Select(group => string.Concat(group.OrderBy(y => y)))
					.Any(sortedGroup => sortedGroup.Contains(str));
		}

		private Color ToColor(PoeFilterParser.Model.PoeFilterParser.ColorContext colorContext)
		{
			var red = Convert.ToByte(colorContext.red().GetText());
			var green = Convert.ToByte(colorContext.green().GetText());
			var blue = Convert.ToByte(colorContext.blue().GetText());
			var alphaContext = colorContext.alpha();
			var alpha = alphaContext.DIGITS() != null ? Convert.ToByte(alphaContext.GetText()) : 255;
			return new Color(red, green, blue, alpha);
		}

		private Func<int, int, bool> OpConvertor(
			PoeFilterParser.Model.PoeFilterParser.CompareOpNullableContext terminalnode)
		{
			var text = terminalnode.COMPAREOP()?.GetText() ?? "=";
			switch (text)
			{
				case "=": return (x, y) => x == y;
				case "<": return (x, y) => x < y;
				case ">": return (x, y) => x > y;
				case "<=": return (x, y) => x <= y;
				case ">=": return (x, y) => x >= y;
			}
			throw new ArrayTypeMismatchException();
		}
	}
}
