local _, ns = ...

---------------------------------------------------------------------------
-- Our own text frames above the default bars. Each overlay is our frame,
-- a child of the Blizzard bar (SetParent on our frame, SetAllPoints). So it
-- moves, scales and rises with the bar and draws above its fill.
--
-- (1.5) Frame restylers such as BetterBlizzFrames put their own frames on
-- the bar: a fill bar as a child of the bar at the bar's level ("Smooth
-- Bars"), pixel borders in a higher strata, bars at level 9998. Our overlay
-- therefore stays above the highest visible child of the bar and the
-- highest visible status bar next to it in its container (read only:
-- GetChildren, GetFrameLevel, GetFrameStrata, IsVisible). If that is not
-- possible with the frame level alone (frame in a higher strata, or the
-- level limit), the option "Always keep text in front" moves our overlay
-- one strata above the bar. Blizzard frames are only read, never changed.
--
-- (1.6) Cost: the ticker (4 per second) reads per shown bar only its
-- level and number of children and our overlay's level and strata. The
-- full layer scan runs when one of these changes, when the overlay appears,
-- on target and focus changes and otherwise every 5 seconds per bar
-- (staggered). Nothing in the ticker or the event path creates tables,
-- closures or strings.
---------------------------------------------------------------------------

local entries = {}
ns.entries = entries
-- Our overlays, so the scan skips them.
local ownOverlay = {}

local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
local LEVEL_ABOVE = 20
-- Highest frame level the client accepts.
local MAX_LEVEL = 10000
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local STRATA_RANK = {}
for i, name in ipairs(STRATA) do STRATA_RANK[name] = i end
ns.STRATA, ns.STRATA_RANK, ns.MAX_LEVEL = STRATA, STRATA_RANK, MAX_LEVEL
-- Distance of left and right aligned text from the bar edge (4 px grid).
local EDGE = 4
ns.TEXT_EDGE = EDGE
-- Soft shadow like Blizzard's own small fonts: 1 px down right, black 80 %.
local SHADOW_X, SHADOW_Y, SHADOW_ALPHA = 1, -1, 0.8

local VALID_FORMAT = {}
for _, key in ipairs(ns.FORMATS) do VALID_FORMAT[key] = true end
-- Full layer scan at the latest after this many seconds per bar.
local SAFETY_SCAN = 5
ns.SAFETY_SCAN = SAFETY_SCAN

-- Setting key of the format override per group, built once (1.6: no
-- string concatenation on every tick and event).
local formatKeys = { health = {}, power = {} }
for _, g in ipairs(ns.GROUPS) do
  formatKeys.health[g.key] = "healthFormat" .. g.id
  formatKeys.power[g.key] = "powerFormat" .. g.id
end

-- Format of a unit group: its own override, else the general format.
local function GroupFormat(kind, group)
  local db = ns.db
  local key = group and (kind == "health" and formatKeys.health or formatKeys.power)[group]
  local own = key and db[key]
  if type(own) == "string" and VALID_FORMAT[own] then return own end
  return kind == "health" and db.healthFormat or db.powerFormat
end
ns.GroupFormat = GroupFormat

-- (1.10) Hide at full health per unit group: "on" or "off" win over the
-- general option, "inherit" (default) follows it.
local hideKeys = {}
for _, g in ipairs(ns.GROUPS) do hideKeys[g.key] = "hideFull" .. g.id end
local function GroupHideFull(group)
  local db = ns.db
  local own = group and hideKeys[group] and db[hideKeys[group]]
  if own == "on" then return true end
  if own == "off" then return false end
  return db.hideFull and true or false
end
ns.GroupHideFull = GroupHideFull

local function Settings(kind, group)
  local db = ns.db
  if kind == "health" then
    return db.showHealth, GroupFormat(kind, group), db.healthAlign
  end
  return db.showPower, GroupFormat(kind, group), db.powerAlign
end

-- Built-in WoW fonts only. "default" = the font of Blizzard's bar text.
ns.FONTS = { "default", "friz", "arialn", "skurri", "morpheus" }
ns.FONT_LABELS = {
  default = "Like Blizzard's bar text", friz = "Friz Quadrata", arialn = "Arial Narrow",
  skurri = "Skurri", morpheus = "Morpheus",
}
ns.FONT_FILES = {
  friz = "Fonts\\FRIZQT__.TTF", arialn = "Fonts\\ARIALN.TTF",
  skurri = "Fonts\\SKURRI.TTF", morpheus = "Fonts\\MORPHEUS.TTF",
}
-- These four files only have Latin letters. The Russian, Korean and Chinese clients write the
-- number abbreviations in their own script (Т, 만, 萬), so there only Blizzard's font is offered.
do
  local loc = type(GetLocale) == "function" and GetLocale()
  if loc == "ruRU" or loc == "koKR" or loc == "zhTW" or loc == "zhCN" then
    ns.FONTS = { "default" }
    ns.FONT_FILES = {}
  end
end

local function FallbackFont()
  local obj = GameFontNormal
  local font = obj and obj.GetFont and ns.Call(obj.GetFont, obj)
  if type(font) == "string" and ns.Usable(font) then return font end
  return STANDARD_TEXT_FONT or FALLBACK_FONT
end

-- Shadow on our own FontString: soft shadow, or none.
local function ApplyShadow(fs, on)
  if type(fs.SetShadowOffset) ~= "function" then return end
  if on then
    pcall(fs.SetShadowOffset, fs, SHADOW_X, SHADOW_Y)
    if type(fs.SetShadowColor) == "function" then pcall(fs.SetShadowColor, fs, 0, 0, 0, SHADOW_ALPHA) end
  else
    pcall(fs.SetShadowOffset, fs, 0, 0)
  end
end

-- SetFont may throw or return false for a missing file.
local function TrySetFont(fs, file, size, flags)
  if type(file) ~= "string" then return false end
  local ok, res = pcall(fs.SetFont, fs, file, size, flags)
  return ok and res ~= false
end

---------------------------------------------------------------------------
-- (1.9) Size and fit. Power bars are thinner than health bars: their text
-- is one point smaller unless "Same size on power bars" is on. "Fit text
-- to bar" caps the size by the bar height and shrinks the text step by step
-- (down to FIT_MIN) only when it is wider than the bar.
--
-- Width: the width of OUR FontString after SetFormattedText. With secret
-- values the client may report that width as secret too (or refuse), so it
-- is read protected and only used when readable (ns.Num). Otherwise a
-- hidden probe FontString of ours measures the same format with readable
-- reference numbers (the player's own maximum, at least 100, and 100 %),
-- once per format, size and reference; the result is cached. Only our own
-- font strings are changed, never a Blizzard font.
---------------------------------------------------------------------------
local FIT_MIN = 8
ns.FIT_MIN = FIT_MIN
-- Size cap from the bar height: digits are about 0.7 of the font size high,
-- plus 1 px outline on each side; 1.4 x height keeps them within the bar
-- (10 px mana bar: up to 14, 6 px bar: 8).
local HEIGHT_FACTOR = 1.4
ns.HEIGHT_FACTOR = HEIGHT_FACTOR

-- Size the user set, minus one on power bars.
local function BaseSize(entry)
  local db = ns.db
  local size = math.floor((tonumber(db.fontSize) or ns.defaults.fontSize) + 0.5)
  if entry.kind == "power" and not db.powerSameSize and size > FIT_MIN then size = size - 1 end
  return size
end
ns.BaseSize = BaseSize

-- Readable size of our own overlay (it has the bar's size), else nil.
local function OverlaySize(entry)
  local overlay = entry.overlay
  local w = ns.Num(ns.Call(overlay.GetWidth, overlay))
  local h = ns.Num(ns.Call(overlay.GetHeight, overlay))
  if w and w <= 0 then w = nil end
  if h and h <= 0 then h = nil end
  return w, h
end

local function SetSize(entry, fs, size)
  if not entry.fontFile then return false end
  return TrySetFont(fs, entry.fontFile, size, entry.flags)
end

-- Reference values of the probe, one table per entry (no garbage per event).
local probeOpts = {}
local function ReferenceMax(entry)
  local fn = entry.kind == "health" and UnitHealthMax or UnitPowerMax
  local m = ns.Num(ns.Call(fn, "player"))
  if not m or m < 100 then m = 100 end
  return math.floor(m + 0.5)
end

-- Width of the text at the current size: our FontString if readable, else
-- the probe. Returns width, source ("text", "probe") or nil.
local function TextWidth(entry, mode)
  local fs = entry.fs
  local w = ns.Num(ns.Call(fs.GetStringWidth, fs))
  if w then
    entry.widthSource = "text"
    return w
  end
  entry.widthSource = "secret"
  local ref = ReferenceMax(entry)
  local db = ns.db
  local style = db.textStyle == "mono" and "mono" or "clear"
  if entry.probeW and entry.probeMode == mode and entry.probeRef == ref and entry.probeSize == entry.curSize
    and entry.probeStamp == ns.styleStamp and entry.probeAbbr == db.abbreviate and entry.probeDec == db.percentDecimals
    and entry.probeStyle == style then
    entry.widthSource = "probe"
    return entry.probeW
  end
  local probe = entry.probe
  if not probe then
    local ok, p = pcall(entry.overlay.CreateFontString, entry.overlay, nil, "OVERLAY")
    if not ok or not p then return nil end
    if p.SetWordWrap then p:SetWordWrap(false) end
    p:Hide()
    entry.probe, probe = p, p
  end
  if not SetSize(entry, probe, entry.curSize) then return nil end
  local values = entry.probeValues or {}
  entry.probeValues = values
  values[1], values[2], values[3], values[4] = ref, ref, 100, ref
  probeOpts.values = values
  probeOpts.abbreviate = db.abbreviate
  probeOpts.decimals = db.percentDecimals
  probeOpts.style = style
  local okBuild, fmt, a, b, c = pcall(ns.BuildText, "player", entry.kind, mode, probeOpts)
  probeOpts.values = nil
  if not okBuild or type(fmt) ~= "string" then return nil end
  local okFmt, text = pcall(string.format, fmt, a, b, c)
  if not okFmt or type(text) ~= "string" then return nil end
  pcall(probe.SetText, probe, text)
  w = ns.Num(ns.Call(probe.GetStringWidth, probe))
  if not w then return nil end
  entry.probeW, entry.probeMode, entry.probeRef, entry.probeSize = w, mode, ref, entry.curSize
  entry.probeStamp, entry.probeAbbr, entry.probeDec, entry.probeStyle = ns.styleStamp, db.abbreviate, db.percentDecimals, style
  entry.widthSource = "probe"
  return w
end

local function ApplySize(entry, size)
  if size == entry.curSize then return end
  if SetSize(entry, entry.fs, size) then
    entry.curSize = size
    if entry.altFs then SetSize(entry, entry.altFs, size) end
  end
end

-- Size for the text just written. mode: the format (for the probe).
-- fitText off: the base size, nothing measured.
local function Fit(entry, mode)
  if not entry.fs or not entry.curSize then return end
  local want = BaseSize(entry)
  entry.fitBy = nil
  if not ns.db.fitText then
    ApplySize(entry, want)
    return
  end
  local floorSize = want < FIT_MIN and want or FIT_MIN
  local w, h = OverlaySize(entry)
  if h then
    local cap = math.floor(h * HEIGHT_FACTOR)
    if cap < floorSize then cap = floorSize end
    if want > cap then want = cap; entry.fitBy = "height" end
  end
  local avail = w and (w - 2 * EDGE)
  -- Up to three steps: estimate the size from the measured width (it grows
  -- about linearly with the size), set it, measure again.
  local measured = false
  for _ = 1, 3 do
    local tw = avail and avail > 0 and TextWidth(entry, mode)
    if not tw or tw <= 0 then break end
    measured = true
    local cur = entry.curSize
    local target = want
    if tw * want / cur > avail then
      entry.fitBy = "width"
      if tw > avail then
        target = math.floor(cur * avail / tw)
        if target >= cur then target = cur - 1 end
      else
        -- Fits now, wider would not: grow only with one point to spare,
        -- so the size never swings back and forth between two values.
        target = math.floor(cur * avail / tw) - 1
        if target < cur then target = cur end
      end
      if target > want then target = want end
      if target < floorSize then target = floorSize end
    end
    if target == cur then break end
    ApplySize(entry, target)
    if entry.curSize ~= target or target > cur then break end
  end
  if not measured then ApplySize(entry, want) end
end
ns.FitText = Fit

local function Enabled(entry)
  local db = ns.db
  if not db or not db[entry.group] then return false end
  local show = Settings(entry.kind, entry.group)
  return show and true or false
end

local function CreateOverlay(entry)
  if entry.overlay then return end
  local parent = UIParent
  local overlay = CreateFrame("Frame", nil, parent)
  if overlay.EnableMouse then overlay:EnableMouse(false) end
  local ok, fs = pcall(overlay.CreateFontString, overlay, nil, "OVERLAY", "TextStatusBarText")
  if not ok or not fs then fs = overlay:CreateFontString(nil, "OVERLAY") end
  local font = fs.GetFont and ns.Call(fs.GetFont, fs)
  entry.baseFont = type(font) == "string" and font or STANDARD_TEXT_FONT or FALLBACK_FONT
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  if entry.unit == "player" and entry.kind == "power" then
    -- Second line for the mana of a druid in cat or bear form.
    local okAlt, alt = pcall(overlay.CreateFontString, overlay, nil, "OVERLAY", "TextStatusBarText")
    if not okAlt or not alt then alt = overlay:CreateFontString(nil, "OVERLAY") end
    if alt.SetWordWrap then alt:SetWordWrap(false) end
    entry.altFs = alt
  end
  overlay:Hide()
  entry.overlay, entry.fs = overlay, fs
  ownOverlay[overlay] = true
end

-- (1.8) Visibility of a Blizzard frame: unreadable (secret) counts as
-- visible. Our overlay is a child of the bar, so the client hides the text
-- with the bar anyway; for the layer scan an unknown frame is the safe
-- side. Missing method or error: not visible.
local function Visible(f)
  local v = ns.Call(f.IsVisible, f)
  if type(v) == "nil" then return false end
  if not ns.Usable(v) then return true end
  return v == true
end
ns.FrameVisible = Visible

-- Layer scan: highest level per strata of the visible frames that can draw
-- above the bar. Children of the bar: every visible frame (they lie on the
-- bar). Siblings in the bar's container: only visible status bars (fills).
-- Varargs only, no table per scan.
local function Consider(scan, bar, f, onlyBars)
  if type(f) ~= "table" or not ns.Usable(f) or f == bar or ownOverlay[f] then return end
  if not Visible(f) then return end
  if onlyBars and ns.Value(f.GetObjectType, f) ~= "StatusBar" then return end
  local level = ns.Num(ns.Value(f.GetFrameLevel, f))
  local rank = STRATA_RANK[ns.Value(f.GetFrameStrata, f) or ""]
  if not (level and rank) then return end
  scan.count = scan.count + 1
  if level > (scan[rank] or -1) then scan[rank] = level end
  if rank > scan.maxRank then scan.maxRank = rank end
end

-- (1.6) Eight frames per select: a container with many children (party
-- and raid frames) costs a few copies of the list instead of one per child.
local function ScanList(scan, bar, onlyBars, ...)
  for i = 1, select("#", ...), 8 do
    local a, b, c, d, e, f, g, h = select(i, ...)
    Consider(scan, bar, a, onlyBars); Consider(scan, bar, b, onlyBars)
    Consider(scan, bar, c, onlyBars); Consider(scan, bar, d, onlyBars)
    Consider(scan, bar, e, onlyBars); Consider(scan, bar, f, onlyBars)
    Consider(scan, bar, g, onlyBars); Consider(scan, bar, h, onlyBars)
  end
end

local function ScanChildren(scan, bar, frame, onlyBars)
  if type(frame) ~= "table" or type(frame.GetChildren) ~= "function" then return end
  ScanList(scan, bar, onlyBars, frame:GetChildren())
end

local function Scan(entry, bar)
  local scan = entry.scan or {}
  entry.scan = scan
  for i = 1, #STRATA do scan[i] = nil end
  scan.count, scan.maxRank = 0, 0
  pcall(ScanChildren, scan, bar, bar, false)
  -- The tick watches this count: a frame added to the bar (restyler fill
  -- or border) triggers the next scan at once.
  entry.barChildren = ns.Value(bar.GetNumChildren, bar)
  local container = ns.Value(bar.GetParent, bar)
  if type(container) == "table" and container ~= UIParent then
    pcall(ScanChildren, scan, bar, container, true)
  end
  return scan
end

-- Wanted strata and level of the overlay for this bar.
-- Returns strata, level, state; state: "ok", "raised" (one strata up),
-- "below" (option off, a frame may draw above the text), "limit" (even
-- one strata up not enough) or (1.8) "unknown": the bar's strata or level
-- is not readable; then strata and level are nil and the overlay keeps
-- what the client gave it as the bar's child (up to 1.7 it fell back to
-- LOW and level 20 and could end up below the bar).
local function WantedLayer(entry, bar)
  local barStrata = ns.Value(bar.GetFrameStrata, bar)
  local barRank = STRATA_RANK[barStrata or ""]
  local barLevel = ns.Num(ns.Value(bar.GetFrameLevel, bar))
  if not (barRank and barLevel) then return nil, nil, "unknown" end
  local scan = Scan(entry, bar)
  local level = barLevel + LEVEL_ABOVE
  local same = scan[barRank]
  if same and same + 1 > level then level = same + 1 end
  if level > MAX_LEVEL then level = MAX_LEVEL end
  -- Enough if the (capped) level is above the bar and every frame on it in
  -- the same strata, and nothing on it sits in a higher strata. A bar at
  -- 9998 (BetterBlizzFrames' classic target of target) still fits: 10000.
  local fits = level > barLevel and (not same or level > same) and scan.maxRank <= barRank
  if fits then return STRATA[barRank], level, "ok" end
  if not (ns.db and ns.db.textOnTop) or barRank >= #STRATA then
    return STRATA[barRank], level, "below"
  end
  -- One strata above the bar: any level there draws above the bar strata;
  -- frames already in that strata still count.
  local rank = barRank + 1
  local up = math.min(barLevel + LEVEL_ABOVE, MAX_LEVEL)
  local there = scan[rank]
  if there and there + 1 > up then up = there + 1 end
  local state = (up <= MAX_LEVEL and scan.maxRank <= rank) and "raised" or "limit"
  if up > MAX_LEVEL then up = MAX_LEVEL end
  return STRATA[rank], up, state
end

-- Keeps the overlay a child of the bar and above everything that draws on
-- the bar. Reads the overlay's real strata and level, so a change by the
-- client (frame raised, strata of the parent changed) is noticed too.
local function SyncLayout(entry)
  local bar, overlay = entry.bar, entry.overlay
  if not (bar and overlay) then return end
  if entry.anchoredTo ~= bar then
    -- (1.4) Our overlay is a child of the bar: when Blizzard raises the
    -- player frame (any click on it or the world), the client raises the
    -- whole subtree, so the bar fill can never end up above our text.
    -- Only our own frame changes; the bar itself is only read.
    if overlay.SetParent then pcall(overlay.SetParent, overlay, bar) end
    overlay:ClearAllPoints()
    overlay:SetAllPoints(bar)
    entry.anchoredTo = bar
    entry.scale = nil
  end
  local strata, level, state = WantedLayer(entry, bar)
  entry.layerState = state
  if strata and ns.Value(overlay.GetFrameStrata, overlay) ~= strata then
    overlay:SetFrameStrata(strata)
  end
  if level and ns.Value(overlay.GetFrameLevel, overlay) ~= level then
    overlay:SetFrameLevel(level)
  end
  -- (1.6) Remember what the client really applied: if it clamps the level,
  -- the tick would otherwise see a change and scan on every tick.
  entry.strata = ns.Value(overlay.GetFrameStrata, overlay) or strata
  entry.level = ns.Num(ns.Value(overlay.GetFrameLevel, overlay)) or level
  entry.barLevel = ns.Num(ns.Value(bar.GetFrameLevel, bar))
  -- Child of the bar: the scale is inherited, our own scale stays 1.
  if entry.scale ~= 1 then
    overlay:SetScale(1)
    entry.scale = 1
  end
end
ns.SyncLayout = SyncLayout

-- Cheap check for the ticker: did the bar change its level or get a new
-- child, or did our overlay change level or strata since the last sync?
-- Four reads, no scan.
local function LayerChanged(entry)
  local bar, overlay = entry.bar, entry.overlay
  if ns.Num(ns.Value(bar.GetFrameLevel, bar)) ~= entry.barLevel then return true end
  if ns.Value(bar.GetNumChildren, bar) ~= entry.barChildren then return true end
  if ns.Value(overlay.GetFrameLevel, overlay) ~= entry.level then return true end
  return ns.Value(overlay.GetFrameStrata, overlay) ~= entry.strata
end

local function ApplyStyle(entry)
  local fs = entry.fs
  if not fs then return end
  local _, _, align = Settings(entry.kind, entry.group)
  align = (align == "LEFT" or align == "RIGHT") and align or "CENTER"
  fs:ClearAllPoints()
  if align == "LEFT" then
    fs:SetPoint("LEFT", entry.overlay, "LEFT", EDGE, 0)
  elseif align == "RIGHT" then
    fs:SetPoint("RIGHT", entry.overlay, "RIGHT", -EDGE, 0)
  else
    fs:SetPoint("CENTER", entry.overlay, "CENTER", 0, 0)
  end
  if fs.SetJustifyH then fs:SetJustifyH(align) end
  -- (1.9) Vertically centred on the bar: the outline grows the glyphs by one
  -- pixel on every side, so the centre stays where it is.
  if fs.SetJustifyV then pcall(fs.SetJustifyV, fs, "MIDDLE") end
  -- Base size; the fit (UpdateEntry) makes it smaller where needed.
  local size = BaseSize(entry)
  local flags = ns.db.outline and "OUTLINE" or ""
  local file = ns.FONT_FILES[ns.db.font] or entry.baseFont
  entry.flags = flags
  if TrySetFont(fs, file, size, flags) then
    entry.fontFallback = nil
    entry.fontFile = file
  else
    entry.fontFallback = true
    entry.fontFile = nil
    if TrySetFont(fs, entry.baseFont, size, flags) then
      entry.fontFile = entry.baseFont
    else
      local fb = FallbackFont()
      if TrySetFont(fs, fb, size, flags) then entry.fontFile = fb end
    end
  end
  entry.curSize = entry.fontFile and size or nil
  entry.probeW = nil
  local shadow = ns.db.shadow and true or false
  ApplyShadow(fs, shadow)
  local alt = entry.altFs
  if alt then
    -- Opposite side of the power text, so both fit on the bar.
    local side = align == "RIGHT" and "LEFT" or "RIGHT"
    alt:ClearAllPoints()
    alt:SetPoint(side, entry.overlay, side, side == "LEFT" and EDGE or -EDGE, 0)
    if alt.SetJustifyH then alt:SetJustifyH(side) end
    if alt.SetJustifyV then pcall(alt.SetJustifyV, alt, "MIDDLE") end
    if not (entry.fontFile and TrySetFont(alt, entry.fontFile, size, flags)) then
      if not TrySetFont(alt, entry.baseFont, size, flags) then TrySetFont(alt, FallbackFont(), size, flags) end
    end
    ApplyShadow(alt, shadow)
  end
end

local function BarVisible(bar)
  if not bar then return false end
  return Visible(bar)
end

-- Unknown (secret or missing API) counts as existing; the bar visibility
-- decides then. No unit (compact frame without a unit): not present.
local function UnitPresent(unit)
  if not unit then return false end
  local v = ns.Call(UnitExists, unit)
  if type(v) == "nil" then return type(UnitExists) ~= "function" end
  if not ns.Usable(v) then return true end
  return v and true or false
end

-- Blizzard shows its own "Dead" (and "Unconscious") on target, focus, boss
-- and target of target bars. (1.7) In the forever branch these texts sit
-- on the bar's container for target, focus and boss
-- (TargetFrameContentMain.HealthBarsContainer.DeadText, Mainline/
-- TargetFrame.xml, TargetFrameMixin:CheckDead) and on the bar itself only
-- for target of target (TargetofTargetFrameTemplate HealthBar.DeadText).
-- Up to 1.6 only the bar was checked, so a dead target showed "Dead" twice.
-- Found once per bar (Resolve), then only IsShown is read.
local DEAD_KEYS = { "DeadText", "UnconsciousText" }
local function IsFontObject(v) return type(v) == "table" and ns.Usable(v) and type(v.IsShown) == "function" end
local function Field(t, k) return t[k] end
local function FindDeadTexts(entry)
  local list = entry.deadTexts
  if list then for i = #list, 1, -1 do list[i] = nil end end
  local bar = entry.bar
  if entry.kind ~= "health" or not bar or entry.compact then return end
  local container = ns.Value(bar.GetParent, bar)
  if type(container) ~= "table" or container == UIParent then container = nil end
  for h = 1, 2 do
    local holder = h == 1 and bar or container
    if holder then
      for _, key in ipairs(DEAD_KEYS) do
        local ok, fs = pcall(Field, holder, key)
        if ok and IsFontObject(fs) then
          list = list or {}
          list[#list + 1] = fs
        end
      end
    end
  end
  entry.deadTexts = list
end
ns.FindDeadTexts = FindDeadTexts

local function BlizzardDeadShown(entry)
  local list = entry.deadTexts
  if not list then return false end
  for i = 1, #list do
    local fs = list[i]
    if ns.True(ns.Call(fs.IsShown, fs)) then return true end
  end
  return false
end

-- Vehicles and possess: Blizzard's player frame then shows "vehicle" and
-- the pet frame shows "player". We read the unit the Blizzard frame shows
-- (frame.unit, read only); without it UnitHasVehicleUI decides.
local FRAME_UNIT = { player = "PlayerFrame.unit", pet = "PetFrame.unit" }
local VALID_UNIT = { player = true, vehicle = true, pet = true }

local function InVehicle()
  if not ns.True(ns.Call(UnitHasVehicleUI, "player")) then return false end
  return ns.True(ns.Call(UnitExists, "vehicle"))
end

-- (1.6) Compact frames: the unit token the frame shows right now.
-- (1.8) An unreadable (secret) token keeps the last known unit instead of
-- hiding the text.
local function CompactUnit(entry)
  local paths = entry.unitPaths
  for i = 1, #paths do
    local u = ns.Lookup(paths[i])
    if type(u) ~= "nil" then
      if not ns.Usable(u) then return entry.curUnit end
      if type(u) == "string" and u ~= "" then return u end
    end
  end
  return nil
end

local function EffectiveUnit(entry)
  if entry.compact then return CompactUnit(entry) end
  local path = FRAME_UNIT[entry.unit]
  if not path then return entry.unit end
  local shown = ns.Lookup(path)
  if type(shown) == "string" and ns.Usable(shown) and VALID_UNIT[shown] then return shown end
  if InVehicle() then return entry.unit == "player" and "vehicle" or "player" end
  return entry.unit
end
ns.EffectiveUnit = EffectiveUnit

-- Preview: fake values on the player bars for a few seconds.
local PREVIEW = {
  health = { 12345, 15000, 82.3, 2655 },
  power = { 8000, 10000, 80, 2000 },
  mana = { 6200, 10000, 62, 3800 },
  absorb = 3400,
}
local PREVIEW_SECONDS = 5

local function PreviewActive(entry)
  if entry.unit ~= "player" or not ns.previewUntil then return false end
  local now = GetTime and GetTime() or 0
  return now < ns.previewUntil
end

-- Druid mana: the player shows another power (energy, rage) but still has
-- mana. Readable maximum decides; a secret maximum counts for druids only.
-- Calm blue: Blizzard's mana blue (0, 0, 1) lightened so it reads as text.
local MANA_COLOR = { 0.47, 0.66, 1 }
ns.MANA_COLOR = MANA_COLOR
local manaType
local function ManaType()
  if manaType then return manaType end
  local v = ns.Num(ns.Lookup("Enum.PowerType.Mana"))
  if v then manaType = v end
  return v or 0
end

-- The player's class never changes: read once, then cached.
local playerClass
local function PlayerClass()
  if playerClass then return playerClass end
  if type(UnitClass) ~= "function" then return nil end
  local ok, _, classFile = pcall(UnitClass, "player")
  if ok and type(classFile) == "string" and ns.Usable(classFile) then playerClass = classFile end
  return playerClass
end

local function AltManaWanted(unit)
  if unit ~= "player" or not ns.db.druidMana then return false end
  local mana = ManaType()
  local shown = ns.Num(ns.Call(UnitPowerType, "player"))
  if not shown or shown == mana then return false end
  local max = ns.Call(UnitPowerMax, "player", mana)
  local m = ns.Num(max)
  if m then return m > 0 end
  if type(max) == "nil" then return false end
  return PlayerClass() == "DRUID"
end
ns.AltManaWanted = AltManaWanted

local function AltFormat()
  local f = ns.db.druidManaFormat
  if type(f) == "string" and VALID_FORMAT[f] then return f end
  return "percent"
end

local function UpdateAlt(entry, unit, preview, opts)
  local alt = entry.altFs
  if not alt then return end
  local want
  if preview then
    want = ns.db.druidMana and PlayerClass() == "DRUID"
  else
    want = AltManaWanted(unit)
  end
  if not want then
    alt:SetText("")
    entry.altShown = false
    return
  end
  local altOpts = entry.altOpts or {}
  entry.altOpts = altOpts
  altOpts.abbreviate = opts.abbreviate
  altOpts.decimals = opts.decimals
  altOpts.stateText = opts.stateText
  altOpts.style = "mono" -- the whole mana line in mana blue
  altOpts.preview = preview
  altOpts.values = preview and PREVIEW.mana or nil
  altOpts.powerType = ManaType()
  local result = ns.ApplyText(alt, "player", "power", AltFormat(), altOpts)
  if alt.SetTextColor then pcall(alt.SetTextColor, alt, MANA_COLOR[1], MANA_COLOR[2], MANA_COLOR[3]) end
  -- Set directly: the colour cache of ApplyText must not skip the next call.
  alt._vdR = nil
  entry.altShown = result == "text"
end

-- (1.6) Unit token -> entries showing it, so a unit event touches only its
-- own bars (raid frames add up to 40 entries). Rebuilt only when a bar
-- changes its unit; the lists are reused. ns.extraUnits holds the units of
-- the compact frames: the event filter in Core.lua lets them through.
local byUnit, unitsDirty = {}, true
ns.extraUnits = {}
local function IndexUnits()
  unitsDirty = false
  for _, list in pairs(byUnit) do
    for i = #list, 1, -1 do list[i] = nil end
  end
  local extra = ns.extraUnits
  for k in pairs(extra) do extra[k] = nil end
  for i = 1, #entries do
    local e = entries[i]
    local u = e.curUnit
    if not u and not e.compact then u = e.unit end
    if u then
      local list = byUnit[u]
      if not list then list = {}; byUnit[u] = list end
      list[#list + 1] = e
      if e.compact then extra[u] = true end
    end
  end
end
function ns.EntriesFor(unit)
  if unitsDirty then IndexUnits() end
  return byUnit[unit]
end
-- For the event filter in Core.lua (runs before any handler, so a rebuild
-- here never happens while UpdateUnit walks a list).
function ns.IsExtraUnit(unit)
  if unitsDirty then IndexUnits() end
  return ns.extraUnits[unit] == true
end

local function SetCurUnit(entry, unit)
  if unit == entry.curUnit then return end
  entry.curUnit = unit
  unitsDirty = true
  if entry.compact then
    -- Tokens like raid1target get no unit events: refresh on the ticker.
    entry.poll = type(unit) == "string" and unit:find("target", 1, true) ~= nil
  end
end

local function UpdateEntry(entry)
  local overlay = entry.overlay
  if not overlay then return end
  local enabled = Enabled(entry)
  -- A switched off compact frame keeps no unit, so its raid unit events
  -- stay filtered out.
  local unit = (enabled or not entry.compact) and EffectiveUnit(entry) or nil
  SetCurUnit(entry, unit)
  local preview = entry.bar and PreviewActive(entry)
  if not (entry.bar and enabled and BarVisible(entry.bar) and (preview or UnitPresent(unit))) then
    overlay:Hide()
    entry.shown = false
    return
  end
  -- Layout only when the overlay appears or the bar changed; the ticker
  -- keeps it in sync otherwise (no frame reads on every health event).
  if not entry.shown or entry.anchoredTo ~= entry.bar then SyncLayout(entry) end
  local _, mode = Settings(entry.kind, entry.group)
  local db = ns.db
  local color = db.textColor
  local opts = entry.opts or {}
  entry.opts = opts
  opts.abbreviate = db.abbreviate
  opts.decimals = db.percentDecimals
  opts.hideFull = GroupHideFull(entry.group) and not preview
  opts.stateText = db.stateText
  opts.blizzardDeadShown = BlizzardDeadShown(entry)
  -- Compact frames write Dead and Offline themselves (their status text).
  opts.blizzardStateShown = entry.compact
  opts.color = color
  opts.style = db.textStyle == "mono" and "mono" or "clear"
  if color == "class" then
    opts.classR, opts.classG, opts.classB = ns.ClassColor(preview and "player" or unit)
  else
    opts.classR, opts.classG, opts.classB = nil, nil, nil
  end
  opts.values = preview and PREVIEW[entry.kind] or nil
  opts.preview = preview
  opts.absorbs = db.showAbsorbs and entry.kind == "health"
  opts.previewAbsorb = preview and PREVIEW.absorb or nil
  entry.result = ns.ApplyText(entry.fs, unit, entry.kind, mode, opts)
  -- (1.9) Fit only real values; Dead, Ghost and Offline are short.
  if entry.result == "text" then Fit(entry, mode) end
  if entry.altFs then UpdateAlt(entry, unit, preview, opts) end
  overlay:Show()
  entry.shown = true
end
ns.UpdateEntry = UpdateEntry

local function Resolve(entry)
  local now = GetTime and GetTime() or 0
  entry.lastTry = now
  local bar, path, index = ns.FindBar(entry.paths)
  entry.bar, entry.path, entry.pathIndex = bar, path, index
  if bar then
    CreateOverlay(entry)
    entry.anchoredTo, entry.strata, entry.level, entry.scale, entry.barLevel = nil, nil, nil, nil, nil
    SyncLayout(entry)
    -- Safety scans of all bars spread over the 5 seconds (one slot per
    -- quarter second by entry number); syncs on events keep this phase.
    entry.scanDue = now + SAFETY_SCAN + (entry.index % (SAFETY_SCAN * 4)) * 0.25
    ApplyStyle(entry)
    FindDeadTexts(entry)
  elseif entry.overlay then
    entry.overlay:Hide()
    -- (1.6) Bug fix: the entry still counted as shown, so a bar that came
    -- back (Edit Mode, restyler) stayed without text until the next event.
    entry.shown = false
  end
end

function ns.ResolveAll()
  for _, entry in ipairs(entries) do ns.SafeCall("resolve", Resolve, entry) end
  -- Raid frames Blizzard built in the meantime (defined below).
  if ns.DiscoverRaid then ns.SafeCall("resolve", ns.DiscoverRaid) end
end

-- Matches the unit the entry shows right now ("vehicle" for the player bar
-- in a vehicle), so vehicle events reach the right bar.
local function UpdateUnit(unit, kind)
  if type(unit) ~= "string" or not ns.Usable(unit) then return end
  local list = ns.EntriesFor(unit)
  if not list then return end
  for i = 1, #list do
    local entry = list[i]
    if not kind or entry.kind == kind then UpdateEntry(entry) end
  end
end
ns.UpdateUnit = UpdateUnit

-- (1.9) Changes on every RefreshAll (options, Edit Mode): the probe widths
-- measured before are no longer valid.
ns.styleStamp = 0
function ns.RefreshAll()
  ns.styleStamp = ns.styleStamp + 1
  -- (1.6) Raid frames right after the option is switched on.
  if ns.DiscoverRaid then ns.DiscoverRaid() end
  for _, entry in ipairs(entries) do
    if entry.fs then ApplyStyle(entry) end
    ns.SafeCall("refresh", UpdateEntry, entry)
    -- Options (e.g. "Always keep text in front") may change the layer.
    if entry.shown then ns.SafeCall("refresh", SyncLayout, entry) end
  end
end

-- Units the client sends no reliable events for are refreshed on the ticker.
local POLLED = { targettarget = true, focustarget = true, pet = true }

-- A bar Blizzard replaced (Edit Mode, party frame rebuild) no longer sits
-- at its path: search again.
local function Stale(entry)
  if not entry.path then return false end
  return ns.Lookup(entry.path) ~= entry.bar
end

local KINDS = { "health", "power" }
local function AddEntries(def)
  for _, kind in ipairs(KINDS) do
    if def[kind] then
      local entry = {
        unit = def.unit, group = def.group, kind = kind, paths = def[kind],
        compact = def.compact, unitPaths = def.unitPaths, poll = POLLED[def.unit] or false,
      }
      entries[#entries + 1] = entry
      entry.index = #entries
      unitsDirty = true
    end
  end
end

-- (1.6) Raid frames exist only after Blizzard created them: new ones are
-- picked up on roster changes and every 2 seconds while the option is on.
-- Frames are never destroyed, so the entries stay.
local raid = { flat = 0, groups = {} }
local function DiscoverRaid()
  if not (ns.db and ns.db.showRaid) then return end
  local names = ns.RaidNames()
  for i = raid.flat + 1, ns.RAID_FRAME_MAX do
    local name = names.flat[i]
    if type(ns.Lookup(name)) ~= "table" then break end
    raid.flat = i
    local def = ns.CompactDef(name, "raidframe" .. i, "showRaid")
    AddEntries(def)
    Resolve(entries[#entries])
  end
  for g = 1, ns.RAID_GROUPS do
    if not raid.groups[g] and type(ns.Lookup(names.groups[g])) == "table" then
      raid.groups[g] = true
      for m = 1, 5 do
        AddEntries(ns.CompactDef(names.groups[g] .. "Member" .. m, ("raidgroup%d.%d"):format(g, m), "showRaid"))
        Resolve(entries[#entries])
      end
    end
  end
end
ns.DiscoverRaid = DiscoverRaid

local raidLookAt = 0
local function Tick()
  local now = GetTime and GetTime() or 0
  if ns.db.showRaid and now - raidLookAt >= 2 then
    raidLookAt = now
    DiscoverRaid()
  end
  for i = 1, #entries do
    local entry = entries[i]
    local enabled = Enabled(entry)
    -- (1.6) Switched off and already hidden: nothing to do.
    if enabled or entry.shown then
      if not entry.bar then
        if enabled and now - (entry.lastTry or 0) >= 2 then Resolve(entry) end
      elseif enabled and now - (entry.lastTry or 0) >= 2 then
        entry.lastTry = now
        if Stale(entry) then Resolve(entry) end
      end
      if entry.bar then
        local unit = entry.curUnit
        if enabled then unit = EffectiveUnit(entry) end
        local visible = enabled and BarVisible(entry.bar) and (PreviewActive(entry) or UnitPresent(unit))
        local changed = visible ~= entry.shown or unit ~= entry.curUnit
        if changed or (visible and entry.poll) then UpdateEntry(entry) end
        -- (1.6) Full sync with the layer scan only when the cheap check
        -- sees a change (frame raised by a click, restyler added a frame
        -- to the bar or moved it) and otherwise every 5 seconds per bar.
        -- Up to 1.5 every bar was scanned once per second.
        if not changed and visible and entry.shown then
          local due = entry.scanDue or now
          if now >= due then
            -- Next slot in the same phase, also after a long pause.
            entry.scanDue = now + SAFETY_SCAN - math.fmod(now - due, SAFETY_SCAN)
            SyncLayout(entry)
          elseif LayerChanged(entry) then
            SyncLayout(entry)
          end
        end
      end
    end
  end
  if unitsDirty then IndexUnits() end
end
ns.Tick = Tick

local function Build()
  for _, def in ipairs(ns.UnitDefs()) do AddEntries(def) end
  ns.ResolveAll()
  ns.RefreshAll()
  ns.ticker = ns.NewTicker(0.25, Tick)
end
ns.OnInit(Build)

-- Events -------------------------------------------------------------------
-- Every unit token one of our bars can show. Unit events for other units
-- (raid1..40, nameplates, ...) are dropped by the dispatcher before any
-- handler runs.
local WATCHED = { player = true, vehicle = true, pet = true, target = true, focus = true, targettarget = true, focustarget = true }
for i = 1, 4 do WATCHED["party" .. i] = true end
for i = 1, 5 do WATCHED["boss" .. i] = true end
ns.WATCHED = WATCHED

local function OnHealth(_, unit) UpdateUnit(unit, "health") end
local function OnPower(_, unit) UpdateUnit(unit, "power") end
local function OnBoth(_, unit) UpdateUnit(unit) end

-- The last argument lets the units of the compact frames through as well
-- (ns.extraUnits, empty while those options are off).
ns.On("UNIT_HEALTH", OnHealth, WATCHED, true)
ns.On("UNIT_MAXHEALTH", OnHealth, WATCHED, true)
ns.On("UNIT_ABSORB_AMOUNT_CHANGED", function(_, unit)
  if ns.db.showAbsorbs then UpdateUnit(unit, "health") end
end, WATCHED, true)
ns.On("UNIT_POWER_UPDATE", OnPower, WATCHED)
ns.On("UNIT_MAXPOWER", OnPower, WATCHED)
ns.On("UNIT_DISPLAYPOWER", OnPower, WATCHED)
ns.On("UNIT_CONNECTION", OnBoth, WATCHED, true)
-- Target frames are rebuilt and raised on a target change; restylers then
-- often move their frames too: check the layer at once.
local function SyncUnit(unit)
  for _, entry in ipairs(entries) do
    if entry.unit == unit and entry.shown then SyncLayout(entry) end
  end
end
ns.On("PLAYER_TARGET_CHANGED", function()
  UpdateUnit("target")
  UpdateUnit("targettarget")
  SyncUnit("target")
  SyncUnit("targettarget")
end)
ns.On("UNIT_TARGET", function(_, unit)
  if unit == "focus" then UpdateUnit("focustarget") else UpdateUnit("targettarget") end
end, { target = true, focus = true })
ns.On("PLAYER_FOCUS_CHANGED", function()
  UpdateUnit("focus")
  UpdateUnit("focustarget")
  SyncUnit("focus")
  SyncUnit("focustarget")
end)
-- Boss frames appear and change when an encounter adds or removes units.
local function UpdateBosses()
  for _, entry in ipairs(entries) do
    if entry.group == "showBoss" then UpdateEntry(entry) end
  end
end
ns.On("INSTANCE_ENCOUNTER_ENGAGE_UNIT", function()
  UpdateBosses()
  ns.After(0.1, UpdateBosses)
end)
ns.On("UNIT_PET", function()
  -- The pet frame is shown by Blizzard right after this event.
  UpdateUnit("pet")
  ns.After(0.1, function() UpdateUnit("pet") end)
end, { player = true })
-- Party frames: search again only where Blizzard replaced a bar (roster
-- updates come often in raids).
-- (1.6) Compact frames too: Blizzard may build them now and changes the
-- units they show (the ticker also notices that within a quarter second).
local ROSTER_GROUPS = { showParty = true, showCompactParty = true, showRaid = true }
ns.On("GROUP_ROSTER_UPDATE", function()
  DiscoverRaid()
  local db = ns.db
  for _, entry in ipairs(entries) do
    if ROSTER_GROUPS[entry.group] and (db[entry.group] or entry.shown) then
      if not entry.bar or Stale(entry) then Resolve(entry) end
      UpdateEntry(entry)
    end
  end
end)
-- Vehicle and possess change which unit the player and pet frame show.
local function UpdateSelf()
  for _, entry in ipairs(entries) do
    if entry.unit == "player" or entry.unit == "pet" then UpdateEntry(entry) end
  end
end
local function OnVehicle()
  UpdateSelf()
  ns.After(0.1, UpdateSelf)
end
ns.On("UNIT_ENTERED_VEHICLE", OnVehicle, { player = true })
ns.On("UNIT_EXITED_VEHICLE", OnVehicle, { player = true })

-- Edit Mode may rebuild or move frames; ns.On ignores unknown events.
local function Rescan()
  ns.ResolveAll()
  ns.RefreshAll()
end
ns.On("EDIT_MODE_LAYOUTS_UPDATED", function()
  Rescan()
  ns.After(0.2, Rescan)
end)

-- Returns true if the player frame shows the preview text.
function ns.StartPreview()
  local now = GetTime and GetTime() or 0
  ns.previewUntil = now + PREVIEW_SECONDS
  ns.RefreshAll()
  ns.After(PREVIEW_SECONDS + 0.1, function()
    -- A second click extends the preview: an older timer must not end it.
    local t = GetTime and GetTime() or 0
    if not ns.previewUntil or t < ns.previewUntil then return end
    ns.previewUntil = nil
    ns.RefreshAll()
  end)
  for _, entry in ipairs(entries) do
    if entry.unit == "player" and entry.shown then return true end
  end
  return false
end

-- (1.5) A restyler that hid the original bar and shows its own: the bar is
-- not visible (or fully transparent) while its container is. Read only.
-- (1.8.1) Hidden or transparent alone is no proof: Blizzard hides the power
-- bar of units without power (most mobs) and its own frames hide bars too.
-- "Another addon" only with evidence: a visible status bar next to the bar
-- in the same container that is not one of Blizzard's own, or a known
-- restyler is loaded. Unknown (secret) values never count as evidence.
local RESTYLERS = { "BetterBlizzFrames" }
-- Blizzard's own status bars that can sit next to a unit frame bar.
local BLIZZ_SIBLINGS = { "HealthBar", "ManaBar", "PowerBar", "AlternatePowerBar", "TempMaxHealthLoss",
  "TempMaxHealthLossBar", "MyHealPredictionBar", "OtherHealPredictionBar", "TotalAbsorbBar", "HealAbsorbBar",
  "MyHealAbsorbBar", "SpellBar", "ClassPowerBar" }
local function Raw(t, k) local ok, v = pcall(rawget, t, k); return ok and v or nil end

local function OwnBar(f)
  for _, e in ipairs(entries) do
    if e.bar == f or e.overlay == f then return true end
  end
  return ownOverlay[f] and true or false
end

-- (1.10) Alpha of a frame including its parents (GetEffectiveAlpha), else
-- its own; readable or nil. Read only.
local function EffectiveAlpha(f)
  if type(f) ~= "table" or not ns.Usable(f) then return nil end
  local a = ns.Num(ns.Value(f.GetEffectiveAlpha, f))
  if a then return a end
  return ns.Num(ns.Value(f.GetAlpha, f))
end
ns.EffectiveAlpha = EffectiveAlpha

-- (1.10) faded = false: a visible foreign bar next to ours (evidence for a
-- replacement). faded = true: a foreign bar that is transparent too, which
-- is what a clean-UI addon that fades every child of the frame leaves.
local function SiblingCheck(bar, container, faded, ...)
  for i = 1, select("#", ...) do
    local f = select(i, ...)
    if type(f) == "table" and ns.Usable(f) and f ~= bar and not OwnBar(f)
      and ns.Value(f.GetObjectType, f) == "StatusBar" and ns.True(ns.Call(f.IsVisible, f)) then
      local blizz = false
      for _, k in ipairs(BLIZZ_SIBLINGS) do
        if Raw(container, k) == f then blizz = true break end
      end
      if not blizz then
        local fa = ns.Num(ns.Value(f.GetAlpha, f))
        local isFaded = fa ~= nil and fa <= 0.01
        if isFaded == faded then return true end
      end
    end
  end
  return false
end

local function OtherBarShown(bar, container, faded)
  if type(container.GetChildren) ~= "function" then return false end
  local ok, r = pcall(function() return SiblingCheck(bar, container, faded, container:GetChildren()) end)
  return ok and r == true
end

local function RestylerLoaded()
  for _, name in ipairs(RESTYLERS) do
    if ns.AddOnLoaded(name) == true then return true end
  end
  return false
end

-- Readable proof that the unit has no power (maximum 0 or power type
-- "none"). Secret or missing values: false (unknown).
local function NoPower(unit)
  local max = ns.Num(ns.Call(UnitPowerMax, unit))
  if max and max <= 0 then return true end
  local ptype = ns.Num(ns.Call(UnitPowerType, unit))
  if ptype and ptype < 0 then return true end
  return false
end

-- Returns state ("hidden", "transparent" or nil) and reason: "addon"
-- (evidence for another addon), "nopower" (the unit has no power) or
-- "blizzard" (no evidence; Blizzard's normal behaviour).
function ns.BarCondition(entry)
  local bar = entry and entry.bar
  if not bar then return nil end
  local container = ns.Value(bar.GetParent, bar)
  if type(container) ~= "table" or not ns.True(ns.Call(container.IsVisible, container)) then return nil end
  local state
  if not BarVisible(bar) then
    if not UnitPresent(EffectiveUnit(entry)) then return nil end
    state = "hidden"
  else
    local alpha = ns.Num(ns.Value(bar.GetAlpha, bar))
    if not (alpha and alpha <= 0.01) then return nil end
    state = "transparent"
    -- (1.10) The whole unit frame is faded (clean-UI addons, fade on
    -- mouseover): the container is transparent too. Not a replacement.
    local frameAlpha = EffectiveAlpha(container)
    if frameAlpha and frameAlpha <= 0.01 then return state, "faded" end
    if OtherBarShown(bar, container, true) then return state, "faded" end
  end
  local unit = EffectiveUnit(entry)
  if entry.kind == "power" and NoPower(unit) then return state, "nopower" end
  -- (1.10) A hidden power bar of a unit whose power cannot be read (target
  -- values are secret): a loaded restyler alone proves nothing, Blizzard
  -- hides the bar of mobs without power. Only a foreign bar counts then.
  local unknownPower = entry.kind == "power" and state == "hidden" and not ns.Num(ns.Call(UnitPowerMax, unit))
  if OtherBarShown(bar, container, false) or (not unknownPower and RestylerLoaded()) then return state, "addon" end
  return state, "blizzard"
end

-- "hidden" or "transparent" only when another addon replaced the bar.
function ns.RestylerState(entry)
  local state, reason = ns.BarCondition(entry)
  if reason == "addon" then return state end
  return nil
end

-- One chat line per session each: Blizzard's status text, BetterBlizzFrames'
-- own bar text.
local function LoginHints()
  local L = ns.L
  -- (1.7) New installation: one short line where to find the options.
  if ns.firstRun and not ns.welcomeDone then
    ns.welcomeDone = true
    ns.Print(L["Text is on your unit frames. Options: /vd, commands: /vd help."])
  end
  local bbf = ns.BBFInfo()
  if bbf.loaded and not ns.bbfHintDone and (bbf.centerText or (bbf.formatText and ns.BlizzardStatusTextOn())) then
    ns.bbfHintDone = true
    ns.statusHintDone = true
    ns.Print(L["BetterBlizzFrames shows its own text on the bars (Format Numbers or Current HP Only & Center on Bars). It may overlap Vitaldon's text. Turn it off in BetterBlizzFrames or turn off Vitaldon for these frames."])
  end
  if not ns.statusHintDone and ns.BlizzardStatusTextOn() then
    ns.statusHintDone = true
    ns.Print(L["Blizzard's status text is on and may overlap Vitaldon's text. Turn it off in the Vitaldon options (/vd) or under Options > Interface > Status text."])
  end
end

ns.On("PLAYER_ENTERING_WORLD", function()
  ns.ResolveAll()
  ns.RefreshAll()
  LoginHints()
end)
