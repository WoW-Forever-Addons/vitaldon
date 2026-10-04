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
  local function Section(title) local s = { title = title, rows = {} }; model[#model + 1] = s; return s end

  local general = Section(L["General"])
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
  local bars = Section(L["Bars"])
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
    bars.rows[#bars.rows + 1] = { label, value, color, tip, hint }
  end

  -- Values: readable or secret, per existing unit
  local values = Section(L["Values"])
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
  local features = Section(L["Features"])
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
  local errSec = Section(L["Errors"])
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
-- list in /vd diag instead of staying silent.
if ns.Style then
  ns.Style.onError = function(where, err) ns.RecordError("kit:" .. tostring(where), err) end
end

local function WindowStore()
  local db = ns.db or {}
  if type(db.diagWindow) ~= "table" then db.diagWindow = {} end
  return db.diagWindow
end

local function BuildPanel()
  local Style = ns.Style
  local panel = Style.Panel("VitaldonDiagPanel", UIParent, {
    title = Style.Wordmark("Vital", "don") .. "  " .. Style.Colorize(L["Diagnostics"], "textSecondary"),
    width = 340,
    close = true,
    closeTooltip = L["Close"],
    get = function(key) return WindowStore()[key] end,
    set = function(key, value) WindowStore()[key] = value end,
    defaultPoint = { "CENTER", "CENTER", 0, 80 },
    strata = "DIALOG",
  })
  return panel
end

-- Report to copy (Ctrl+A, Ctrl+C) for bug reports: our own scroll frame
-- with an edit box, placed in the window through Style.Content. Typing does
-- not change the text, Escape leaves the box.
local REPORT_HEIGHT = 96
local function Report(panel)
  if panel._vdReport then return panel._vdReport end
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  local box = CreateFrame("EditBox", nil, scroll)
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  box:SetFontObject("GameFontHighlightSmall")
  box:SetWidth(290)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnTextChanged", function(self, user)
    if user and self._vdText then self:SetText(self._vdText) end
  end)
  scroll:SetScrollChild(box)
  panel._vdReport = { scroll = scroll, box = box }
  return panel._vdReport
end

local function Fill(panel)
  local Style = ns.Style
  panel:ClearRows()
  for _, section in ipairs(ns.DiagModel()) do
    Style.Header(panel, section.title)
    for _, r in ipairs(section.rows) do
      local row
      if r.text then
        row = Style.Row(panel):SetText(r.text, r.color or "textPrimary")
      else
        row = Style.KeyValue(panel, r[1], r[2], r[3])
      end
      local tip, hint, title = r.tip or r[4], r[5], r.text or r[1]
      if row and (tip or hint) then
        row:SetTooltip(function() return title, tip, hint end)
      end
    end
  end
  if Style.Content then
    Style.Header(panel, L["Report to copy"])
    local rep = Report(panel)
    rep.box._vdText = table.concat(ns.DiagLines(), "\n")
    rep.box:SetText(rep.box._vdText)
    Style.Content(panel, rep.scroll, REPORT_HEIGHT)
  end
  local foot = Style.Row(panel):SetText(L["/vd diag chat prints everything to the chat. In the report: Ctrl+A, Ctrl+C copies it."], "textHint")
  foot:SetGapBefore(Style.SPACING.section)
  return panel
end

-- Opens (or refreshes) the window. Without the kit: chat output.
function ns.ShowDiag()
  if not (ns.Style and ns.Style.Panel) then return ns.PrintDiag() end
  if not ns.diagPanel then ns.diagPanel = BuildPanel() end
  Fill(ns.diagPanel)
  WindowStore().shown = true
  ns.diagPanel:FadeIn()
  return ns.diagPanel
end
