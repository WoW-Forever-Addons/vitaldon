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

-- Tool "Turn off Blizzard's status text", also the button of the hint in the diagnostics window.
function ns.TurnOffStatusTextTool()
  local ok, why = ns.TurnOffBlizzardStatusText()
  if ok then
    ns.Print(L["Blizzard's status text is now off (Options > Interface > Status text: None)."])
  elseif why == "combat" then
    ns.Print(L["Not possible in combat. Try again after the fight."])
  else
    ns.Print(L["Could not change Blizzard's status text. Set Options > Interface > Status text to None."])
  end
  Refresh()
end

local TOOLS = {
  { "Turn off Blizzard's status text", "Turn off", function() ns.TurnOffStatusTextTool() end, "Sets Blizzard's option Status text to None, so only Vitaldon's text is on the bars. You can change it back under Options > Interface." },
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

-- (01.11.2026, StyleKit 2 step 3) the commands, shown under the status on the Tools tab of the shared options window
local function Help()
  local lines = {}
  for _, c in ipairs(ns.COMMANDS or {}) do lines[#lines + 1] = c[1] .. "  " .. L[c[2]] end
  return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- (02.11.2026, StyleKit 2 step 4, docs/layout_2026-11-02/vitaldon/, approved by Daniel) The preview card of the shared
-- options window: your player frame and a second frame (the target, or the group whose row the mouse is on) with sample
-- values in the current settings: format, style, colour, font, size, outline, shadow, position, absorb shield, druid mana.
-- Vitaldon's own text functions draw it (ns.ApplyStyle, ns.ApplyText), so it is the text the bars get. DonCore's Options
-- (minor 3) calls page.preview(frame, width, height) on every page.
---------------------------------------------------------------------------
local PREVIEW_OTHER = { health = { 4700, 10000, 47, 5300 }, power = { 30, 100, 30, 70 }, absorb = nil }
local PREVIEW_RAGE = { 40, 100, 40, 60 }
local BAR_COLOR = { health = { 0.1, 0.72, 0.15 }, mana = { 0.15, 0.35, 0.95 }, rage = { 0.8, 0.12, 0.12 } }
local HEALTH_H, POWER_H, LABEL_H, GAP = 18, 12, 14, 2

-- the group of the option row under the mouse (format, hide at full health, unit switch), else nil
local function HoveredGroup()
  local Core = LibStub and LibStub("DonCore-1.0", true)
  local O = Core and Core:Get("Options", 1)
  local e = O and O.state and O.state.hovered
  local key = e and e.spec and e.spec.id == "Vitaldon" and e.key
  if type(key) ~= "string" then return nil end
  local id = key:match("^healthFormat(%u%a+)$") or key:match("^powerFormat(%u%a+)$") or key:match("^hideFull(%u%a+)$")
  for _, g in ipairs(ns.GROUPS) do
    if (id and g.id == id) or g.key == key then return g end
  end
end

local function Bar(parent, color)
  local b = CreateFrame("Frame", nil, parent)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints(b)
  b.bg:SetColorTexture(0, 0, 0, 0.7)
  b.fill = b:CreateTexture(nil, "ARTWORK")
  b.fill:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
  b.fill:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
  b.fill:SetColorTexture(color[1], color[2], color[3], 1)
  return b
end

local function Block(f, i)
  f.vdBlocks = f.vdBlocks or {}
  local u = f.vdBlocks[i]
  if u then return u end
  u = {}
  u.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  u.label:SetJustifyH("LEFT")
  u.health = Bar(f, BAR_COLOR.health)
  u.power = Bar(f, BAR_COLOR.mana)
  local base = ns.FallbackFont and ns.FallbackFont()
  u.h = { kind = "health", overlay = u.health, fs = u.health:CreateFontString(nil, "OVERLAY"), baseFont = base, opts = {} }
  u.p = { kind = "power", overlay = u.power, fs = u.power:CreateFontString(nil, "OVERLAY"), baseFont = base, opts = {} }
  if i == 1 then u.p.altFs = u.power:CreateFontString(nil, "OVERLAY") end
  f.vdBlocks[i] = u
  return u
end

-- one text in the current settings with fixed values
local function Fill(entry, group, values, absorb)
  local db = ns.db
  entry.group = group.key
  ns.ApplyStyle(entry)
  local on = db[group.key] and (entry.kind == "health" and db.showHealth or entry.kind == "power" and db.showPower)
  if not on then entry.fs:SetText("") return end
  local o = entry.opts
  o.abbreviate, o.decimals, o.stateText = db.abbreviate, db.percentDecimals, db.stateText
  o.color, o.style = db.textColor, db.textStyle == "mono" and "mono" or "clear"
  if o.color == "class" then o.classR, o.classG, o.classB = ns.ClassColor("player") end
  o.values, o.preview = values, true
  o.absorbs, o.previewAbsorb = db.showAbsorbs and entry.kind == "health", absorb
  ns.ApplyText(entry.fs, "player", entry.kind, ns.GroupFormat(entry.kind, group.key), o)
end

local function Place(u, f, y, w, group, values, druid)
  u.label:ClearAllPoints()
  u.label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
  u.label:SetWidth(w)
  u.label:SetText(L[group.name] .. (ns.db[group.key] and "" or (" (" .. L["off"] .. ")")))
  y = y + LABEL_H + GAP
  for _, part in ipairs({ { u.health, HEALTH_H, values.health[3] }, { u.power, POWER_H, druid and PREVIEW_RAGE[3] or values.power[3] } }) do
    local bar, h, pct = part[1], part[2], part[3]
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
    bar:SetSize(w, h)
    bar.fill:SetWidth(math.max(1, math.floor(w * pct / 100)))
    y = y + h + GAP
  end
  local c = druid and BAR_COLOR.rage or BAR_COLOR.mana
  u.power.fill:SetColorTexture(c[1], c[2], c[3], 1)
  Fill(u.h, group, values.health, values.absorb)
  -- compact frames: health only
  if group.healthOnly then u.power:Hide() u.p.fs:SetText("") else u.power:Show() Fill(u.p, group, druid and PREVIEW_RAGE or values.power) end
  if u.p.altFs then
    local alt = u.p.altFs
    if druid and not group.healthOnly then
      local side = ns.db.powerAlign == "RIGHT" and "LEFT" or "RIGHT"
      alt:ClearAllPoints()
      alt:SetPoint(side, u.power, side, side == "LEFT" and 4 or -4, 0)
      alt:SetFont(u.p.fontFile or u.p.baseFont, u.p.curSize or 11, u.p.flags or "")
      local o = u.p.altOpts or {}
      u.p.altOpts = o
      o.abbreviate, o.decimals, o.style, o.preview = ns.db.abbreviate, ns.db.percentDecimals, "mono", true
      o.values = ns.PREVIEW_VALUES.mana
      ns.ApplyText(alt, "player", "power", ns.AltFormat(), o)
      alt:SetTextColor(ns.MANA_COLOR[1], ns.MANA_COLOR[2], ns.MANA_COLOR[3])
    else
      alt:SetText("")
    end
  end
  return y
end

function ns.DrawPreview(f, w, h)
  if not (ns.db and ns.ApplyStyle and ns.ApplyText and ns.PREVIEW_VALUES) then return end
  local groups = ns.GROUPS
  local other = HoveredGroup()
  if not other or other.key == "showPlayer" then other = groups[2] end
  local bw = math.max(40, math.min(w, 220))
  local x = math.floor((w - bw) / 2)
  local inner = f.vdInner
  if not inner then inner = CreateFrame("Frame", nil, f) f.vdInner = inner end
  inner:ClearAllPoints()
  inner:SetPoint("TOPLEFT", f, "TOPLEFT", x, -8)
  inner:SetSize(bw, h - 8)
  local pv = ns.PREVIEW_VALUES
  local druid = ns.db.druidMana and ns.PlayerClass and ns.PlayerClass() == "DRUID"
  local y = Place(Block(inner, 1), inner, 0, bw, groups[1], { health = pv.health, power = pv.power, absorb = pv.absorb }, druid)
  Place(Block(inner, 2), inner, y + 10, bw, other, PREVIEW_OTHER, false)
end

local function Build()
  for _, page in ipairs(PAGES) do page.preview = ns.DrawPreview end
  ns.settingsPages = PAGES
  category = ns.BuildSettings({ name = "Vitaldon", status = Status, tools = TOOLS, pages = PAGES, help = Help })
  ns.settingsCategory = category ~= nil
end

-- (01.11.2026) DonCore's options window of all Don addons (no Blizzard panel, so also in combat); Blizzard's settings
-- only when that window is not there (an older DonCore), and those stay closed in combat.
function ns.OpenOptions()
  if ns.OpenDonOptions and ns.OpenDonOptions() then return end
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
