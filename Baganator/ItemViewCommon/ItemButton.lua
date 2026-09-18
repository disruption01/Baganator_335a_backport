---@class addonTableBaganator
local addonTable = select(2, ...)

addonTable.ItemButtonUtil = {}

local itemCallbacks = {}
local iconSettings = {}

-- WoW 3.3.5a Cooldown frames do not expose the modern :Clear() API.
-- Keep all cooldown manipulation behind a small compatibility wrapper so
-- both the classic and retail-style button mixins can share the same path.
local function SetCooldownCompat(cooldown, start, duration, enable)
  if not cooldown then
    return
  end

  start = tonumber(start) or 0
  duration = tonumber(duration) or 0
  enable = enable == nil and 1 or enable

  if duration > 0 and enable ~= 0 then
    if cooldown.Show then
      cooldown:Show()
    end
    if cooldown.SetDrawEdge then
      cooldown:SetDrawEdge()
    end
    if cooldown.SetCooldown then
      cooldown:SetCooldown(start, duration)
    elseif CooldownFrame_SetTimer then
      CooldownFrame_SetTimer(cooldown, start, duration, enable)
    end
  else
    if cooldown.Clear then
      cooldown:Clear()
    elseif CooldownFrame_SetTimer then
      CooldownFrame_SetTimer(cooldown, 0, 0, 0)
    elseif cooldown.SetCooldown then
      cooldown:SetCooldown(0, 0)
    end
    if cooldown.Hide then
      cooldown:Hide()
    end
  end
end

local QueueWidget
do
  local widgetsQueued = {}
  local RetryWidgets = CreateFrame("Frame")
  QueueWidget = function(callback)
    table.insert(widgetsQueued, callback)
    if RetryWidgets:GetScript("OnUpdate") == nil then
      RetryWidgets:SetScript("OnUpdate", function()
        addonTable.ReportEntry()
        local queue = widgetsQueued
        widgetsQueued = {}
        for _, queuedCallback in ipairs(queue) do
          queuedCallback()
        end
        if #widgetsQueued == 0 then
          RetryWidgets:SetScript("OnUpdate", nil)
        end
      end)
    end
  end
end

local registered = false
function addonTable.ItemButtonUtil.UpdateSettings()
  if not registered  then
    registered = true
    addonTable.CallbackRegistry:RegisterCallback("SettingChanged", function()
      addonTable.ItemButtonUtil.UpdateSettings()
    end)
    addonTable.CallbackRegistry:RegisterCallback("PluginsUpdated", function()
      addonTable.ItemButtonUtil.UpdateSettings()
      addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.ItemWidgets] = true})
    end)
  end
  itemCallbacks = {}
  iconSettings = {
    markJunk = addonTable.Config.Get("icon_grey_junk"),
    equipmentSetBorder = addonTable.Config.Get("icon_equipment_set_border"),
    contextFading = addonTable.Config.Get("icon_context_fading"),
  }

  local junkPluginID = addonTable.Config.Get("junk_plugin")
  local junkPlugin = addonTable.API.JunkPlugins[junkPluginID]
  if junkPlugin and junkPluginID ~= "poor_quality" then
    iconSettings.usingJunkPlugin = true
    table.insert(itemCallbacks, function(self)
      if self.JunkIcon then
        local _, junkStatus = pcall(junkPlugin.callback, self:GetParent():GetID(), self:GetID(), self.BGR.itemID, self.BGR.itemLink)
        self.BGR.isJunk = junkStatus == true
        if iconSettings.markJunk and self.BGR.isJunk then
          self.BGR.persistIconGrey = true
        end
        self.icon:SetDesaturated(self.BGR.persistIconGrey)
      end
    end)
  end

  local markUnusable = addonTable.Config.Get("icon_mark_unusable")
  if markUnusable then
    table.insert(itemCallbacks, function(self)
      if not self.BGR.tooltipInfo then
        self.BGR.tooltipInfo = self.BGR.tooltipGetter()
      end
      self.icon:SetVertexColor(1, 1, 1)
      self.BGR.markUnusable = false
      if not self.icon.hooked then
        self.icon.hooked = true
        local inHook = false
        hooksecurefunc(self.icon,"SetVertexColor", function()
          if not inHook and self.BGR.markUnusable then
            inHook = true
            self.icon:SetVertexColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
            inHook = false
          end
        end)
      end
      if self.BGR.tooltipInfo then
        for _, row in ipairs(self.BGR.tooltipInfo.lines) do
          if row.leftColor.r == 1 and row.leftColor.g < 0.2 and row.leftColor.b < 0.2 and row.leftText ~= ITEM_SCRAPABLE_NOT and row.leftText ~= CANNOT_UNEQUIP_COMBAT and row.leftText ~= ITEM_DISENCHANT_NOT_DISENCHANTABLE or
             row.rightColor and row.rightColor.r == 1 and row.rightColor.g < 0.2 and row.rightColor.b < 0.2 then
            self.BGR.markUnusable = true
            self.icon:SetVertexColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
          end
        end
      end
    end)
  else
    table.insert(itemCallbacks, function(self)
      self.BGR.markUnusable = false
      self.icon:SetVertexColor(1, 1, 1)
    end)
  end

  local upgradePluginID = addonTable.Config.Get("upgrade_plugin")
  local upgradePlugin = addonTable.API.UpgradePlugins[upgradePluginID]
  if upgradePlugin and upgradePluginID ~= "poor_quality" then
    iconSettings.usingUpgradePlugin = true
    table.insert(itemCallbacks, function(self)
      if self.BGR.itemLink then
        local _, upgradeStatus = pcall(upgradePlugin.callback, self.BGR.itemLink)
        self.BGR.isUpgrade = upgradeStatus == true
      end
    end)
  end

  local positions = {
    "icon_top_left_corner_array",
    "icon_top_right_corner_array",
    "icon_bottom_left_corner_array",
    "icon_bottom_right_corner_array",
  }

  for _, key in ipairs(positions) do
    local array = CopyTable(addonTable.Config.Get(key))
    local callbacks = {}
    local fastStatus = {}
    local plugins = {}
    for _, plugin in ipairs(array) do
      if addonTable.API.IconCornerPlugins[plugin] then
        table.insert(callbacks, addonTable.API.IconCornerPlugins[plugin].onUpdate)
        table.insert(fastStatus, addonTable.API.IconCornerPlugins[plugin].isFast)
        table.insert(plugins, plugin)
      end
    end
    if #callbacks > 0 then
      local function Callback(itemButton)
        local queued = false

        for index = 1, #callbacks do
          local cb = callbacks[index]
          local widget = itemButton.cornerPlugins[plugins[index]]
          if widget then
            local show
            if fastStatus[index] or not addonTable.CheckTimeout() then
              show = cb(widget, itemButton.BGR)
            end
            if show == nil then
              local BGR = itemButton.BGR
              if not queued then
                local function queueFunc()
                  -- Ensure the item button's state is still the same
                  -- IsShown ensures the item hasn't been returned to the pool
                  if itemButton.BGR == BGR and itemButton:IsShown() then
                    if addonTable.CheckTimeout() then
                      QueueWidget(queueFunc)
                      return
                    end
                    -- Hide any widgets shown immediately because the widget
                    -- wasn't available
                    for i = 1, #callbacks do
                      local cornerWidget = itemButton.cornerPlugins[plugins[i]]
                      if cornerWidget then
                        cornerWidget:Hide()
                      end
                    end
                    if itemButton.BGR.guid and (not C_Item.DoesItemExist(itemButton.BGR.itemLocation) or itemButton.BGR.guid ~= C_Item.GetItemGUID(itemButton.BGR.itemLocation)) then
                      itemButton.BGR.guid = nil
                      itemButton.BGR.itemLocation = nil
                    end
                    Callback(itemButton)
                  end
                end
                QueueWidget(queueFunc)
                queued = true
              end
            elseif show then
              widget:Show()
              break
            end
          end
        end
      end
      table.insert(itemCallbacks, Callback)
    end
  end
end

local function GetInfo(self, cacheData, earlyCallback, finalCallback)
  local info = Syndicator.Search.GetBaseInfo(cacheData)
  self.BGR = info

  self.BGR.earlyCallback = earlyCallback or function() end
  self.BGR.finalCallback = finalCallback or function() end

  self.BGR.bagType = cacheData.bagType

  self.BGR.earlyCallback()

  for _, widget in pairs(self.cornerPlugins) do
    widget:Hide()
  end

  if self.BaganatorBagHighlight then
    self.BaganatorBagHighlight:Hide()
  end

  if self.BGR.itemID == nil then
    return
  end

  if not iconSettings.usingJunkPlugin and self.JunkIcon then
    self.BGR.isJunk = not self.BGR.hasNoValue and self.BGR.quality == Enum.ItemQuality.Poor
    self.BGR.persistIconGrey = iconSettings.markJunk and self.BGR.isJunk
    self.icon:SetDesaturated(self.BGR.persistIconGrey)
  end

  local function OnCached()
    if self.BGR ~= info then -- Check that the item button hasn't been refreshed
      return
    end
    if C_Item.IsCosmeticItem and C_Item.IsCosmeticItem(self.BGR.itemLink) then
      self.IconOverlay:SetAtlas("CosmeticIconFrame")
      self.IconOverlay:Show();
    end
    for _, callback in ipairs(itemCallbacks) do -- Process any item widgets/effects
      callback(self)
    end
    self.BGR.finalCallback()
  end

  if C_Item.IsItemDataCachedByID(self.BGR.itemID) then
    OnCached()
  else
    addonTable.Utilities.LoadItemData(self.BGR.itemID, OnCached)
  end
end

-- Called to reset searched state, widgets, and tooltip data cache
function addonTable.ItemButtonUtil.ResetCache(self, cacheData)
  GetInfo(self, cacheData, self.BGR.earlyCallback, self.BGR.finalCallback)
end

local function SearchCheck(self, text)
  if text == "" then
    return true
  end

  if self.BGR == nil or self.BGR.itemLink == nil then
    return false
  end

  return Syndicator.Search.CheckItem(self.BGR, text)
end

local function EnsureWidgetContainer335(button)
  if not button.widgetContainer then
    button.widgetContainer = CreateFrame("Frame", nil, button)
    button.widgetContainer:SetAllPoints(button)
  end
  button.cornerPlugins = button.cornerPlugins or {}
  return button.widgetContainer
end

-- Used to fade widgets when the item doesn't match the current search/context
local function SetWidgetsAlpha(self, result)
  local widgetContainer = EnsureWidgetContainer335(self)
  if not result then
    widgetContainer:SetAlpha(0.4)
  else
    widgetContainer:SetAlpha(1)
  end
end

local function ApplyItemDetailSettings(button)
  local newSize = addonTable.Config.Get("icon_text_font_size")

  local positions = {
    ["icon_top_left_corner_array"] = {"TOPLEFT", 2, -2},
    ["icon_top_right_corner_array"] = {"TOPRIGHT", -2, -2},
    ["icon_bottom_left_corner_array"] = {"BOTTOMLEFT", 2, 2},
    ["icon_bottom_right_corner_array"] = {"BOTTOMRIGHT", -2, 2},
  }

  EnsureWidgetContainer335(button)

  for key, anchor in pairs(positions) do
    for _, plugin in ipairs(addonTable.Config.Get(key)) do
      local setup = addonTable.API.IconCornerPlugins[plugin]
      if setup and not button.cornerPlugins[plugin] then
        button.cornerPlugins[plugin] = setup.onInit(button)
        if button.cornerPlugins[plugin] then
          addonTable.Skins.AddFrame("CornerWidget", button.cornerPlugins[plugin], {plugin})
          button.cornerPlugins[plugin]:Hide()
        end
      end
      local corner = button.cornerPlugins[plugin]
      if corner then
        corner:SetParent(button.widgetContainer)
        local extraScale = 1
        if corner.sizeFont then
          extraScale = newSize / 14 -- 14 is default font size
          if corner.SetScale then
            corner:SetScale(extraScale)
          elseif corner.GetFont and corner.SetFont then
            local fontPath, fontSize, fontFlags = corner:GetFont()
            if fontPath then corner:SetFont(fontPath, newSize, fontFlags) end
          end
        end
        local padding = 1
        if corner.padding then
          padding = corner.padding
        end
        corner:ClearAllPoints()
        corner:SetPoint(anchor[1], button, anchor[2]*padding/extraScale, anchor[3]*padding/extraScale)
      end
    end
  end
end

local function AddRetailBackground(button)
  button.emptyBackgroundAtlas = nil
  button.SlotBackground = button:CreateTexture(nil, "BACKGROUND", nil, -1)
  button.SlotBackground:SetAllPoints(button.icon)
  button.SlotBackground:SetAtlas("bags-item-slot64")
end

local function AnchorClassicItemRegionToButton(region, button)
  if not region or not button then return end
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
  region:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
end

local function AddClassicBackground(button)
  if not button.SlotBackground then
    button.SlotBackground = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    button.SlotBackground:SetTexture("Interface\\AddOns\\Baganator\\Assets\\classic-bag-slot")
  end
  -- The item icon is hidden when a slot becomes empty. On stock 3.3.5a, a
  -- texture anchored to that hidden region can retain stale screen coordinates
  -- while the bag frame is dragged. Anchor persistent slot chrome directly to
  -- the button so empty slots always move with their parent.
  AnchorClassicItemRegionToButton(button.SlotBackground, button)
end

local function FlashItemButton(self)
  if not self.BaganatorFlashAnim then
    local flash = self:CreateTexture(nil, "OVERLAY", nil)
    AnchorClassicItemRegionToButton(flash, self)
    flash:SetAtlas("bags-glow-orange")
    flash:SetAlpha(0)
    self.BaganatorFlashAnim = self:CreateAnimationGroup()
    self.BaganatorFlashAnim:SetLooping("REPEAT")
    self.BaganatorFlashAnim:SetToFinalAlpha(false)
    local alpha1 = self.BaganatorFlashAnim:CreateAnimation("Alpha", nil, nil)
    alpha1:SetDuration(0.3)
    alpha1:SetOrder(1)
    alpha1:SetFromAlpha(1)
    alpha1:SetToAlpha(0)
    alpha1:SetSmoothing("IN_OUT")
    alpha1:SetTarget(flash)
    local alpha2 = self.BaganatorFlashAnim:CreateAnimation("Alpha", nil, nil)
    alpha2:SetDuration(0.3)
    alpha2:SetOrder(2)
    alpha2:SetFromAlpha(0)
    alpha2:SetToAlpha(1)
    alpha2:SetSmoothing("IN_OUT")
    alpha2:SetTarget(flash)
    self:HookScript("OnHide", function()
      self.BaganatorFlashAnim:Stop()
    end)
  end
  self.BaganatorFlashAnim:Play()
  C_Timer.NewTimer(2.1, function()
    self.BaganatorFlashAnim:Stop()
  end)
end

local function SetHighlightItemButton(self, isShown)
  if not self.BaganatorBagHighlight then
    local highlight = self:CreateTexture(nil, "OVERLAY", nil)
    AnchorClassicItemRegionToButton(highlight, self)
    if BAGANATOR_335 then
      highlight:SetTexture(1, 0.82, 0, 0.22)
      highlight:SetBlendMode("ADD")
    else
      highlight:SetAtlas("bags-glow-heirloom")
    end
    self.BaganatorBagHighlight = highlight
  end
  self.BaganatorBagHighlight:SetShown(isShown)
end

local function ReparentOverlays(self)
  if self.ProfessionQualityOverlay then
    self.ProfessionQualityOverlay:SetParent(self.widgetContainer)
  end
end

local function ApplyNewItemAnimation(self, quality)
  -- Retail/TBC Classic use atlas-based new-item glows. 3.3.5a cannot render
  -- those atlases correctly (they become the large white wedges seen across
  -- occupied slots), so keep new-item tracking but suppress the visual glow.
  if BAGANATOR_335 then
    if self.NewItemTexture then self.NewItemTexture:Hide() end
    if self.BattlepayItemTexture then self.BattlepayItemTexture:Hide() end
    if self.flashAnim and self.flashAnim.Stop then self.flashAnim:Stop() end
    if self.newitemglowAnim and self.newitemglowAnim.Stop then self.newitemglowAnim:Stop() end
    return
  end

  -- Modified code from Blizzard for classic
  local isNewItem = addonTable.NewItems:IsNewItem(self:GetParent():GetID(), self:GetID()) and addonTable.Config.Get(addonTable.Config.Options.NEW_ITEMS_FLASHING);

  local newItemTexture = self.NewItemTexture;
  local battlepayItemTexture = self.BattlepayItemTexture;
  local flash = self.flashAnim;
  local newItemAnim = self.newitemglowAnim;

  if ( isNewItem ) then
    if C_Container.IsBattlePayItem and C_Container.IsBattlePayItem(self:GetBagID(), self:GetID()) then
      self.NewItemTexture:Hide();
      self.BattlepayItemTexture:Show();
    else
      if (quality and NEW_ITEM_ATLAS_BY_QUALITY[quality]) then
        newItemTexture:SetAtlas(NEW_ITEM_ATLAS_BY_QUALITY[quality]);
      else
        newItemTexture:SetAtlas("bags-glow-white");
      end
      battlepayItemTexture:Hide();
      newItemTexture:Show();
      if (not flash:IsPlaying() and not newItemAnim:IsPlaying()) then
        flash:Play();
        newItemAnim:Play();
      end
    end
  else
    newItemTexture:Hide();
    if (flash:IsPlaying() or newItemAnim:IsPlaying()) then
      flash:Stop();
      newItemAnim:Stop();
    end
    battlepayItemTexture:Hide();
    newItemTexture:Hide();
  end
end

local function GetItemContextMatch(self)
  if self.BGR and self.BGR.itemID and self.BGR.itemLocation and C_Item.DoesItemExist(self.BGR.itemLocation) then
    local needsData = false

    local bankFrame = addonTable.ViewManagement.GetBankFrame()
    if addonTable.Constants.IsRetail and bankFrame and bankFrame.currentTab.isLive and bankFrame.Warband:IsVisible() then
      if not C_Item.IsItemDataCachedByID(self.BGR.itemID) then
        C_Item.RequestLoadItemDataByID(self.BGR.itemID)
        needsData = true
      else
        return C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, self.BGR.itemLocation)
      end
    elseif addonTable.Compatibility.Context.Auctioneer then
      local auctionable = addonTable.Utilities.IsAuctionable(self.BGR)
      if auctionable == nil then
        needsData = true
      else
        return auctionable
      end
    elseif addonTable.Constants.IsRetail and addonTable.Compatibility.Context.MailInfo and addonTable.Compatibility.Context.SendMail then
      if not C_Item.IsItemDataCachedByID(self.BGR.itemID) then
        C_Item.RequestLoadItemDataByID(self.BGR.itemID)
        needsData = true
      else
        return not self.BGR.isBound or C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, self.BGR.itemLocation)
      end
    elseif addonTable.Compatibility.Context.Merchant then
      return not self.BGR.hasNoValue or (C_Item.DoesItemExist(self.BGR.itemLocation) and C_Item.CanBeRefunded(self.BGR.itemLocation))
    elseif addonTable.Compatibility.Context.GuildBanker then
      if not C_Item.IsItemDataCachedByID(self.BGR.itemID) then
        C_Item.RequestLoadItemDataByID(self.BGR.itemID)
        needsData = true
      else
        return not self.BGR.isBound and (not addonTable.Constants.IsRetail or not C_Item.IsBoundToAccountUntilEquip(self.BGR.itemLocation))
      end
    elseif addonTable.Compatibility.Context.Socket then
      return (select(6, C_Item.GetItemInfoInstant(self.BGR.itemID)) == Enum.ItemClass.Gem)
    end

    if needsData then -- Missing item/spell data
      local BGR = self.BGR
      QueueWidget(function()
        if self.BGR ~= BGR then
          return
        end
        self:UpdateItemContextMatching()
      end)
      return false
    end
  end
  return true
end

BaganatorRetailCachedItemButtonMixin = {}

function BaganatorRetailCachedItemButtonMixin:OnLoad()
  AddRetailBackground(self)
end

function BaganatorRetailCachedItemButtonMixin:UpdateTextures()
  ApplyItemDetailSettings(self)
end

function BaganatorRetailCachedItemButtonMixin:SetItemDetails(details)
  self:SetItemButtonTexture(details.iconTexture)
  self:SetItemButtonQuality(details.quality, details.itemLink, false, details.isBound)
  SetItemButtonCount(self, details.itemCount, details.itemCount and details.itemCount > 9999) -- true results in abbreviating large numbers
  SetItemButtonDesaturated(self, false);
  ReparentOverlays(self)

  GetInfo(self, details, nil, function()
    self:SetItemButtonQuality(details.quality, details.itemLink, false, details.isBound)

    ReparentOverlays(self)
  end)
end

function BaganatorRetailCachedItemButtonMixin:BGRStartFlashing()
  FlashItemButton(self)
end

function BaganatorRetailCachedItemButtonMixin:BGRSetHighlight(isHighlighted)
  SetHighlightItemButton(self, isHighlighted)
end

function BaganatorRetailCachedItemButtonMixin:SetItemFiltered(text)
  local result = SearchCheck(self, text)
  if result == nil then
    return true
  end
  if self.BGR ~= nil then
    self.BGR.matchesSearch = result
  end
  self:SetMatchesSearch(result)
  SetWidgetsAlpha(self, result)
end

function BaganatorRetailCachedItemButtonMixin:OnClick()
  if IsModifiedClick("CHATLINK") then
    addonTable.Utilities.ChatInsertLink(self.BGR.itemLink)
  elseif IsModifiedClick("DRESSUP") then
    DressUpLink(self.BGR.itemLink)
  elseif IsAltKeyDown() then
    addonTable.CallbackRegistry:TriggerEvent("HighlightSimilarItems", self.BGR.itemLink)
  end
end

function BaganatorRetailCachedItemButtonMixin:OnEnter()
  self:UpdateTooltip()
end

function BaganatorRetailCachedItemButtonMixin:UpdateTooltip()
  local itemLink = self.BGR.itemLink

  if itemLink == nil then
    return
  end

  if IsModifiedClick("DRESSUP") then
    ShowInspectCursor();
  else
    ResetCursor()
  end

  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

  if itemLink:match("battlepet:") then
    BattlePetToolTip_ShowLink(itemLink)
  else
    GameTooltip:SetHyperlink(itemLink)
    GameTooltip:Show()
  end
end

function BaganatorRetailCachedItemButtonMixin:OnLeave()
  ResetCursor()
  BattlePetTooltip:Hide()
  GameTooltip:Hide()
end

BaganatorRetailLiveContainerItemButtonMixin = {}

function BaganatorRetailLiveContainerItemButtonMixin:MyOnLoad()
  AddRetailBackground(self)
  self:HookScript("OnClick", function(_, mouseButton)
    if not self.BGR or not self.BGR.itemID then
      return
    end

    if IsAltKeyDown() then
      addonTable.CallbackRegistry:TriggerEvent("HighlightSimilarItems", self.BGR.itemLink)
    end
  end)
  self:HookScript("PreClick", self.PreClickHook)

  self:HookScript("OnShow", self.OnShowHook)
  self:HookScript("OnHide", self.OnHideHook)

  self.GetItemContextMatchResult = function()
    local result = (
      not iconSettings.contextFading or

      ItemButtonUtil.GetItemContextMatchResultForItem({bagID = self:GetBagID(), slotIndex = self:GetID()})
        ~= ItemButtonUtil.ItemContextMatchResult.Mismatch and
      GetItemContextMatch(self)
    )
    if self.BGR then
      self.BGR.contextMatch = result
    end
    return result and ItemButtonUtil.ItemContextMatchResult.Match or ItemButtonUtil.ItemContextMatchResult.Mismatch
  end
  hooksecurefunc(self, "UpdateItemContextOverlay", self.PostUpdateItemContextOverlay)

  self:HookScript("OnEnter", function()
    local bagID, slotID = self:GetParent():GetID(), self:GetID()
    addonTable.NewItems:ClearNewItem(bagID, slotID)
  end)
end

function BaganatorRetailLiveContainerItemButtonMixin:PreClickHook(mouseButton)
  if mouseButton == "RightButton" and not IsModifiedClick() and addonTable.ViewManagement.GetBankFrame():IsShown() and tIndexOf(Syndicator.Constants.AllBagIndexes, self:GetParent():GetID()) ~= nil and
      self.BGR.itemLocation and C_Item.DoesItemExist(self.BGR.itemLocation) and C_Bank.IsItemAllowedInBankType(addonTable.ViewManagement.GetBankFrame():GetBankType(), self.BGR.itemLocation) then
    addonTable.BankTransferManager:Queue(self:GetParent():GetID(), self:GetID())
  elseif self.BGR and self.BGR.itemID and not IsModifierKeyDown() then
    if (SpellCanTargetItem and SpellCanTargetItem()) or (SpellCanTargetItemID and SpellCanTargetItemID()) then
      addonTable.CallbackRegistry:TriggerEvent("ItemSpellTargeted", self.BGR.itemID)
    elseif C_Item.GetItemSpell(self.BGR.itemID) and mouseButton == "RightButton" then
      addonTable.CallbackRegistry:TriggerEvent("ItemSpellUsed", self.BGR.itemID)
    end
  end
end

function BaganatorRetailLiveContainerItemButtonMixin:OnShowHook()
  addonTable.CallbackRegistry:RegisterCallback("ItemContextChanged", self.OnItemContextChanged, self)
end

function BaganatorRetailLiveContainerItemButtonMixin:OnHideHook()
  addonTable.CallbackRegistry:UnregisterCallback("ItemContextChanged", self)
end

function BaganatorRetailLiveContainerItemButtonMixin:PostUpdateItemContextOverlay()
  if self.widgetContainer then
    SetWidgetsAlpha(self, not self.ItemContextOverlay:IsShown() and (self.BGR == nil or self.BGR.matchesSearch ~= false))
  end
end

function BaganatorRetailLiveContainerItemButtonMixin:UpdateTextures()
  ApplyItemDetailSettings(self)
end

function BaganatorRetailLiveContainerItemButtonMixin:SetItemDetails(cacheData)
  -- Copied code from Blizzard Container Frame logic
  local info = C_Container.GetContainerItemInfo(self:GetBagID(), self:GetID())

  -- Keep cache and display in sync
  if info and not cacheData.itemLink then
    info = nil
  end

  local texture = ResolveClassicItemTexture(cacheData.itemID or (info and info.itemID), cacheData.itemLink, cacheData.iconTexture or (info and info.iconFileID));
  local itemCount = cacheData.itemCount;
  local locked = info and info.isLocked;
  local quality = cacheData.quality or (info and info.quality);
  local readable = info and info.isReadable;
  local itemLink = info and info.hyperlink;
  local noValue = info and info.hasNoValue;
  --local itemID = info and info.itemID;
  local isBound = info and info.isBound;

  ClearItemButtonOverlay(self);

  self:SetHasItem(texture);
  self:SetItemButtonTexture(texture);

  self:SetItemButtonQuality(quality, nil, true, isBound);

  SetItemButtonCount(self, itemCount, itemCount and itemCount > 9999); -- true results in abbreviating large numbers
  SetItemButtonDesaturated(self, locked);

  self:UpdateExtended();
  self:UpdateJunkItem(quality, noValue);
  self:SetReadable(readable);
  self:SetMatchesSearch(true)
  self.Cooldown:Hide()

  if GameTooltip:IsOwned(self) then
    GameTooltip:Hide()
    BattlePetTooltip:Hide()
  end

  if self:IsMouseOver() then
    self:OnEnter()
  end

  SetWidgetsAlpha(self, true)
  ReparentOverlays(self)

  GetInfo(self, cacheData, function()
    self.BGR.tooltipGetter = function() return C_TooltipInfo.GetBagItem(self:GetBagID(), self:GetID()) end
    local itemLocation = {bagID = bagID, slotIndex = slotID}
    if C_Item.DoesItemExist(itemLocation) then
      self.BGR.guid = C_Item.GetItemGUID(itemLocation)
      self.BGR.setInfo = addonTable.ItemViewCommon.GetEquipmentSetInfo(itemLocation, self.BGR.guid, self.BGR.itemLink)
      self.BGR.itemLocation = itemLocation
    end

    self.BGR.hasNoValue = noValue

    self:BGRUpdateQuests()
    ApplyNewItemAnimation(self, quality);
  end, function()
    self.BGR.hasSpell = C_Item.GetItemSpell(self.BGR.itemID) ~= nil
    self:BGRUpdateCooldown()
    self:UpdateItemContextMatching();
    local doNotSuppressOverlays = false
    self:SetItemButtonQuality(quality, itemLink, doNotSuppressOverlays, isBound);
    ReparentOverlays(self)
    self:BGRUpdateQuests()
  end)

  if not self.BGR.itemID then
    self:UpdateItemContextMatching();
  end
end

function BaganatorRetailLiveContainerItemButtonMixin:BGRStartFlashing()
  FlashItemButton(self)
end

function BaganatorRetailLiveContainerItemButtonMixin:BGRSetHighlight(isHighlighted)
  SetHighlightItemButton(self, isHighlighted)
end

function BaganatorRetailLiveContainerItemButtonMixin:BGRUpdateCooldown()
  if self.BGR.hasSpell then
    local bagID, slotID = GetClassicContainerButtonCoordinates(self)
    local start, duration, enable = C_Container.GetContainerItemCooldown(bagID, slotID)
    SetCooldownCompat(self.Cooldown, start, duration, enable)
    if ( duration > 0 and enable == 0 ) then
      self.icon:SetVertexColor(0.4, 0.4, 0.4);
    else
      self.icon:SetVertexColor(1, 1, 1);
    end
  else
    self.Cooldown:Hide();
  end
end

function BaganatorRetailLiveContainerItemButtonMixin:BGRUpdateQuests()
  local questInfo = C_Container.GetContainerItemQuestInfo(self:GetBagID(), self:GetID()) or {}
  self.BGR.isQuestItem = self.BGR.itemID and (questInfo.isQuestItem or questInfo.questID)
  self:UpdateQuestItem(questInfo.isQuestItem, questInfo.questID, questInfo.isActive);
end

function BaganatorRetailLiveContainerItemButtonMixin:SetItemFiltered(text)
  local result = SearchCheck(self, text)
  if result == nil then
    return true
  end
  if self.BGR ~= nil then
    self.BGR.matchesSearch = result
  end
  self:SetMatchesSearch(result)
  SetWidgetsAlpha(self, result and not self.ItemContextOverlay:IsShown())
end

function BaganatorRetailLiveContainerItemButtonMixin:ClearNewItem()
  local bagID, slotID = GetClassicContainerButtonCoordinates(self)
  addonTable.NewItems:ClearNewItem(bagID, slotID)
  -- Copied code from Blizzard Container Frame
  self.BattlepayItemTexture:Hide();
  self.NewItemTexture:Hide();
  if (self.flashAnim:IsPlaying() or self.newitemglowAnim:IsPlaying()) then
    self.flashAnim:Stop();
    self.newitemglowAnim:Stop();
  end
end

BaganatorRetailLiveGuildItemButtonMixin = {}

function BaganatorRetailLiveGuildItemButtonMixin:OnLoad()
  AddRetailBackground(self)
  self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  self:RegisterForDrag("LeftButton")
  self.SplitStack = function(button, split)
    SplitGuildBankItem(self.tabIndex, button:GetID(), split)
  end
  self.UpdateTooltip = self.OnEnter
end

function BaganatorRetailLiveGuildItemButtonMixin:OnDragStart()
  if self.tabIndex ~= nil and self.tabIndex ~= GetCurrentGuildBankTab() then
    SetCurrentGuildBankTab(self.tabIndex)
  end
  PickupGuildBankItem(self.tabIndex, self:GetID())
end

function BaganatorRetailLiveGuildItemButtonMixin:OnReceiveDrag()
  if self.tabIndex ~= nil and self.tabIndex ~= GetCurrentGuildBankTab() then
    SetCurrentGuildBankTab(self.tabIndex)
  end
  PickupGuildBankItem(self.tabIndex, self:GetID())
end

function BaganatorRetailLiveGuildItemButtonMixin:OnClick(button)
  if self.BGR and self.BGR.itemLink and IsAltKeyDown() then
    addonTable.CallbackRegistry:TriggerEvent("HighlightSimilarItems", self.BGR.itemLink)
    ClearCursor()
    return
  end

  if self.BGR and self.BGR.itemLink and HandleModifiedItemClick(self.BGR.itemLink) then
    return
  end

  if self.tabIndex ~= nil and self.tabIndex ~= GetCurrentGuildBankTab() then
    SetCurrentGuildBankTab(self.tabIndex)
  end

  if ( IsModifiedClick("SPLITSTACK") ) then
    if ( not CursorHasItem() ) then
      local _, count, locked = GetGuildBankItemInfo(self.tabIndex, self:GetID())
      if ( not locked and count and count > 1) then
        StackSplitFrame:OpenStackSplitFrame(count, self, "BOTTOMLEFT", "TOPLEFT")
      end
    end
    return
  end

  local type, money = GetCursorInfo()
  if ( type == "money" ) then
    DepositGuildBankMoney(money)
    ClearCursor()
  elseif ( type == "guildbankmoney" ) then
    DropCursorMoney()
    ClearCursor()
  else
    if ( button == "RightButton" ) then
      AutoStoreGuildBankItem(self.tabIndex, self:GetID())
      self:OnLeave()
    else
      PickupGuildBankItem(self.tabIndex, self:GetID())
    end
  end
end

function BaganatorRetailLiveGuildItemButtonMixin:OnEnter()
  if self.BGR and self.BGR.itemLink and IsModifiedClick("DRESSUP") then
    ShowInspectCursor();
  else
    ResetCursor()
  end
  if self.tabIndex ~= nil then
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetGuildBankItem(self.tabIndex, self:GetID())
  end
end

function BaganatorRetailLiveGuildItemButtonMixin:OnLeave()
  self.updateTooltipTimer = nil
  GameTooltip_Hide()
  ResetCursor()
end

function BaganatorRetailLiveGuildItemButtonMixin:OnHide()
  if ( self.hasStackSplit and (self.hasStackSplit == 1) ) then
    StackSplitFrame:Hide()
  end
end

function BaganatorRetailLiveGuildItemButtonMixin:UpdateTextures()
  ApplyItemDetailSettings(self)
end

function BaganatorRetailLiveGuildItemButtonMixin:SetItemDetails(cacheData, tabIndex)
  self.tabIndex = tabIndex

  local texture, itemCount, locked, _, quality = GetGuildBankItemInfo(tabIndex, self:GetID());
  if cacheData.itemLink == nil then
    texture, itemCount, locked, _, quality = nil, nil, nil, nil, nil
  end
  texture = ResolveClassicItemTexture(cacheData.itemID, cacheData.itemLink, cacheData.iconTexture or texture)
  itemCount = cacheData.itemCount
  quality = cacheData.quality or quality

  SetItemButtonTexture(self, texture);
  SetItemButtonCount(self, itemCount);
  SetItemButtonDesaturated(self, locked);

  self:SetMatchesSearch(true);

  SetItemButtonQuality(self, quality, cacheData.itemLink or GetGuildBankItemLink(tabIndex, self:GetID()));
  ReparentOverlays(self)

  if GameTooltip:IsOwned(self) then
    GameTooltip:Hide()
  end
  if self:IsMouseOver() then
    self:OnEnter()
  end

  GetInfo(self, cacheData, function()
    self.BGR.tooltipGetter = function() return C_TooltipInfo.GetGuildBankItem(tabIndex, self:GetID()) end
  end, function()
    SetItemButtonQuality(self, quality, self.BGR.itemLink or GetGuildBankItemLink(tabIndex, self:GetID()));
    ReparentOverlays(self)
  end)
end

function BaganatorRetailLiveGuildItemButtonMixin:BGRStartFlashing()
  FlashItemButton(self)
end

function BaganatorRetailLiveGuildItemButtonMixin:BGRSetHighlight(isHighlighted)
  SetHighlightItemButton(self, isHighlighted)
end

function BaganatorRetailLiveGuildItemButtonMixin:ClearNewItem()
end

function BaganatorRetailLiveGuildItemButtonMixin:SetItemFiltered(text)
  local result = SearchCheck(self, text)
  if result == nil then
    return true
  end
  if self.BGR ~= nil then
    self.BGR.matchesSearch = result
  end
  self:SetMatchesSearch(result);
  SetWidgetsAlpha(self, result)
end

local function EnsureClassicIconBorder(self)
  if not self.IconBorder then
    local name = self.GetName and self:GetName()
    if name then
      self.IconBorder = _G[name .. "IconBorder"] or _G[name .. "IconBorderTexture"]
    end
  end

  if not self.IconBorder then
    self.IconBorder = self:CreateTexture(nil, "OVERLAY")
  end

  -- Do not use UI-ActionButton-Border here. On the 3.3.5a client that
  -- texture is a large action-button glow and produces the white diagonal
  -- wedges seen across occupied bag slots. Baganator already ships a simple
  -- square alpha mask which can be vertex-coloured exactly like TBC Classic.
  self.IconBorder:SetTexture("Interface\\AddOns\\Baganator\\Assets\\Skins\\dark-icon-border")
  self.IconBorder:SetBlendMode("BLEND")
  AnchorClassicItemRegionToButton(self.IconBorder, self)
  self.IconBorder:Hide()
  return self.IconBorder
end

local function ApplyQualityBorderClassic(self, quality)
  local border = EnsureClassicIconBorder(self)
  local color
  local uncommonQuality = LE_ITEM_QUALITY_UNCOMMON or (Enum.ItemQuality and Enum.ItemQuality.Uncommon) or 2
  local colors = BAG_ITEM_QUALITY_COLORS or ITEM_QUALITY_COLORS or {}

  if type(quality) == "number" and quality >= uncommonQuality and colors[quality] then
    color = colors[quality]
  end

  if color then
    border:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, 1)
    border:Show()
  else
    border:SetVertexColor(1, 1, 1, 1)
    border:Hide()
  end
end

local function ResetClassicItemButtonChrome(self)
  -- Do not rely on the visual layers inherited from the original Wrath
  -- ItemButton/ContainerFrameItemButton templates. Their Border/normal layers
  -- have different semantics from modern Classic and were rendering as the
  -- white diagonal wedges across Baganator item icons.
  local function clearTexture(getter, setter)
    if self[getter] then
      local texture = self[getter](self)
      if texture and texture.Hide then texture:Hide() end
    end
    if self[setter] then self[setter](self, nil) end
  end
  clearTexture("GetNormalTexture", "SetNormalTexture")
  clearTexture("GetPushedTexture", "SetPushedTexture")
  clearTexture("GetHighlightTexture", "SetHighlightTexture")
  clearTexture("GetDisabledTexture", "SetDisabledTexture")

  -- The legacy template may expose a generic Border texture. It is not the
  -- modern quality border, so never allow it to cover the item icon.
  if self.SetText then self:SetText("") end
  if self.Border and self.Border.Hide then self.Border:Hide() end
  local name = self.GetName and self:GetName()
  if name then
    local legacyBorder = _G[name .. "Border"]
    if legacyBorder and legacyBorder.Hide then legacyBorder:Hide() end
  end
end

local function ResolveClassicItemTexture(itemID, itemLink, fallback)
  if BAGANATOR_335 and GetItemIcon then
    local icon = itemID and GetItemIcon(itemID)
    if not icon and itemLink then icon = GetItemIcon(itemLink) end
    if icon then return icon end
  end
  return fallback
end

local function EnsureClassicCachedItemButtonRegions(self)
  local name = self.GetName and self:GetName()
  if not self.icon then
    self.icon = self.IconTexture or (name and (_G[name .. "IconTexture"] or _G[name .. "Icon"]))
  end
  if not self.icon then
    self.icon = self:CreateTexture(nil, "ARTWORK")
  end
  self.IconTexture = self.IconTexture or self.icon
  self.icon:ClearAllPoints()
  self.icon:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -1)
  self.icon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -1, 1)

  -- Keep the real stack count in the classic position. Some 3.3.5a template
  -- combinations expose the count region without the modern anchor chain.
  local countRegion = self.Count or self.CountText or (name and (_G[name .. "Count"] or _G[name .. "CountText"]))
  if countRegion then
    self.Count = self.Count or countRegion
    if countRegion.ClearAllPoints then countRegion:ClearAllPoints() end
    if countRegion.SetPoint then countRegion:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, 2) end
    if countRegion.SetJustifyH then countRegion:SetJustifyH("RIGHT") end
  end
  if self.icon.SetTexCoord then self.icon:SetTexCoord(0, 1, 0, 1) end
  if self.icon.SetBlendMode then self.icon:SetBlendMode("BLEND") end
  ResetClassicItemButtonChrome(self)
  if not self.searchOverlay then
    self.searchOverlay = self:CreateTexture(nil, "OVERLAY")
    self.searchOverlay:SetTexture(0, 0, 0, 0.55)
    self.searchOverlay:Hide()
  end
  AnchorClassicItemRegionToButton(self.searchOverlay, self)
end

BaganatorClassicCachedItemButtonMixin = {}

function BaganatorClassicCachedItemButtonMixin:OnLoad()
  EnsureClassicCachedItemButtonRegions(self)
  AddClassicBackground(self)
end

function BaganatorClassicCachedItemButtonMixin:UpdateTextures()
  ApplyItemDetailSettings(self)
end

function BaganatorClassicCachedItemButtonMixin:SetItemDetails(details)
  GetInfo(self, details)

  local texture = ResolveClassicItemTexture(details.itemID, details.itemLink, details.iconTexture)
  SetItemButtonTexture(self, texture);
  SetItemButtonQuality(self, details.quality); -- Doesn't do much
  ApplyQualityBorderClassic(self, details.quality)
  SetItemButtonCount(self, details.itemCount, details.itemCount and details.itemCount > 9999);
  SetItemButtonDesaturated(self, false)
end

function BaganatorClassicCachedItemButtonMixin:BGRStartFlashing()
  FlashItemButton(self)
end

function BaganatorClassicCachedItemButtonMixin:BGRSetHighlight(isHighlighted)
  SetHighlightItemButton(self, isHighlighted)
end

function BaganatorClassicCachedItemButtonMixin:SetItemFiltered(text)
  EnsureClassicCachedItemButtonRegions(self)
  local result = SearchCheck(self, text)
  if result == nil then
    return true
  end
  if self.BGR ~= nil then
    self.BGR.matchesSearch = result
  end
  if self.searchOverlay then self.searchOverlay:SetShown(not result) end
  SetWidgetsAlpha(self, result)
end

function BaganatorClassicCachedItemButtonMixin:OnClick()
  if IsModifiedClick("CHATLINK") then
    addonTable.Utilities.ChatInsertLink(self.BGR.itemLink)
  elseif IsModifiedClick("DRESSUP") then
   return DressUpItemLink(self.BGR.itemLink) or DressUpBattlePetLink(self.BGR.itemLink) or DressUpMountLink(self.BGR.itemLink)
  elseif IsAltKeyDown() then
    addonTable.CallbackRegistry:TriggerEvent("HighlightSimilarItems", self.BGR.itemLink)
  end
end

function BaganatorClassicCachedItemButtonMixin:OnEnter()
  self:UpdateTooltip()
end

function BaganatorClassicCachedItemButtonMixin:UpdateTooltip()
  local itemLink = self.BGR.itemLink

  if itemLink == nil then
    return
  end

  if IsModifiedClick("DRESSUP") then
    ShowInspectCursor();
  else
    ResetCursor()
  end

  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetHyperlink(itemLink)
  GameTooltip:Show()
end

function BaganatorClassicCachedItemButtonMixin:OnLeave()
  ResetCursor()
  GameTooltip:Hide()
end

BaganatorClassicLiveContainerItemButtonMixin = {}

local function BGR335DummyAnimation()
  return {
    Play = function(self) self.playing = true end,
    Stop = function(self) self.playing = false end,
    IsPlaying = function(self) return self.playing == true end,
  }
end

local function EnsureClassicLiveItemButtonRegions(self)
  EnsureClassicCachedItemButtonRegions(self)

  if not self.NewItemTexture then
    self.NewItemTexture = self:CreateTexture(nil, "OVERLAY")
    AnchorClassicItemRegionToButton(self.NewItemTexture, self)
    self.NewItemTexture:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    self.NewItemTexture:SetBlendMode("ADD")
    self.NewItemTexture:Hide()
  end
  if not self.BattlepayItemTexture then
    self.BattlepayItemTexture = self:CreateTexture(nil, "OVERLAY")
    AnchorClassicItemRegionToButton(self.BattlepayItemTexture, self)
    self.BattlepayItemTexture:Hide()
  end
  self.flashAnim = self.flashAnim or BGR335DummyAnimation()
  self.newitemglowAnim = self.newitemglowAnim or BGR335DummyAnimation()

  local name = self.GetName and self:GetName()
  if name then
    local cooldownName = name .. "Cooldown"
    if not _G[cooldownName] then
      local cooldown = CreateFrame("Cooldown", cooldownName, self, "CooldownFrameTemplate")
      AnchorClassicItemRegionToButton(cooldown, self)
      cooldown:Hide()
    end

    local questName = name .. "IconQuestTexture"
    if not _G[questName] then
      local questTexture = self:CreateTexture(questName, "OVERLAY")
      AnchorClassicItemRegionToButton(questTexture, self)
      questTexture:Hide()
    end
  end
end

local function SanitizeClassicLiveItemButtonRegions(self)
  if not BAGANATOR_335 or not self.GetRegions then return end

  -- ContainerFrameItemButtonTemplate in 3.3.5a brings several visual layers
  -- whose purpose/texture coordinates differ from modern Classic. Keep only
  -- the icon and Baganator-owned layers; hide every other inherited texture.
  local keep = {}
  local function Keep(region)
    if region then keep[region] = true end
  end
  Keep(self.icon)
  Keep(self.IconTexture)
  Keep(self.SlotBackground)
  Keep(self.IconBorder)
  Keep(self.searchOverlay)
  Keep(self.ItemContextOverlay)
  Keep(self.BaganatorBagHighlight)
  Keep(self.bagTypeIcon)

  for _, region in ipairs({self:GetRegions()}) do
    if region and region.GetObjectType then
      local objectType = region:GetObjectType()
      if objectType == "Texture" and not keep[region] then
        if region.Hide then region:Hide() end
      elseif objectType == "FontString" then
        -- Wrath item-button templates can expose extra/stale text regions.
        -- Preserve only the actual stack-count text used by Baganator.
        local countRegion = self.Count or self.CountText
        local name = self.GetName and self:GetName()
        if not countRegion and name then countRegion = _G[name .. "Count"] end
        if region ~= countRegion and region.Hide then region:Hide() end
      end
    end
  end

  if self.NewItemTexture then self.NewItemTexture:Hide() end
  if self.BattlepayItemTexture then self.BattlepayItemTexture:Hide() end
end

local function SetClassicLiveItemTexture(self, itemID, itemLink, fallback)
  EnsureClassicLiveItemButtonRegions(self)
  local texture = ResolveClassicItemTexture(itemID, itemLink, fallback)
  if BAGANATOR_335 and self.icon then
    -- Set the actual texture region directly. The stock Wrath helper also
    -- touches legacy ItemButton layers and was producing corrupted visuals in
    -- the backpack path on some 3.3.5a clients.
    self.icon:SetTexture(texture)
    self.icon:SetTexCoord(0, 1, 0, 1)
    self.icon:SetVertexColor(1, 1, 1, 1)
    self.icon:SetAlpha(1)
    self.icon:SetShown(texture ~= nil)
  else
    SetItemButtonTexture(self, texture)
  end
  return texture
end

-- Alter the item button so that the tooltip works both on bag items and bank
-- items
function BaganatorClassicLiveContainerItemButtonMixin:MyOnLoad()
  EnsureClassicLiveItemButtonRegions(self)
  ResetClassicItemButtonChrome(self)
  AddClassicBackground(self)
  self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  self:RegisterForDrag("LeftButton")
  self.SplitStack = function(button, split)
    local bagID = button.__bgr335BagID
    local slotID = button.__bgr335SlotID
    if bagID == nil then local parent = button:GetParent(); bagID = parent and parent:GetID() end
    if slotID == nil then slotID = button:GetID() end
    if bagID ~= nil and slotID ~= nil and SplitContainerItem then
      SplitContainerItem(bagID, slotID, split)
    end
  end
  self:HookScript("OnClick", function()
    if not self.BGR or not self.BGR.itemID then
      return
    end

    if IsAltKeyDown() then
      addonTable.CallbackRegistry:TriggerEvent("HighlightSimilarItems", self.BGR.itemLink)
    end
  end)

  self:HookScript("PreClick", self.PreClickHook)

  self:SetScript("OnEnter", self.OnEnter)
  self:SetScript("OnLeave", self.OnLeave)

  self.UpdateTooltip = self.OnEnter

  self:HookScript("OnShow", self.OnShowHook)
  self:HookScript("OnHide", self.OnHideHook)

  self.ItemContextOverlay = self:CreateTexture(nil, "OVERLAY")
  if self.ItemContextOverlay.SetColorTexture then
    self.ItemContextOverlay:SetColorTexture(0, 0, 0, 0.8)
  else
    self.ItemContextOverlay:SetTexture(0, 0, 0, 0.8)
  end
  self.ItemContextOverlay:SetAllPoints()
  self.ItemContextOverlay:Hide()
  SanitizeClassicLiveItemButtonRegions(self)
end

local function GetClassicContainerButtonCoordinates(self)
  local parent = self:GetParent()
  local bagID = self.__bgr335BagID
  local slotID = self.__bgr335SlotID
  if bagID == nil then bagID = parent and parent:GetID() end
  if slotID == nil then slotID = self:GetID() end
  return bagID, slotID
end

function BaganatorClassicLiveContainerItemButtonMixin:OnClick(mouseButton)
  local bagID, slotID = GetClassicContainerButtonCoordinates(self)
  if bagID == nil or slotID == nil then return end

  local itemLink = self.BGR and self.BGR.itemLink
  if itemLink and HandleModifiedItemClick and HandleModifiedItemClick(itemLink) then
    return
  end

  if IsModifiedClick and IsModifiedClick("SPLITSTACK") and not CursorHasItem() then
    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    local count = (info and info.stackCount) or (self.BGR and self.BGR.itemCount) or self.count
    local locked = info and info.isLocked
    if not locked and count and count > 1 and OpenStackSplitFrame then
      OpenStackSplitFrame(count, self, "BOTTOMLEFT", "TOPLEFT")
    end
    return
  end

  if mouseButton == "RightButton" and UseContainerItem then
    UseContainerItem(bagID, slotID)
  elseif PickupContainerItem then
    PickupContainerItem(bagID, slotID)
  end
end

function BaganatorClassicLiveContainerItemButtonMixin:OnDragStart()
  local bagID, slotID = GetClassicContainerButtonCoordinates(self)
  if bagID ~= nil and slotID ~= nil and PickupContainerItem then
    PickupContainerItem(bagID, slotID)
  end
end

function BaganatorClassicLiveContainerItemButtonMixin:OnReceiveDrag()
  local bagID, slotID = GetClassicContainerButtonCoordinates(self)
  if bagID ~= nil and slotID ~= nil and PickupContainerItem then
    PickupContainerItem(bagID, slotID)
  end
end

function BaganatorClassicLiveContainerItemButtonMixin:PreClickHook(mouseButton)
  local bagID = GetClassicContainerButtonCoordinates(self)
  if mouseButton == "RightButton" and not IsModifiedClick() and BankFrame:IsShown() and tIndexOf(Syndicator.Constants.AllBagIndexes, bagID) ~= nil then
    return
  elseif self.BGR and self.BGR.itemID and not IsModifierKeyDown() then
    if (SpellCanTargetItem and SpellCanTargetItem()) or (SpellCanTargetItemID and SpellCanTargetItemID()) then
      addonTable.CallbackRegistry:TriggerEvent("ItemSpellTargeted", self.BGR.itemID)
    elseif C_Item.GetItemSpell(self.BGR.itemID) and mouseButton == "RightButton" then
      addonTable.CallbackRegistry:TriggerEvent("ItemSpellUsed", self.BGR.itemID)
    end
  end
end

function BaganatorClassicLiveContainerItemButtonMixin:OnShowHook()
  addonTable.CallbackRegistry:RegisterCallback("ItemContextChanged", self.UpdateItemContextMatching, self)
  self:UpdateItemContextMatching()
end

function BaganatorClassicLiveContainerItemButtonMixin:OnHideHook()
  addonTable.CallbackRegistry:UnregisterCallback("ItemContextChanged", self)
end

function BaganatorClassicLiveContainerItemButtonMixin:UpdateItemContextMatching()
  EnsureClassicLiveItemButtonRegions(self)
  local result = not iconSettings.contextFading or GetItemContextMatch(self)
  if self.BGR then
    self.BGR.contextMatch = result
  end
  self.ItemContextOverlay:SetShown(not result)
  SetWidgetsAlpha(self, not self.ItemContextOverlay:IsShown() and (not self.searchOverlay or not self.searchOverlay:IsShown()))
end

function BaganatorClassicLiveContainerItemButtonMixin:GetInventorySlot()
  return BankButtonIDToInvSlotID(self:GetID())
end

function BaganatorClassicLiveContainerItemButtonMixin:OnEnter()
  self:ClearNewItem()
  local bagID, slotID = GetClassicContainerButtonCoordinates(self)

  if bagID == -1 then
    if BankFrameItemButton_OnEnter then
      BankFrameItemButton_OnEnter(self)
    else
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetInventoryItem("player", self:GetInventorySlot())
    end
  else
    if ContainerFrameItemButton_OnEnter then
      ContainerFrameItemButton_OnEnter(self)
    else
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetBagItem(bagID, slotID)
    end
  end
end

function BaganatorClassicLiveContainerItemButtonMixin:BGRUpdateCooldown()
  EnsureClassicLiveItemButtonRegions(self)
  local Cooldown = _G[self:GetName() .. "Cooldown"]
  if not Cooldown then return end
  if self.BGR.hasSpell then
    local bagID, slotID = GetClassicContainerButtonCoordinates(self)
    local start, duration, enable = C_Container.GetContainerItemCooldown(bagID, slotID)
    SetCooldownCompat(Cooldown, start, duration, enable)
    if ( duration > 0 and enable == 0 ) then
      self.icon:SetVertexColor(0.4, 0.4, 0.4);
    else
      self.icon:SetVertexColor(1, 1, 1);
    end
  else
    Cooldown:Hide();
  end
end


function BaganatorClassicLiveContainerItemButtonMixin:BGRUpdateQuests()
  local bagID, slotID = GetClassicContainerButtonCoordinates(self)
  local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slotID) or {}
  self.BGR.isQuestItem = self.BGR.itemID and (questInfo.isQuestItem or questInfo.questID)

  EnsureClassicLiveItemButtonRegions(self)
  local questTexture = _G[self:GetName().."IconQuestTexture"];
  if not questTexture then return end

  if ( questInfo.questID and not questInfo.isActive ) then
    questTexture:SetTexture(TEXTURE_ITEM_QUEST_BANG);
    questTexture:Show();
  elseif ( questInfo.questID or questInfo.isQuestItem ) then
    questTexture:SetTexture(TEXTURE_ITEM_QUEST_BORDER);
    questTexture:Show();
  else
    questTexture:Hide();
  end
end

function BaganatorClassicLiveContainerItemButtonMixin:OnLeave()
  local bagID = GetClassicContainerButtonCoordinates(self)
  if bagID == -1 then
    GameTooltip_Hide()
    ResetCursor()
  else
    if ContainerFrameItemButton_OnLeave then
      ContainerFrameItemButton_OnLeave(self)
    else
      GameTooltip_Hide()
      ResetCursor()
    end
  end
end
-- end alterations

function BaganatorClassicLiveContainerItemButtonMixin:UpdateTextures()
  ApplyItemDetailSettings(self)
end

function BaganatorClassicLiveContainerItemButtonMixin:SetItemDetails(cacheData)
  EnsureClassicLiveItemButtonRegions(self)
  if BAGANATOR_335 then
    self.__bgr335BagID = cacheData and cacheData.bagID or (self:GetParent() and self:GetParent():GetID())
    self.__bgr335SlotID = cacheData and cacheData.slotID or self:GetID()
  end
  if self.SetText then self:SetText("") end
  local defaultText = self.GetFontString and self:GetFontString()
  if defaultText and defaultText ~= self.Count and defaultText ~= self.CountText then defaultText:SetText(""); defaultText:Hide() end
  local bagID, slotID = GetClassicContainerButtonCoordinates(self)
  local info = C_Container.GetContainerItemInfo(bagID, slotID)

  if cacheData.itemLink == nil then
    info = nil
  end

  local itemID = cacheData.itemID or (info and info.itemID);
  local itemLink = cacheData.itemLink or (info and info.hyperlink)
  local texture = SetClassicLiveItemTexture(self, itemID, itemLink, cacheData.iconTexture or (info and info.iconFileID));
  local itemCount = cacheData.itemCount
  local locked = info and info.isLocked;
  local quality = cacheData.quality
  if type(quality) ~= "number" or quality < 0 then
    quality = info and info.quality
  end
  local readable = info and info.isReadable;
  local noValue = info and info.hasNoValue;

  SetItemButtonQuality(self, quality, itemID);
  ApplyQualityBorderClassic(self, quality)
  SetItemButtonCount(self, itemCount, itemCount and itemCount > 9999);
  local countRegion = self.Count or self.CountText or (self.GetName and self:GetName() and _G[self:GetName() .. "Count"])
  if countRegion and (not itemCount or itemCount <= 1) then countRegion:SetText("") end
  SetItemButtonDesaturated(self, locked);
  _G[self:GetName() .. "Cooldown"]:Hide()

  if ContainerFrameItemButton_SetForceExtended then
    ContainerFrameItemButton_SetForceExtended(self, false)
  end

  self.readable = readable;

  if GameTooltip:IsOwned(self) then
    GameTooltip:Hide()
  end

  if self:IsMouseOver() then
    self:OnEnter()
  end

  if self.searchOverlay then self.searchOverlay:SetShown(false) end;
  self.ItemContextOverlay:Hide()
  SetWidgetsAlpha(self, true)
  SanitizeClassicLiveItemButtonRegions(self)

  GetInfo(self, cacheData, function()
    ApplyNewItemAnimation(self, quality)
    self:BGRUpdateQuests()
    self.BGR.tooltipGetter = function()
      return Syndicator.Search.DumpClassicTooltip(function(tooltip)
        local tooltipBagID, tooltipSlotID = GetClassicContainerButtonCoordinates(self)
        if tooltipBagID == -1 then
          tooltip:SetInventoryItem("player", self:GetInventorySlot())
        else
          tooltip:SetBagItem(tooltipBagID, tooltipSlotID)
        end
      end)
    end
    local itemLocation = {bagID = bagID, slotIndex = slotID}
    if C_Item.DoesItemExist(itemLocation) then
      self.BGR.guid = C_Item.GetItemGUID(itemLocation)
      self.BGR.setInfo = addonTable.ItemViewCommon.GetEquipmentSetInfo(itemLocation, self.BGR.guid, self.BGR.itemLink)
      self.BGR.itemLocation = itemLocation
    end

    if C_Engraving and C_Engraving.IsEngravingEnabled() then
      self.BGR.isEngravable = false
      local bagID, slotID = self:GetParent():GetID(), self:GetID()
      if bagID == Enum.BagIndex.Bank then
        local invID = BankButtonIDToInvSlotID(slotID)
        self.BGR.isEngravable = C_Engraving.IsEquipmentSlotEngravable(invID)
        if self.BGR.isEngravable then
          self.BGR.engravingInfo = C_Engraving.GetRuneForEquipmentSlot(invID)
        end
      elseif bagID >= 0 and C_Engraving.IsInventorySlotEngravable(bagID, slotID) then
        self.BGR.isEngravable = true
        self.BGR.engravingInfo = C_Engraving.GetRuneForInventorySlot(bagID, slotID)
      end
    end

    self.BGR.hasNoValue = noValue
  end, function()
    self.BGR.hasSpell = C_Item.GetItemSpell(self.BGR.itemID) ~= nil
    self:BGRUpdateCooldown()
    self:BGRUpdateQuests()
    self:UpdateItemContextMatching()
  end)
end

function BaganatorClassicLiveContainerItemButtonMixin:BGRStartFlashing()
  FlashItemButton(self)
end

function BaganatorClassicLiveContainerItemButtonMixin:BGRSetHighlight(isHighlighted)
  SetHighlightItemButton(self, isHighlighted)
end

function BaganatorClassicLiveContainerItemButtonMixin:ClearNewItem()
  EnsureClassicLiveItemButtonRegions(self)
  local bagID, slotID = GetClassicContainerButtonCoordinates(self)
  addonTable.NewItems:ClearNewItem(bagID, slotID)
  self.NewItemTexture:Hide();
  if (self.flashAnim:IsPlaying() or self.newitemglowAnim:IsPlaying()) then
    self.flashAnim:Stop();
    self.newitemglowAnim:Stop();
  end
end

function BaganatorClassicLiveContainerItemButtonMixin:SetItemFiltered(text)
  EnsureClassicLiveItemButtonRegions(self)
  local result = SearchCheck(self, text)
  if result == nil then
    return true
  end
  if self.BGR ~= nil then
    self.BGR.matchesSearch = result
  end
  if self.searchOverlay then self.searchOverlay:SetShown(not result) end
  SetWidgetsAlpha(self, result and not self.ItemContextOverlay:IsShown())
end

BaganatorClassicLiveGuildItemButtonMixin = {}

function BaganatorClassicLiveGuildItemButtonMixin:OnLoad()
  EnsureClassicLiveItemButtonRegions(self)
  ResetClassicItemButtonChrome(self)
  AddClassicBackground(self)
  self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  self:RegisterForDrag("LeftButton")
  self.SplitStack = function(button, split)
    SplitGuildBankItem(button.tabIndex, button:GetID(), split)
  end
  self.UpdateTooltip = self.OnEnter
end

function BaganatorClassicLiveGuildItemButtonMixin:OnDragStart()
  if self.tabIndex ~= nil and self.tabIndex ~= GetCurrentGuildBankTab() then
    SetCurrentGuildBankTab(self.tabIndex)
  end
  PickupGuildBankItem(self.tabIndex, self:GetID())
end

function BaganatorClassicLiveGuildItemButtonMixin:OnReceiveDrag()
  if self.tabIndex ~= nil and self.tabIndex ~= GetCurrentGuildBankTab() then
    SetCurrentGuildBankTab(self.tabIndex)
  end
  PickupGuildBankItem(self.tabIndex, self:GetID())
end

function BaganatorClassicLiveGuildItemButtonMixin:OnClick(button)
  if self.BGR and self.BGR.itemLink and IsAltKeyDown() then
    addonTable.CallbackRegistry:TriggerEvent("HighlightSimilarItems", self.BGR.itemLink)
    ClearCursor()
    return
  end

  if self.BGR and self.BGR.itemLink and HandleModifiedItemClick(self.BGR.itemLink) then
    return
  end

  if self.tabIndex ~= nil and self.tabIndex ~= GetCurrentGuildBankTab() then
    SetCurrentGuildBankTab(self.tabIndex)
  end

  if ( IsModifiedClick("SPLITSTACK") ) then
    if ( not CursorHasItem() ) then
      local _, count, locked = GetGuildBankItemInfo(self.tabIndex, self:GetID())
      if ( not locked and count and count > 1) then
        OpenStackSplitFrame(count, self, "BOTTOMLEFT", "TOPLEFT")
      end
    end
    return
  end

  local type, money = GetCursorInfo()
  if ( type == "money" ) then
    DepositGuildBankMoney(money)
    ClearCursor()
  elseif ( type == "guildbankmoney" ) then
    DropCursorMoney()
    ClearCursor()
  else
    if ( button == "RightButton" ) then
      AutoStoreGuildBankItem(self.tabIndex, self:GetID())
      self:OnLeave()
    else
      PickupGuildBankItem(self.tabIndex, self:GetID())
    end
  end
end

function BaganatorClassicLiveGuildItemButtonMixin:OnEnter()
  if self.BGR and self.BGR.itemLink and IsModifiedClick("DRESSUP") then
    ShowInspectCursor();
  else
    ResetCursor()
  end
  if self.tabIndex ~= nil then
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetGuildBankItem(self.tabIndex, self:GetID())
  end
end

function BaganatorClassicLiveGuildItemButtonMixin:OnLeave()
  GameTooltip_Hide()
  ResetCursor()
end

function BaganatorClassicLiveGuildItemButtonMixin:OnHide()
  if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then
    GameTooltip:Hide()
  end
  if StackSplitFrame and StackSplitFrame:IsShown() and StackSplitFrame.owner == self then
    StackSplitFrame:Hide()
  end
end

function BaganatorClassicLiveGuildItemButtonMixin:UpdateTextures()
  ApplyItemDetailSettings(self)
end

function BaganatorClassicLiveGuildItemButtonMixin:SetItemDetails(cacheData, tabIndex)
  EnsureClassicLiveItemButtonRegions(self)
  self.tabIndex = tabIndex

  local texture, itemCount, locked, _, quality = GetGuildBankItemInfo(tabIndex, self:GetID());

  if cacheData.itemLink == nil then
    texture, itemCount, locked, _, quality = nil, nil, nil, nil, nil
  end
  texture = cacheData.iconTexture or texture
  itemCount = cacheData.itemCount
  quality = cacheData.quality or quality

  SetItemButtonTexture(self, texture);
  SetItemButtonCount(self, itemCount);
  SetItemButtonDesaturated(self, locked);
  ApplyQualityBorderClassic(self, quality)

  if GameTooltip:IsOwned(self) then
    GameTooltip:Hide()
  end

  if self:IsMouseOver() then
    self:OnEnter()
  end

  if self.searchOverlay then self.searchOverlay:SetShown(false) end;
  SetWidgetsAlpha(self, true)

  GetInfo(self, cacheData, function()
    self.BGR.tooltipGetter = function()
      return Syndicator.Search.DumpClassicTooltip(function(tooltip)
          tooltip:SetGuildBankItem(tabIndex, self:GetID())
      end)
    end
  end)
end

function BaganatorClassicLiveGuildItemButtonMixin:BGRStartFlashing()
  FlashItemButton(self)
end

function BaganatorClassicLiveGuildItemButtonMixin:BGRSetHighlight(isHighlighted)
  SetHighlightItemButton(self, isHighlighted)
end

function BaganatorClassicLiveGuildItemButtonMixin:ClearNewItem()
end

function BaganatorClassicLiveGuildItemButtonMixin:SetItemFiltered(text)
  EnsureClassicLiveItemButtonRegions(self)
  local result = SearchCheck(self, text)
  if result == nil then
    return true
  end
  if self.BGR ~= nil then
    self.BGR.matchesSearch = result
  end
  if self.searchOverlay then self.searchOverlay:SetShown(not result) end
  SetWidgetsAlpha(self, result)
end

if table.freeze then
  table.freeze(BaganatorRetailCachedItemButtonMixin)
  table.freeze(BaganatorRetailLiveContainerItemButtonMixin)
  table.freeze(BaganatorRetailLiveGuildItemButtonMixin)
  table.freeze(BaganatorClassicCachedItemButtonMixin)
  table.freeze(BaganatorClassicLiveContainerItemButtonMixin)
  table.freeze(BaganatorClassicLiveGuildItemButtonMixin)
end
