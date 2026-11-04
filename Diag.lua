local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- /vd diag: which bars were found (and by which path), which APIs exist,
-- whether the values of each unit are secret right now, the Blizzard status
-- text setting and caught errors. No names, only units and true/false.
---------------------------------------------------------------------------

local APIS = {
  "UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax",
  "UnitHealthPercent", "UnitPowerPercent", "UnitHealthMissing", "UnitPowerMissing",
  "CurveConstants.ScaleTo100", "C_CurveUtil.CreateCurve",
  "AbbreviateNumbers", "AbbreviateLargeNumbers", "BreakUpLargeNumbers",
  "C_StringUtil.TruncateWhenZero", "C_StringUtil.WrapString", "UnitGetTotalAbsorbs",
  "UnitPowerType", "Enum.PowerType.Mana", "issecretvalue", "canaccessvalue",
  "UnitIsDead", "UnitIsGhost", "UnitIsConnected", "UnitExists",
  "Settings.RegisterAddOnSetting", "C_CVar.GetCVar", "C_CVar.SetCVar",
}

-- (1.9) Source of the text width for the fit.
local WIDTH_LABEL = { text = "readable", secret = "secret, no sample", probe = "secret, measured with sample values" }

local function Kind(v)
  if type(v) == "nil" then return "nil" end
  if ns.IsSecret(v) then return "secret" end
  return type(v)
end

-- Layer facts of one entry (read only): parent of our overlay, frame level
-- and strata of bar and overlay, scan result, restyler state.
local function Layer(entry)
  local bar, overlay = entry.bar, entry.overlay
  if not (bar and overlay) then return nil end
  local parent = ns.Call(overlay.GetParent, overlay)
  local r = {
    parent = parent == bar and "bar" or (parent == UIParent and "UIParent" or "other"),
    barLevel = ns.Num(ns.Value(bar.GetFrameLevel, bar)),
    barStrata = ns.Value(bar.GetFrameStrata, bar),
    level = ns.Num(ns.Value(overlay.GetFrameLevel, overlay)),
    strata = ns.Value(overlay.GetFrameStrata, overlay),
    state = entry.layerState or "ok",
    others = entry.scan and entry.scan.count or 0,
    -- (1.10) Alpha including parents: our text follows the bar's alpha.
    barAlpha = ns.EffectiveAlpha and ns.EffectiveAlpha(bar),
    alpha = ns.EffectiveAlpha and ns.EffectiveAlpha(overlay),
  }
  -- (1.8.1) Hidden or transparent bar: "another addon" only with evidence,
  -- otherwise a neutral state (no power, Blizzard's normal behaviour).
  local cond, reason = nil, nil
  if ns.BarCondition then cond, reason = ns.BarCondition(entry) end
  if cond then
    if reason == "addon" then r.restyled = cond else r.barNote = cond .. "_" .. reason end
  end
  return r
end
ns.DiagLayer = Layer

local LAYER_LABEL = {
  ok = "above the bar", raised = "one layer up", below = "may be covered", limit = "may be covered",
  unknown = "not readable",
}
local RESTYLED_LABEL = {
  hidden = "bar hidden, another addon shows its own",
  transparent = "bar transparent, another addon shows its own",
}
local BAR_NOTE_LABEL = {
  hidden_nopower = "bar hidden (no power)",
  hidden_blizzard = "bar hidden by Blizzard",
  transparent_nopower = "bar transparent (no power)",
  transparent_blizzard = "bar transparent",
  transparent_faded = "bar transparent (frame faded)",
}

-- (1.6) Blizzard's own health text on compact frames (raid profile option
-- "Display health text": none, health, losthealth, perc), read from the
-- first compact frame Vitaldon found. nil if none or unreadable.
function ns.CompactHealthText()
  for _, entry in ipairs(ns.entries or {}) do
    if entry.compact and entry.bar and entry.unitPaths then
      local frame = ns.Value(entry.bar.GetParent, entry.bar)
      local opts = type(frame) == "table" and frame.optionTable
      local v = type(opts) == "table" and ns.Usable(opts) and opts.healthText
      if type(v) == "string" and ns.Usable(v) then return v end
    end
  end
  return nil
end

-- (1.7) The game's number abbreviation in this client's language, from
-- fixed sample numbers (e.g. "12K, 1.2M" in English, "12K, 1,2 Mio." in
-- German). Shows what "Abbreviate large numbers" will look like.
function ns.AbbrevSample()
  local a = ns.FormatNumber(12345, true)
  local b = ns.FormatNumber(1234567, true)
  local c = ns.FormatNumber(1234567, false)
  local function S(v) return (type(v) == "string" and ns.Usable(v)) and v or "?" end
  return ("%s, %s"):format(S(a), S(b)), S(c)
end

local function BBFText(bbf)
  if not bbf.loaded then return nil end
  local on = {}
  if bbf.smoothBars then on[#on + 1] = "Smooth Bars" end
  if bbf.classicFrames then on[#on + 1] = "Classic Frames" end
  if bbf.noPortrait then on[#on + 1] = "No Portrait" end
  if bbf.formatText then on[#on + 1] = "Format Numbers" end
  if bbf.centerText then on[#on + 1] = "Current HP Only & Center on Bars" end
  return #on > 0 and table.concat(on, ", ") or nil
end

function ns.DiagLines()
  local out = {}
  local build = ns.Call(GetBuildInfo)
  out[#out + 1] = ("Vitaldon %s, client %s"):format(ns.Version(), ns.Usable(build) and tostring(build) or "?")

  local have, missing = 0, {}
  for _, name in ipairs(APIS) do
    if type(ns.Lookup(name)) ~= "nil" then have = have + 1 else missing[#missing + 1] = name end
  end
  out[#out + 1] = L["APIs: %d of %d present"]:format(have, #APIS)
  if #missing > 0 then out[#out + 1] = L["Missing: %s"]:format(table.concat(missing, ", ")) end

  out[#out + 1] = L["Blizzard status text: %s (statusTextDisplay=%s, statusText=%s)"]:format(
    ns.BlizzardStatusTextOn() and L["on"] or L["off"],
    ns.GetCVarValue("statusTextDisplay") or "?", ns.GetCVarValue("statusText") or "?")
  local bbf = ns.BBFInfo()
  local bbfOpts = BBFText(bbf)
  out[#out + 1] = L["BetterBlizzFrames loaded: %s"]:format(bbf.loaded and L["yes"] or L["no"]) .. (bbfOpts and (" (" .. bbfOpts .. ")") or "")
  out[#out + 1] = L["Always keep text in front: %s"]:format((ns.db or {}).textOnTop and L["on"] or L["off"])
  out[#out + 1] = ("%s: %s"):format(L["Fit text to bar"], (ns.db or {}).fitText and L["on"] or L["off"])
  local abbr, full = ns.AbbrevSample()
  out[#out + 1] = L["Number abbreviation: %s (unabbreviated %s)"]:format(abbr, full)

  local found, total = 0, 0
  for _, entry in ipairs(ns.entries or {}) do
    if not ns.Counted(entry) then
      -- compact frames with their option off: not listed
    elseif entry.bar then
      total = total + 1
      found = found + 1
      local note = entry.pathIndex and entry.pathIndex > 1 and (" " .. L["(fallback)"]) or ""
      local ly = Layer(entry)
      local layer = ""
      if ly then
        layer = (", parent=%s level %s/%s strata %s/%s, %s"):format(ly.parent, tostring(ly.barLevel), tostring(ly.level),
          tostring(ly.barStrata), tostring(ly.strata), ly.state)
        if ly.barAlpha and ly.alpha and (ly.barAlpha < 0.99 or ly.alpha < 0.99) then
          layer = layer .. (", alpha %.2f/%.2f"):format(ly.barAlpha, ly.alpha)
        end
        if ly.restyled then layer = layer .. ", " .. L[RESTYLED_LABEL[ly.restyled]]
        elseif ly.barNote then layer = layer .. ", " .. L[BAR_NOTE_LABEL[ly.barNote]] end
      end
      if entry.curSize then
        layer = layer .. (", size %d%s, width %s"):format(entry.curSize, entry.fitBy and ("/" .. entry.fitBy) or "", entry.widthSource or "-")
      end
      out[#out + 1] = ("%s %s: %s%s, %s%s"):format((entry.curUnit and entry.curUnit ~= entry.unit) and (entry.unit .. ">" .. entry.curUnit) or entry.unit, entry.kind, entry.path, note,
        entry.shown and L["shown"] or L["hidden"], layer)
    else
      total = total + 1
      out[#out + 1] = ("%s %s: %s"):format(entry.unit, entry.kind, L["not found"])
    end
  end
  out[#out + 1] = L["Bars found: %d of %d"]:format(found, total)

  local seen = {}
  for _, entry in ipairs(ns.entries or {}) do
    if not seen[entry.unit] and not entry.compact then
      seen[entry.unit] = true
      local exists = ns.Call(UnitExists, entry.unit)
      if ns.True(exists) or ns.IsSecret(exists) then
        out[#out + 1] = ("%s: health %s, max %s, percent %s, power %s, absorbs %s"):format(entry.unit,
          Kind(ns.Call(UnitHealth, entry.unit)), Kind(ns.Call(UnitHealthMax, entry.unit)),
          Kind(select(3, ns.ReadValues(entry.unit, "health"))), Kind(ns.Call(UnitPower, entry.unit)),
          Kind(ns.Call(UnitGetTotalAbsorbs, entry.unit)))
      else
        out[#out + 1] = ("%s: %s"):format(entry.unit, L["no unit"])
      end
    end
  end

  local db = ns.db or {}
  local mana = ns.Num(ns.Lookup("Enum.PowerType.Mana")) or 0
  out[#out + 1] = L["Druid mana: %s (power type %s, mana max %s)"]:format(
    not db.druidMana and L["off"] or (ns.AltManaWanted and ns.AltManaWanted("player") and L["shown"] or L["not needed"]),
    Kind(ns.Call(UnitPowerType, "player")), Kind(ns.Call(UnitPowerMax, "player", mana)))
  out[#out + 1] = L["Absorb shields: %s"]:format(db.showAbsorbs and L["on"] or L["off"])
  out[#out + 1] = L["Raid-style party frames: %s, raid frames: %s, Blizzard health text there: %s"]:format(
    db.showCompactParty and L["on"] or L["off"], db.showRaid and L["on"] or L["off"], ns.CompactHealthText() or "?")

  local errors = ns.Errors()
  if #errors == 0 then
    out[#out + 1] = L["Errors: none"]
  else
    for _, e in ipairs(errors) do
      out[#out + 1] = ("Error [%s] x%d: %s%s"):format(e.context, e.count, e.msg, e.stack and (" | " .. e.stack) or "")
    end
    if ns.droppedErrors then out[#out + 1] = L["More errors not listed: %d"]:format(ns.droppedErrors) end
  end
  return out
end

function ns.PrintDiag()
  ns.Print(L["Diagnostics:"])
  for _, line in ipairs(ns.DiagLines()) do print("  " .. line) end
end

---------------------------------------------------------------------------
-- Diagnostics window (StyleKit panel). Same facts as the chat output,
-- grouped and short: one row per unit, details in the row tooltip.
---------------------------------------------------------------------------
local function BarState(entry)
  if not entry then return nil end
  if not entry.bar then return "missing" end
  if entry.shown then return "shown" end
  return "hidden"
end

local STATE_LABEL = { shown = "shown", hidden = "hidden", missing = "not found" }
local STATE_COLOR = { shown = "good", hidden = "textSecondary", missing = "critical" }

-- Sections for the window: { title, rows = { { label, value, color, tip, hint } | { text = ..., color = ... } } }
function ns.DiagModel()
  local model = {}
  -- (02.11.2026) key: the window's tab of a section (general and features on Overview)
  local function Section(title, key) local s = { title = title, key = key, rows = {} }; model[#model + 1] = s; return s end

  local general = Section(L["General"], "general")
  local build = ns.Call(GetBuildInfo)
  general.rows[#general.rows + 1] = { L["Version"], ns.Version() }
  general.rows[#general.rows + 1] = { L["Client"], ns.Usable(build) and tostring(build) or "?" }
  local have, missing = 0, {}
  for _, name in ipairs(APIS) do
    if type(ns.Lookup(name)) ~= "nil" then have = have + 1 else missing[#missing + 1] = name end
  end
  general.rows[#general.rows + 1] = { L["Game functions"], L["%d of %d"]:format(have, #APIS), have == #APIS and "good" or "warning",
    #missing > 0 and { L["Missing: %s"]:format(table.concat(missing, ", ")) } or nil }
  local statusOn = ns.BlizzardStatusTextOn()
  general.rows[#general.rows + 1] = { L["Blizzard status text"], statusOn and L["on"] or L["off"], statusOn and "warning" or "good",
    { ("statusTextDisplay=%s, statusText=%s"):format(ns.GetCVarValue("statusTextDisplay") or "?", ns.GetCVarValue("statusText") or "?") },
    statusOn and L["Turn it off in the Vitaldon options (/vd > Tools)."] or nil }
  local abbr, full = ns.AbbrevSample()
  general.rows[#general.rows + 1] = { L["Number abbreviation"], abbr, nil,
    { { L["Unabbreviated"], full } }, L["From the game in your language, used with Abbreviate large numbers."] }
  local bbf = ns.BBFInfo()
  local bbfOpts = BBFText(bbf)
  local bbfTip
  if bbf.loaded then
    bbfTip = { { header = L["Options that touch the bars"] } }
    bbfTip[#bbfTip + 1] = bbfOpts or (bbf.read and L["none"] or L["not readable"])
    if bbf.centerText or bbf.formatText then
      bbfTip[#bbfTip + 1] = L["Its own bar text may overlap Vitaldon's text."]
    end
  end
  general.rows[#general.rows + 1] = { L["BetterBlizzFrames loaded"], bbf.loaded and L["yes"] or L["no"],
    (bbf.centerText or bbf.formatText) and "warning" or nil, bbfTip,
    bbf.loaded and L["Vitaldon keeps its text above the bar's fill. Details per bar in the Bars section."] or nil }

  -- Bars: one row per unit (health and power together)
  local bars = Section(L["Bars"], "bars")
  local order, byUnit = {}, {}
  local found, total = 0, 0
  for _, entry in ipairs(ns.entries or {}) do
    if ns.Counted(entry) then
      total = total + 1
      if entry.bar then found = found + 1 end
      if not byUnit[entry.unit] then byUnit[entry.unit] = {}; order[#order + 1] = entry.unit end
      byUnit[entry.unit][entry.kind] = entry
    end
  end
  bars.rows[#bars.rows + 1] = { L["Found"], L["%d of %d"]:format(found, total), found == total and "good" or "warning" }
  for _, unit in ipairs(order) do
    local h, pw = byUnit[unit].health, byUnit[unit].power
    local hs, ps = BarState(h), BarState(pw)
    -- Compact frames have no power entry: the health bar decides alone.
    if not pw then ps = hs end
    local state = (hs == "shown" or ps == "shown") and "shown" or ((hs == "missing" and ps == "missing") and "missing" or "hidden")
    local fallback = (h and h.pathIndex and h.pathIndex > 1) or (pw and pw.pathIndex and pw.pathIndex > 1)
    local value = L[STATE_LABEL[state]]
    if fallback then value = value .. ", " .. L["fallback path"] end
    local label = unit
    local cur = (h and h.curUnit) or (pw and pw.curUnit)
    if cur and cur ~= unit then label = unit .. " > " .. cur end
    local tip, problem = {}, nil
    if h and h.compact then
      tip[#tip + 1] = { L["Shows unit"], h.curUnit or L["none"] }
    end
    for _, e in ipairs({ h, pw }) do
      tip[#tip + 1] = { header = L[e.kind == "health" and "Health" or "Power"] }
      tip[#tip + 1] = e.bar and (e.path .. (e.pathIndex and e.pathIndex > 1 and (" " .. L["(fallback)"]) or "")) or L["not found"]
      local ly = Layer(e)
      if ly then
        tip[#tip + 1] = { L["Text frame parent"], L[ly.parent == "bar" and "the bar" or "other frame"], ly.parent == "bar" and "good" or "warning" }
        tip[#tip + 1] = { L["Level bar / text"], ("%s / %s"):format(tostring(ly.barLevel or "?"), tostring(ly.level or "?")) }
        tip[#tip + 1] = { L["Strata bar / text"], ("%s / %s"):format(tostring(ly.barStrata or "?"), tostring(ly.strata or "?")) }
        tip[#tip + 1] = { L["Other frames on the bar"], tostring(ly.others) }
        -- (1.10) Our text inherits the bar's alpha. Text clearly more opaque
        -- than its bar means another addon ignores the parent's alpha.
        if ly.barAlpha and ly.alpha then
          tip[#tip + 1] = { L["Alpha bar / text"], ("%.2f / %.2f"):format(ly.barAlpha, ly.alpha),
            ly.alpha > ly.barAlpha + 0.01 and "warning" or "good" }
        end
        -- (1.9) Font size in use and where the text width came from.
        if e.curSize then
          local sizeText = tostring(e.curSize)
          if e.fitBy then sizeText = sizeText .. " (" .. L[e.fitBy == "height" and "bar height" or "fitted to width"] .. ")" end
          tip[#tip + 1] = { L["Font size"], sizeText }
        end
        if e.widthSource then
          tip[#tip + 1] = { L["Text width"], (WIDTH_LABEL[e.widthSource] and L[WIDTH_LABEL[e.widthSource]] or "?") }
        end
        local bad = ly.state == "below" or ly.state == "limit"
        tip[#tip + 1] = { L["Text"], L[LAYER_LABEL[ly.state] or "above the bar"], bad and "warning" or "good" }
        if ly.restyled then
          tip[#tip + 1] = { L["Bar"], L[RESTYLED_LABEL[ly.restyled]], "warning" }
          problem = problem or "restyled"
        elseif ly.barNote then
          tip[#tip + 1] = { L["Bar"], L[BAR_NOTE_LABEL[ly.barNote]] }
        end
        if bad then problem = problem or "layer" end
      end
    end
    if problem == "restyled" then
      value = L["replaced by another addon"]
    elseif problem == "layer" then
      value = value .. ", " .. L["may be covered"]
    end
    local hint = problem == "layer" and L["Turn on Always keep text in front (/vd > General)."]
      or (problem == "restyled" and L["Vitaldon only shows text on Blizzard's own bars. Use the other addon's text for this frame."] or nil)
    local color = problem and "warning" or (fallback and state ~= "missing" and "warning" or STATE_COLOR[state])
    -- (02.11.2026) the columns of the window's bar table: unit, health, power, font size, layer
    local function StateCell(e, s)
      if not e then return { L["health only"], "textHint" } end
      if s ~= "missing" and e.pathIndex and e.pathIndex > 1 then return { L["fallback path"], "warning" } end
      return { L[STATE_LABEL[s]], STATE_COLOR[s] }
    end
    local function SizeText(e) return e and e.bar and e.shown and e.curSize and tostring(e.curSize) or "-" end
    local layer = { "-" }
    local ly = (h and Layer(h)) or (pw and Layer(pw))
    if problem == "restyled" then layer = { L["replaced by another addon"], "warning" }
    elseif problem == "layer" then layer = { L["may be covered"], "warning" }
    elseif ly then layer = { L[LAYER_LABEL[ly.state] or "above the bar"], ly.state == "unknown" and "textSecondary" or "good" } end
    bars.rows[#bars.rows + 1] = { label, value, color, tip, hint, unit = unit, cells = {
      { label }, StateCell(h, hs), StateCell(pw, BarState(pw)),
      { pw and (SizeText(h) .. " / " .. SizeText(pw)) or SizeText(h) }, layer } }
  end

  -- Values: readable or secret, per existing unit
  local values = Section(L["Values"], "values")
  local none = {}
  for _, unit in ipairs(order) do
    local compact = byUnit[unit].health and byUnit[unit].health.compact
    local exists = not compact and ns.Call(UnitExists, unit)
    if compact then
      -- compact frames: the unit they show is in the bar tooltip
    elseif ns.True(exists) or ns.IsSecret(exists) then
      local kinds = {
        Kind(ns.Call(UnitHealth, unit)), Kind(ns.Call(UnitHealthMax, unit)),
        Kind(select(3, ns.ReadValues(unit, "health"))), Kind(ns.Call(UnitPower, unit)),
      }
      local secret = false
      for _, k in ipairs(kinds) do if k == "secret" then secret = true end end
      values.rows[#values.rows + 1] = { unit, secret and L["secret"] or L["readable"], secret and "textSecondary" or "textPrimary",
        { ("%s %s, %s %s, %s %s, %s %s, %s %s"):format(L["Health"], kinds[1], L["Maximum"], kinds[2], L["Percent"], kinds[3],
          L["Power"], kinds[4], L["Absorb"], Kind(ns.Call(UnitGetTotalAbsorbs, unit))) },
        secret and L["Secret values are normal: in combat, and for other units (e.g. the target) also outside of combat. Vitaldon shows them without calculating."] or nil }
    else
      none[#none + 1] = unit
    end
  end
  if #none > 0 then values.rows[#values.rows + 1] = { text = L["No unit: %s"]:format(table.concat(none, ", ")), color = "textHint" } end

  -- Features
  local db = ns.db or {}
  local features = Section(L["Features"], "features")
  local mana = ns.Num(ns.Lookup("Enum.PowerType.Mana")) or 0
  local manaState = not db.druidMana and L["off"] or (ns.AltManaWanted and ns.AltManaWanted("player") and L["shown"] or L["not needed"])
  features.rows[#features.rows + 1] = { L["Druid mana"], manaState, nil,
    { ("%s %s, %s %s"):format(L["Power type"], Kind(ns.Call(UnitPowerType, "player")), L["Mana maximum"], Kind(ns.Call(UnitPowerMax, "player", mana))) } }
  features.rows[#features.rows + 1] = { L["Absorb shields"], db.showAbsorbs and L["on"] or L["off"] }
  features.rows[#features.rows + 1] = { L["Style"], db.textStyle == "mono" and L["Single colour"] or L["Clear"] }
  features.rows[#features.rows + 1] = { L["Always keep text in front"], db.textOnTop and L["on"] or L["off"] }
  features.rows[#features.rows + 1] = { L["Fit text to bar"], db.fitText and L["on"] or L["off"], nil,
    { { L["Size health / power"], ("%s / %s"):format(tostring(ns.BaseSize and ns.BaseSize({ kind = "health" }) or "?"), tostring(ns.BaseSize and ns.BaseSize({ kind = "power" }) or "?")) } },
    L["Size per bar in the tooltips of the Bars section."] }
  local compactOn = db.showCompactParty or db.showRaid
  local healthText = ns.CompactHealthText()
  local overlap = compactOn and healthText and healthText ~= "none"
  features.rows[#features.rows + 1] = { L["Raid-style party frames"], db.showCompactParty and L["on"] or L["off"] }
  features.rows[#features.rows + 1] = { L["Raid frames"], db.showRaid and L["on"] or L["off"], overlap and "warning" or nil,
    { { L["Blizzard health text there"], healthText or "?" } },
    overlap and L["Blizzard's own health text on these frames may overlap. Raid profile option Display health text: None."] or nil }

  -- Errors
  local errSec = Section(L["Errors"], "errors")
  local errors = ns.Errors()
  if #errors == 0 then
    errSec.rows[#errSec.rows + 1] = { L["Errors"], L["none"], "good" }
  else
    for _, e in ipairs(errors) do
      errSec.rows[#errSec.rows + 1] = { text = ("[%s] x%d: %s"):format(e.context, e.count, e.msg), color = "critical",
        tip = e.stack and { e.stack } or nil }
    end
    -- (1.8) Like the chat output: errors beyond the first 10 are counted.
    if ns.droppedErrors then
      errSec.rows[#errSec.rows + 1] = { text = L["More errors not listed: %d"]:format(ns.droppedErrors), color = "textHint" }
    end
  end
  return model
end

-- StyleKit errors (tooltips, clicks in the window) go to Vitaldon's error
-- list in /vd diag instead of staying silent. The kit is shared (DonCore):
-- the handler of an addon loaded earlier is kept and called as well.
if ns.Style then
  local before = ns.Style.onError
  ns.Style.onError = function(where, err)
    ns.RecordError("kit:" .. tostring(where), err)
    if before then pcall(before, where, err) end
  end
end

local function WindowStore()
  local db = ns.db or {}
  if type(db.diagWindow) ~= "table" then db.diagWindow = {} end
  return db.diagWindow
end

---------------------------------------------------------------------------
-- (02.11.2026, StyleKit 2 step 4, docs/layout_2026-11-02/vitaldon/) The diagnostics window from DonCore's Kit: Kit.Window
-- with the tabs Overview, Bars, Values, Errors; a hero with the bars found, the problems as hint lines (with a button where
-- Vitaldon can fix it), the bars as a table with their details on the right (over the table under 960 px), the report in
-- the shared copy box (Kit.ShowCopy). Same facts as the chat output (ns.DiagModel). Without the Kit: chat.
---------------------------------------------------------------------------
local function GetKit() return ns.GetKit(7) end

-- Kit errors (clicks, tooltips in the window) also go to the error list; the handler of an addon loaded earlier stays.
do
  local Kit = GetKit()
  if Kit then
    local before = Kit.onError
    Kit.onError = function(where, err)
      ns.RecordError("kit:" .. tostring(where), err)
      if before then pcall(before, where, err) end
    end
  end
end

local TABS = { { "overview", "Overview" }, { "bars", "Bars" }, { "values", "Values" }, { "errors", "Errors" } }
local TITLES = { overview = "Overview", bars = "Bars", values = "Values", errors = "Errors" }
-- detail card width; a table narrower than NARROW_COLS keeps unit, health and power (size and layer in the row tooltip):
-- the five columns need 120 + 110 + 110 + 56 + 110, the gaps and the edges
local DETAIL_W, NARROW_COLS = 300, 561

-- the model's colour names (Style) in the Kit's colours
local function KitColor(Kit, name)
  local C = Kit.C
  if name == "good" then return C.green elseif name == "warning" then return C.yellow elseif name == "critical" then return C.red
  elseif name == "textSecondary" then return C.muted elseif name == "textHint" then return C.quiet end
  return C.title
end

-- tooltip lines of the model ({ label, value, colour name }, { header = }, text) in Kit colours
local function TipLines(Kit, lines)
  local out = {}
  for _, l in ipairs(lines or {}) do
    if type(l) == "table" and l[2] ~= nil then out[#out + 1] = { l[1], l[2], l[3] and KitColor(Kit, l[3]) or nil }
    else out[#out + 1] = l end
  end
  return out
end

local function SectionOf(model, key)
  for _, s in ipairs(model) do if s.key == key then return s end end
  return { rows = {} }
end

-- one model row as a quiet list row: name left, value in the fixed right column, a mark in its colour
local function KeyRow(Kit, r)
  if r.text then
    return { title = r.text, titleColor = KitColor(Kit, r.color), markColor = r.color == "critical" and Kit.C.red or nil,
      compact = true, h = 28, tooltipFn = function() return r.text, TipLines(Kit, r.tip) end }
  end
  local label, value, color, tip, hint = r[1], r[2], r[3], r[4], r[5]
  local lines = { { label, value, color } }
  for _, l in ipairs(tip or {}) do lines[#lines + 1] = l end
  return { title = label, right = value, rightColor = KitColor(Kit, color),
    markColor = (color == "good" or color == "warning" or color == "critical") and KitColor(Kit, color) or nil,
    compact = true, h = 28, tooltipFn = function() return label, TipLines(Kit, lines), hint end }
end

-- the problems for the hint lines: { text, kind, button text, action(win) }
local function Problems(model)
  local out = {}
  if ns.BlizzardStatusTextOn() then
    out[#out + 1] = { L["Blizzard's status text is on and may overlap. Use the button below to turn it off."], "warn", L["Turn off"],
      function() if ns.TurnOffStatusTextTool then ns.TurnOffStatusTextTool() end end }
  end
  local found, total = ns.BarsFound()
  if found < total then
    out[#out + 1] = { L["Bars found: %d of %d"]:format(found, total), "warn", L["Search"], function()
      ns.ResolveAll()
      if ns.RefreshAll then ns.RefreshAll() end
    end }
  end
  for _, r in ipairs(SectionOf(model, "bars").rows) do
    if r[5] then out[#out + 1] = { r[1] .. ": " .. r[5], "warn" } end
  end
  for _, r in ipairs(SectionOf(model, "features").rows) do
    if r[3] == "warning" and r[5] then out[#out + 1] = { r[5], "warn" } end
  end
  local errors = ns.Errors()
  if #errors > 0 then
    out[#out + 1] = { ("%s: %d"):format(L["Errors"], #errors), "red", L["Show"], function(win) win:SelectTab("errors") end }
  end
  if #out == 0 then out[1] = { L["Blizzard's status text is off."], "good" } end
  return out
end

-- found and counted bars (also the hero and the hints)
function ns.BarsFound()
  local found, total = 0, 0
  for _, entry in ipairs(ns.entries or {}) do
    if ns.Counted(entry) then
      total = total + 1
      if entry.bar then found = found + 1 end
    end
  end
  return found, total
end

local function BarItems(Kit, model, narrow)
  local items = {}
  for _, r in ipairs(SectionOf(model, "bars").rows) do
    if r.cells then
      local cells = {}
      for i, c in ipairs(r.cells) do
        if not (narrow and i > 3) then
          cells[i] = { text = c[1], color = c[2] and KitColor(Kit, c[2]) or (i == 1 and Kit.C.title or Kit.C.muted) }
        end
      end
      local tip
      if narrow then
        tip = function() return r[1], { { L["Font size"], r.cells[4][1] }, { L["Text"], r.cells[5][1], r.cells[5][2] and KitColor(Kit, r.cells[5][2]) } } end
      end
      items[#items + 1] = { kind = "table", cells = cells, unit = r.unit, row = r,
        markColor = KitColor(Kit, r[3] == "textSecondary" and "textHint" or r[3]), tooltipFn = tip }
    end
  end
  return items
end

local function ListItems(Kit, model, tab)
  local items = {}
  local function Add(section, withGroup)
    if withGroup then items[#items + 1] = { kind = "group", text = section.title, static = true } end
    for _, r in ipairs(section.rows) do items[#items + 1] = KeyRow(Kit, r) end
  end
  if tab == "overview" then
    Add(SectionOf(model, "general"), true)
    Add(SectionOf(model, "features"), true)
  elseif tab == "values" then
    Add(SectionOf(model, "values"), false)
  elseif tab == "errors" then
    Add(SectionOf(model, "errors"), false)
  end
  return items
end

-- the details of one bar (the facts of its tooltip in the chat-free window)
local function FillDetail(Kit, d, item)
  local r = item.row
  d:SetHead({ title = r.unit or r[1], meta = tostring(r[2] or "") })
  d:Begin()
  for _, l in ipairs(r[4] or {}) do
    if type(l) == "table" and l.header then d:Section(l.header)
    elseif type(l) == "table" and l[2] ~= nil then d:Line(l[1], Kit.C.muted, tostring(l[2]), l[3] and KitColor(Kit, l[3]) or Kit.C.title)
    elseif l ~= nil then d:Line(tostring(type(l) == "table" and (l[1] or "") or l), Kit.C.quiet) end
  end
  if r[5] then d:Space(4) d:Para(r[5], Kit.C.yellow) end
  d:End()
end

local function Layout(win, w, h, mode)
  local Kit, p = win.kit, win.parts
  local S = Kit.SIZE
  p.hero:ClearAllPoints()
  p.hero:SetPoint("TOPLEFT", win.body, "TOPLEFT", 0, 0)
  p.hero:Layout(w)
  local y = (p.hero:GetHeight() or 56) + S.gap
  for i, hint in ipairs(p.hints) do
    if hint:IsShown() then
      local b = p.hintButtons[i]
      local bw = b:IsShown() and (b.natural or 80) or 0
      local rowH = bw > 0 and S.buttonSmall or S.hint
      hint:ClearAllPoints()
      hint:SetPoint("TOPLEFT", win.body, "TOPLEFT", S.pad, -y - math.floor((rowH - S.hint) / 2))
      hint:Layout(w - 2 * S.pad - (bw > 0 and bw + S.gap or 0))
      if bw > 0 then
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", win.body, "TOPRIGHT", -S.pad, -y)
      end
      y = y + rowH + S.unit
    end
  end
  y = y + S.unit
  local bars = win.tab == "bars"
  local narrow = mode ~= "full"
  local side = (bars and not narrow) and DETAIL_W + S.pad or 0
  local lw = w - 2 * S.pad - side
  -- a narrow table keeps three columns (rows built anew once when this changes)
  local colsNarrow = lw < NARROW_COLS
  if bars and colsNarrow ~= (p.colsNarrow or false) then
    p.colsNarrow = colsNarrow
    p.list:SetItems(BarItems(Kit, win.model or ns.DiagModel(), colsNarrow))
    local sel
    for _, it in ipairs(p.list.items or {}) do if it.unit and it.unit == p.picked then sel = it end end
    p.list:Select(sel)
  end
  if bars and not colsNarrow then p.head:Show() else p.head:Hide() end
  if bars and colsNarrow then p.headNarrow:Show() else p.headNarrow:Hide() end
  local listTop = y
  if bars then
    local head = colsNarrow and p.headNarrow or p.head
    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", win.body, "TOPLEFT", S.pad, -y)
    head:Bind(p.list)
    head:Layout(lw)
    listTop = y + S.chip
  end
  p.list:ClearAllPoints()
  p.list:SetPoint("TOPLEFT", win.body, "TOPLEFT", S.pad, -listTop)
  p.list:Resize(lw, math.max(40, h - listTop - S.gap))
  local item
  if bars and p.picked then
    for _, it in ipairs(p.list.items or {}) do if it.unit and it.unit == p.picked then item = it end end
  end
  local show = bars and (item ~= nil or not narrow)
  if show then p.detail:Show() else p.detail:Hide() end
  if show then
    local dw = narrow and math.min(DETAIL_W, w - 2 * S.pad) or DETAIL_W
    p.detail:ClearAllPoints()
    p.detail:SetPoint("TOPRIGHT", win.body, "TOPRIGHT", -S.pad, -y)
    p.detail:Layout(dw, math.max(60, h - y - S.gap))
    if narrow then pcall(p.detail.SetFrameLevel, p.detail, (p.list:GetFrameLevel() or 1) + 20) end
    if item then
      p.detail.close:Show()
      FillDetail(Kit, p.detail, item)
    else
      p.detail.close:Hide()
      p.detail:SetHead({ title = L["Bars"], meta = L["Pick a bar in the list."] })
      p.detail:Begin()
      p.detail:Para(L["Click a bar for its path, layer, font size and alpha."], Kit.C.muted)
      p.detail:End()
    end
  end
  -- footer: the buttons from the right, the hint line gets the rest
  local x = S.pad
  for i = #p.buttons, 1, -1 do
    local b = p.buttons[i]
    b:ClearAllPoints()
    b:SetPoint("RIGHT", win.footer, "RIGHT", -x, 0)
    x = x + (b.natural or 80) + S.unit
  end
  if win.status then Kit.Fit(win.status, math.max(10, w - x - S.pad)) end
end

local function BuildWindow(Kit)
  local win = Kit.Window("VitaldonDiagWindow", {
    title = "Vitaldon", subtitle = L["Diagnostics"], logo = "Interface\\Icons\\Spell_Holy_FlashHeal",
    width = 980, height = 520, min = { 560, 360 }, max = { 1200, 800 }, footer = true, store = WindowStore(),
    options = "Vitaldon", hint = "/vd",
    onTab = function(key)
      WindowStore().tab = key
      ns.FillDiag()
    end,
    onLayout = function(w, bw, bh, mode) if w.parts then Layout(w, bw, bh, mode) end end,
    onClose = function() WindowStore().shown = false end,
  })
  win.kit = Kit
  local p = {}
  p.hero = Kit.Hero(win.body, { height = 56, column = 120 })
  p.hints, p.hintButtons = {}, {}
  for i = 1, 3 do
    p.hints[i] = Kit.Hint(win.body)
    p.hints[i]:Hide()
    p.hintButtons[i] = Kit.Button(win.body, "", { small = true, onClick = function(self)
      if self.action then self.action(win) end
      ns.FillDiag()
    end })
    p.hintButtons[i]:Hide()
  end
  local cols = {
    { key = "unit", text = L["Unit"], width = 120, grow = true },
    { key = "health", text = L["Health"], width = 110 },
    { key = "power", text = L["Power"], width = 110 },
    { key = "size", text = L["Size"], width = 56, justify = "RIGHT" },
    { key = "layer", text = L["Layer"], width = 110 },
  }
  p.head = Kit.TableHead(win.body, { columns = cols })
  p.headNarrow = Kit.TableHead(win.body, { columns = { cols[1], cols[2], cols[3] } })
  -- a click picks a bar (its details on the right), a second click on it lets it go
  function win:PickBar(unit)
    p.picked = (unit and p.picked ~= unit) and unit or nil
    local sel
    for _, it in ipairs(p.list.items or {}) do if it.unit and it.unit == p.picked then sel = it end end
    p.list:Select(sel)
    self:Layout()
  end
  p.list = Kit.List(win.body, { onClick = function(item) if item.unit then win:PickBar(item.unit) end end })
  p.detail = Kit.Detail(win.body, { onClose = function() p.picked = nil p.list:Select(nil) win:Layout() end })
  p.buttons = {
    Kit.Button(win.footer, L["Preview"], { small = true, onClick = function() ns.RunPreview() end }),
    Kit.Button(win.footer, L["Search"], { small = true, onClick = function()
      ns.ResolveAll()
      if ns.RefreshAll then ns.RefreshAll() end
      ns.FillDiag()
    end }),
    Kit.Button(win.footer, L["Copy report"], { small = true, kind = "primary", onClick = function() ns.CopyDiag() end }),
  }
  p.buttons[1]:SetTooltip(L["Preview format"], { L["Shows sample values on your player frame for 5 seconds, so you can check format, position, colour and font without combat. /vd preview"] })
  p.buttons[2]:SetTooltip(L["Find unit frames again"], { L["Searches Blizzard's bars again, e.g. after another addon changed the unit frames. /vd refresh"] })
  win:SetStatus(L["/vd diag chat prints everything to the chat. In the report: Ctrl+A, Ctrl+C copies it."])
  win.parts = p
  win.tabKeys = {}
  for _, t in ipairs(TABS) do win:AddTab(t[1], L[t[2]]) win.tabKeys[t[1]] = true end
  return win
end

-- The report in DonCore's shared copy box.
function ns.CopyDiag()
  local Kit = GetKit()
  if not (Kit and Kit.ShowCopy) then return ns.PrintDiag() end
  return Kit.ShowCopy("Vitaldon: " .. L["Report to copy"], L["Ctrl+A, Ctrl+C copies the report, e.g. for a bug report."],
    table.concat(ns.DiagLines(), "\n"), { selectAll = L["Select all"], close = L["Close"] })
end

-- Fills the open window from a fresh model.
function ns.FillDiag()
  local win = ns.diagWindow
  if not win then return end
  local Kit, p = win.kit, win.parts
  local model = ns.DiagModel()
  win.model = model
  local tab = win.tab or "overview"
  local found, total = ns.BarsFound()
  local build = ns.Call(GetBuildInfo)
  local apis = SectionOf(model, "general").rows[3]
  p.hero:SetData({
    kicker = ("Vitaldon %s  ·  %s %s  ·  %s %s"):format(ns.Version(), L["Client"], ns.Usable(build) and tostring(build) or "?",
      L["Game functions"], tostring(apis and apis[2] or "?")),
    title = L[TITLES[tab]], value = ("%d / %d"):format(found, total), label = L["Bars found"],
    progress = total > 0 and found / total or 0, valueColor = found == total and Kit.C.green or Kit.C.yellow,
    progressColor = found == total and "green" or "yellow" })
  local probs = Problems(model)
  for i, hint in ipairs(p.hints) do
    local pr, b = probs[i], p.hintButtons[i]
    if pr then
      hint:SetHint(pr[1], pr[2])
      hint:Show()
      if pr[3] and pr[4] then b:SetText(pr[3]) b.action = pr[4] b:Show() else b.action = nil b:Hide() end
    else
      hint:Hide()
      b.action = nil
      b:Hide()
    end
  end
  -- a red mark on a tab where something needs a look
  local barWarn = false
  for _, r in ipairs(SectionOf(model, "bars").rows) do if r[3] == "warning" or r[3] == "critical" then barWarn = true end end
  for _, t in ipairs(win.tabs) do
    if t.SetAlert then t:SetAlert((t.key == "bars" and barWarn) or (t.key == "errors" and #ns.Errors() > 0) or false) end
  end
  if tab == "bars" then
    local items = BarItems(Kit, model, p.colsNarrow)
    p.list:SetItems(items)
    local sel
    for _, it in ipairs(items) do if it.unit and it.unit == p.picked then sel = it end end
    if not sel then p.picked = nil end
    p.list:Select(sel)
  else
    p.list:SetItems(ListItems(Kit, model, tab))
    p.list:Select(nil)
  end
  p.list:SetEmpty(L["none"])
  win:Layout()
end

-- Opens (or refreshes) the window. Without the kit: chat output.
function ns.ShowDiag()
  local Kit = GetKit()
  if not (Kit and Kit.Window and Kit.Hint and Kit.Detail and Kit.TableHead) then return ns.PrintDiag() end
  local win = ns.diagWindow
  if not win then
    win = BuildWindow(Kit)
    ns.diagWindow = win
    local tab = WindowStore().tab
    win.tab = win.tabKeys[tab] and tab or "overview"
    for _, t in ipairs(win.tabs) do t:SetSelected(t.key == win.tab) end
  end
  win:Show()
  WindowStore().shown = true
  ns.FillDiag()
  return win
end
