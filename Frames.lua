local _, ns = ...

---------------------------------------------------------------------------
-- Where the default bars are. Paths checked against Gethe/wow-ui-source,
-- branch "forever" (Blizzard_UnitFrame: Mainline/PlayerFrame.xml,
-- Mainline/TargetFrame.xml, Mainline/PetFrame.xml,
-- Mainline/PartyFrameTemplates.xml, Shared/PartyFrame.lua). Older and
-- generic names follow as fallbacks (UnitFrame_Initialize stores the bars as
-- frame.healthbar / frame.manabar). Only read access: we never change, hook
-- or script a Blizzard frame.
---------------------------------------------------------------------------

local function Bars(prefix, health, power)
  local h, p = {}, {}
  for _, path in ipairs(health) do h[#h + 1] = path:gsub("%$", prefix) end
  for _, path in ipairs(power) do p[#p + 1] = path:gsub("%$", prefix) end
  return h, p
end

local TARGET_HEALTH = {
  "$.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar",
  "$.healthbar", "$HealthBar",
}
local TARGET_POWER = {
  "$.TargetFrameContent.TargetFrameContentMain.ManaBar",
  "$.manabar", "$ManaBar",
}

local function Def(unit, group, health, power)
  return { unit = unit, group = group, health = health, power = power }
end

local function UnitDefs()
  local defs = {}
  defs[#defs + 1] = Def("player", "showPlayer",
    { "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar",
      "PlayerFrame.healthbar", "PlayerFrameHealthBar" },
    { "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar",
      "PlayerFrame.manabar", "PlayerFrameManaBar" })
  local h, p = Bars("TargetFrame", TARGET_HEALTH, TARGET_POWER)
  defs[#defs + 1] = Def("target", "showTarget", h, p)
  h, p = Bars("FocusFrame", TARGET_HEALTH, TARGET_POWER)
  defs[#defs + 1] = Def("focus", "showFocus", h, p)
  defs[#defs + 1] = Def("pet", "showPet",
    { "PetFrameHealthBar", "PetFrame.healthbar" },
    { "PetFrameManaBar", "PetFrame.manabar" })
  for i = 1, 4 do
    defs[#defs + 1] = Def("party" .. i, "showParty",
      { "PartyFrame.MemberFrame" .. i .. ".HealthBarContainer.HealthBar",
        "PartyFrame.MemberFrame" .. i .. ".HealthBar",
        "PartyFrame.MemberFrame" .. i .. ".healthbar",
        "PartyMemberFrame" .. i .. ".HealthBar", "PartyMemberFrame" .. i .. "HealthBar" },
      { "PartyFrame.MemberFrame" .. i .. ".ManaBar",
        "PartyFrame.MemberFrame" .. i .. ".manabar",
        "PartyMemberFrame" .. i .. ".ManaBar", "PartyMemberFrame" .. i .. "ManaBar" })
  end
  -- Boss frames (Mainline/TargetFrame.xml: Boss1TargetFrame..Boss5TargetFrame
  -- in BossTargetFrameContainer, template TargetFrameTemplate).
  for i = 1, 5 do
    h, p = Bars("Boss" .. i .. "TargetFrame", TARGET_HEALTH, TARGET_POWER)
    defs[#defs + 1] = Def("boss" .. i, "showBoss", h, p)
  end
  defs[#defs + 1] = Def("targettarget", "showToT",
    { "TargetFrame.totFrame.HealthBar", "TargetFrameToT.HealthBar", "TargetFrameToTHealthBar" },
    { "TargetFrame.totFrame.ManaBar", "TargetFrameToT.ManaBar", "TargetFrameToTManaBar" })
  -- (1.6) Target of the focus: the focus frame builds the same small frame
  -- (Mainline/TargetFrame.xml: FocusFrame OnLoad CreateTargetofTarget
  -- "focustarget", named FocusFrameToT, stored as FocusFrame.totFrame).
  defs[#defs + 1] = Def("focustarget", "showToT",
    { "FocusFrame.totFrame.HealthBar", "FocusFrameToT.HealthBar", "FocusFrameToTHealthBar" },
    { "FocusFrame.totFrame.ManaBar", "FocusFrameToT.ManaBar", "FocusFrameToTManaBar" })
  -- (1.6) Raid-style party frames (Shared/CompactPartyFrame.xml, template
  -- CompactRaidGroupTemplate: CompactPartyFrameMember1..5, created when Edit
  -- Mode uses raid-style party frames). Health only: the power bar of these
  -- frames is a few pixels high.
  for i = 1, 5 do
    defs[#defs + 1] = ns.CompactDef("CompactPartyFrameMember" .. i, "partyframe" .. i, "showCompactParty")
  end
  return defs
end
ns.UnitDefs = UnitDefs

-- (1.6) A compact unit frame (Shared/CompactUnitFrame.xml): health bar
-- frame.healthBar, the unit it shows in frame.displayedUnit (frame.unit as
-- fallback, CompactUnitFrame_SetUnit). Both are only read. label names the
-- frame in /vd diag, the unit changes with the roster.
function ns.CompactDef(frameName, label, group)
  return {
    unit = label, group = group, compact = true, health = { frameName .. ".healthBar" },
    unitPaths = { frameName .. ".displayedUnit", frameName .. ".unit" },
  }
end

-- (1.6) Raid frames are created by Blizzard on demand
-- (Blizzard_CompactRaidFrameContainer.lua: CompactRaidFrame1..n when groups
-- are not kept together; Shared/CompactRaidGroup.lua: CompactRaidGroup1..8
-- with Member1..5 when they are). Names built once.
ns.RAID_FRAME_MAX, ns.RAID_GROUPS = 80, 8
local raidNames
function ns.RaidNames()
  if raidNames then return raidNames end
  raidNames = { flat = {}, groups = {} }
  for i = 1, ns.RAID_FRAME_MAX do raidNames.flat[i] = "CompactRaidFrame" .. i end
  for g = 1, ns.RAID_GROUPS do raidNames.groups[g] = "CompactRaidGroup" .. g end
  return raidNames
end

-- A usable bar: a frame object whose type is StatusBar.
local function IsStatusBar(obj)
  if type(obj) ~= "table" or not ns.Usable(obj) then return false end
  local get = obj.GetObjectType
  if type(get) ~= "function" then return false end
  local ok, t = pcall(get, obj)
  if not ok then return false end
  -- (1.8) Compared only when readable. An unreadable type falls back to a
  -- method only status bars have (read, never called).
  if type(t) == "nil" or not ns.Usable(t) then
    return type(t) ~= "nil" and type(obj.GetStatusBarTexture) == "function"
  end
  return t == "StatusBar"
end
ns.IsStatusBar = IsStatusBar

-- First path that leads to a StatusBar: bar, path, index (1 = current path).
function ns.FindBar(paths)
  for i, path in ipairs(paths) do
    local obj = ns.Lookup(path)
    if IsStatusBar(obj) then return obj, path, i end
  end
  return nil
end
