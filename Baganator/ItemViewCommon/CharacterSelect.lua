---@class addonTableBaganator
local addonTable = select(2, ...)
BaganatorCharacterSelectMixin = {}

local arrowLeft = CreateTextureMarkup("Interface\\AddOns\\Baganator\\Assets\\arrow", 22, 22, 18, 18, 0, 1, 0, 1)

local function SetRaceIcon(frame)
  frame.RaceIcon = frame:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
  frame.RaceIcon:SetSize(15, 15)
  frame.RaceIcon:SetPoint("TOPLEFT", 32, -2.5)
  frame.RaceIcon:SetFont(frame.RaceIcon:GetFont(), 12, nil)
end

local function SetArrowIcon(frame)
  frame.ArrowIcon = frame:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
  frame.ArrowIcon:SetSize(20, 15)
  frame.ArrowIcon:SetPoint("TOPLEFT", 8, -2.5)
  frame.ArrowIcon:SetFont(frame.ArrowIcon:GetFont(), 12, nil)
end

function BaganatorCharacterSelectMixin:OnLoad()
  Baganator335Compat.EnsureButtonFrame(self)
  if BAGANATOR_335 then addonTable.Compatibility.ApplyDarkBackdrop(self) end
  ButtonFrameTemplate_HidePortrait(self)
  ButtonFrameTemplate_HideButtonBar(self)
  self.Inset:Hide()
  self:SetClampedToScreen(true)

  self:RegisterForDrag("LeftButton")
  self:SetMovable(true)
  self:SetUserPlaced(false)

  addonTable.Skins.AddFrame("ButtonFrame", self)
  addonTable.Skins.AddFrame("Button", self.ManageCharactersButton)

  self:SetTitle(addonTable.Locales.ALL_CHARACTERS)

  local function UpdateForSelection(frame)
    if frame.fullName ~= self.selectedCharacter then
      frame:Enable()
      frame.ArrowIcon:SetText("")
    else
      frame:Disable()
      frame.ArrowIcon:SetText(arrowLeft)
    end
  end

  if BAGANATOR_335 then
    -- Stock 3.3.5a: keep this list completely independent of ScrollUtil/
    -- DataProvider shims from other addons. A small fixed row pool is enough for
    -- character selection and avoids the silent-empty-list regression.
    self.ScrollBox:ClearAllPoints()
    self.ScrollBox:SetPoint("TOPLEFT", self, "TOPLEFT", 20, -52)
    self.ScrollBox:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -32, 43)
    self.ScrollBar:ClearAllPoints()
    self.ScrollBar:SetPoint("TOPRIGHT", self, "TOPRIGHT", -10, -55)
    self.ScrollBar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -10, 45)

    self.__bgr335CharacterRows = {}
    self.__bgr335CharacterData = {}
    self.__bgr335CharacterOffset = 0

    local function EnsureClassicRow(slot)
      local frame = self.__bgr335CharacterRows[slot]
      if frame then return frame end
      frame = CreateFrame("Button", nil, self.ScrollBox)
      frame:SetHeight(20)
      frame:SetFrameLevel((self.ScrollBox:GetFrameLevel() or 1) + 2)
      frame:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

      frame.ArrowIcon = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      frame.ArrowIcon:SetWidth(20)
      frame.ArrowIcon:SetPoint("LEFT", 6, 0)
      frame.ArrowIcon:SetJustifyH("CENTER")

      frame.RaceIcon = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      frame.RaceIcon:SetWidth(18)
      frame.RaceIcon:SetPoint("LEFT", 28, 0)
      frame.RaceIcon:SetJustifyH("CENTER")

      frame.CharacterName = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      frame.CharacterName:SetPoint("LEFT", 49, 0)
      frame.CharacterName:SetPoint("RIGHT", -92, 0)
      frame.CharacterName:SetJustifyH("LEFT")

      frame.RealmName = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      frame.RealmName:SetTextColor(0.75, 0.75, 0.75)
      frame.RealmName:SetPoint("RIGHT", -8, 0)
      frame.RealmName:SetWidth(82)
      frame.RealmName:SetJustifyH("RIGHT")

      frame:SetScript("OnClick", function(row)
        if row.fullName then
          addonTable.CallbackRegistry:TriggerEvent("CharacterSelect", row.fullName)
        end
      end)
      self.__bgr335CharacterRows[slot] = frame
      return frame
    end

    function self:RebuildCharacters335()
      local data = self.__bgr335CharacterData or {}
      local rowHeight = 20
      local height = self.ScrollBox:GetHeight() or 360
      if height <= 0 then height = 360 end
      local visibleCount = math.max(1, math.floor(height / rowHeight))
      local maxOffset = math.max(0, #data - visibleCount)
      self.__bgr335CharacterOffset = math.max(0, math.min(self.__bgr335CharacterOffset or 0, maxOffset))

      if self.ScrollBar.SetMinMaxValues then self.ScrollBar:SetMinMaxValues(0, maxOffset) end
      if self.ScrollBar.SetValueStep then self.ScrollBar:SetValueStep(1) end
      if self.ScrollBar.SetValue and self.ScrollBar:GetValue() ~= self.__bgr335CharacterOffset then
        self.ScrollBar:SetValue(self.__bgr335CharacterOffset)
      end
      if maxOffset > 0 then self.ScrollBar:Show() else self.ScrollBar:Hide() end

      local used = 0
      for index = self.__bgr335CharacterOffset + 1, math.min(#data, self.__bgr335CharacterOffset + visibleCount) do
        used = used + 1
        local elementData = data[index]
        local frame = EnsureClassicRow(used)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.ScrollBox, "TOPLEFT", 0, -(used - 1) * rowHeight)
        frame:SetPoint("TOPRIGHT", self.ScrollBox, "TOPRIGHT", 0, -(used - 1) * rowHeight)
        frame:Show()
        frame.fullName = elementData.fullName
        frame.RealmName:SetText(elementData.realm or "")
        frame.CharacterName:SetText(elementData.name or elementData.fullName or "")
        if elementData.race then
          frame.RaceIcon:SetText(Syndicator.Utilities.GetCharacterIcon(elementData.race, elementData.sex) or "")
        else
          frame.RaceIcon:SetText("")
        end
        if elementData.className then
          local classColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[elementData.className]
          if classColor then frame.CharacterName:SetTextColor(classColor.r, classColor.g, classColor.b) end
        else
          frame.CharacterName:SetTextColor(1, 1, 1)
        end
        UpdateForSelection(frame)
      end
      for i = used + 1, #self.__bgr335CharacterRows do self.__bgr335CharacterRows[i]:Hide() end
    end

    if self.ScrollBar.SetScript then
      self.ScrollBar:SetScript("OnValueChanged", function(_, value)
        local offset = math.floor((tonumber(value) or 0) + 0.5)
        if offset ~= (self.__bgr335CharacterOffset or 0) then
          self.__bgr335CharacterOffset = offset
          self:RebuildCharacters335()
        end
      end)
    end
    self.ScrollBox:EnableMouseWheel(true)
    self.ScrollBox:SetScript("OnMouseWheel", function(_, delta)
      local data = self.__bgr335CharacterData or {}
      local visibleCount = math.max(1, math.floor(((self.ScrollBox:GetHeight() or 360) > 0 and (self.ScrollBox:GetHeight() or 360) or 360) / 20))
      local maxOffset = math.max(0, #data - visibleCount)
      self.__bgr335CharacterOffset = math.max(0, math.min(maxOffset, (self.__bgr335CharacterOffset or 0) - (delta or 0)))
      if self.ScrollBar.SetValue then self.ScrollBar:SetValue(self.__bgr335CharacterOffset) else self:RebuildCharacters335() end
    end)
  else
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(20)
    view:SetElementInitializer("Button", function(frame, elementData)
      frame:SetHighlightAtlas("search-highlight")
      frame:SetNormalFontObject(GameFontHighlight)
      if not frame.RealmName then
        frame.RealmName = frame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
        frame.RealmName:SetTextColor(0.75, 0.75, 0.75)
        frame.RealmName:SetPoint("RIGHT", -15, 0)
        frame.RealmName:SetJustifyH("RIGHT")
        frame.RealmName:SetJustifyV("MIDDLE")
      end
      frame.fullName = elementData.fullName
      if not frame.RaceIcon then SetRaceIcon(frame) end
      if not frame.ArrowIcon then SetArrowIcon(frame) end
      if elementData.race then frame.RaceIcon:SetText(Syndicator.Utilities.GetCharacterIcon(elementData.race, elementData.sex)) end
      frame:SetText(elementData.name)
      frame.RealmName:SetText(elementData.realm)
      frame:GetFontString():SetPoint("LEFT", 48, 0)
      frame:GetFontString():SetPoint("RIGHT", -15, 0)
      frame:GetFontString():SetJustifyH("LEFT")
      if elementData.className then
        local classColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[elementData.className]
        frame:GetFontString():SetTextColor(classColor.r, classColor.g, classColor.b)
      else
        frame:GetFontString():SetTextColor(1, 1, 1)
      end
      frame:SetScript("OnClick", function() addonTable.CallbackRegistry:TriggerEvent("CharacterSelect", elementData.fullName) end)
      UpdateForSelection(frame)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)
  end

  addonTable.CallbackRegistry:RegisterCallback("CharacterSelect", function(_, character)
    self.selectedCharacter = character
    if BAGANATOR_335 and self.__bgr335CharacterRows then
      for _, frame in ipairs(self.__bgr335CharacterRows) do
        if frame:IsShown() then UpdateForSelection(frame) end
      end
    elseif self.ScrollBox.EnumerateFrames then
      for _, frame in self.ScrollBox:EnumerateFrames() do UpdateForSelection(frame) end
    else
      self:UpdateList()
    end
  end)
  Syndicator.CallbackRegistry:RegisterCallback("CharacterDeleted", function(_, character)
    self:UpdateList()
    if character == self.selectedCharacter then
      addonTable.CallbackRegistry:TriggerEvent("CharacterSelect", Syndicator.API.GetCurrentCharacter())
    end
  end)

  self.SearchBox:HookScript("OnTextChanged", function()
    self:UpdateList()
  end)
  addonTable.Skins.AddFrame("SearchBox", self.SearchBox)
end

function BaganatorCharacterSelectMixin:UpdateList()
  local characters = addonTable.Utilities.GetAllCharacters(self.SearchBox:GetText())
  local currentCharacter = Syndicator.API.GetCurrentCharacter()
  local connectedRealms = Syndicator.Utilities.GetConnectedRealms()
  local currentRealms = {}
  local everythingElse = {}
  for _, data in ipairs(characters) do
    if data.fullName == currentCharacter then
      table.insert(currentRealms, 1, data)
    elseif tIndexOf(connectedRealms, data.realmNormalized) ~= nil then
      table.insert(currentRealms, data)
    else
      table.insert(everythingElse, data)
    end
  end
  tAppendAll(currentRealms, everythingElse)

  if BAGANATOR_335 then
    self.__bgr335CharacterData = currentRealms
    self.__bgr335CharacterOffset = math.min(self.__bgr335CharacterOffset or 0, math.max(0, #currentRealms - 1))
    self:RebuildCharacters335()
  else
    self.ScrollBox:SetDataProvider(CreateDataProvider(currentRealms), true)
  end
end

function BaganatorCharacterSelectMixin:OnShow()
  self:UpdateList()
end

function BaganatorCharacterSelectMixin:OnDragStart()
  if not addonTable.Config.Get(addonTable.Config.Options.LOCK_FRAMES) then
    self:StartMoving()
    self:SetUserPlaced(false)
  end
end

function BaganatorCharacterSelectMixin:OnDragStop()
  self:StopMovingOrSizing()
  self:SetUserPlaced(false)
  local point, _, _, x, y = self:GetPoint(1)
  addonTable.Config.Set(addonTable.Config.Options.CHARACTER_SELECT_POSITION, {point, x, y})
end
