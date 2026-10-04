local _, ns = ...
local L = ns.L

local category

local function Refresh() if ns.RefreshAll then ns.RefreshAll() end end

-- (1.6) Each format with a sample built from the current settings (style,
-- decimals, abbreviation), e.g. "Current (percent): 12.3k (82%)".
local function FormatList(kind, list)
  for _, key in ipairs(ns.FORMATS) do list[#list + 1] = { key, ns.FormatLabel(key, kind) } end
  return list
end
local function HealthFormatOptions() return FormatList("health", {}) end
local function PowerFormatOptions() return FormatList("power", {}) end

local function AlignOptions()
  local list = {}
  for _, key in ipairs(ns.ALIGNS) do list[#list + 1] = { key, L[ns.ALIGN_LABELS[key]] } end
  return list
end

local function ColorOptions()
  local list = {}
  for _, key in ipairs(ns.COLORS) do list[#list + 1] = { key, L[ns.COLOR_LABELS[key]] } end
  return list
end

local function StyleOptions()
  local list = {}
  for _, key in ipairs(ns.STYLES) do list[#list + 1] = { key, L[ns.STYLE_LABELS[key]] } end
  return list
end

local function GroupHealthOptions() return FormatList("health", { { "inherit", L["Like general format"] } }) end
local function GroupPowerOptions() return FormatList("power", { { "inherit", L["Like general format"] } }) end

local function FontOptions()
  local list = {}
  for _, key in ipairs(ns.FONTS) do list[#list + 1] = { key, L[ns.FONT_LABELS[key]] } end
  return list
end

-- (1.10) Hide at full health per frame.
local function HideFullOptions()
  return { { "inherit", L["Like general setting"] }, { "on", L["Hide"] }, { "off", L["Show"] } }
end

-- One header, health format, hide at full health and power format per unit
-- group (compact frames: no power format).
local function GroupFormatItems()
  local items = {}
  for _, g in ipairs(ns.GROUPS) do
    items[#items + 1] = { header = g.name }
    items[#items + 1] = { key = "healthFormat" .. g.id, kind = "dropdown", name = "Health format",
      tip = "Own health format for this frame. 'Like general format' uses the format from the Text page.",
      options = GroupHealthOptions, onChange = Refresh }
    items[#items + 1] = { key = "hideFull" .. g.id, kind = "dropdown", name = "Hide at full health",
      tip = "Hides the health text of this frame at full health. 'Like general setting' follows Hide at full health on the Text page. Only works when the game lets addons read the values (mostly out of combat), otherwise the text stays.",
      options = HideFullOptions, onChange = Refresh }
    if not g.healthOnly then
      items[#items + 1] = { key = "powerFormat" .. g.id, kind = "dropdown", name = "Power format",
        tip = "Own power format for this frame. 'Like general format' uses the format from the Text page.",
        options = GroupPowerOptions, onChange = Refresh }
    end
  end
  return items
end

local function Points(v) return ("%d"):format(v) end

-- Page order and names follow the addon family: General, Units, Text,
-- Formats per frame, Font. Tooltips: what it does, then limits.
local PAGES = {
  { title = "General", tip = "Style, colour, numbers and states of the text.", items = {
    { header = "Look" },
    { key = "textStyle", kind = "dropdown", name = "Style", tip = "Clear: the value in the text colour, maximum and percent in a softer grey. Single colour: the whole text in the text colour. Both work with values the game hides from addons.", options = StyleOptions, onChange = Refresh },
    { key = "textColor", kind = "dropdown", name = "Text colour", tip = "Colour of the value. By health colours only the health text and only when the game lets addons read the values (mostly out of combat), otherwise white. Class colour only for players, NPCs stay white.", options = ColorOptions, onChange = Refresh },
    { header = "Numbers" },
    { key = "abbreviate", name = "Abbreviate large numbers", tip = "12K instead of 12,345. The abbreviation comes from the game in your language, e.g. 1.2M (English) or 1,2 Mio. (German). Off: full numbers with thousands separators.", onChange = Refresh },
    { key = "percentDecimals", kind = "slider", name = "Decimal places for percent", tip = "0: 82%, 1: 82.3%, 2: 82.35%. Also works with values the game hides from addons.", min = 0, max = 2, step = 1, format = Points, onChange = Refresh },
    { header = "States" },
    { key = "stateText", name = "Dead, ghost and offline text", tip = "Shows Dead, Ghost or Offline instead of numbers. Where Blizzard already shows its own Dead text, Vitaldon stays empty.", onChange = Refresh },
    { header = "Layer" },
    { key = "textOnTop", name = "Always keep text in front", tip = "Vitaldon's text sits on the bar, above its fill. If another addon (e.g. BetterBlizzFrames) puts a fill or frame on the bar in a higher layer, Vitaldon moves its text one layer up, only then. Downside: in that layer the text can also appear above windows that cover the unit frame. Off: the text stays in the bar's layer and such a frame may cover it.", onChange = Refresh },
  } },
  { title = "Units", tip = "Which of Blizzard's unit frames get Vitaldon's text.", items = {
    { header = "Unit frames" },
    { key = "showPlayer", name = "Player", tip = "Text on your own health and power bar.", onChange = Refresh },
    { key = "showTarget", name = "Target", tip = "Text on the target frame.", onChange = Refresh },
    { key = "showFocus", name = "Focus", tip = "Text on the focus frame.", onChange = Refresh },
    { key = "showPet", name = "Pet", tip = "Text on the small pet frame.", onChange = Refresh },
    { key = "showParty", name = "Party frames", tip = "Text on the default party frames. For party frames in raid style (Edit Mode) see Raid-style party frames below.", onChange = Refresh },
    { key = "showToT", name = "Target of target", tip = "Text on the small target of target frames of your target and your focus (if Blizzard shows them).", onChange = Refresh },
    { key = "showBoss", name = "Boss frames", tip = "Text on Blizzard's boss frames (up to five) during encounters.", onChange = Refresh },
    { header = "Raid style" },
    { key = "showCompactParty", name = "Raid-style party frames", tip = "Text on the health bars of Blizzard's party frames in raid style (Edit Mode: Use raid-style party frames). Health only, the power bars are too thin. Blizzard shows Dead and Offline there itself. Blizzard's own health text of these frames (raid profile option Display health text) may overlap; set it to None.", onChange = Refresh },
    { key = "showRaid", name = "Raid frames", tip = "Text on the health bars of Blizzard's raid frames, up to 40. Health only. Off by default: in a raid this adds a text and the unit events of every raid member. Blizzard's own health text of these frames (raid profile option Display health text) may overlap; set it to None.", onChange = Refresh },
  } },
  { title = "Text", tip = "What the health and power text shows and where.", items = {
    { header = "Health" },
    { key = "showHealth", name = "Show health text", tip = "Text on the health bars.", onChange = Refresh },
    { key = "healthFormat", kind = "dropdown", name = "Health format", tip = "The list shows every format with sample values and your current settings. In combat the game may hide exact values from addons (secret values). Vitaldon then shows the game's own numbers without calculating.", options = HealthFormatOptions, parent = "showHealth", onChange = Refresh },
    { key = "healthAlign", kind = "dropdown", name = "Health text position", tip = "Left, center or right on the bar. Left and right keep 4 pixels from the bar edge.", options = AlignOptions, parent = "showHealth", onChange = Refresh },
    { key = "hideFull", name = "Hide at full health", tip = "No health text while the unit has full health. Only works when the game lets addons read the values (mostly out of combat).", parent = "showHealth", onChange = Refresh },
    { key = "showAbsorbs", name = "Show absorb shields", tip = "Adds the absorb shield (e.g. Power Word: Shield) in the blue accent colour after the health text: 12.3k (82%) +3.4k. If the game hides the amount from addons, the game itself builds the text; then the number may be unabbreviated.", parent = "showHealth", onChange = Refresh },
    { header = "Power" },
    { key = "showPower", name = "Show power text", tip = "Text on mana, rage, energy and focus bars.", onChange = Refresh },
    { key = "powerFormat", kind = "dropdown", name = "Power format", tip = "Format of the power text. The list shows every format with sample values and your current settings.", options = PowerFormatOptions, parent = "showPower", onChange = Refresh },
    { key = "powerAlign", kind = "dropdown", name = "Power text position", tip = "Left, center or right on the bar. Left and right keep 4 pixels from the bar edge.", options = AlignOptions, parent = "showPower", onChange = Refresh },
    { header = "Druid mana" },
    { key = "druidMana", name = "Mana in cat and bear form", tip = "While your power bar shows energy or rage, your mana appears in a calm mana blue on the other side of your own power bar. Only on your player frame and only if your character has mana.", onChange = Refresh },
    { key = "druidManaFormat", kind = "dropdown", name = "Mana format", tip = "Format of the mana text in cat and bear form.", options = PowerFormatOptions, parent = "druidMana", onChange = Refresh },
  } },
  { title = "Formats per frame", tip = "Own health and power format and Hide at full health for single unit frames, e.g. only percent on the party frames.", items = GroupFormatItems() },
  { title = "Font", tip = "Font, size, shadow and outline of the text.", items = {
    { header = "Font" },
    { key = "font", kind = "dropdown", name = "Font", tip = "Built-in game fonts only. If a font cannot be loaded, Vitaldon uses the font of Blizzard's bar text.", options = FontOptions, onChange = Refresh },
    { key = "fontSize", kind = "slider", name = "Font size", tip = "Size of the text on the bars. Default 12, a bit larger than Blizzard's small bar text. Power bars are thinner: their text is one point smaller unless Same size on power bars is on.", min = 6, max = 20, step = 1, format = Points, onChange = Refresh },
    { key = "powerSameSize", name = "Same size on power bars", tip = "Power text (mana, rage, energy) in the same size as the health text. Off: one point smaller, because power bars are thinner.", onChange = Refresh },
    { key = "fitText", name = "Fit text to bar", tip = "Text that is wider than its bar (small frames such as pet or target of target, long numbers) gets smaller step by step, down to size 8. Thin bars cap the size by their height. Only Vitaldon's own text changes. Off: always the size set above.", onChange = Refresh },
    { key = "shadow", name = "Shadow", tip = "Soft dark shadow below the text, like Blizzard's own small fonts. Readable on every bar colour.", onChange = Refresh },
    { key = "outline", name = "Outline", tip = "Additional dark outline for maximum contrast. Looks heavier than the shadow.", onChange = Refresh },
  } },
}

-- Family warning colour (DESIGN.md 0.95, 0.75, 0.25).
local WARNING = (ns.Style and ns.Style.Hex and ns.Style.Hex("warning")) or "fff2bf40"

local function Status()
  local lines = {}
  local version = ns.Version()
  if version ~= "?" then lines[#lines + 1] = L["Version %s"]:format(version) end
  local found, total = 0, 0
  for _, entry in ipairs(ns.entries or {}) do
    if ns.Counted(entry) then
      total = total + 1
      if entry.bar then found = found + 1 end
    end
  end
  lines[#lines + 1] = L["Bars found: %d of %d"]:format(found, total)
  if ns.BlizzardStatusTextOn() then
    lines[#lines + 1] = "|c" .. WARNING .. L["Blizzard's status text is on and may overlap. Use the button below to turn it off."] .. "|r"
  else
    lines[#lines + 1] = L["Blizzard's status text is off."]
  end
  return lines
end

-- Tool "Preview format" and /vd preview.
function ns.RunPreview()
  if ns.StartPreview and ns.StartPreview() then
    ns.Print(L["Preview: sample values on your player frame for 5 seconds."])
  else
    ns.Print(L["Preview not possible: the player frame text is off or the player frame was not found."])
  end
end

local TOOLS = {
  { "Turn off Blizzard's status text", "Turn off", function()
      local ok, why = ns.TurnOffBlizzardStatusText()
      if ok then
        ns.Print(L["Blizzard's status text is now off (Options > Interface > Status text: None)."])
      elseif why == "combat" then
        ns.Print(L["Not possible in combat. Try again after the fight."])
      else
        ns.Print(L["Could not change Blizzard's status text. Set Options > Interface > Status text to None."])
      end
      Refresh()
    end, "Sets Blizzard's option Status text to None, so only Vitaldon's text is on the bars. You can change it back under Options > Interface." },
  { "Find unit frames again", "Search", function()
      ns.ResolveAll()
      Refresh()
      ns.Print(L["Unit frames searched again."])
    end, "Searches Blizzard's bars again, e.g. after another addon changed the unit frames. /vd refresh" },
  { "Preview format", "Preview", function() ns.RunPreview() end,
    "Shows sample values on your player frame for 5 seconds, so you can check format, position, colour and font without combat. /vd preview" },
  { "Show all formats", "Show", function()
      ns.PrintFormats()
    end, "Lists every format in the chat with sample values and your current settings (style, decimals, abbreviation). The format lists in the options show the same samples. /vd formats" },
  { "Diagnostics", "Show", function()
      if ns.ShowDiag then ns.ShowDiag() elseif ns.PrintDiag then ns.PrintDiag() end
    end, "Opens a window with the bars found, the game functions and whether values are secret. /vd diag, in the chat: /vd diag chat" },
}

for _, t in ipairs(TOOLS) do t[3] = ns.Guard("tool", t[3]) end

local function Build()
  category = ns.BuildSettings({ name = "Vitaldon", status = Status, tools = TOOLS, pages = PAGES })
  ns.settingsCategory = category ~= nil
end

function ns.OpenOptions()
  if InCombatLockdown and InCombatLockdown() then
    ns.Print(L["Options cannot be opened in combat."])
    return
  end
  if category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(category:GetID())
  else
    ns.Print(ns.HELP)
  end
end

ns.OnInit(Build)
