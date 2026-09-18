---@class addonTableBaganator
local addonTable = select(2, ...)

function addonTable.Utilities.GetAllCharacters(searchText)
  searchText = searchText and searchText:lower() or ""
  local characters = {}
  for _, char in ipairs(Syndicator.API.GetAllCharacters()) do
    local info = Syndicator.API.GetCharacter(char)
    if searchText == "" or char:lower():find(searchText, nil, true) then
      table.insert(characters, {
        fullName = char,
        name = info.details.character,
        realmNormalized = info.details.realmNormalized,
        realm = info.details.realm,
        faction = info.details.faction,
        className = info.details.className,
        race = info.details.race,
        sex = info.details.sex,
      })
    end
  end
  table.sort(characters, function(a, b)
    if a.realm == b.realm then
      return a.name < b.name
    else
      return a.realm < b.realm
    end
  end)

  return characters
end

function addonTable.Utilities.GetAllGuilds(searchText)
  searchText = searchText and searchText:lower() or ""
  local guilds = {}

  local realmNormalizedToRealmMap = {}
  for _, character in ipairs(Syndicator.API.GetAllCharacters()) do
    local data = Syndicator.API.GetCharacter(character)
    realmNormalizedToRealmMap[data.details.realmNormalized] = data.details.realm
  end

  for _, guild in ipairs(Syndicator.API.GetAllGuilds()) do
    local info = Syndicator.API.GetGuild(guild)
    if searchText == "" or guild:lower():find(searchText, nil, true) then
      table.insert(guilds, {
        fullName = guild,
        name = info.details.guild,
        realmNormalized = info.details.realm,
        realm = realmNormalizedToRealmMap[info.details.realm] or info.details.realm or "MISSING",
      })
    end
  end

  table.sort(guilds, function(a, b)
    if a.realm == b.realm then
      return a.name < b.name
    else
      return a.realm < b.realm
    end
  end)

  return guilds
end

function addonTable.Utilities.ShouldShowSortButton()
  return addonTable.Config.Get(addonTable.Config.Options.SHOW_SORT_BUTTON)
end

function addonTable.Utilities.CountEmptySlots(cachedBag)
  local empty = 0
  for _, slotContents in ipairs(cachedBag) do
    if next(slotContents) == nil then
      empty = empty + 1
    end
  end

  return empty
end

function addonTable.Utilities.GetRandomSearchesText()
  local term = addonTable.Constants.SampleSearchTerms[random(#addonTable.Constants.SampleSearchTerms)]

  return addonTable.Locales.SEARCH_TRY_X:format(term)
end

function addonTable.Utilities.AddBagSortManager(parent)
  parent.sortManager = CreateFrame("Frame", nil, parent)
  parent.sortManager.owner = parent
  local function ClearStaleSortGreys335(owner)
    if not BAGANATOR_335 or not owner then return end
    local function visit(frame)
      if not frame or not frame.GetChildren then return end
      if frame.BGR and frame.icon then
        -- Sorting must never own the persistent grey flag: that flag belongs to
        -- real item state such as junk marking. Once a sort ends, remove only
        -- transient lock desaturation and restore the intended persistent state.
        SetItemButtonDesaturated(frame, frame.BGR.persistIconGrey or false)
      end
      for _, child in ipairs({frame:GetChildren()}) do visit(child) end
    end
    visit(owner)
  end
  local function ClearSortGreysSoon335(owner)
    ClearStaleSortGreys335(owner)
    if BAGANATOR_335 and C_Timer and C_Timer.After then
      C_Timer.After(0.35, function() ClearStaleSortGreys335(owner) end)
      C_Timer.After(1.0, function() ClearStaleSortGreys335(owner) end)
    end
  end
  function parent.sortManager:Cancel(cancelHardTimeout)
    self:SetScript("OnUpdate", nil)
    Syndicator.CallbackRegistry:UnregisterCallback("BagCacheUpdate", self)
    if self.timer then
      self.timer:Cancel()
      self.timer = nil
    end
    if cancelHardTimeout and self.hardTimeoutTimer then
      self.hardTimeoutTimer:Cancel()
      self.hardTimeoutTimer = nil
    end
  end
  function parent.sortManager:Apply(status, retryFunc, completeFunc)
    -- Preserve the short Wrath watchdog across the normal retry cycle.
    self:Cancel(false)
    if status == addonTable.Constants.SortStatus.Complete then
      self:Cancel(true)
      self.retryCount = 0
      self.startedAt = nil
      -- Once sorting reports complete, no item should stay visually locked.
      ClearSortGreysSoon335(self.owner)
      completeFunc()
      return
    end

    self.startedAt = self.startedAt or GetTime()
    if BAGANATOR_335 and not self.hardTimeoutTimer then
      self.hardTimeoutTimer = C_Timer.NewTimer(5, function()
        self.hardTimeoutTimer = nil
        self:Cancel(false)
        self.retryCount = 0
        self.startedAt = nil
        ClearSortGreysSoon335(self.owner)
        completeFunc()
      end)
    end
    if GetTime() - self.startedAt >= 5 then
      self:Cancel(true)
      self.retryCount = 0
      self.startedAt = nil
      ClearSortGreysSoon335(self.owner)
      completeFunc()
      return
    end

    self.retryCount = (self.retryCount or 0) + 1
    -- A stale cache/lock state must never leave sorting running forever.
    if self.retryCount > 600 then
      self:Cancel(true)
      self.retryCount = 0
      self.startedAt = nil
      ClearSortGreysSoon335(self.owner)
      completeFunc()
      return
    end

    if status == addonTable.Constants.SortStatus.WaitingMove then
      Syndicator.CallbackRegistry:RegisterCallback("BagCacheUpdate", function()
        self:Cancel(false)
        retryFunc()
      end, self)
      self.timer = C_Timer.NewTimer(0.35, function()
        self:Cancel(false)
        retryFunc()
      end)
    else -- waiting item data or item unlock
      local elapsed = 0
      self:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + (dt or 0)
        if elapsed >= 0.1 then
          self:SetScript("OnUpdate", nil)
          retryFunc()
        end
      end)
    end
  end
  parent.sortManager:SetScript("OnHide", function(self) self:Cancel(true) end)
end

function addonTable.Utilities.AddBagTransferManager(parent)
  parent.transferManager = CreateFrame("Frame", nil, parent)
  -- Tidy up all the recovery methods so they don't trigger after everything is
  -- complete
  addonTable.CallbackRegistry:RegisterCallback("TransferCancel", function(self)
    self:SetScript("OnUpdate", nil)
    if self.modes ~= nil then
      for _, m in ipairs(self.modes) do
        Syndicator.CallbackRegistry:UnregisterCallback(m, self)
      end
      self.modes = nil
    end
    if self.timer then
      self.timer:Cancel()
      self.timer = nil
    end
  end, parent.transferManager)
  function parent.transferManager:Apply(status, modes, retryFunc, completeFunc)
    addonTable.CallbackRegistry:TriggerEvent("TransferCancel")
    self.modes = modes
    if status == addonTable.Constants.SortStatus.Complete then
      completeFunc()
    elseif status == addonTable.Constants.SortStatus.WaitingMove then
      local pending = #modes
      -- Recovery method if the Blizzard APIs stop responding when moving items
      self.timer = C_Timer.NewTimer(1, function()
        self.timer = nil
        addonTable.CallbackRegistry:TriggerEvent("TransferCancel")
        retryFunc()
      end)
      -- Wait for all affected caches to update before moving onto the next
      -- action
      for _, m in ipairs(self.modes) do
        Syndicator.CallbackRegistry:RegisterCallback(m, function(_, _, affected)
          local anyChanges = false
          for _, changed in pairs(affected) do
            anyChanges = anyChanges or changed
          end
          if not anyChanges then
            return
          end
          addonTable.CallbackRegistry:UnregisterCallback(m, self)
          pending = pending - 1
          if pending == 0 then
            addonTable.CallbackRegistry:TriggerEvent("TransferCancel")
            -- We save the timer so a TransferCancel event will be effective if
            -- done while this timer is pending.
            self.timer = C_Timer.NewTimer(0.1, function()
              self.timer = nil
              retryFunc()
            end)
          end
        end, self)
      end
    else -- waiting item data or item unlock
      self:SetScript("OnUpdate", retryFunc)
    end
  end
  parent.transferManager:SetScript("OnHide", function()
    addonTable.CallbackRegistry:TriggerEvent("TransferCancel")
  end)
end

-- Prevent coin icons getting offset on varying screen resolutions by removing
-- the coin icon offset
function addonTable.Utilities.GetMoneyString(amount, splitThousands)
  local result = GetMoneyString(amount, splitThousands)
  result = result:gsub("0:0:2:0", "12"):gsub("|T", " |T")
  return result
end

local hidden = CreateFrame("Frame")
hidden:Hide()
function addonTable.Utilities.AddGeneralDropSlot(parent, getData, bagIndexes)
  local cursorChanged = false
  local function UpdateSlot(self)
    if not cursorChanged then
      return
    end
    cursorChanged = false
    local cursorType, itemID = GetCursorInfo()
    if cursorType == "item" then
      local usageChecks = addonTable.Sorting.GetBagUsageChecks(bagIndexes)
      local sortedBagIDs = CopyTable(bagIndexes)
      table.sort(sortedBagIDs, function(a, b)
        if usageChecks.sortOrder[a] == usageChecks.sortOrder[b] then
          return a < b
        else
          return usageChecks.sortOrder[a] < usageChecks.sortOrder[b]
        end
      end)
      local currentCharacterBags = getData()
      local backupBagID = nil
      for _, bagID in ipairs(sortedBagIDs) do
        local bag = currentCharacterBags[tIndexOf(bagIndexes, bagID)]
        if bag and #bag > 0 then
          if not usageChecks.checks[bagID] or usageChecks.checks[bagID]({itemID = itemID}) then
            for index, slot in ipairs(bag) do
              if slot.itemID == nil then
                self:Enable()
                self:SetID(index)
                self:GetParent():SetID(bagID)
                return
              end
            end
          end
          if not usageChecks.checks[bagID] then
            backupBagID = bagID
          end
        end
      end
      self:Disable()
      self:SetID(1)
      self:GetParent():SetID(backupBagID or sortedBagIDs[1])
    end
  end
  local function UpdateVisibility()
    cursorChanged = true
    if parent.isLive then
      local cursorType = GetCursorInfo()
      parent.backgroundButton:SetShown(cursorType == "item")
      parent.backgroundButton:SetFrameLevel(parent.ScrollBox:GetFrameLevel() + 1)
    else
      parent.backgroundButton:Hide()
    end
  end
  if parent.backgroundButton then
    UpdateVisibility()
    return
  end

  local pool = parent.liveItemButtonPool or addonTable.ItemViewCommon.GetLiveItemButtonPool(parent)

  local indexFrame = CreateFrame("Frame", nil, parent.Container)
  parent.backgroundButton = pool:Acquire()
  parent.backgroundButton:SetParent(indexFrame)
  parent.backgroundButton:SetMotionScriptsWhileDisabled(true)
  parent.backgroundButton:ClearAllPoints()
  parent.backgroundButton:SetAllPoints(parent.Container, true)
  -- 3.3.5a has no Button:Clear*Texture helpers. Clear/hide the actual
  -- texture regions instead so the invisible general drop target remains
  -- clickable without rendering an ItemButton skin.
  local function ClearButtonTexture(getter)
    if not getter then return end
    local texture = getter(parent.backgroundButton)
    if texture then
      texture:SetTexture(nil)
      texture:Hide()
    end
  end
  ClearButtonTexture(parent.backgroundButton.GetHighlightTexture)
  ClearButtonTexture(parent.backgroundButton.GetNormalTexture)
  ClearButtonTexture(parent.backgroundButton.GetDisabledTexture)
  ClearButtonTexture(parent.backgroundButton.GetPushedTexture)
  parent.backgroundButton.SlotBackground:Hide()
  for _, child in ipairs({parent.backgroundButton:GetRegions()}) do
    child:Hide()
    child:SetParent(hidden)
  end
  for _, child in ipairs({parent.backgroundButton:GetChildren()}) do
    child:Hide()
    child:SetParent(hidden)
  end

  UpdateVisibility()
  parent.backgroundButton:RegisterEvent("CURSOR_CHANGED")
  parent.backgroundButton:SetScript("OnEvent", UpdateVisibility)

  parent.backgroundButton:SetScript("OnEnter", UpdateSlot)
  parent.backgroundButton:SetScript("OnLeave", nil)
end

function addonTable.Utilities.AddScrollBar(self)
  if BAGANATOR_335 then
    -- Wrath has neither WowScrollBox nor MinimalScrollBar. Use a native
    -- ScrollFrame + UIPanelScrollBarTemplate while keeping the small surface
    -- area Baganator's views expect (FullUpdate/SetPanExtent).
    Baganator335Compat.ScrollCounter = (Baganator335Compat.ScrollCounter or 0) + 1
    local scrollName = "Baganator335ScrollBar" .. Baganator335Compat.ScrollCounter

    self.ScrollBox = CreateFrame("ScrollFrame", nil, self)
    self.ScrollBar = CreateFrame("Slider", scrollName, self, "UIPanelScrollBarTemplate")
    self.ScrollBar:SetWidth(16)
    self.ScrollChild = CreateFrame("Frame", nil, self.ScrollBox)
    self.ScrollChild.scrollable = true
    self.ScrollBox:SetScrollChild(self.ScrollChild)
    self.ScrollBox:EnableMouseWheel(true)

    self.Container:SetParent(self.ScrollChild)
    self.Container:ClearAllPoints()
    self.Container:SetPoint("TOPLEFT", 2, -2)

    local updating = false
    local function UpdateRange()
      if updating then return end
      updating = true
      local contentHeight = self.ScrollChild:GetHeight() or 0
      local viewHeight = self.ScrollBox:GetHeight() or 0
      local maxScroll = math.max(0, contentHeight - viewHeight)
      self.ScrollBar:SetMinMaxValues(0, maxScroll)
      self.ScrollBar:SetValueStep(20)
      local current = math.min(self.ScrollBox:GetVerticalScroll() or 0, maxScroll)
      self.ScrollBox:SetVerticalScroll(current)
      self.ScrollBar:SetValue(current)
      if maxScroll > 0.5 then self.ScrollBar:Show() else self.ScrollBar:Hide() end
      updating = false
    end

    self.ScrollBar:SetScript("OnValueChanged", function(_, value)
      if not updating then self.ScrollBox:SetVerticalScroll(value or 0) end
    end)
    self.ScrollBox:SetScript("OnMouseWheel", function(_, delta)
      local current = self.ScrollBox:GetVerticalScroll() or 0
      local minValue, maxValue = self.ScrollBar:GetMinMaxValues()
      local nextValue = math.max(minValue or 0, math.min(maxValue or 0, current - delta * 40))
      self.ScrollBar:SetValue(nextValue)
    end)
    self.ScrollBox.FullUpdate = function() UpdateRange() end
    self.ScrollBox.SetPanExtent = function() end

    function self:UpdateScroll(ySaved, scale)
      local sideSpacing, topSpacing, searchSpacing = addonTable.Utilities.GetSpacing()
      self.ScrollBox:ClearAllPoints()
      self.ScrollBox:SetPoint("TOPLEFT", sideSpacing + addonTable.Constants.ButtonFrameOffset - 4, -25 - searchSpacing - topSpacing / 4 + 2)
      self.ScrollChild:SetWidth(self.Container:GetWidth() + 4)
      self.ScrollChild:SetHeight(self.Container:GetHeight() + 4)
      self.ScrollBox:SetWidth(self.Container:GetWidth() + 4)
      self.ScrollBox:SetHeight(math.min(self.Container:GetHeight() + 5, UIParent:GetHeight() / scale - ySaved))
      UpdateRange()
      self.ScrollBar:ClearAllPoints()
      if self.ScrollBar:IsShown() then
        local xOffset = 7 + sideSpacing / 2 - 2
        if addonTable.Config.Get(addonTable.Config.Options.REDUCE_SPACING) then xOffset = 4 end
        self.ScrollBar:SetPoint("TOPLEFT", self.ScrollBox, "TOPRIGHT", xOffset, -16)
        self.ScrollBar:SetPoint("BOTTOMLEFT", self.ScrollBox, "BOTTOMRIGHT", xOffset, 16)
        self:SetWidth(self:GetWidth() + 10 + sideSpacing / 2)
      end
    end
    return
  end

  self.ScrollBox = CreateFrame("Frame", nil, self, "WowScrollBox")
  self.ScrollBar = CreateFrame("Frame", nil, self, "MinimalScrollBar")
  addonTable.Skins.AddFrame("TrimScrollBar", self.ScrollBar)
  self.ScrollChild = CreateFrame("Frame", nil, self.ScrollBox)
  self.ScrollChild.scrollable = true
  self.Container:SetParent(self.ScrollChild)
  self.Container:ClearAllPoints()
  -- Offset is to prevent default item buttons getting edges cropped on edges of
  -- container
  self.Container:SetPoint("TOPLEFT", 2, -2)
  ScrollUtil.InitScrollBoxWithScrollBar(self.ScrollBox, self.ScrollBar, CreateScrollBoxLinearView())
  ScrollUtil.AddManagedScrollBarVisibilityBehavior(self.ScrollBox, self.ScrollBar)
  self.ScrollChild:SetScript("OnSizeChanged", nil)
  self.ScrollBox:SetScript("OnSizeChanged", nil)
  self.ScrollBox:SetPanExtent(100)

  function self:UpdateScroll(ySaved, scale)
    local sideSpacing, topSpacing, searchSpacing = addonTable.Utilities.GetSpacing()
    self.ScrollBox:ClearAllPoints()
    self.ScrollBox:SetPoint("TOPLEFT", sideSpacing + addonTable.Constants.ButtonFrameOffset - 2 - 2, -25 - searchSpacing - topSpacing / 4 + 2)
    self.ScrollChild:SetSize(self.Container:GetWidth() + 4, self.Container:GetHeight() + 4)
    self.ScrollBox:SetSize(
      self.Container:GetWidth() + 4,
      math.min(
        self.Container:GetHeight() + 5,
        UIParent:GetHeight() / scale - ySaved
      )
    )
    self.ScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
    if self.ScrollBar:IsShown() then
      local xOffset = 7 + sideSpacing / 2 - 2
      if addonTable.Config.Get(addonTable.Config.Options.REDUCE_SPACING) then
        xOffset = 4
      end
      self.ScrollBar:SetPoint("TOPLEFT", self.ScrollBox, "TOPRIGHT", xOffset, -2)
      self.ScrollBar:SetPoint("BOTTOMLEFT", self.ScrollBox, "BOTTOMRIGHT", xOffset, 2)
      self:SetWidth(self:GetWidth() + 10 + sideSpacing / 2)
    end
  end
end

function addonTable.Utilities.GetExternalSortMethodName()
  local sortsDetails = addonTable.API.ExternalContainerSorts[addonTable.Config.Get(addonTable.Config.Options.SORT_METHOD)]
  return sortsDetails and addonTable.Locales.USING_X:format(sortsDetails.label)
end

function addonTable.Utilities.GetBagType(bagID, itemID)
  local _, classID, subClassID
  if itemID then
    _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
  end
  local iconDetails = addonTable.Constants.ContainerKeyToInfo[subClassID]
  if classID ~= nil and classID == Enum.ItemClass.Quiver then
    return "quiver"
  elseif iconDetails then
    return subClassID
  elseif addonTable.Constants.IsRetail and bagID == Enum.BagIndex.ReagentBag then
    return "reagentBag"
  elseif addonTable.Constants.IsRetail and bagID == Enum.BagIndex.Reagentbank and not Syndicator.Constants.CharacterBankTabsActive then
    return "reagentBag"
  elseif bagID == Enum.BagIndex.Keyring then
    return "keyring"
  else
    return 0 -- regular bag
  end
end

-- Anchor is relative to UIParent
function addonTable.Utilities.ConvertAnchorToCorner(targetCorner, frame)
  local _ = frame:GetRect() -- Force evaluation of the position of the frame
  if targetCorner == "TOPLEFT" then
    return "TOPLEFT", frame:GetLeft(), frame:GetTop() - UIParent:GetTop()/frame:GetScale()
  elseif targetCorner == "TOPRIGHT" then
    return "TOPRIGHT", frame:GetRight() - UIParent:GetRight()/frame:GetScale(), frame:GetTop() - UIParent:GetTop()/frame:GetScale()
  elseif targetCorner == "BOTTOMLEFT" then
    return "BOTTOMLEFT", frame:GetLeft(), frame:GetBottom()
  elseif targetCorner == "BOTTOMRIGHT" then
    return "BOTTOMRIGHT", frame:GetRight() - UIParent:GetRight()/frame:GetScale(), frame:GetBottom()
  elseif targetCorner == "RIGHT" then
    return "RIGHT", frame:GetRight() - UIParent:GetRight()/frame:GetScale(), select(2, frame:GetCenter()) - select(2, UIParent:GetCenter())/frame:GetScale()
  elseif targetCorner == "LEFT" then
    return "LEFT", frame:GetLeft(), select(2, frame:GetCenter()) - select(2, UIParent:GetCenter())/frame:GetScale()
  elseif targetCorner == "TOP" then
    return "TOP", select(1, frame:GetCenter() - select(1, UIParent:GetCenter())/frame:GetScale()), (frame:GetTop() - UIParent:GetTop()/frame:GetScale())
  elseif targetCorner == "BOTTOM" then
    return "BOTTOM", select(1, frame:GetCenter()) - select(1, UIParent:GetCenter())/frame:GetScale(), frame:GetBottom()
  else
    error("Unknown anchor")
  end
end

function addonTable.Utilities.GetSpacing()
  local sideSpacing, topSpacing = 13, 14
  if addonTable.Config.Get(addonTable.Config.Options.REDUCE_SPACING) then
    sideSpacing = 8
    topSpacing = 7
  end
  local searchSpacing = 25
  if not addonTable.Config.Get(addonTable.Config.Options.SHOW_SEARCH_BOX) then
    searchSpacing = 0
  end

  return sideSpacing, topSpacing, searchSpacing
end

function addonTable.Utilities.AddButtons(allButtons, lastButton, parent, spacing, regionDetails)
  local buttonsWidth = 0
  for _, details in ipairs(regionDetails) do
    local button = details.frame
    button:ClearAllPoints()
    if button:IsShown() then
      button:SetParent(parent)
      buttonsWidth = buttonsWidth + spacing + button:GetWidth()
      button:SetPoint("LEFT", lastButton, "RIGHT", spacing, 0)
      lastButton = button
      table.insert(allButtons, button)
    end
  end

  return buttonsWidth
end

do
  local possibleChargePatterns
  if addonTable.Constants.IsRetail then
    possibleChargePatterns = {
      "^" .. ITEM_SPELL_CHARGES_NONE .. "$",
      "^" .. ITEM_SPELL_CHARGES:gsub("%%d", "%%d+") .. "$",
    }

  else
    possibleChargePatterns = {
      "^" .. ITEM_SPELL_CHARGES_NONE .. "$",
    }

    local escapeSequence = ITEM_SPELL_CHARGES:match("|4([^;]*);")

    if escapeSequence then
      for _, part in ipairs({ strsplit(":", escapeSequence) }) do
        table.insert(possibleChargePatterns, "^" .. (ITEM_SPELL_CHARGES:gsub("%%d", "%%d%+"):gsub("|4[^;]*;", part)) .. "$")
      end
    else
      table.insert(possibleChargePatterns, "^" .. ITEM_SPELL_CHARGES .. "$")
    end
  end

  function addonTable.Utilities.GetChargesLine(tooltipInfo)
    for _, line in ipairs(tooltipInfo.lines) do
      for _, p in ipairs(possibleChargePatterns) do
        if line.leftText:match(p) then
          return line.leftText
        end
      end
    end
    return nil
  end
end

if addonTable.Constants.IsRetail or IsUsingLegacyAuctionClient and not IsUsingLegacyAuctionClient() then
  function addonTable.Utilities.IsAuctionable(details)
    if not C_Item.IsItemDataCachedByID(details.itemID) then
      C_Item.RequestLoadItemDataByID(details.itemID)
      return nil
    end
    return C_Item.DoesItemExist(details.itemLocation) and C_AuctionHouse.IsSellItemValid(details.itemLocation, false)
  end
else
  local cachedCharges = {}

  function addonTable.Utilities.IsAuctionable(details)
    if not C_Item.IsItemDataCachedByID(details.itemID) then
      C_Item.RequestLoadItemDataByID(details.itemID)
      return nil
    end

    local result = false

    local currentDurability, maxDurability
    if details.itemLocation.bagID then
      currentDurability, maxDurability = C_Container.GetContainerItemDurability(details.itemLocation.bagID, details.itemLocation.slotIndex)
    else
      currentDurability, maxDurability = GetInventoryItemDurability(details.itemLocation.equipmentSlotIndex)
    end

    result = not C_Item.IsBound(details.itemLocation) and currentDurability == maxDurability

    -- Determine if the item is at max charges (if it has charges)
    if result and select(6, C_Item.GetItemInfoInstant(details.itemID)) == Enum.ItemClass.Consumable and C_Item.GetItemSpell(details.itemID) and details.itemLocation.bagID ~= nil then
      local _, spellID = C_Item.GetItemSpell(details.itemID)
      if not C_Spell.IsSpellDataCached(spellID) then
        C_Spell.RequestLoadSpellData(spellID)
        return nil
      end

      if not details.tooltipInfoSpell then
        details.tooltipInfoSpell = details.tooltipGetter()
      end

      if not cachedCharges[details.itemID] then
        cachedCharges[details.itemID] = addonTable.Utilities.GetChargesLine(Syndicator.Search.DumpClassicTooltip(function(t) t:SetItemByID(details.itemID) end)) or ""
      end

      local cached = cachedCharges[details.itemID]
      if cached ~= "" then
        result = false
        for _, line in ipairs(details.tooltipInfoSpell.lines) do
          if line.leftText == cached then
            result = true
            break
          end
        end
      end
    end

    return result
  end
end

do
  local timer
  function addonTable.ItemViewCommon.NotifySearchMonitorComplete(text)
    if timer then
      return
    end
    timer = C_Timer.NewTimer(0, function()
      addonTable.CallbackRegistry:TriggerEvent("SearchMonitorComplete", text)
      timer = nil
    end)
  end
end
