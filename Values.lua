local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Health and power text that also works with secret values.
--
-- Rules (warcraft.wiki.gg "Secret Values", Patch 12.0.0 API changes):
-- secrets may be stored, passed to functions, concatenated and given to
-- string.format, FontString:SetText/SetFormattedText, AbbreviateNumbers,
-- AbbreviateLargeNumbers and tostring. Arithmetic, comparisons, # and table
-- keys are forbidden. So with secret values this file never computes: the
-- percent comes from the game (UnitHealthPercent / UnitPowerPercent with
-- CurveConstants.ScaleTo100), numbers are only formatted. With readable
-- values (out of combat, own unit) it may compute, e.g. for "hide at full".
-- Every game call is protected: a failing call gives nil, never an error.
---------------------------------------------------------------------------

ns.FORMATS = { "percent", "current", "current_max", "current_percent", "current_max_percent", "deficit" }
ns.FORMAT_LABELS = {
  percent = "Percent (87%)",
  current = "Current (12.3k)",
  current_max = "Current / max (12.3k / 15k)",
  current_percent = "Current (percent) (12.3k (82%))",
  current_max_percent = "Current / max (percent) (12.3k / 15k (82%))",
  deficit = "Deficit (-2.7k)",
}
-- (1.6) Names without the fixed example: the option lists add a sample
-- built with the current settings (ns.FormatSample).
ns.FORMAT_NAMES = {
  percent = "Percent", current = "Current", current_max = "Current / max",
  current_percent = "Current (percent)", current_max_percent = "Current / max (percent)", deficit = "Deficit",
}
ns.ALIGNS = { "CENTER", "LEFT", "RIGHT" }
ns.ALIGN_LABELS = { CENTER = "Center", LEFT = "Left", RIGHT = "Right" }

-- The curve is a constant of the client: read once, then cached (this runs
-- on every health and power event).
local curveCache
local function ReadCurve(c) return c.ScaleTo100 end
local function Curve()
  if type(curveCache) ~= "nil" then return curveCache end
  local c = CurveConstants
  if type(c) == "table" or type(c) == "userdata" then
    local ok, curve = pcall(ReadCurve, c)
    if ok and type(curve) ~= "nil" then curveCache = curve end
    if ok then return curve end
  end
  return nil
end
ns.Curve = Curve

-- Own short form for readable numbers when the client has no abbreviation.
-- (1.10) The decimal separator follows the client (DECIMAL_SEPARATOR, a
-- constant of the game, only read): 1,2M in German. Rounding that reaches
-- 1000 moves to the next unit: 999,999 is 1M (up to 1.9: 1000k), 999.96M is
-- 1B (up to 1.9: 1000M).
local function DecimalSeparator()
  local d = _G.DECIMAL_SEPARATOR
  if type(d) == "string" and ns.Usable(d) and d ~= "" then return d end
  return "."
end

-- t = value in tenths of the unit: 125 -> "12.5k", 120 -> "12k".
local function Tenths(t, suffix)
  local whole, dec = math.floor(t / 10), t % 10
  if dec == 0 then return whole .. suffix end
  return whole .. DecimalSeparator() .. dec .. suffix
end

local function ShortReadable(n)
  local sign = n < 0 and "-" or ""
  local a = math.abs(n)
  if math.floor(a + 0.5) < 1000 then return sign .. math.floor(a + 0.5) end
  if a < 1e6 then
    if a < 1e4 then
      local t = math.floor(a / 100 + 0.5)
      if t < 100 then return sign .. Tenths(t, "k") end
    end
    local k = math.floor(a / 1e3 + 0.5)
    if k < 1000 then return sign .. k .. "k" end
  end
  if a < 1e9 then
    local t = math.floor(a / 1e5 + 0.5)
    if t < 10000 then return sign .. Tenths(t, "M") end
  end
  return sign .. Tenths(math.floor(a / 1e8 + 0.5), "B")
end
ns.ShortReadable = ShortReadable

local function GroupReadable(n)
  local s = tostring(math.floor(n + 0.5))
  local sign, digits = s:match("^(-?)(%d+)$")
  if not digits then return s end
  digits = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
  return sign .. digits
end

-- Text for a number that may be secret. The result may be a secret string:
-- only pass it on to string.format / SetFormattedText.
function ns.FormatNumber(v, abbreviate)
  if type(v) == "nil" then return nil end
  local readable = ns.Num(v)
  if abbreviate then
    local s = ns.Call(AbbreviateNumbers, v)
    if type(s) ~= "nil" then return s end
    s = ns.Call(AbbreviateLargeNumbers, v)
    if type(s) ~= "nil" then return s end
    if readable then return ShortReadable(readable) end
  else
    local s = ns.Call(BreakUpLargeNumbers, v)
    if type(s) ~= "nil" then return s end
    if readable then return GroupReadable(readable) end
  end
  return ns.Call(tostring, v)
end

-- Raw values (possibly secret) for one unit and bar kind.
-- Returns cur, max, pct (0 to 100), missing. powerType (optional, power
-- only) reads a power other than the one the unit shows, e.g. the mana of
-- a druid in cat form.
function ns.ReadValues(unit, kind, powerType)
  local cur, max, pct, missing
  local curve = Curve()
  if kind == "health" then
    cur = ns.Call(UnitHealth, unit)
    max = ns.Call(UnitHealthMax, unit)
    if type(curve) ~= "nil" then pct = ns.Call(UnitHealthPercent, unit, true, curve) end
    missing = ns.Call(UnitHealthMissing, unit, true)
  else
    cur = ns.Call(UnitPower, unit, powerType)
    max = ns.Call(UnitPowerMax, unit, powerType)
    if type(curve) ~= "nil" then pct = ns.Call(UnitPowerPercent, unit, powerType, false, curve) end
    missing = ns.Call(UnitPowerMissing, unit, powerType)
  end
  -- Readable fallbacks where the client lacks an API.
  local c, m = ns.Num(cur), ns.Num(max)
  if type(pct) == "nil" and c and m then pct = m > 0 and (c / m * 100) or 0 end
  if c and m then missing = m - c end
  return cur, max, pct, missing
end

-- Percent with 0, 1 or 2 decimals; the format goes to SetFormattedText, so
-- secret percents need no arithmetic.
local PCT = { [0] = "%.0f%%", [1] = "%.1f%%", [2] = "%.2f%%" }
function ns.PercentFormat(decimals)
  return PCT[tonumber(decimals) or 0] or PCT[0]
end

---------------------------------------------------------------------------
-- Text style. "clear": the value in the text colour, the details (" / max",
-- " (percent)") in a softer grey. The grey is a colour code inside the
-- format string: literal text, so it also works with secret values (no
-- value is compared or changed, only SetFormattedText fills the gaps).
-- "mono": the whole text in the text colour (Vitaldon up to 1.3).
---------------------------------------------------------------------------
ns.STYLES = { "clear", "mono" }
ns.STYLE_LABELS = { clear = "Clear (white value, grey details)", mono = "Single colour (as before)" }
-- Family secondary text colour (DESIGN.md 0.62, 0.64, 0.68), lightened for
-- the coloured bars so the details stay readable on green and blue.
ns.DETAIL_COLOR = "ffc4c8cf"
local DETAIL_OPEN, DETAIL_CLOSE = "|c" .. ns.DETAIL_COLOR, "|r"

-- Format strings per style, mode and decimals, built once (no garbage per event).
local formatCache = {}
local function Formats(clear, decimals)
  local key = (clear and "c" or "m") .. (PCT[tonumber(decimals) or 0] and (tonumber(decimals) or 0) or 0)
  local f = formatCache[key]
  if f then return f end
  local pf = ns.PercentFormat(decimals)
  local open, close = "", ""
  if clear then open, close = DETAIL_OPEN, DETAIL_CLOSE end
  f = {
    percent = pf,
    current = "%s",
    deficit = "-%s",
    current_max = "%s" .. open .. " / %s" .. close,
    current_percent = "%s" .. open .. " (" .. pf .. ")" .. close,
    current_max_percent = "%s" .. open .. " / %s (" .. pf .. ")" .. close,
  }
  formatCache[key] = f
  return f
end
ns.Formats = Formats

-- Absorb shield text: "" or " +3.4k" (coloured). With a secret amount the
-- game builds the text: C_StringUtil.TruncateWhenZero gives "" for 0, and
-- C_StringUtil.WrapString adds prefix and suffix only to a non-empty text.
-- Without these functions a secret amount shows nothing.
-- Accent colour of the addon family (#3FA9F5).
ns.ABSORB_PREFIX, ns.ABSORB_SUFFIX = " |cff3fa9f5+", "|r"
function ns.AbsorbText(unit, abbreviate, amount)
  if type(amount) == "nil" then amount = ns.Call(UnitGetTotalAbsorbs, unit) end
  if type(amount) == "nil" then return "" end
  local readable = ns.Num(amount)
  if readable then
    if readable < 1 then return "" end
    local s = ns.FormatNumber(readable, abbreviate)
    if type(s) ~= "string" then return "" end
    return ns.ABSORB_PREFIX .. s .. ns.ABSORB_SUFFIX
  end
  local util = C_StringUtil
  if type(util) ~= "table" then return "" end
  local digits = ns.Call(util.TruncateWhenZero, amount)
  if type(digits) == "nil" then return "" end
  local text = ns.Call(util.WrapString, digits, ns.ABSORB_PREFIX, ns.ABSORB_SUFFIX)
  if type(text) == "nil" then return "" end
  return text
end

-- "dead", "ghost", "offline" or nil. Secret answers count as unknown.
function ns.UnitState(unit)
  local connected = ns.Value(UnitIsConnected, unit)
  if connected == false then return "offline" end
  if ns.True(ns.Call(UnitIsGhost, unit)) then return "ghost" end
  if ns.True(ns.Call(UnitIsDead, unit)) then return "dead" end
  if type(UnitIsDead) ~= "function" and ns.True(ns.Call(UnitIsDeadOrGhost, unit)) then return "dead" end
  return nil
end

ns.STATE_TEXT = { dead = "Dead", ghost = "Ghost", offline = "Offline" }

-- Builds the text as format string plus arguments for SetFormattedText.
-- Returns nil for "show nothing", or fmt, arg1, arg2, arg3.
-- opts.values = { cur, max, pct, missing } replaces the game values
-- (used by the preview); opts.powerType reads another power type;
-- opts.decimals = decimals of the percent (0 to 2).
function ns.BuildText(unit, kind, mode, opts)
  opts = opts or {}
  local cur, max, pct, missing
  if type(opts.values) == "table" then
    cur, max, pct, missing = opts.values[1], opts.values[2], opts.values[3], opts.values[4]
  else
    cur, max, pct, missing = ns.ReadValues(unit, kind, opts.powerType)
  end
  local c, m = ns.Num(cur), ns.Num(max)

  -- Readable maximum 0: no bar to describe (power: e.g. no power type;
  -- (1.7) health: unit data not loaded yet, instead of "0 (0%)").
  if m and m <= 0 then return nil end
  if kind == "health" and opts.hideFull and c and m and m > 0 and c >= m then return nil end

  local abbr = opts.abbreviate
  local F = Formats(opts.style ~= "mono", opts.decimals)
  if mode == "percent" then
    if type(pct) == "nil" then return nil end
    return F.percent, pct
  elseif mode == "deficit" then
    local miss = ns.Num(missing)
    if miss then
      if miss <= 0 then return nil end
      return F.deficit, ns.FormatNumber(miss, abbr)
    end
    if type(missing) == "nil" then return nil end
    return F.deficit, ns.FormatNumber(missing, abbr)
  end

  local curText = ns.FormatNumber(cur, abbr)
  if type(curText) == "nil" then return nil end
  if mode == "current_max" or mode == "current_max_percent" then
    local maxText = ns.FormatNumber(max, abbr)
    if type(maxText) == "nil" then return F.current, curText end
    if mode == "current_max_percent" and type(pct) ~= "nil" then
      return F.current_max_percent, curText, maxText, pct
    end
    return F.current_max, curText, maxText
  elseif mode == "current_percent" then
    if type(pct) ~= "nil" then return F.current_percent, curText, pct end
    return F.current, curText
  end
  return F.current, curText
end

ns.COLORS = { "white", "health", "class" }
ns.COLOR_LABELS = {
  white = "White",
  health = "By health (green, yellow, red)",
  class = "Class colour",
}

-- Colour for a readable percent (0 to 100). Secret or missing: nil.
-- Family status colours (DESIGN.md): good, warning, critical.
ns.STATUS_COLORS = {
  good = { 0.40, 0.80, 0.45 }, warning = { 0.95, 0.75, 0.25 }, critical = { 0.92, 0.35, 0.32 },
}
function ns.HealthColor(pct)
  local p = ns.Num(pct)
  if not p then return nil end
  local c = ns.STATUS_COLORS
  if p > 50 then return c.good[1], c.good[2], c.good[3] end
  if p > 20 then return c.warning[1], c.warning[2], c.warning[3] end
  return c.critical[1], c.critical[2], c.critical[3]
end

-- Readable class colour of a player unit, else nil.
function ns.ClassColor(unit)
  if not ns.True(ns.Call(UnitIsPlayer, unit)) then return nil end
  if type(UnitClass) ~= "function" then return nil end
  local ok, _, classFile = pcall(UnitClass, unit)
  if not ok or type(classFile) ~= "string" or not ns.Usable(classFile) then return nil end
  local c
  if C_ClassColor and C_ClassColor.GetClassColor then c = ns.Call(C_ClassColor.GetClassColor, classFile) end
  if (type(c) ~= "table" or not ns.Usable(c)) and type(RAID_CLASS_COLORS) == "table" then c = RAID_CLASS_COLORS[classFile] end
  if type(c) ~= "table" or not ns.Usable(c) then return nil end
  local r, g, b = ns.Num(c.r), ns.Num(c.g), ns.Num(c.b)
  if r and g and b then return r, g, b end
  return nil
end

-- Only when the colour changes (one game call less per event). The last
-- colour is kept on our own FontString.
local function SetColor(fs, r, g, b)
  r, g, b = r or 1, g or 1, b or 1
  if fs._vdR == r and fs._vdG == g and fs._vdB == b then return end
  if fs.SetTextColor and pcall(fs.SetTextColor, fs, r, g, b) then
    fs._vdR, fs._vdG, fs._vdB = r, g, b
  end
end

-- Format plus "%s" for the absorb text, built once per format.
local absorbFormats = {}
local function WithAbsorb(fmt)
  local f = absorbFormats[fmt]
  if not f then f = fmt .. "%s"; absorbFormats[fmt] = f end
  return f
end

-- Values of one update. Reused: one table for the whole addon, no garbage
-- per event.
local scratch = {}

-- Writes the text into our own FontString. Never errors: if the client
-- refuses a value, the FontString stays empty.
-- opts.style: "clear" (default) or "mono", see ns.Formats.
-- opts.color: "white", "health" (health text only, readable values only)
-- or "class" (opts.classR/G/B). opts.absorbs: absorb shield text after the
-- health text. opts.values: fixed values (preview). opts.blizzardStateShown:
-- the frame shows Dead and Offline itself (compact frames), stay empty then.
function ns.ApplyText(fs, unit, kind, mode, opts)
  opts = opts or {}
  local values = opts.values
  if type(values) ~= "table" then
    values = scratch
    values[1], values[2], values[3], values[4] = ns.ReadValues(unit, kind, opts.powerType)
  end
  local r, g, b
  if opts.color == "health" and kind == "health" then
    r, g, b = ns.HealthColor(values[3])
  elseif opts.color == "class" then
    if type(opts.classColor) == "table" then
      r, g, b = opts.classColor[1], opts.classColor[2], opts.classColor[3]
    else
      r, g, b = opts.classR, opts.classG, opts.classB
    end
  end
  SetColor(fs, r, g, b)
  -- (1.7) Blizzard's own Dead/Unconscious text is on this bar: stay empty,
  -- also when the game hides the dead state from addons.
  if opts.blizzardDeadShown and kind == "health" and not opts.preview then
    fs:SetText("")
    return "state"
  end
  if (opts.stateText ~= false or opts.blizzardStateShown) and not opts.preview then
    local state = ns.UnitState(unit)
    if state then
      if kind == "power" or opts.blizzardStateShown then fs:SetText("") return "state" end
      fs:SetText(L[ns.STATE_TEXT[state]])
      return "state"
    end
  end
  local saved = opts.values
  opts.values = values
  local fmt, a, b2, c = ns.BuildText(unit, kind, mode, opts)
  opts.values = saved
  if type(fmt) == "nil" then
    fs:SetText("")
    return "empty"
  end
  local ok
  if opts.absorbs and kind == "health" then
    local absorb = opts.preview and ns.AbsorbText(unit, opts.abbreviate, opts.previewAbsorb) or ns.AbsorbText(unit, opts.abbreviate)
    -- The absorb text is always the last argument.
    local fa = WithAbsorb(fmt)
    if type(c) ~= "nil" then
      ok = pcall(fs.SetFormattedText, fs, fa, a, b2, c, absorb)
    elseif type(b2) ~= "nil" then
      ok = pcall(fs.SetFormattedText, fs, fa, a, b2, absorb)
    else
      ok = pcall(fs.SetFormattedText, fs, fa, a, absorb)
    end
  else
    ok = pcall(fs.SetFormattedText, fs, fmt, a, b2, c)
  end
  if not ok then
    pcall(fs.SetText, fs, "")
    return "refused"
  end
  return "text"
end

---------------------------------------------------------------------------
-- (1.6) Format preview: every format with fixed sample numbers and the
-- current style, decimals and abbreviation. Only readable sample numbers,
-- never game values, so this works anywhere (options, chat).
---------------------------------------------------------------------------
ns.SAMPLE_VALUES = {
  health = { 12345, 15000, 82.3, 2655 },
  power = { 8000, 10000, 80, 2000 },
}
local sampleOpts = {}
function ns.FormatSample(mode, kind)
  local db = ns.db or ns.defaults
  kind = kind == "power" and "power" or "health"
  sampleOpts.values = ns.SAMPLE_VALUES[kind]
  sampleOpts.abbreviate = db.abbreviate
  sampleOpts.decimals = db.percentDecimals
  sampleOpts.style = db.textStyle == "mono" and "mono" or "clear"
  local okBuild, fmt, a, b, c = pcall(ns.BuildText, "player", kind, mode, sampleOpts)
  if not okBuild or type(fmt) ~= "string" then return nil end
  local ok, text = pcall(string.format, fmt, a, b, c)
  if ok and type(text) == "string" then return text end
  return nil
end

-- "Current (percent): 12.3k (82%)", or the fixed label if no sample.
function ns.FormatLabel(mode, kind)
  local name = ns.FORMAT_NAMES[mode]
  local sample = name and ns.FormatSample(mode, kind)
  if sample then return L[name] .. ": " .. sample end
  return L[ns.FORMAT_LABELS[mode] or tostring(mode)]
end

-- /vd formats and the tool "Show all formats": one chat line per format,
-- health and power sample side by side.
function ns.PrintFormats()
  ns.Print(L["Formats with your settings (health | power):"])
  for _, mode in ipairs(ns.FORMATS) do
    print(("  |cffebebeb%s|r  %s  |cff9ea3ad|||r  %s"):format(L[ns.FORMAT_NAMES[mode]],
      ns.FormatSample(mode, "health") or "-", ns.FormatSample(mode, "power") or "-"))
  end
end
