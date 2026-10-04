local addonName, ns = ...
local L = ns.L

-- Flat keys: SettingsUI.lua registers every key directly on ns.db.
ns.defaults = {
  -- unit groups
  showPlayer = true,
  showTarget = true,
  showFocus = true,
  showPet = true,
  showParty = true,
  showToT = false,
  showBoss = true,
  -- (1.6) compact frames (raid style), health only, off by default
  showCompactParty = false,
  showRaid = false,
  -- health text
  showHealth = true,
  healthFormat = "current_percent",
  healthAlign = "CENTER",
  hideFull = false,
  showAbsorbs = false,
  -- power text
  showPower = true,
  powerFormat = "current",
  powerAlign = "CENTER",
  druidMana = true,
  druidManaFormat = "percent",
  -- numbers and states
  abbreviate = true,
  percentDecimals = 0,
  stateText = true,
  -- look: "clear" = white value, details (/ max, percent) in a softer grey;
  -- "mono" = whole text in one colour (up to 1.3)
  textStyle = "clear",
  textColor = "white",
  -- font: Blizzard's bar text font, a bit larger than Blizzard's small bar
  -- text, with outline and soft shadow for contrast (1.8.2, user's choice)
  font = "default",
  fontSize = 12,
  shadow = true,
  outline = true,
  -- (1.9) fit: cap the size by the bar height and shrink text that is wider
  -- than the bar (down to 8); power text one point smaller than health text
  -- unless powerSameSize is on
  fitText = true,
  powerSameSize = false,
  -- layer: if the bar's frame level is not enough (another addon draws a
  -- fill or frame in a higher strata above the bar), our text frame moves
  -- one strata up
  textOnTop = true,
}

-- Version of the saved settings. 1 = up to Vitaldon 1.3, 2 = 1.4.
ns.SCHEMA = 3

-- Per unit group format overrides ("inherit" = general format).
-- key: setting of the group checkbox, id: suffix of the override keys.
ns.GROUPS = {
  { key = "showPlayer", id = "Player", name = "Player" },
  { key = "showTarget", id = "Target", name = "Target" },
  { key = "showFocus", id = "Focus", name = "Focus" },
  -- (1.7) healthDefault: the small pet and target of target bars (70 px)
  -- start with percent only; "12K (82%)" barely fits there.
  { key = "showPet", id = "Pet", name = "Pet", healthDefault = "percent" },
  { key = "showParty", id = "Party", name = "Party frames" },
  { key = "showToT", id = "ToT", name = "Target of target", healthDefault = "percent" },
  { key = "showBoss", id = "Boss", name = "Boss frames" },
  -- healthOnly: compact frames get no power text (their power bar is too thin)
  { key = "showCompactParty", id = "CompactParty", name = "Raid-style party frames", healthOnly = true },
  { key = "showRaid", id = "Raid", name = "Raid frames", healthOnly = true },
}
ns.GROUP_ID = {}
-- (1.8) Keys whose default is not "inherit": an existing installation from
-- before 1.2 (no per-frame formats saved) keeps "inherit", so its pet and
-- target of target text does not change on the update.
ns.INHERIT_IF_MISSING = {}
for _, g in ipairs(ns.GROUPS) do
  ns.GROUP_ID[g.key] = g.id
  ns.defaults["healthFormat" .. g.id] = g.healthDefault or "inherit"
  if g.healthDefault then ns.INHERIT_IF_MISSING["healthFormat" .. g.id] = true end
  if not g.healthOnly then ns.defaults["powerFormat" .. g.id] = "inherit" end
  -- (1.10) "Hide at full health" per frame: "inherit" (follows the general
  -- option, which is off by default), "on" or "off".
  ns.defaults["hideFull" .. g.id] = "inherit"
end

---------------------------------------------------------------------------
-- Error guard: every event handler, timer callback and UI callback runs
-- protected. The first distinct errors are kept for /vd diag and one chat
-- line per session says that something went wrong.
---------------------------------------------------------------------------
-- Family wordmark (DESIGN.md): accent part plus "don".
ns.WORDMARK = "|cff3fa9f5Vital|rdon"

local MAX_ERRORS, MAX_MSG = 10, 160
local errors, warned = {}, false
-- (1.7) The same error repeating on every event (e.g. 40 raid frames) is
-- counted without shortening the message again: last raw message and its
-- record.
local lastRaw, lastContext, lastRecord

local function Shorten(msg)
  msg = tostring(msg or "?"):gsub("\\", "/")
  msg = msg:gsub("[^%s:]*/([%w_]+%.[lx][um][al])", "%1")
  if #msg > MAX_MSG then msg = msg:sub(1, MAX_MSG) .. "..." end
  return msg
end

local function ShortStack()
  if not debugstack then return nil end
  local ok, stack = pcall(debugstack, 3, 4, 0)
  if not ok or type(stack) ~= "string" then return nil end
  local lines = {}
  for line in stack:gmatch("[^\n]+") do
    line = Shorten(line)
    if not line:find("Core.lua", 1, true) and #lines < 3 then lines[#lines + 1] = line end
  end
  return #lines > 0 and table.concat(lines, " < ") or nil
end

local function Record(context, err)
  -- (1.8) Only a readable string is compared or kept as the last message.
  -- Up to 1.7 an unreadable (secret) message stayed in lastRaw, and every
  -- later error failed at this comparison and was lost.
  local plain = type(err) == "string" and ns.Usable(err)
  if lastRecord and plain and err == lastRaw and context == lastContext then
    lastRecord.count = lastRecord.count + 1
    return
  end
  if not plain then err = "(unreadable error)" end
  local ok, msg = pcall(Shorten, err)
  if not ok then msg = "(unreadable error)" end
  for _, e in ipairs(errors) do
    if e.msg == msg and e.context == context then
      e.count = e.count + 1
      lastRaw, lastContext, lastRecord = err, context, e
      return
    end
  end
  if #errors < MAX_ERRORS then
    local e = {
      module = msg:match("([%w_]+)%.lua[\"%]]*:%d+") or "?",
      context = context, msg = msg, count = 1, stack = ShortStack(),
    }
    errors[#errors + 1] = e
    lastRaw, lastContext, lastRecord = err, context, e
  else
    lastRaw, lastContext, lastRecord = nil, nil, nil
    -- (1.7) Further distinct errors are only counted.
    ns.droppedErrors = (ns.droppedErrors or 0) + 1
  end
  if not warned then
    warned = true
    print(ns.WORDMARK .. ": " .. L["an error occurred, /vd diag for details"])
  end
end

function ns.Errors() return errors end

-- For errors caught elsewhere (StyleKit Style.onError).
function ns.RecordError(context, err)
  pcall(Record, context, err)
end

-- Runs without creating a closure or table per call for up to four
-- arguments (unit events arrive many times per second in raids). The
-- runner reads the upvalues the moment xpcall starts it, so a nested
-- SafeCall cannot change the arguments of the outer one.
local runFn, runA, runB, runC, runD, runContext
local function Runner() return runFn(runA, runB, runC, runD) end
local function Handler(err)
  pcall(Record, runContext, err)
  return err
end

function ns.SafeCall(context, fn, ...)
  local n = select("#", ...)
  if n > 4 then
    local args = { ... }
    local prev = runContext
    runContext = context
    local ok, a, b, c = xpcall(function() return fn(unpack(args, 1, n)) end, Handler)
    runContext = prev
    if ok then return a, b, c end
    return
  end
  local prev = runContext
  runFn, runA, runB, runC, runD = fn, ...
  runContext = context
  local ok, a, b, c = xpcall(Runner, Handler)
  runFn, runA, runB, runC, runD = nil, nil, nil, nil, nil
  runContext = prev
  if ok then return a, b, c end
end

function ns.Guard(context, fn)
  return function(...) return ns.SafeCall(context, fn, ...) end
end

function ns.After(delay, fn)
  if C_Timer and C_Timer.After then C_Timer.After(delay, ns.Guard("timer", fn)) end
end

function ns.NewTicker(interval, fn, iterations)
  if C_Timer and C_Timer.NewTicker then return C_Timer.NewTicker(interval, ns.Guard("timer", fn), iterations) end
end

-- Event dispatcher on our own frame. Several modules may listen to one event.
local frame = CreateFrame("Frame")
local listeners, initCallbacks = {}, {}

-- Unit events: units = { token = true, ... } drops every other unit before
-- any handler runs (no protected call, no garbage). Secret or non-string
-- unit arguments are dropped too. One listener without units turns the
-- filter off for that event; several unit lists are merged.
local unitFilters, unfiltered = {}, {}
-- (1.6) Events registered with extra = true also pass the units for which
-- ns.IsExtraUnit (Text.lua) is true: units shown by the compact party and
-- raid frames, none while those options are off.
local extraEvents = {}

-- Saved settings from older versions. Up to 1.3 the outline was on by
-- default and stored like every default: 1.4 switches to the new look
-- (soft shadow, "Clear" style) once; the outline can be turned on again.
-- (1.5) If the outline was on before, one chat line at login says how to
-- turn it on again. (1.8.2) Outline is the default again; no notice needed.
function ns.Migrate(db, fresh)
  local schema = tonumber(db.schema) or 1
  if not fresh and schema < 2 then
    db.shadow = true
    db.textStyle = "clear"
  end
  -- (1.8.2) New defaults: outline on, size 12. Values that are still the old
  -- defaults (or the outline that 1.4 switched off) follow the new ones;
  -- a size the player chose stays.
  if not fresh and schema < 3 then
    if db.outline ~= true then db.outline = true end
    if tonumber(db.fontSize) == 10 then db.fontSize = 12 end
  end
  db.schema = ns.SCHEMA
end

function ns.On(event, fn, units, extra)
  if extra then extraEvents[event] = true end
  if not units then
    unfiltered[event] = true
    unitFilters[event] = nil
  elseif not unfiltered[event] then
    local filter = unitFilters[event] or {}
    for unit in pairs(units) do filter[unit] = true end
    unitFilters[event] = filter
  end
  if not listeners[event] then
    listeners[event] = {}
    local ok = pcall(frame.RegisterEvent, frame, event) -- unknown events throw
    if not ok then listeners[event] = nil return false end
  end
  table.insert(listeners[event], fn)
  return true
end

function ns.OnInit(fn) table.insert(initCallbacks, fn) end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= addonName then return end
    VitaldonDB = type(VitaldonDB) == "table" and VitaldonDB or {}
    local fresh = next(VitaldonDB) == nil
    -- (1.7) One welcome line at login for a new installation (Text.lua).
    ns.firstRun = fresh
    for k, v in pairs(ns.defaults) do
      if not fresh and VitaldonDB[k] == nil and ns.INHERIT_IF_MISSING[k] then
        VitaldonDB[k] = "inherit"
      elseif VitaldonDB[k] == nil or type(VitaldonDB[k]) ~= type(v) then
        VitaldonDB[k] = v
      end
    end
    ns.db = VitaldonDB
    ns.SafeCall("migrate", ns.Migrate, VitaldonDB, fresh)
    for _, fn in ipairs(initCallbacks) do ns.SafeCall("init", fn) end
    frame:UnregisterEvent("ADDON_LOADED")
    return
  end
  if not ns.db then return end
  local filter = unitFilters[event]
  if filter then
    local unit = ...
    if type(unit) ~= "string" or not ns.Usable(unit) then return end
    if not filter[unit] and not (extraEvents[event] and ns.IsExtraUnit and ns.IsExtraUnit(unit)) then return end
  end
  local list = listeners[event]
  if list then
    for i = 1, #list do ns.SafeCall(event, list[i], event, ...) end
  end
end)

---------------------------------------------------------------------------
-- Helpers. Secret values (Midnight rules) must never reach comparisons,
-- arithmetic or table keys in our code.
---------------------------------------------------------------------------
function ns.Print(msg)
  print(ns.WORDMARK .. ": " .. tostring(msg))
end

function ns.Usable(v)
  if type(v) == "nil" then return false end
  if canaccessvalue then
    local ok, r = pcall(canaccessvalue, v)
    if ok then return r and true or false end
    return false
  end
  if issecretvalue then
    local ok, r = pcall(issecretvalue, v)
    if ok then return not r end
    return false
  end
  return true
end

function ns.IsSecret(v)
  if type(v) == "nil" then return false end
  return not ns.Usable(v)
end

-- Number or nil (nil if missing, not a number or secret).
function ns.Num(v)
  if type(v) == "number" and ns.Usable(v) then return v end
  return nil
end

-- true only for a readable true (secret booleans count as unknown).
function ns.True(v)
  return ns.Usable(v) and v == true
end

-- Raw first result of fn(...): may be secret, nil on error or missing fn.
function ns.Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if ok then return v end
  return nil
end

-- First result of fn(...) only if it is readable.
function ns.Value(fn, ...)
  local v = ns.Call(fn, ...)
  if ns.Usable(v) then return v end
  return nil
end

-- Look up "A.B.C" paths below _G without erroring. The parts of each path
-- are split once and cached; no closure per call (runs on unit events).
local pathParts = {}
local function Index(t, k) return t[k] end
function ns.Lookup(path)
  local parts = pathParts[path]
  if not parts then
    parts = {}
    for part in path:gmatch("[^%.]+") do parts[#parts + 1] = part end
    pathParts[path] = parts
  end
  local v = _G
  for i = 1, #parts do
    if type(v) ~= "table" then return nil end
    local ok, nextV = pcall(Index, v, parts[i])
    if not ok then return nil end
    v = nextV
  end
  return v
end

function ns.Version()
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local v = ns.Value(get, addonName, "Version")
  v = type(v) == "string" and v:gsub("%s", "") or ""
  return v ~= "" and v or "?"
end

-- Another addon is loaded (read only). nil if the client cannot tell.
function ns.AddOnLoaded(name)
  local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  if type(fn) ~= "function" then return nil end
  local v = ns.Call(fn, name)
  if not ns.Usable(v) then return nil end
  return v and true or false
end

-- BetterBlizzFrames (Bodify): what of it touches the bars. Only reads its
-- global saved settings table; nothing is changed. Option keys from its
-- source (github.com/Bodify/BetterBlizzFrames, forever/gui.lua):
-- smoothBars (own fill bar as a child of the bar), classicFrames and
-- noPortraitModes (own frame art in MEDIUM/HIGH strata), formatStatusBarText
-- and centerCurrentValueOnBars (own text on Blizzard's bar text; the latter
-- turns Blizzard's status text on).
function ns.BBFInfo()
  local info = { loaded = ns.AddOnLoaded("BetterBlizzFrames") == true }
  if not info.loaded then return info end
  local db = rawget(_G, "BetterBlizzFramesDB")
  if type(db) ~= "table" then return info end
  local function On(key) local ok, v = pcall(Index, db, key); return ok and v == true end
  info.read = true
  info.smoothBars = On("smoothBars")
  info.classicFrames = On("classicFrames")
  info.noPortrait = On("noPortraitModes")
  info.formatText = On("formatStatusBarText")
  info.centerText = On("centerCurrentValueOnBars")
  return info
end

function ns.GetCVarValue(name)
  local get = (C_CVar and C_CVar.GetCVar) or GetCVar
  local v = ns.Value(get, name)
  if type(v) == "nil" then return nil end
  return tostring(v)
end

-- Blizzard's own bar text (Interface > Status text) overlaps ours when on.
function ns.BlizzardStatusTextOn()
  local display = ns.GetCVarValue("statusTextDisplay")
  local legacy = ns.GetCVarValue("statusText")
  if display then return display ~= "NONE" end
  return legacy == "1"
end

-- Only after a click in our options: same values Blizzard's "None" choice sets.
-- (1.8) Not in combat: the options can stay open when a fight starts, and
-- the CVar change makes Blizzard update the status text of its unit frames;
-- that should not start from addon code during a fight.
function ns.TurnOffBlizzardStatusText()
  if InCombatLockdown and InCombatLockdown() then return false, "combat" end
  local set = (C_CVar and C_CVar.SetCVar) or SetCVar
  if type(set) ~= "function" then return false end
  local ok1 = pcall(set, "statusTextDisplay", "NONE")
  local ok2 = pcall(set, "statusText", "0")
  return ok1 and ok2
end

function Vitaldon_OnAddonCompartmentClick()
  if ns.OpenOptions then ns.OpenOptions() end
end

-- Entries that count in "Bars found": compact frames only while their
-- option is on (they exist only in raid style or in a raid).
function ns.Counted(entry)
  if not entry.compact then return true end
  return ns.db and ns.db[entry.group] and true or false
end

SLASH_VITALDON1 = "/vd"
SLASH_VITALDON2 = "/vitaldon"
ns.HELP = L["Commands: /vd (options), /vd preview (sample values on your player frame), /vd formats (all formats with your settings), /vd diag (diagnostics window), /vd diag chat (diagnostics in chat), /vd refresh (find the unit frames again), /vd help"]
ns.COMMANDS = {
  { "/vd", "options" }, { "/vd preview", "sample values on your player frame for 5 seconds" },
  { "/vd formats", "all formats with your settings" },
  { "/vd diag", "diagnostics window" }, { "/vd diag chat", "diagnostics in chat" },
  { "/vd refresh", "find the unit frames again" }, { "/vd help", "this list" },
}
-- Words that open the options like /vd alone.
local OPEN = { [""] = true, options = true, config = true, optionen = true }

-- One line per command: command in primary, description in secondary.
function ns.PrintHelp()
  ns.Print(L["Commands:"])
  for _, c in ipairs(ns.COMMANDS) do print("  |cffebebeb" .. c[1] .. "|r  |cff9ea3ad" .. L[c[2]] .. "|r") end
end

function ns.Slash(msg)
  msg = tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower():gsub("%s+", " ")
  if msg == "diag chat" then
    if ns.PrintDiag then ns.PrintDiag() end
  elseif msg == "diag" then
    if ns.ShowDiag then ns.ShowDiag() elseif ns.PrintDiag then ns.PrintDiag() end
  elseif msg == "refresh" then
    if ns.ResolveAll then ns.ResolveAll() end
    if ns.RefreshAll then ns.RefreshAll() end
    ns.Print(L["Unit frames searched again."])
  elseif msg == "help" or msg == "?" or msg == "hilfe" then
    ns.PrintHelp()
  elseif msg == "preview" or msg == "vorschau" then
    if ns.RunPreview then ns.RunPreview() end
  elseif msg == "formats" or msg == "formate" then
    if ns.PrintFormats then ns.PrintFormats() end
  elseif OPEN[msg] then
    if ns.OpenOptions then ns.OpenOptions() end
  else
    -- (1.6) A typo no longer opens the options silently.
    ns.Print(L["Unknown command: %s"]:format(msg))
    ns.PrintHelp()
  end
end
SlashCmdList.VITALDON = ns.Guard("slash", ns.Slash)
