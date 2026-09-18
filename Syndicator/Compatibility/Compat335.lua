-- Baganator/Syndicator 3.3.5a compatibility bootstrap
-- Target: WoW 3.3.5a (Interface 30300)

local _, build, _, interface = GetBuildInfo()
if tonumber(interface) ~= 30300 then
  return
end

BAGANATOR_335 = true
SYNDICATOR_335 = true

-- ---------------------------------------------------------------------------
-- Project constants used by modern Classic code
-- ---------------------------------------------------------------------------
WOW_PROJECT_MAINLINE = WOW_PROJECT_MAINLINE or 1
WOW_PROJECT_CLASSIC = WOW_PROJECT_CLASSIC or 2
WOW_PROJECT_BURNING_CRUSADE_CLASSIC = WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5
WOW_PROJECT_WRATH_CLASSIC = WOW_PROJECT_WRATH_CLASSIC or 11
WOW_PROJECT_CATACLYSM_CLASSIC = WOW_PROJECT_CATACLYSM_CLASSIC or 14
WOW_PROJECT_MISTS_CLASSIC = WOW_PROJECT_MISTS_CLASSIC or 19
WOW_PROJECT_ID = WOW_PROJECT_WRATH_CLASSIC

NUM_BAG_SLOTS = NUM_BAG_SLOTS or 4
NUM_BANKBAGSLOTS = NUM_BANKBAGSLOTS or 7
BACKPACK_CONTAINER = BACKPACK_CONTAINER or 0
BANK_CONTAINER = BANK_CONTAINER or -1
KEYRING_CONTAINER = KEYRING_CONTAINER or -2

SOUNDKIT = SOUNDKIT or {}
SOUNDKIT.IG_BACKPACK_OPEN = "igBackPackOpen"
SOUNDKIT.IG_BACKPACK_CLOSE = "igBackPackClose"
SOUNDKIT.IG_MAINMENU_OPTION = "igMainMenuOptionCheckBoxOn"
SOUNDKIT.IG_MAINMENU_OPEN = "igMainMenuOpen"
SOUNDKIT.IG_MAINMENU_CLOSE = "igMainMenuClose"

MuteSoundFile = MuteSoundFile or function() end
UnmuteSoundFile = UnmuteSoundFile or function() end
GetDungeonDifficultyID = GetDungeonDifficultyID or GetDungeonDifficulty or function() return 0 end
GameFontNormalMed2 = GameFontNormalMed2 or GameFontNormal

-- ---------------------------------------------------------------------------
-- Small Lua/API helpers introduced after Wrath
-- ---------------------------------------------------------------------------
table.unpack = table.unpack or unpack

-- Modern WoW/Lua permits xpcall(func, errhandler, ...). Lua 5.1 does not,
-- so preserve the modern calling contract used throughout Baganator/Syndicator.
do
  local xpcall_51 = xpcall
  xpcall = function(func, errhandler, ...)
    local argc = select("#", ...)
    if argc == 0 then
      return xpcall_51(func, errhandler)
    end
    local args = {...}
    return xpcall_51(function()
      return func(unpack(args, 1, argc))
    end, errhandler)
  end
end

if not CopyTable then
  function CopyTable(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do
      out[CopyTable(k)] = CopyTable(v)
    end
    return out
  end
end

if not tAppendAll then
  function tAppendAll(dest, src)
    for i = 1, #src do dest[#dest + 1] = src[i] end
    return dest
  end
end

if not tFilter then
  function tFilter(src, predicate, preserveKeys)
    local out = {}
    if preserveKeys then
      for k, v in pairs(src) do
        if predicate(v, k) then out[k] = v end
      end
    else
      for _, v in ipairs(src) do
        if predicate(v) then out[#out + 1] = v end
      end
    end
    return out
  end
end

if not FindInTableIf then
  -- Modern helper: return the first matching key/index and value.
  function FindInTableIf(tbl, predicate)
    if type(tbl) ~= "table" or type(predicate) ~= "function" then
      return nil
    end
    for k, v in pairs(tbl) do
      if predicate(v, k) then
        return k, v
      end
    end
    return nil
  end
end

if not Mixin then
  function Mixin(object, ...)
    for i = 1, select("#", ...) do
      local mixin = select(i, ...)
      if mixin then
        for k, v in pairs(mixin) do object[k] = v end
      end
    end
    return object
  end
end

if not CreateFromMixins then
  function CreateFromMixins(...)
    return Mixin({}, ...)
  end
end

if not CreateAndInitFromMixin then
  function CreateAndInitFromMixin(mixin, ...)
    local object = CreateFromMixins(mixin)
    if object.Init then object:Init(...) end
    return object
  end
end

local function ReportCompatError335(err)
  local text = tostring(err or "Unknown error")
  if geterrorhandler then
    local handler = geterrorhandler()
    if handler then
      -- Some 3.3.5 Blizzard_DebugTools builds can themselves error when an
      -- error originated inside pcall/xpcall and debuglocals() is nil. Never
      -- allow the error UI to recurse into a C stack overflow.
      local ok = pcall(handler, text)
      if ok then return end
    end
  end
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff4040Baganator/Syndicator:|r " .. text)
  elseif print then
    print(text)
  end
end

if not CallErrorHandler then
  function CallErrorHandler(err)
    return ReportCompatError335(err)
  end
end

GetTimePreciseSec = GetTimePreciseSec or GetTime

if not UnitFullName then
  function UnitFullName(unit)
    local name, realm = UnitName(unit)
    return name, realm or GetRealmName()
  end
end

if not GetNormalizedRealmName then
  function GetNormalizedRealmName()
    return (GetRealmName() or ""):gsub("[%s%-']", "")
  end
end

if not GetAutoCompleteRealms then
  function GetAutoCompleteRealms()
    return { GetNormalizedRealmName() }
  end
end

if not CreateColor then
  local ColorMixin335 = {}
  function ColorMixin335:GetRGB() return self.r, self.g, self.b end
  function ColorMixin335:GetRGBA() return self.r, self.g, self.b, self.a or 1 end
  function ColorMixin335:GenerateHexColor()
    local a = math.floor((self.a or 1) * 255 + 0.5)
    local r = math.floor((self.r or 1) * 255 + 0.5)
    local g = math.floor((self.g or 1) * 255 + 0.5)
    local b = math.floor((self.b or 1) * 255 + 0.5)
    return string.format("%02x%02x%02x%02x", a, r, g, b)
  end
  function ColorMixin335:GenerateHexColorMarkup()
    return "|c" .. self:GenerateHexColor()
  end
  function ColorMixin335:WrapTextInColorCode(text)
    return self:GenerateHexColorMarkup() .. tostring(text) .. "|r"
  end
  function CreateColor(r, g, b, a)
    return setmetatable({r=r or 1, g=g or 1, b=b or 1, a=a or 1}, {__index=ColorMixin335})
  end
end

local function DecorateColor(color)
  if type(color) ~= "table" then return end
  local c = CreateColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
  if not color.GenerateHexColor then color.GenerateHexColor = c.GenerateHexColor end
  if not color.GenerateHexColorMarkup then
    color.GenerateHexColorMarkup = c.GenerateHexColorMarkup or function(self)
      return "|c" .. self:GenerateHexColor()
    end
  end
  if not color.WrapTextInColorCode then
    color.WrapTextInColorCode = c.WrapTextInColorCode or function(self, text)
      return self:GenerateHexColorMarkup() .. tostring(text) .. "|r"
    end
  end
  if not color.GetRGB then color.GetRGB = c.GetRGB end
  if not color.GetRGBA then color.GetRGBA = c.GetRGBA end
end

-- Several modern named colors don't exist in the 3.3.5 FrameXML.  Create
-- sensible fallbacks before any Syndicator/Baganator file can reference them.
local colorFallbacks = {
  NORMAL_FONT_COLOR       = {1.00, 0.82, 0.00},
  LINK_FONT_COLOR         = {0.00, 0.66, 1.00},
  RED_FONT_COLOR          = {1.00, 0.10, 0.10},
  GREEN_FONT_COLOR        = {0.10, 1.00, 0.10},
  YELLOW_FONT_COLOR       = {1.00, 1.00, 0.00},
  GRAY_FONT_COLOR         = {0.50, 0.50, 0.50},
  HIGHLIGHT_FONT_COLOR    = {1.00, 1.00, 1.00},
  WHITE_FONT_COLOR        = {1.00, 1.00, 1.00},
  BLUE_FONT_COLOR         = {0.25, 0.50, 1.00},
  LIGHTBLUE_FONT_COLOR    = {0.50, 0.75, 1.00},
  LIGHTGRAY_FONT_COLOR    = {0.75, 0.75, 0.75},
  PASSIVE_SPELL_FONT_COLOR= {0.77, 0.12, 0.23},
  TRANSMOGRIFY_FONT_COLOR = {0.70, 0.20, 1.00},
}
for name, rgb in pairs(colorFallbacks) do
  if type(_G[name]) ~= "table" then
    _G[name] = CreateColor(rgb[1], rgb[2], rgb[3], 1)
  else
    DecorateColor(_G[name])
  end
end
if ITEM_QUALITY_COLORS then
  for _, q in pairs(ITEM_QUALITY_COLORS) do
    DecorateColor(q)
    if not q.color then q.color = CreateColor(q.r or 1, q.g or 1, q.b or 1) end
  end
end

-- Wrath's RAID_CLASS_COLORS/CUSTOM_CLASS_COLORS entries predate ColorMixin and
-- do not expose the modern `colorStr` field Syndicator uses in tooltips.
local function DecorateClassColorTable(colors)
  if type(colors) ~= "table" then return end
  for _, color in pairs(colors) do
    if type(color) == "table" then
      DecorateColor(color)
      if not color.colorStr then
        local r = math.floor((color.r or 1) * 255 + 0.5)
        local g = math.floor((color.g or 1) * 255 + 0.5)
        local b = math.floor((color.b or 1) * 255 + 0.5)
        color.colorStr = string.format("ff%02x%02x%02x", r, g, b)
      end
    end
  end
end
DecorateClassColorTable(RAID_CLASS_COLORS)
DecorateClassColorTable(CUSTOM_CLASS_COLORS)

-- SetItemButtonQuality was added after the original 3.3.5 FrameXML. Modern
-- Classic addons call it for bag/bank/item buttons. Preserve the quality on the
-- button and tint any border region when one exists; otherwise this is a safe
-- visual no-op rather than a load blocker.
if not SetItemButtonQuality then
  function SetItemButtonQuality(button, quality, itemIDOrLink)
    if not button then return end
    button.__bgr335ItemQuality = quality
    button.__bgr335ItemIDOrLink = itemIDOrLink

    -- 3.3.5a ItemButtonTemplate exposes a generic `Border` texture which is
    -- NOT the modern item-quality border. Tinting/showing it produces the
    -- large diagonal action-button wedges seen over occupied Baganator slots.
    -- Only touch a real IconBorder, and only for uncommon+ quality. Baganator
    -- creates its own IconBorder for the Classic layouts when needed.
    local border = button.IconBorder or button.iconBorder
    if not border and button.GetName then
      local name = button:GetName()
      if name then
        border = _G[name .. "IconBorder"] or _G[name .. "IconBorderTexture"]
      end
    end
    if border and border.SetVertexColor then
      local q = tonumber(quality)
      local color = q and q >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
      if color then
        border:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, 1)
        if border.Show then border:Show() end
      elseif border.Hide then
        border:Hide()
      end
    end
  end
end

if not GameTooltip_AddBlankLineToTooltip then
  function GameTooltip_AddBlankLineToTooltip(tooltip)
    if tooltip and tooltip.AddLine then
      tooltip:AddLine(" ")
    end
  end
end

if not CreateAtlasMarkup then
  function CreateAtlasMarkup() return "" end
end

if not CreateTextureMarkup then
  function CreateTextureMarkup(texture, fileWidth, fileHeight, width, height, left, right, top, bottom, xOffset, yOffset)
    if not texture then return "" end
    width = tonumber(width) or tonumber(fileWidth) or 0
    height = tonumber(height) or tonumber(fileHeight) or width
    -- Wrath understands the classic |T texture escape.  Coordinates are
    -- intentionally omitted here; Baganator only needs a correctly sized icon.
    return ("|T%s:%d:%d|t"):format(tostring(texture), height, width)
  end
end

if not GetKeysArray then
  function GetKeysArray(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do keys[#keys + 1] = key end
    return keys
  end
end

-- ---------------------------------------------------------------------------
-- Callback registry (modern FrameXML replacement)
-- ---------------------------------------------------------------------------
CallbackRegistryMixin = CallbackRegistryMixin or {}
function CallbackRegistryMixin:OnLoad()
  self._callbacks335 = self._callbacks335 or {}
end
function CallbackRegistryMixin:GenerateCallbackEvents(events)
  self._callbacks335 = self._callbacks335 or {}
  for _, event in ipairs(events or {}) do self._callbacks335[event] = self._callbacks335[event] or {} end
end
function CallbackRegistryMixin:RegisterCallback(event, callback, owner)
  self._callbacks335 = self._callbacks335 or {}
  self._callbacks335[event] = self._callbacks335[event] or {}
  table.insert(self._callbacks335[event], {callback=callback, owner=owner})
end
function CallbackRegistryMixin:UnregisterCallback(event, ownerOrCallback)
  local callbacks = self._callbacks335 and self._callbacks335[event]
  if not callbacks then return end
  for i = #callbacks, 1, -1 do
    local e = callbacks[i]
    if e.owner == ownerOrCallback or e.callback == ownerOrCallback then table.remove(callbacks, i) end
  end
end
function CallbackRegistryMixin:TriggerEvent(event, ...)
  local callbacks = self._callbacks335 and self._callbacks335[event]
  if not callbacks then return end
  local copy = {}
  for i, e in ipairs(callbacks) do copy[i] = e end
  for _, e in ipairs(copy) do
    local ok, err = pcall(e.callback, e.owner or self, ...)
    if not ok then ReportCompatError335(err) end
  end
end

-- ---------------------------------------------------------------------------
-- Blizzard EventRegistry compatibility
-- ---------------------------------------------------------------------------
EventRegistry = EventRegistry or {}
EventRegistry._callbacks335 = EventRegistry._callbacks335 or {}
if not EventRegistry.RegisterCallback then
  function EventRegistry:RegisterCallback(event, callback, owner)
    self._callbacks335[event] = self._callbacks335[event] or {}
    table.insert(self._callbacks335[event], {callback = callback, owner = owner})
  end
end
if not EventRegistry.UnregisterCallback then
  function EventRegistry:UnregisterCallback(event, ownerOrCallback)
    local callbacks = self._callbacks335[event]
    if not callbacks then return end
    for i = #callbacks, 1, -1 do
      local entry = callbacks[i]
      if entry.owner == ownerOrCallback or entry.callback == ownerOrCallback then
        table.remove(callbacks, i)
      end
    end
  end
end
if not EventRegistry.TriggerEvent then
  function EventRegistry:TriggerEvent(event, ...)
    local callbacks = self._callbacks335[event]
    if not callbacks then return end
    local snapshot = {}
    for i, entry in ipairs(callbacks) do snapshot[i] = entry end
    for _, entry in ipairs(snapshot) do
      local ok, err = pcall(entry.callback, entry.owner or self, ...)
      if not ok then ReportCompatError335(err) end
    end
  end
end

-- Modern FrameXML emits EventRegistry's SetItemRef callback from its hyperlink
-- handler.  Re-create that bridge on Wrath so /syndicator search result links work.
if hooksecurefunc and SetItemRef and not SYNDICATOR_335_SETITEMREF_HOOKED then
  SYNDICATOR_335_SETITEMREF_HOOKED = true
  hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
    EventRegistry:TriggerEvent("SetItemRef", link, text, button, chatFrame)
  end)
end

-- ---------------------------------------------------------------------------
-- Timers/events
-- ---------------------------------------------------------------------------
C_Timer = C_Timer or {}
if not C_Timer.After then
  local queue, timerFrame = {}, CreateFrame("Frame")
  timerFrame:Hide()
  timerFrame:SetScript("OnUpdate", function(self, elapsed)
    for i = #queue, 1, -1 do
      local t = queue[i]
      t.left = t.left - elapsed
      if t.left <= 0 then
        table.remove(queue, i)
        local ok, err = pcall(t.func)
        if not ok then ReportCompatError335(err) end
      end
    end
    if #queue == 0 then self:Hide() end
  end)
  function C_Timer.After(seconds, func)
    queue[#queue + 1] = {left=tonumber(seconds) or 0, func=func}
    timerFrame:Show()
  end
end

FrameUtil = FrameUtil or {}
function FrameUtil.RegisterFrameForEvents(frame, events)
  for _, event in ipairs(events or {}) do pcall(frame.RegisterEvent, frame, event) end
end
function FrameUtil.UnregisterFrameForEvents(frame, events)
  for _, event in ipairs(events or {}) do pcall(frame.UnregisterEvent, frame, event) end
end

C_EventUtils = C_EventUtils or {}
function C_EventUtils.IsEventValid(event)
  local f = CreateFrame("Frame")
  local ok = pcall(f.RegisterEvent, f, event)
  if ok then pcall(f.UnregisterEvent, f, event) end
  return ok
end

-- ---------------------------------------------------------------------------
-- AddOn/UI namespaces
-- ---------------------------------------------------------------------------
C_AddOns = C_AddOns or {}
local LegacyIsAddOnLoaded335 = IsAddOnLoaded
local addonsFinishedLoading335 = {}
local addonLoadTracker335 = CreateFrame("Frame")
addonLoadTracker335:RegisterEvent("ADDON_LOADED")
addonLoadTracker335:SetScript("OnEvent", function(_, _, loadedName)
  addonsFinishedLoading335[loadedName] = true
end)

-- The old IsAddOnLoaded() can return true while the current addon's TOC is
-- still being executed.  Modern C_AddOns exposes a second "finished loading"
-- result and the upstream code relies on it.  Returning true for both was the
-- cause of alpha0.01 initialising Syndicator/Baganator halfway through the TOC.
function C_AddOns.IsAddOnLoaded(name)
  local loaded = LegacyIsAddOnLoaded335 and LegacyIsAddOnLoaded335(name) or false
  local finished = addonsFinishedLoading335[name] or false
  if loaded and name ~= "Syndicator" and name ~= "Baganator" and not finished then
    -- Addons loaded before this compatibility layer existed are already done.
    finished = true
  end
  return loaded, finished
end
function C_AddOns.DoesAddOnExist(name)
  if not GetAddOnInfo then return false end
  local addonName = GetAddOnInfo(name)
  return addonName ~= nil
end
function C_AddOns.GetAddOnEnableState(name, character)
  if GetAddOnEnableState then
    local ok, state = pcall(GetAddOnEnableState, character or UnitName("player"), name)
    if ok and state ~= nil then return state end
  end
  local _, _, _, enabled = GetAddOnInfo and GetAddOnInfo(name)
  return enabled and 2 or 0
end
function C_AddOns.IsAddOnLoadable(name)
  if IsAddOnLoadable then
    local ok, loadable, reason = pcall(IsAddOnLoadable, name)
    if ok then return loadable, reason end
  end
  if GetAddOnInfo then
    local _, _, _, _, loadable, reason = GetAddOnInfo(name)
    return loadable ~= false, reason
  end
  return false
end
function C_AddOns.GetAddOnDependencies(name)
  if GetAddOnDependencies then
    local ok, a,b,c,d,e,f,g,h = pcall(GetAddOnDependencies, name)
    if ok then return a,b,c,d,e,f,g,h end
  end
end
C_AddOns.EnableAddOn = C_AddOns.EnableAddOn or EnableAddOn
C_AddOns.DisableAddOn = C_AddOns.DisableAddOn or DisableAddOn
C_AddOns.GetAddOnMetadata = C_AddOns.GetAddOnMetadata or GetAddOnMetadata

C_UI = C_UI or {}
C_UI.Reload = C_UI.Reload or ReloadUI

-- Never expose a partial modern Blizzard Settings namespace on 3.3.5a.
-- Third-party addons feature-detect that global and, when it exists, assume the
-- complete modern Settings API is available (for example slider mixins). Keep
-- the compatibility entry point private to this backport instead.
Syndicator335Compat = Syndicator335Compat or {}
function Syndicator335Compat.OpenOptionsCategory(category)
  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(type(category) == "table" and category.frame or category)
  end
end

C_Texture = C_Texture or {}
function C_Texture.GetAtlasInfo() return nil end

-- ---------------------------------------------------------------------------
-- Enum values used by Baganator/Syndicator
-- ---------------------------------------------------------------------------
Enum = Enum or {}
Enum.BagIndex = Enum.BagIndex or {
  Backpack=0, Bag_1=1, Bag_2=2, Bag_3=3, Bag_4=4,
  Bank=-1, Keyring=-2, ReagentBag=99, Reagentbank=98,
  CharacterBankTab_1=101, CharacterBankTab_2=102, CharacterBankTab_3=103,
  CharacterBankTab_4=104, CharacterBankTab_5=105, CharacterBankTab_6=106,
  AccountBankTab_1=111, AccountBankTab_2=112, AccountBankTab_3=113,
  AccountBankTab_4=114, AccountBankTab_5=115,
}
Enum.BankType = Enum.BankType or { Character=1, Account=2 }
Enum.BankLockedReason = Enum.BankLockedReason or { BankDisabled=1 }
Enum.ItemClass = Enum.ItemClass or {
  Consumable=0, Container=1, Weapon=2, Gem=3, Armor=4, Reagent=5,
  Projectile=6, Tradegoods=7, ItemEnhancement=8, Recipe=9, Money=10,
  Quiver=11, Questitem=12, Key=13, Permanent=14, Miscellaneous=15,
  Glyph=16, Battlepet=17, WoWToken=18, Profession=19, Housing=20,
}
Enum.ItemWeaponSubclass = Enum.ItemWeaponSubclass or { Axe1H=0, Axe2H=1, Mace1H=4, Mace2H=5, Sword1H=7, Sword2H=8 }
Enum.ItemArmorSubclass = Enum.ItemArmorSubclass or { Cloth=1 }
Enum.ItemMiscellaneousSubclass = Enum.ItemMiscellaneousSubclass or { Junk=0, CompanionPet=2, Mount=5 }
Enum.ItemGemSubclass = Enum.ItemGemSubclass or { Artifactrelic=11 }
Enum.ItemReagentSubclass = Enum.ItemReagentSubclass or { Keystone=1 }
Enum.ItemHousingSubclass = Enum.ItemHousingSubclass or { Decor=0 }
Enum.ItemQuality = Enum.ItemQuality or {}
Enum.ItemQuality.Poor = Enum.ItemQuality.Poor or 0
Enum.ItemQuality.Common = Enum.ItemQuality.Common or 1
Enum.ItemQuality.Uncommon = Enum.ItemQuality.Uncommon or 2
Enum.ItemQuality.Rare = Enum.ItemQuality.Rare or 3
Enum.ItemQuality.Epic = Enum.ItemQuality.Epic or 4
Enum.ItemQuality.Legendary = Enum.ItemQuality.Legendary or 5
Enum.ItemQuality.Artifact = Enum.ItemQuality.Artifact or 6
Enum.ItemQuality.Heirloom = Enum.ItemQuality.Heirloom or 7

-- Modern Classic code uses LE_ITEM_QUALITY_* constants and
-- BAG_ITEM_QUALITY_COLORS. Wrath only reliably exposes ITEM_QUALITY_COLORS.
LE_ITEM_QUALITY_POOR = LE_ITEM_QUALITY_POOR or 0
LE_ITEM_QUALITY_COMMON = LE_ITEM_QUALITY_COMMON or 1
LE_ITEM_QUALITY_UNCOMMON = LE_ITEM_QUALITY_UNCOMMON or 2
LE_ITEM_QUALITY_RARE = LE_ITEM_QUALITY_RARE or 3
LE_ITEM_QUALITY_EPIC = LE_ITEM_QUALITY_EPIC or 4
LE_ITEM_QUALITY_LEGENDARY = LE_ITEM_QUALITY_LEGENDARY or 5
LE_ITEM_QUALITY_ARTIFACT = LE_ITEM_QUALITY_ARTIFACT or 6
LE_ITEM_QUALITY_HEIRLOOM = LE_ITEM_QUALITY_HEIRLOOM or 7
BAG_ITEM_QUALITY_COLORS = BAG_ITEM_QUALITY_COLORS or ITEM_QUALITY_COLORS or {}
Enum.ItemTryOnReason = Enum.ItemTryOnReason or { Success=0 }
Enum.BagSlotFlags = Enum.BagSlotFlags or {
  DisableAutoSort=1, ClassEquipment=2, ClassConsumables=4, ClassProfessionGoods=8,
  ClassJunk=16, ClassReagents=32, ExpansionCurrent=64, ExpansionLegacy=128, ExcludeJunkSell=256,
}
local function FillEnum335(target, defaults)
  target = target or {}
  for key, value in pairs(defaults) do
    if target[key] == nil then target[key] = value end
  end
  return target
end
Enum.PlayerInteractionType = FillEnum335(Enum.PlayerInteractionType, {
  Merchant=-33501, Auctioneer=-33502, MailInfo=-33503, GuildBanker=-33504,
  TradePartner=-33505, VoidStorageBanker=-33506, AccountBanker=-33507,
  ScrappingMachine=-33508, Soulbind=-33509, ItemUpgrade=-33510,
  ItemInteraction=-33511,
})
Enum.TooltipDataType = FillEnum335(Enum.TooltipDataType, { Item=0, Currency=1 })
Enum.TooltipDataLineType = FillEnum335(Enum.TooltipDataLineType, { SellPrice=11 })
Enum.AddOnEnableState = FillEnum335(Enum.AddOnEnableState, { All=2, Character=1, None=0 })
Enum.AuctionStatus = FillEnum335(Enum.AuctionStatus, { Active=0 })
Enum.AuctionHouseNotification = FillEnum335(Enum.AuctionHouseNotification, { AuctionSold=0, AuctionExpired=1 })

-- ---------------------------------------------------------------------------
-- Item/container compatibility
-- ---------------------------------------------------------------------------
local function ItemIDFromLink(link)
  if type(link) == "number" then return link end
  if type(link) ~= "string" then return nil end
  return tonumber(link:match("item:(%-?%d+)")) or tonumber(link)
end

-- In 3.3.5 GetAuctionItemClasses() returns the *Auction House display order*,
-- not ItemClass.dbc IDs.  Keep the two domains separate.  Treating row 1 as
-- classID 0 made Weapon become Consumable, Armor become Container, etc.
local CLASS_ID_TO_AH_INDEX = {
  [2]=1,  -- Weapon
  [4]=2,  -- Armor
  [1]=3,  -- Container
  [0]=4,  -- Consumable
  [16]=5, -- Glyph
  [7]=6,  -- Trade Goods
  [6]=7,  -- Projectile
  [11]=8, -- Quiver
  [9]=9,  -- Recipe
  [3]=10, -- Gem
  [15]=11,-- Miscellaneous
  [12]=12,-- Quest
}
local CLASS_NAME_FALLBACK_335 = {
  [0]="Consumable", [1]="Container", [2]="Weapon", [3]="Gem", [4]="Armor",
  [5]="Reagent", [6]="Projectile", [7]="Trade Goods", [8]="Generic (OBSOLETE)",
  [9]="Recipe", [10]="Money", [11]="Quiver", [12]="Quest", [13]="Key",
  [14]="Permanent (OBSOLETE)", [15]="Miscellaneous", [16]="Glyph",
}

-- English DBC names are used as a fallback and also let an English 3.3.5 client
-- recover the real subclass ID from GetItemInfo's subtype string.  Localized
-- Auction House names are layered on top where the old API exposes them.
local SUBCLASS_NAME_FALLBACK_335 = {
  [0] = {[0]="Consumable",[1]="Potion",[2]="Elixir",[3]="Flask",[4]="Scroll",[5]="Food & Drink",[6]="Item Enhancement",[7]="Bandage",[8]="Other"},
  [1] = {[0]="Bag",[1]="Soul Bag",[2]="Herb Bag",[3]="Enchanting Bag",[4]="Engineering Bag",[5]="Gem Bag",[6]="Mining Bag",[7]="Leatherworking Bag",[8]="Inscription Bag"},
  [2] = {[0]="One-Handed Axes",[1]="Two-Handed Axes",[2]="Bows",[3]="Guns",[4]="One-Handed Maces",[5]="Two-Handed Maces",[6]="Polearms",[7]="One-Handed Swords",[8]="Two-Handed Swords",[9]="Obsolete",[10]="Staves",[11]="One-Handed Exotics",[12]="Two-Handed Exotics",[13]="Fist Weapons",[14]="Miscellaneous",[15]="Daggers",[16]="Thrown",[17]="Spears",[18]="Crossbows",[19]="Wands",[20]="Fishing Poles"},
  [3] = {[0]="Red",[1]="Blue",[2]="Yellow",[3]="Purple",[4]="Green",[5]="Orange",[6]="Meta",[7]="Simple",[8]="Prismatic"},
  [4] = {[0]="Miscellaneous",[1]="Cloth",[2]="Leather",[3]="Mail",[4]="Plate",[5]="Bucklers",[6]="Shields",[7]="Librams",[8]="Idols",[9]="Totems",[10]="Sigils"},
  [5] = {[0]="Reagent"},
  [6] = {[2]="Arrows",[3]="Bullets"},
  [7] = {[0]="Trade Goods",[1]="Parts",[2]="Explosives",[3]="Devices",[4]="Jewelcrafting",[5]="Cloth",[6]="Leather",[7]="Metal & Stone",[8]="Meat",[9]="Herb",[10]="Elemental",[11]="Other",[12]="Enchanting",[13]="Materials",[14]="Armor Enchantment",[15]="Weapon Enchantment"},
  [8] = {[0]="Generic"},
  [9] = {[0]="Book",[1]="Leatherworking",[2]="Tailoring",[3]="Engineering",[4]="Blacksmithing",[5]="Cooking",[6]="Alchemy",[7]="First Aid",[8]="Enchanting",[9]="Fishing",[10]="Jewelcrafting",[11]="Inscription"},
  [10] = {[0]="Money"},
  [11] = {[0]="Quiver",[1]="Quiver",[2]="Quiver",[3]="Ammo Pouch"},
  [12] = {[0]="Quest"},
  [13] = {[0]="Key",[1]="Lockpick"},
  [14] = {[0]="Permanent"},
  [15] = {[0]="Junk",[1]="Reagent",[2]="Companion Pet",[3]="Holiday",[4]="Other",[5]="Mount"},
  [16] = {[1]="Warrior",[2]="Paladin",[3]="Hunter",[4]="Rogue",[5]="Priest",[6]="Death Knight",[7]="Shaman",[8]="Mage",[9]="Warlock",[11]="Druid"},
}

local classMap, subclassMap
local function BuildItemClassMaps()
  if classMap then return end
  classMap, subclassMap = {}, {}

  -- First seed exact 3.3.5 English DBC names.
  for classID, className in pairs(CLASS_NAME_FALLBACK_335) do
    classMap[className] = classID
    subclassMap[className] = subclassMap[className] or {}
    local subs = SUBCLASS_NAME_FALLBACK_335[classID]
    if subs then
      for subID, subName in pairs(subs) do
        subclassMap[className][subName] = subID
      end
    end
  end

  -- Then add localized Auction House class names with the *real* DBC IDs.
  if GetAuctionItemClasses then
    local classes = {GetAuctionItemClasses()}
    for classID, ahIndex in pairs(CLASS_ID_TO_AH_INDEX) do
      local className = classes[ahIndex]
      if className then
        classMap[className] = classID
        subclassMap[className] = subclassMap[className] or {}
      end
    end
  end
end

C_Item = C_Item or {}
function C_Item.GetItemInfo(item)
  if item == nil then return nil end
  local name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, equipLoc, texture, sellPrice = GetItemInfo(item)
  if not name then return nil end
  BuildItemClassMaps()
  local classID = itemType and classMap[itemType] or nil
  local subClassID = itemType and itemSubType and subclassMap[itemType] and subclassMap[itemType][itemSubType] or nil
  -- Match the modern return layout closely enough for the upstream Classic code.
  return name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, equipLoc, texture, sellPrice, classID, subClassID, nil, nil, nil, false
end
function C_Item.GetItemInfoInstant(item)
  if item == nil then return nil end
  local itemID = ItemIDFromLink(item)
  local name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, equipLoc, texture, sellPrice = GetItemInfo(item)
  BuildItemClassMaps()
  local classID = itemType and classMap[itemType] or nil
  local subClassID = itemType and itemSubType and subclassMap[itemType] and subclassMap[itemType][itemSubType] or nil
  return itemID, itemType, itemSubType, equipLoc, texture, classID, subClassID
end
function C_Item.IsItemDataCachedByID(item)
  if item == nil then return false end
  return GetItemInfo(item) ~= nil
end
function C_Item.RequestLoadItemDataByID(item)
  if item == nil then return end
  GetItemInfo(item)
end
function C_Item.GetItemMaxStackSizeByID(item)
  if item == nil then return 1 end
  return select(8, GetItemInfo(item)) or 1
end
function C_Item.GetDetailedItemLevelInfo(item)
  if item == nil then return 0 end
  return select(4, GetItemInfo(item)) or 0
end
function C_Item.IsDressableItemByID(item)
  if item == nil then return false end
  return IsDressableItem and IsDressableItem(item) or false
end
function C_Item.IsCosmeticItem() return false end
function C_Item.GetItemSpell(item)
  if item == nil then return nil end
  return GetItemSpell and GetItemSpell(item)
end
function C_Item.DoesItemExist(location)
  if not location then return false end
  if location.bagID ~= nil and location.slotIndex ~= nil then
    return GetContainerItemLink(location.bagID, location.slotIndex) ~= nil
  elseif location.equipmentSlotIndex then
    return GetInventoryItemLink("player", location.equipmentSlotIndex) ~= nil
  end
  return false
end
function C_Item.GetItemID(location)
  if location and location.bagID ~= nil then return ItemIDFromLink(GetContainerItemLink(location.bagID, location.slotIndex)) end
  if location and location.equipmentSlotIndex then return ItemIDFromLink(GetInventoryItemLink("player", location.equipmentSlotIndex)) end
end
function C_Item.IsLocked(location)
  if not location or location.bagID == nil then return false end
  return select(3, GetContainerItemInfo(location.bagID, location.slotIndex)) and true or false
end
function C_Item.GetCurrentItemLevel(location)
  local id = C_Item.GetItemID(location)
  return id and (select(4, GetItemInfo(id)) or 0) or 0
end
function C_Item.CanBeRefunded() return false end
function C_Item.IsItemBindToAccountUntilEquip() return false end

C_Container = C_Container or {}
C_Container.GetContainerNumSlots = C_Container.GetContainerNumSlots or GetContainerNumSlots
C_Container.GetContainerItemLink = C_Container.GetContainerItemLink or GetContainerItemLink
C_Container.GetContainerItemCooldown = C_Container.GetContainerItemCooldown or GetContainerItemCooldown
C_Container.PickupContainerItem = C_Container.PickupContainerItem or PickupContainerItem
C_Container.UseContainerItem = C_Container.UseContainerItem or UseContainerItem
C_Container.SplitContainerItem = C_Container.SplitContainerItem or SplitContainerItem
function C_Container.GetContainerItemInfo(bag, slot)
  local texture, count, locked, quality, readable, lootable, link, filtered, noValue = GetContainerItemInfo(bag, slot)
  if not texture and not link then return nil end
  return {
    iconFileID=texture, stackCount=count or 0, isLocked=locked and true or false,
    quality=quality, isReadable=readable and true or false, hasLoot=lootable and true or false,
    hyperlink=link, isFiltered=filtered and true or false, hasNoValue=noValue and true or false,
    itemID=ItemIDFromLink(link), isBound=false,
  }
end
function C_Container.GetBagName(bag)
  return GetBagName and GetBagName(bag)
end
function C_Container.GetContainerFreeSlots(bag)
  local free = {}
  for slot=1,(GetContainerNumSlots(bag) or 0) do
    if not GetContainerItemLink(bag, slot) then free[#free+1] = slot end
  end
  return free
end
function C_Container.GetContainerNumFreeSlots(bag)
  local n = 0
  for slot=1,(GetContainerNumSlots(bag) or 0) do if not GetContainerItemLink(bag, slot) then n=n+1 end end
  return n, 0
end
function C_Container.SortBags() end
function C_Container.SortBank() end
function C_Container.SetSortBagsRightToLeft() end

-- Old currency API facade
if GetCurrencyListInfo then
  C_CurrencyInfo = C_CurrencyInfo or {}
  function C_CurrencyInfo.GetCurrencyListLink(index) return GetCurrencyListLink and GetCurrencyListLink(index) end
  function C_CurrencyInfo.GetCurrencyIDFromLink(link) return link and tonumber(link:match("currency:(%d+)")) end
  function C_CurrencyInfo.GetCurrencyListSize() return GetCurrencyListSize and GetCurrencyListSize() or 0 end
  function C_CurrencyInfo.ExpandCurrencyList(index, expand)
    if ExpandCurrencyList then ExpandCurrencyList(index, expand and 1 or 0) end
  end
  function C_CurrencyInfo.GetCurrencyListInfo(index)
    local name, isHeader, isHeaderExpanded, isUnused, isWatched, quantity, iconFileID, maxQuantity, canEarnPerWeek, quantityEarnedThisWeek = GetCurrencyListInfo(index)
    if not name then return nil end
    return {
      name=name, isHeader=isHeader and true or false, isHeaderExpanded=isHeaderExpanded and true or false,
      isUnused=isUnused and true or false, isWatched=isWatched and true or false, quantity=quantity or 0,
      iconFileID=iconFileID, maxQuantity=maxQuantity or 0, canEarnPerWeek=canEarnPerWeek and true or false,
      quantityEarnedThisWeek=quantityEarnedThisWeek or 0, discovered=true,
    }
  end
  function C_CurrencyInfo.GetCurrencyInfo(currencyID)
    for index=1,C_CurrencyInfo.GetCurrencyListSize() do
      local link=C_CurrencyInfo.GetCurrencyListLink(index)
      if link and C_CurrencyInfo.GetCurrencyIDFromLink(link)==currencyID then
        local info=C_CurrencyInfo.GetCurrencyListInfo(index)
        if info then info.currencyID=currencyID end
        return info
      end
    end
    return nil
  end
  function C_CurrencyInfo.GetCurrencyLink(currencyID, amount)
    for index=1,C_CurrencyInfo.GetCurrencyListSize() do
      local link=C_CurrencyInfo.GetCurrencyListLink(index)
      if link and C_CurrencyInfo.GetCurrencyIDFromLink(link)==currencyID then return link end
    end
  end
  function C_CurrencyInfo.GetBackpackCurrencyInfo() return nil end
  function C_CurrencyInfo.SetCurrencyBackpackByID() end
  function C_CurrencyInfo.RequestCurrencyDataForAccountCharacters() end
  function C_CurrencyInfo.FetchCurrencyDataFromAccountCharacters() return {} end
end

FlagsUtil = FlagsUtil or {}
if not FlagsUtil.IsSet then
  function FlagsUtil.IsSet(flags, flag)
    if not flags or not flag or flag == 0 then return false end
    if bit and bit.band then return bit.band(flags, flag) == flag end
    -- All Baganator flags are powers of two.
    return flags % (flag * 2) >= flag
  end
end

C_Bank = C_Bank or {}
function C_Bank.FetchBankLockedReason() return nil end
function C_Bank.FetchDepositedMoney() return 0 end

C_PlayerInfo = C_PlayerInfo or {}
function C_PlayerInfo.HasAccountInventoryLock() return false end

C_PlayerInteractionManager = C_PlayerInteractionManager or {}
function C_PlayerInteractionManager.IsInteractingWithNpcOfType(kind)
  if kind == Enum.PlayerInteractionType.Merchant then return MerchantFrame and MerchantFrame:IsShown() end
  if kind == Enum.PlayerInteractionType.Auctioneer then return AuctionFrame and AuctionFrame:IsShown() end
  if kind == Enum.PlayerInteractionType.MailInfo then return MailFrame and MailFrame:IsShown() end
  if kind == Enum.PlayerInteractionType.GuildBanker then return GuildBankFrame and GuildBankFrame:IsShown() end
  return false
end

-- ---------------------------------------------------------------------------
-- Pools used heavily by both addons
-- ---------------------------------------------------------------------------
local function NewPool(createFunc, resetFunc)
  local pool = {active={}, inactive={}}
  function pool:Acquire()
    local obj = table.remove(self.inactive)
    if not obj then obj = createFunc(self) end
    self.active[obj] = true
    if obj.Show then obj:Show() end
    return obj, true
  end
  function pool:Release(obj)
    if not obj or not self.active[obj] then return end
    self.active[obj] = nil
    if resetFunc then resetFunc(self, obj) elseif obj.Hide then obj:Hide() end
    self.inactive[#self.inactive+1] = obj
  end
  function pool:ReleaseAll()
    local list = {}
    for obj in pairs(self.active) do list[#list+1] = obj end
    for _, obj in ipairs(list) do self:Release(obj) end
  end
  return pool
end

if not CreateObjectPool then
  function CreateObjectPool(createFunc, resetFunc) return NewPool(createFunc, resetFunc) end
end
if not CreateFramePool then
  function CreateFramePool(frameType, parent, template, resetFunc, forbidden, onAcquire)
    return NewPool(function(pool)
      local frame = CreateFrame(frameType == "ItemButton" and "Button" or frameType, nil, parent, template)
      return frame
    end, function(pool, frame)
      if frame.Hide then frame:Hide() end
      if frame.ClearAllPoints then frame:ClearAllPoints() end
    end)
  end
end
if not CreateFontStringPool then
  function CreateFontStringPool(parent, layer, subLayer, template)
    return NewPool(function() return parent:CreateFontString(nil, layer, template) end, function(_, fs)
      fs:Hide(); fs:ClearAllPoints(); fs:SetText("")
    end)
  end
end

-- ---------------------------------------------------------------------------
-- Minimal modern method aliases/no-ops on widget metatables
-- ---------------------------------------------------------------------------
local function PatchIndex(object, methods)
  local mt = getmetatable(object)
  local idx = mt and mt.__index
  if type(idx) == "table" then
    for name, func in pairs(methods) do if idx[name] == nil then idx[name] = func end end
  end
end
local probe = CreateFrame("Frame", nil, UIParent)
PatchIndex(probe, {
  SetResizeBounds=function(self,minW,minH,maxW,maxH) if self.SetMinResize then self:SetMinResize(minW or 0,minH or 0) end if maxW and self.SetMaxResize then self:SetMaxResize(maxW,maxH) end end,
  SetFixedFrameStrata=function() end,
  SetFixedFrameLevel=function() end,
  SetTitle=function(self, text)
    local title = self.TitleText
    if not title and self.GetName then
      local name = self:GetName()
      if name then title = _G[name .. "TitleText"] or _G[name .. "Title"] end
    end
    if title and title.SetText then title:SetText(text or "") end
  end,
})
local tex = probe:CreateTexture(nil,"ARTWORK")
PatchIndex(tex, {
  SetShown=function(self, shown) if shown then self:Show() else self:Hide() end end,
  SetAtlas=function(self) self:SetTexture(nil) end,
  SetTexelSnappingBias=function() end,
  SetSnapToPixelGrid=function() end,
  SetColorTexture=function(self, r, g, b, a) self:SetTexture(r or 1, g or 1, b or 1, a == nil and 1 or a) end,
})
local fontProbe = probe:CreateFontString(nil, "ARTWORK", "GameFontNormal")
PatchIndex(fontProbe, {
  SetShown=function(self, shown) if shown then self:Show() else self:Hide() end end,
  SetScale=function(self, scale)
    local path, size, flags = self:GetFont()
    if not self.__bgr335BaseFontSize then self.__bgr335BaseFontSize = size or 12 end
    if path then self:SetFont(path, self.__bgr335BaseFontSize * (tonumber(scale) or 1), flags) end
  end,
})
probe:Hide()

-- Legacy-friendly helpers used by converted XML
Baganator335Compat = Baganator335Compat or {}

-- ButtonFrameTemplate differs substantially between stock 3.3.5a and modern
-- Classic. Modern Baganator expects fields such as self.Inset to always exist.
-- On Wrath, some ButtonFrameTemplate variants do not create/export that region,
-- which aborts OnLoad and leaves the whole view only half initialized.
function Baganator335Compat.EnsureButtonFrame(frame)
  if not frame then return frame end

  local name = frame.GetName and frame:GetName()
  if name then
    frame.Inset = frame.Inset or _G[name .. "Inset"] or _G[name .. "InsetFrame"]
    local titleCandidate = frame.TitleText or _G[name .. "TitleText"]
    if titleCandidate and titleCandidate.SetText then
      frame.TitleText = titleCandidate
    else
      frame.TitleText = nil
    end
    frame.CloseButton = frame.CloseButton or _G[name .. "CloseButton"]
    frame.Portrait = frame.Portrait or _G[name .. "Portrait"]
  end

  -- Baganator hides the inset on all of its main ButtonFrames. A plain hidden
  -- frame is therefore the safest faithful fallback: it satisfies the modern
  -- object contract without adding any Retail/TBC artwork to Wrath.
  if not frame.Inset and frame.CreateTexture then
    local inset = CreateFrame("Frame", nil, frame)
    inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -24)
    inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    inset:Hide()
    frame.Inset = inset
  end

  -- Stock 3.3.5 ButtonFrameTemplate does not expose the same title/close
  -- contract as modern Classic. Build a deterministic header instead of
  -- relying on inherited named regions. This also gives the converted XML a
  -- real anchor for Customise/Sort/Transfer buttons.
  if not frame.TitleText or not frame.TitleText.SetText then
    frame.TitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  end
  if frame.TitleText then
    if frame.TitleText.SetFontObject and GameFontNormal then frame.TitleText:SetFontObject(GameFontNormal) end
    if frame.TitleText.GetFont and frame.TitleText.SetFont then
      local fontPath, _, flags = frame.TitleText:GetFont()
      if fontPath then frame.TitleText:SetFont(fontPath, 12, flags) end
    end
    frame.TitleText:ClearAllPoints()
    frame.TitleText:SetPoint("TOP", frame, "TOP", 0, -8)
    frame.TitleText:SetJustifyH("CENTER")
    frame.TitleText:SetJustifyV("TOP")
    if frame.TitleText.SetTextColor then frame.TitleText:SetTextColor(1, 0.82, 0, 1) end
  end

  local close = frame.CloseButton
  if not close or not close.SetScript then
    local closeName = name and (name .. "CloseButton335") or nil
    close = CreateFrame("Button", closeName, frame, "UIPanelCloseButton")
    frame.CloseButton = close
  end
  if close then
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    close:SetWidth(22)
    close:SetHeight(22)
    if close.SetFrameLevel and frame.GetFrameLevel then close:SetFrameLevel(frame:GetFrameLevel() + 20) end
    if close.SetNormalTexture then close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up") end
    if close.SetPushedTexture then close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down") end
    if close.SetHighlightTexture then close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD") end
    close:SetScript("OnClick", function() frame:Hide() end)
    close:Show()
  end

  if frame.Portrait and frame.Portrait.Hide then frame.Portrait:Hide() end

  -- Rebuild the right-side header chain explicitly. The converted XML anchors
  -- reference $parentCloseButton, which cannot resolve when the modern
  -- ButtonFrame child does not exist during XML creation on 3.3.5a.
  if frame.CustomiseButton and close then
    frame.CustomiseButton:ClearAllPoints()
    frame.CustomiseButton:SetPoint("TOPRIGHT", close, "TOPLEFT", 0, 0)
  end
  if frame.SortButton and frame.CustomiseButton then
    frame.SortButton:ClearAllPoints()
    frame.SortButton:SetPoint("RIGHT", frame.CustomiseButton, "LEFT", 0, 0)
  end
  if frame.TransferButton and frame.SortButton then
    frame.TransferButton:ClearAllPoints()
    frame.TransferButton:SetPoint("RIGHT", frame.SortButton, "LEFT", 0, 0)
  elseif frame.TransferButton and frame.CustomiseButton then
    frame.TransferButton:ClearAllPoints()
    frame.TransferButton:SetPoint("RIGHT", frame.CustomiseButton, "LEFT", 0, 0)
  end

  return frame
end

-- Keep Baganator's small icon buttons deterministic on stock 3.3.5a.
-- Virtual-template visual regions/scripts do not always survive into concrete
-- children, so restore only Baganator-owned chrome/icons here rather than
-- faking any Blizzard-global template state.
function Baganator335Compat.EnsureClassicIconButton(button, texture, iconSize, yOffset)
  if not button then return end

  local chrome = "Interface\\AddOns\\Baganator\\Assets\\classic-bag-slot.tga"

  -- Do not rely on inherited Button normal textures on Wrath. In particular
  -- the bank/shield and global-search buttons could end up with a different
  -- looking background depending on which virtual OnLoad chain happened to
  -- run. Give every Baganator icon button the exact same explicit backdrop.
  if button.SetNormalTexture then button:SetNormalTexture(nil) end
  if button.SetPushedTexture then button:SetPushedTexture(nil) end
  if button.SetDisabledTexture then button:SetDisabledTexture(nil) end
  if not button.__bgr335Chrome and button.CreateTexture then
    button.__bgr335Chrome = button:CreateTexture(nil, "BACKGROUND")
  end
  if button.__bgr335Chrome then
    -- Keep the visual chrome slightly inside the clickable button bounds.
    -- This gives the left header buttons the same breathing room as the
    -- modern Classic presentation without changing button size or glyph size.
    local chromeInset = button.__bgr335ChromeInset or 0
    button.__bgr335Chrome:ClearAllPoints()
    if chromeInset > 0 then
      button.__bgr335Chrome:SetPoint("TOPLEFT", button, "TOPLEFT", chromeInset, -chromeInset)
      button.__bgr335Chrome:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -chromeInset, chromeInset)
    else
      button.__bgr335Chrome:SetAllPoints(button)
    end
    button.__bgr335Chrome:SetTexture(chrome)
    button.__bgr335Chrome:SetVertexColor(1, 1, 1, 1)
    button.__bgr335Chrome:Show()
  end
  if button.SetHighlightTexture then button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD") end

  local name = button.GetName and button:GetName()
  local icon = button.Icon
  if not icon and name then icon = _G[name .. "Icon"] end
  if texture and button.CreateTexture then
    if not icon then icon = button:CreateTexture(nil, "OVERLAY") end
    button.Icon = icon
    if icon then
      if icon.SetTexture then icon:SetTexture(texture) end
      if icon.SetDrawLayer then icon:SetDrawLayer("OVERLAY", 1) end
      if icon.SetWidth then icon:SetWidth(iconSize or 14) end
      if icon.SetHeight then icon:SetHeight(iconSize or 14) end
      if icon.ClearAllPoints then icon:ClearAllPoints() end
      if icon.SetPoint then icon:SetPoint("CENTER", button, "CENTER", 0, yOffset or 0) end
      if icon.Show then icon:Show() end
    end
  end

  return icon
end

function Baganator335Compat.ParentKey(self, key, array)
  local parent = self and self.GetParent and self:GetParent()
  if not parent then return end
  if key then parent[key] = self end

  -- 3.3.5 does not reliably chain virtual-template OnLoad scripts. Hydrate the
  -- common named regions that modern templates expose as self.Icon/self.Bg/etc.
  local name = self.GetName and self:GetName()
  if name then
    local regionKeys = {"Icon", "SelectedTexture", "Background", "Bg", "TopTileStreaks", "TitleBg", "Money", "TitleText", "Count", "CountText", "NormalTexture", "HighlightTexture", "PushedTexture", "DisabledTexture"}
    for _, regionKey in ipairs(regionKeys) do
      if self[regionKey] == nil then self[regionKey] = _G[name .. regionKey] end
    end
  end

  -- Header navigation icons are inherited from virtual templates in modern
  -- Classic, but stock 3.3.5a can lose the inherited region or its draw state
  -- when a concrete child supplies its own OnLoad script. Keep this deliberately
  -- narrow: only the four left-side Baganator header buttons are repaired here.
  -- This avoids the broad alpha0.24 icon override regression while making the
  -- icon state deterministic across characters / freshly-created frame groups.
  local headerIcons = {
    -- Left navigation: one extra pixel down from alpha0.29 so the glyphs sit
    -- fully inside the title-bar line.
    ToggleBankButton = {"Interface\\AddOns\\Baganator\\Assets\\Chest.tga", 17, 0},
    ToggleGuildBankButton = {"Interface\\AddOns\\Baganator\\Assets\\Guild.tga", 17, -2},
    ToggleAllCharacters = {"Interface\\AddOns\\Baganator\\Assets\\All_Characters.tga", 17, -2},
    ToggleBagSlotsButton = {"Interface\\AddOns\\Baganator\\Assets\\Bags.tga", 17, -2},

    -- Narrow deterministic repairs for concrete children whose inherited icon
    -- region can vanish on a fresh character/frame group.
    CustomiseButton = {"Interface\\AddOns\\Baganator\\Assets\\Cog.tga", 17, 0},
    SortButton = {"Interface\\AddOns\\Baganator\\Assets\\Sorting.tga", 17, 0},
    TransferButton = {"Interface\\AddOns\\Baganator\\Assets\\Transfer.tga", 16, 0},
    CurrencyButton = {"Interface\\AddOns\\Baganator\\Assets\\Currency.tga", 14, 0},
    GlobalSearchButton = {"Interface\\AddOns\\Baganator\\Assets\\Search.tga", 14, 0},
    SavedSearchesButton = {"Interface\\AddOns\\Baganator\\Assets\\SavedSearches.tga", 14, 0},
  }
  local iconSpec = key and headerIcons[key]
  -- Header chrome must fill the same button bounds on both sides. Older 3.3.5
  -- builds added a 2px inset only to the left group, making those buttons look
  -- smaller despite having the same clickable dimensions.
  self.__bgr335ChromeInset = 0
  local classicIconButtonKeys = {
    ToggleBankButton = true, ToggleGuildBankButton = true, ToggleAllCharacters = true, ToggleBagSlotsButton = true,
    CustomiseButton = true, SortButton = true, TransferButton = true, CurrencyButton = true,
    GlobalSearchButton = true, SavedSearchesButton = true, HelpButton = true,
  }
  if key and classicIconButtonKeys[key] then
    Baganator335Compat.EnsureClassicIconButton(self, iconSpec and iconSpec[1], iconSpec and iconSpec[2], iconSpec and iconSpec[3])
  end

  -- Do not replace Baganator's other inherited icon textures here. Most of those
  -- already render correctly on 3.3.5a, and overriding them globally caused
  -- regressions in alpha0.24. Only restore the missing click handlers that do
  -- not reliably chain from virtual templates.
  if key == "CustomiseButton" and self.SetScript then
    self:SetScript("OnClick", function()
      if Baganator and Baganator.CallbackRegistry then Baganator.CallbackRegistry:TriggerEvent("ShowCustomise") end
    end)
  elseif key == "CurrencyButton" and self.SetScript then
    self:SetScript("OnClick", function()
      if Baganator and Baganator.CallbackRegistry then Baganator.CallbackRegistry:TriggerEvent("CurrencyPanelToggle") end
    end)
  end
  if array then
    parent[array] = parent[array] or {}
    table.insert(parent[array], self)
  end
end

-- ---------------------------------------------------------------------------
-- Additional 3.3.5 helpers used by the original TBC Classic code
-- ---------------------------------------------------------------------------
if not tIndexOf then
  function tIndexOf(tbl, value)
    for i, v in ipairs(tbl or {}) do if v == value then return i end end
    return nil
  end
end

if not tContains then
  function tContains(tbl, value)
    return tIndexOf(tbl, value) ~= nil
  end
end

if not tCompare then
  local function DeepEqual(a, b, depth)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' or depth <= 0 then return false end
    for k, v in pairs(a) do if not DeepEqual(v, b[k], depth - 1) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
  end
  function tCompare(a, b, depth) return DeepEqual(a, b, depth or 10) end
end

-- Always provide stock-3.3.5 class/subclass lookup semantics here. Other legacy
-- addons may install placeholder C_Item shims (for example returning "class 17"),
-- which tricks Syndicator into enabling post-Wrath search categories.
function C_Item.GetItemClassInfo(classID)
  if type(classID) ~= "number" or classID < 0 or classID > 16 then return nil end
  local ahIndex = CLASS_ID_TO_AH_INDEX[classID]
  if ahIndex and GetAuctionItemClasses then
    local name = select(ahIndex, GetAuctionItemClasses())
    if name then return name end
  end
  return CLASS_NAME_FALLBACK_335[classID]
end
function C_Item.GetItemSubClassInfo(classID, subClassID)
  -- A few legacy consumers (notably old Auctionator category code) already
  -- pass the localized subclass text here. Modern C_Item callers pass an ID.
  if type(subClassID) == "string" then return subClassID end
  if type(classID) ~= "number" or type(subClassID) ~= "number" or classID < 0 or subClassID < 0 then return nil end
  local subs = SUBCLASS_NAME_FALLBACK_335[classID]
  return subs and subs[subClassID] or nil
end
if not C_Item.GetItemFamily then
  function C_Item.GetItemFamily(item)
    if item == nil then return 0 end
    return GetItemFamily and GetItemFamily(item) or 0
  end
end
if not C_Item.GetItemInventoryTypeByID then
  local INVENTORY_TYPE_ID_335 = {
    [""] = 0, INVTYPE_NON_EQUIP_IGNORE = 0,
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4,
    INVTYPE_CHEST = 5, INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8,
    INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12,
    INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14, INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16,
    INVTYPE_2HWEAPON = 17, INVTYPE_BAG = 18, INVTYPE_TABARD = 19, INVTYPE_ROBE = 20,
    INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22, INVTYPE_HOLDABLE = 23,
    INVTYPE_AMMO = 24, INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26, INVTYPE_QUIVER = 27,
    INVTYPE_RELIC = 28,
  }
  function C_Item.GetItemInventoryTypeByID(item)
    if item == nil then return nil end
    local equipLoc = select(9, GetItemInfo(item))
    if type(equipLoc) == "number" then return equipLoc end
    return INVENTORY_TYPE_ID_335[equipLoc or ""] or 0
  end
end
if not C_Item.GetItemNameByID then
  function C_Item.GetItemNameByID(item)
    if item == nil then return nil end
    return GetItemInfo(item)
  end
end
if not C_Item.GetItemQualityByID then
  function C_Item.GetItemQualityByID(item)
    if item == nil then return nil end
    return select(3, GetItemInfo(item))
  end
end
if not C_Item.GetItemStats then
  C_Item.GetItemStats = GetItemStats or function() return {} end
end
if not C_Item.GetItemGUID then
  function C_Item.GetItemGUID(location)
    if not location then return nil end
    local id = C_Item.GetItemID(location)
    if not id then return nil end
    if location.bagID ~= nil then return ('bag:%s:%s:%s'):format(location.bagID, location.slotIndex or 0, id) end
    if location.equipmentSlotIndex then return ('equip:%s:%s'):format(location.equipmentSlotIndex, id) end
    return tostring(id)
  end
end
if not C_Item.IsBound then C_Item.IsBound = function() return false end end
if not C_Item.IsBoundToAccountUntilEquip then C_Item.IsBoundToAccountUntilEquip = function() return false end end
if not C_Item.CanScrapItem then C_Item.CanScrapItem = function() return false end end
if not C_Item.IsAnimaItemByID then C_Item.IsAnimaItemByID = function() return false end end
if not C_Item.IsDecorItem then C_Item.IsDecorItem = function() return false end end
if not C_Item.IsItemKeystoneByID then C_Item.IsItemKeystoneByID = function() return false end end
if not C_Item.GetItemLearnTransmogSet then C_Item.GetItemLearnTransmogSet = function() return nil end end
if not C_Item.GetItemUpgradeInfo then C_Item.GetItemUpgradeInfo = function() return nil end end
if not C_Item.GetSetBonusesForSpecializationByItemID then C_Item.GetSetBonusesForSpecializationByItemID = function() return nil end end

if not C_Container.ContainerIDToInventoryID then
  function C_Container.ContainerIDToInventoryID(bag)
    if bag >= 1 and bag <= 4 and ContainerIDToInventoryID then return ContainerIDToInventoryID(bag) end
    return nil
  end
end
if not C_Container.GetContainerItemDurability then C_Container.GetContainerItemDurability = GetContainerItemDurability or function() end end
if not C_Container.GetContainerItemQuestInfo then
  function C_Container.GetContainerItemQuestInfo()
    -- Modern clients always return a structure. Wrath has no equivalent API
    -- for arbitrary bag slots, so return the neutral structure Baganator expects.
    return { isQuestItem = false, questID = nil, isActive = false }
  end
end
if not C_Container.IsBattlePayItem then C_Container.IsBattlePayItem = function() return false end end
if not C_Container.GetBagSlotFlag then C_Container.GetBagSlotFlag = function() return false end end
if not C_Container.SetBagSlotFlag then C_Container.SetBagSlotFlag = function() end end
if not C_Container.GetBackpackAutosortDisabled then C_Container.GetBackpackAutosortDisabled = function() return false end end
if not C_Container.SetBackpackAutosortDisabled then C_Container.SetBackpackAutosortDisabled = function() end end
if not C_Container.GetBankAutosortDisabled then C_Container.GetBankAutosortDisabled = function() return false end end
if not C_Container.SetBankAutosortDisabled then C_Container.SetBankAutosortDisabled = function() end end
if not C_Container.GetBackpackSellJunkDisabled then C_Container.GetBackpackSellJunkDisabled = function() return false end end
if not C_Container.SetBackpackSellJunkDisabled then C_Container.SetBackpackSellJunkDisabled = function() end end

C_Spell = C_Spell or {}
local function SafeGetSpellInfo335(id)
  if id == nil or (type(id) ~= "number" and type(id) ~= "string") then return nil end
  local ok, name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange = pcall(GetSpellInfo, id)
  if not ok or not name then return nil end
  return name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange
end
if not C_Spell.IsSpellDataCached then C_Spell.IsSpellDataCached = function(id) return SafeGetSpellInfo335(id) ~= nil end end
if not C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData = function(id) SafeGetSpellInfo335(id) end end
if not C_Spell.GetSpellInfo then
  function C_Spell.GetSpellInfo(id)
    local name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange = SafeGetSpellInfo335(id)
    if not name then return nil end
    return {name=name, iconID=icon, castTime=castTime, minRange=minRange, maxRange=maxRange}
  end
end

-- Wrath equipment manager facade.
C_EquipmentSet = C_EquipmentSet or {}
if not C_EquipmentSet.GetEquipmentSetIDs then
  function C_EquipmentSet.GetEquipmentSetIDs()
    local out = {}
    if GetNumEquipmentSets then
      for i=1,GetNumEquipmentSets() do out[#out+1]=i end
    end
    return out
  end
end
if not C_EquipmentSet.GetEquipmentSetInfo then
  function C_EquipmentSet.GetEquipmentSetInfo(id)
    if not GetEquipmentSetInfo then return nil end
    local name, icon = GetEquipmentSetInfo(id)
    return name, icon
  end
end
if not C_EquipmentSet.GetItemIDs then
  function C_EquipmentSet.GetItemIDs(id)
    if not GetEquipmentSetItemIDs then return {} end
    local a={GetEquipmentSetItemIDs(id)}
    return a
  end
end
if not C_EquipmentSet.GetItemLocations then
  function C_EquipmentSet.GetItemLocations(id)
    if not GetEquipmentSetLocations then return {} end
    local a={GetEquipmentSetLocations(id)}
    return a
  end
end

ItemLocation = ItemLocation or {}
local function NewBagItemLocation335(bagID, slotIndex)
  return {
    bagID = bagID,
    slotIndex = slotIndex,
    IsBagAndSlot = function() return true end,
    IsEquipmentSlot = function() return false end,
    GetBagAndSlot = function(self) return self.bagID, self.slotIndex end,
  }
end
local function NewEquipmentItemLocation335(slot)
  return {
    equipmentSlotIndex = slot,
    IsBagAndSlot = function() return false end,
    IsEquipmentSlot = function() return true end,
    GetEquipmentSlot = function(self) return self.equipmentSlotIndex end,
  }
end
function ItemLocation:CreateFromBagAndSlot(bagID, slotIndex)
  return NewBagItemLocation335(bagID, slotIndex)
end
function ItemLocation:CreateFromEquipmentSlot(slot)
  return NewEquipmentItemLocation335(slot)
end

-- Timer objects used by lockpicking/refund tracking.
if not C_Timer.NewTimer then
  function C_Timer.NewTimer(seconds, callback)
    local obj={cancelled=false}
    function obj:Cancel() self.cancelled=true end
    C_Timer.After(seconds, function() if not obj.cancelled then callback(obj) end end)
    return obj
  end
end
if not C_Timer.NewTicker then
  function C_Timer.NewTicker(seconds, callback, iterations)
    local obj={cancelled=false, count=0}
    function obj:Cancel() self.cancelled=true end
    local function tick()
      if obj.cancelled then return end
      obj.count=obj.count+1
      callback(obj)
      if not obj.cancelled and (not iterations or obj.count < iterations) then C_Timer.After(seconds, tick) end
    end
    C_Timer.After(seconds, tick)
    return obj
  end
end

C_ChatInfo = C_ChatInfo or {}
if not C_ChatInfo.InChatMessagingLockdown then C_ChatInfo.InChatMessagingLockdown=function() return false end end

C_Cursor = C_Cursor or {}
if not C_Cursor.GetCursorItem then
  function C_Cursor.GetCursorItem()
    local kind, id, link = GetCursorInfo()
    if kind == 'item' then return id, link end
  end
end

C_XMLUtil = C_XMLUtil or {}
if not C_XMLUtil.GetTemplateInfo then C_XMLUtil.GetTemplateInfo=function() return nil end end

-- No battle pets/transmog/toys/housing in stock 3.3.5a. Keep feature-presence
-- globals nil so upstream feature gates remain false. C_ItemSocketInfo is the one
-- exception because the item-button code safely checks a method on the table.
C_PetJournal = nil
C_MountJournal = nil
C_ToyBox = nil
C_HousingCatalog = nil
C_Transmog = nil
C_TransmogCollection = nil
C_TradeSkillUI = nil
C_ItemSocketInfo = C_ItemSocketInfo or {}


if not ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait = function() end end
if not ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar = function() end end



-- 3.3.5a has no modern ScrollBox/DataProvider framework. This lightweight
-- compatibility layer implements the subset Baganator/Syndicator use: linear
-- rows, data providers, visible-frame enumeration and a classic scrollbar.
if not CreateDataProvider then
  function CreateDataProvider(data)
    local provider = { collection = data or {} }
    function provider:FindIndex(element)
      for i, value in ipairs(self.collection) do
        if value == element then return i end
      end
      return nil
    end
    function provider:GetSize()
      return #self.collection
    end
    function provider:Enumerate()
      return ipairs(self.collection)
    end
    return provider
  end
end

if not CreateScrollBoxListLinearView then
  function CreateScrollBoxListLinearView()
    local view = { elementExtent = 20 }
    function view:SetElementExtent(extent) self.elementExtent = extent or 20 end
    function view:SetElementExtentCalculator(func) self.elementExtentCalculator = func end
    function view:SetElementInitializer(frameType, func)
      self.frameType = frameType or "Button"
      self.elementInitializer = func
    end
    return view
  end
end

ScrollUtil = ScrollUtil or {}
if not ScrollUtil.InitScrollBoxListWithScrollBar then
  function ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    scrollBox.__bgr335View = view
    scrollBox.__bgr335Rows = scrollBox.__bgr335Rows or {}
    scrollBox.__bgr335VisibleRows = scrollBox.__bgr335VisibleRows or {}
    scrollBox.__bgr335Offset = scrollBox.__bgr335Offset or 0
    scrollBox.__bgr335ScrollBar = scrollBar

    local function RowExtent(index, data)
      if view.elementExtentCalculator then
        return view.elementExtentCalculator(index, data) or view.elementExtent or 20
      end
      return view.elementExtent or 20
    end

    local function EnsureRow(slot, frameType)
      local row = scrollBox.__bgr335Rows[slot]
      if row then return row end
      frameType = frameType or "Button"
      row = CreateFrame(frameType == "ItemButton" and "Button" or frameType, nil, scrollBox)
      row:SetFrameLevel(scrollBox:GetFrameLevel() + 1)
      if frameType == "Button" and row.SetNormalFontObject then
        row:SetNormalFontObject(GameFontHighlight)
      end
      scrollBox.__bgr335Rows[slot] = row
      return row
    end

    function scrollBox:GetDataProvider()
      return self.__bgr335DataProvider
    end

    function scrollBox:EnumerateFrames()
      return ipairs(self.__bgr335VisibleRows or {})
    end

    function scrollBox:Rebuild335()
      local provider = self.__bgr335DataProvider
      local data = provider and provider.collection or {}
      local baseExtent = math.max(1, view.elementExtent or 20)
      local height = self:GetHeight() or 0
      local visibleCount = math.max(1, math.floor((height > 0 and height or 360) / baseExtent) + 2)
      local maxOffset = math.max(0, #data - visibleCount)
      if self.__bgr335Offset > maxOffset then self.__bgr335Offset = maxOffset end

      if scrollBar and scrollBar.SetMinMaxValues then
        scrollBar:SetMinMaxValues(0, maxOffset)
        if scrollBar.SetValueStep then scrollBar:SetValueStep(1) end
        if scrollBar.SetValue and scrollBar:GetValue() ~= self.__bgr335Offset then
          scrollBar:SetValue(self.__bgr335Offset)
        end
        if maxOffset > 0 then scrollBar:Show() else scrollBar:Hide() end
      end

      wipe(self.__bgr335VisibleRows)
      local y = 0
      local slot = 0
      for index = self.__bgr335Offset + 1, math.min(#data, self.__bgr335Offset + visibleCount) do
        slot = slot + 1
        local elementData = data[index]
        local row = EnsureRow(slot, view.frameType)
        local extent = RowExtent(index, elementData)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y)
        row:SetHeight(extent)
        row:Show()
        if view.elementInitializer then
          view.elementInitializer(row, elementData)
        end
        self.__bgr335VisibleRows[#self.__bgr335VisibleRows + 1] = row
        y = y + extent
      end
      for i = slot + 1, #self.__bgr335Rows do
        self.__bgr335Rows[i]:Hide()
      end
    end

    function scrollBox:SetDataProvider(provider, retainScrollPosition)
      self.__bgr335DataProvider = provider or CreateDataProvider({})
      if not retainScrollPosition then self.__bgr335Offset = 0 end
      self:Rebuild335()
    end

    -- Only Sliders support OnValueChanged in 3.3.5a. Converted XML can
    -- otherwise leave a plain Frame here; do not call an unsupported script.
    if scrollBar and scrollBar.SetMinMaxValues and scrollBar.SetValue and scrollBar.SetScript then
      scrollBar:SetScript("OnValueChanged", function(_, value)
        local offset = math.floor((tonumber(value) or 0) + 0.5)
        if offset ~= scrollBox.__bgr335Offset then
          scrollBox.__bgr335Offset = offset
          scrollBox:Rebuild335()
        end
      end)
    end
  end
end
if not ScrollUtil.AddManagedScrollBarVisibilityBehavior then
  function ScrollUtil.AddManagedScrollBarVisibilityBehavior() end
end

-- Baganator must not depend on another addon's ScrollUtil shim. Auctionator's
-- 3.3.5 implementation expects its scrollbar to be parented to a ScrollFrame,
-- while Baganator's converted layouts use a sibling Slider. Keep a private
-- linear-list implementation for Baganator/Syndicator-owned frames.
Baganator335Compat = Baganator335Compat or {}
function Baganator335Compat.CreateDataProvider(data)
  local provider = { collection = data or {} }
  function provider:GetSize() return #self.collection end
  function provider:Enumerate() return ipairs(self.collection) end
  function provider:FindIndex(value)
    for i, v in ipairs(self.collection) do if v == value then return i end end
  end
  return provider
end
function Baganator335Compat.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
  scrollBox.__bgr335View = view
  scrollBox.__bgr335Rows = scrollBox.__bgr335Rows or {}
  scrollBox.__bgr335VisibleRows = scrollBox.__bgr335VisibleRows or {}
  scrollBox.__bgr335Offset = scrollBox.__bgr335Offset or 0

  local function rowExtent(index, data)
    if view.elementExtentCalculator then return view.elementExtentCalculator(index, data) or view.elementExtent or 20 end
    return view.elementExtent or 20
  end
  local function ensureRow(slot)
    local row = scrollBox.__bgr335Rows[slot]
    if row then return row end
    local frameType = view.frameType or "Button"
    row = CreateFrame(frameType == "ItemButton" and "Button" or frameType, nil, scrollBox)
    row:SetFrameLevel((scrollBox:GetFrameLevel() or 1) + 1)
    if frameType == "Button" and row.SetNormalFontObject then
      row:SetNormalFontObject(GameFontHighlight)
      if row.GetFontString and not row:GetFontString() and row.SetFontString then
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetJustifyH("LEFT")
        text:SetPoint("LEFT", 4, 0)
        text:SetPoint("RIGHT", -4, 0)
        row:SetFontString(text)
      end
    end
    scrollBox.__bgr335Rows[slot] = row
    return row
  end
  function scrollBox:GetDataProvider() return self.__bgr335DataProvider end
  function scrollBox:EnumerateFrames() return ipairs(self.__bgr335VisibleRows or {}) end
  function scrollBox:Rebuild335()
    local provider = self.__bgr335DataProvider
    local data = provider and provider.collection
    if not data and provider and provider.Enumerate then
      data = {}
      local ok, iterator, state, initial = pcall(provider.Enumerate, provider)
      if ok and iterator then
        for _, value in iterator, state, initial do data[#data + 1] = value end
      end
    end
    data = data or {}
    local baseExtent = math.max(1, view.elementExtent or 20)
    local visibleCount = math.max(1, math.floor(((self:GetHeight() or 360) > 0 and (self:GetHeight() or 360) or 360) / baseExtent) + 2)
    local maxOffset = math.max(0, #data - visibleCount)
    self.__bgr335Offset = math.max(0, math.min(self.__bgr335Offset or 0, maxOffset))
    if scrollBar and scrollBar.SetMinMaxValues then
      scrollBar:SetMinMaxValues(0, maxOffset)
      if scrollBar.SetValueStep then scrollBar:SetValueStep(1) end
      if scrollBar.SetValue and scrollBar:GetValue() ~= self.__bgr335Offset then scrollBar:SetValue(self.__bgr335Offset) end
      if maxOffset > 0 then scrollBar:Show() else scrollBar:Hide() end
    end
    wipe(self.__bgr335VisibleRows)
    local y, slot = 0, 0
    for index=self.__bgr335Offset+1, math.min(#data, self.__bgr335Offset+visibleCount) do
      slot=slot+1
      local elementData=data[index]
      local row=ensureRow(slot)
      local extent=rowExtent(index, elementData)
      row:ClearAllPoints(); row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y); row:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y); row:SetHeight(extent); row:Show()
      if view.elementInitializer then view.elementInitializer(row, elementData) end
      self.__bgr335VisibleRows[#self.__bgr335VisibleRows+1]=row
      y=y+extent
    end
    for i=slot+1,#self.__bgr335Rows do self.__bgr335Rows[i]:Hide() end
  end
  function scrollBox:SetDataProvider(provider, retainScrollPosition)
    self.__bgr335DataProvider=provider or CreateDataProvider({})
    if not retainScrollPosition then self.__bgr335Offset=0 end
    self:Rebuild335()
  end
  if scrollBar and scrollBar.SetMinMaxValues and scrollBar.SetValue then
    scrollBar:SetScript("OnValueChanged", function(_, value)
      local offset=math.floor((tonumber(value) or 0)+0.5)
      if offset ~= (scrollBox.__bgr335Offset or 0) then scrollBox.__bgr335Offset=offset; scrollBox:Rebuild335() end
    end)
  end
  scrollBox:EnableMouseWheel(true)
  scrollBox:SetScript("OnMouseWheel", function(_, delta)
    local maxOffset=0
    if scrollBar and scrollBar.GetMinMaxValues then local _, m=scrollBar:GetMinMaxValues(); maxOffset=m or 0 end
    scrollBox.__bgr335Offset=math.max(0, math.min(maxOffset, (scrollBox.__bgr335Offset or 0) - (delta or 0)))
    if scrollBar and scrollBar.SetValue then scrollBar:SetValue(scrollBox.__bgr335Offset) else scrollBox:Rebuild335() end
  end)
end

if not ContainerFrameItemButton_SetForceExtended then
  function ContainerFrameItemButton_SetForceExtended() end
end

-- Widget method aliases.
local buttonProbe = CreateFrame('Button', nil, UIParent)
PatchIndex(buttonProbe, {
  SetShown=function(self, shown) if shown then self:Show() else self:Hide() end end,
  SetNormalAtlas=function(self) self:SetNormalTexture(nil) end,
  SetHighlightAtlas=function(self) self:SetHighlightTexture(nil) end,
  SetPushedAtlas=function(self) self:SetPushedTexture(nil) end,
  SetDisabledAtlas=function(self) self:SetDisabledTexture(nil) end,
  SetItemButtonQuality=function(self, ...) return SetItemButtonQuality(self, ...) end,
  SetItemButtonTexture=function(self, texture) if SetItemButtonTexture then return SetItemButtonTexture(self, texture) end end,
  SetItemButtonCount=function(self, count) if SetItemButtonCount then return SetItemButtonCount(self, count) end end,
})
PatchIndex(probe, {
  SetShown=function(self, shown) if shown then self:Show() else self:Hide() end end,
  IsMouseOver=function(self) return MouseIsOver and MouseIsOver(self) or false end,
  SetPropagateMouseMotion=function() end,
  SetPropagateMouseClicks=function() end,
})
buttonProbe:Hide()
