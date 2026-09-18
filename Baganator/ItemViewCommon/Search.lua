---@class addonTableBaganator
local addonTable = select(2, ...)
if not Syndicator then
  return
end

local CONTAINER_TYPE_TO_MESSAGE = {
  equipped = addonTable.Locales.THAT_ITEM_IS_EQUIPPED,
  auctions = addonTable.Locales.THAT_ITEM_IS_LISTED_ON_THE_AUCTION_HOUSE,
  mail = addonTable.Locales.THAT_ITEM_IS_IN_A_MAILBOX,
  void = addonTable.Locales.THAT_ITEM_IS_IN_VOID_STORAGE,
}

Syndicator.API.RegisterShowItemLocation(function(mode, entity, container, itemLink, searchText)
  local self = {}

  addonTable.CallbackRegistry:RegisterCallback("ViewComplete", function()
    addonTable.CallbackRegistry:UnregisterCallback("ViewComplete", self)
    addonTable.CallbackRegistry:TriggerEvent("HighlightIdenticalItems", itemLink)
  end, self)

  if mode == "character" then
    if container == "bag" then
      addonTable.CallbackRegistry:TriggerEvent("GuildHide")
      addonTable.CallbackRegistry:TriggerEvent("BankHide")
      addonTable.CallbackRegistry:TriggerEvent("BagShow", entity)
      addonTable.CallbackRegistry:TriggerEvent("SearchTextChanged", searchText)
    elseif container == "bank" then
      addonTable.CallbackRegistry:TriggerEvent("GuildHide")
      addonTable.CallbackRegistry:TriggerEvent("BagHide")
      addonTable.CallbackRegistry:TriggerEvent("BankShow", entity)
      addonTable.CallbackRegistry:TriggerEvent("SearchTextChanged", searchText)
    else
      addonTable.Dialogs.ShowAcknowledge(CONTAINER_TYPE_TO_MESSAGE[container])
      addonTable.CallbackRegistry:UnregisterCallback("ViewComplete", self)
      return
    end
  elseif mode == "guild" then
    addonTable.CallbackRegistry:TriggerEvent("BagHide")
    addonTable.CallbackRegistry:TriggerEvent("BankHide")
    addonTable.CallbackRegistry:TriggerEvent("GuildShow", entity, tonumber(container))
    addonTable.CallbackRegistry:TriggerEvent("SearchTextChanged", searchText)
    addonTable.CallbackRegistry:TriggerEvent("HighlightIdenticalItems", itemLink)
  elseif mode == "warband" then
    addonTable.CallbackRegistry:TriggerEvent("GuildHide")
    addonTable.CallbackRegistry:TriggerEvent("BagHide")
    if addonTable.Config.Get(addonTable.Config.Options.WARBAND_CURRENT_TAB) == 0 then
      addonTable.CallbackRegistry:TriggerEvent("BankShow", tonumber(entity), 0)
    else
      addonTable.CallbackRegistry:TriggerEvent("BankShow", tonumber(entity), tonumber(container))
    end
    addonTable.CallbackRegistry:TriggerEvent("SearchTextChanged", searchText)
  else
    addonTable.CallbackRegistry:UnregisterCallback("ViewComplete", self)
    return
  end
end)

local function SaveSearch(label, search)
  local list = addonTable.Config.Get(addonTable.Config.Options.SAVED_SEARCHES)
  local oldIndex = FindInTableIf(list, function(a) return a.label == label end)
  if oldIndex then
    list[oldIndex].search = search
  else
    table.insert(list, {label = label, search = search})
    table.sort(list, function(a, b)
      if a.label == b.label then
        return a.search < b.search
      else
        return a.label < b.label
      end
    end)
  end
end

BaganatorSearchWidgetMixin = {}

function BaganatorSearchWidgetMixin:OnLoad()
  -- SearchBoxTemplate does not exist in stock 3.3.5a. The converted XML uses
  -- InputBoxTemplate, so recreate the small pieces Baganator expects.
  if BAGANATOR_335 then
    -- Concrete SearchWidget children can skip visual inheritance on Wrath.
    -- Reassert only Baganator's own icon-button chrome here.
    if Baganator335Compat and Baganator335Compat.EnsureClassicIconButton then
      Baganator335Compat.EnsureClassicIconButton(self.SavedSearchesButton, "Interface\\AddOns\\Baganator\\Assets\\SavedSearches.tga", 14, 0)
      Baganator335Compat.EnsureClassicIconButton(self.GlobalSearchButton, "Interface\\AddOns\\Baganator\\Assets\\Search.tga", 14, 0)
      Baganator335Compat.EnsureClassicIconButton(self.HelpButton, nil, nil, 0)
    end
    if self.SavedSearchesButton then
      self.SavedSearchesButton.Icon = self.SavedSearchesButton.Icon or (self.SavedSearchesButton.GetName and _G[self.SavedSearchesButton:GetName() .. "Icon"])
      if not self.SavedSearchesButton.Icon then self.SavedSearchesButton.Icon = self.SavedSearchesButton:CreateTexture(nil, "ARTWORK"); self.SavedSearchesButton.Icon:SetSize(14,14); self.SavedSearchesButton.Icon:SetPoint("CENTER") end
      self.SavedSearchesButton.Icon:SetTexture("Interface\\AddOns\\Baganator\\Assets\\SavedSearches.tga"); self.SavedSearchesButton.Icon:Show()
      self.SavedSearchesButton.tooltipHeader = addonTable.Locales.SAVED_SEARCHES
    end
    if self.HelpButton then
      self.HelpButton.Icon = self.HelpButton.Icon or (self.HelpButton.GetName and _G[self.HelpButton:GetName() .. "Icon"])
      if self.HelpButton.Icon then self.HelpButton.Icon:Hide() end
      if not self.HelpButton.HelpText335 then self.HelpButton.HelpText335=self.HelpButton:CreateFontString(nil,"OVERLAY","GameFontNormal"); self.HelpButton.HelpText335:SetPoint("CENTER"); self.HelpButton.HelpText335:SetText("?"); self.HelpButton.HelpText335:SetTextColor(1,0.82,0,1) end
      self.HelpButton.tooltipHeader = addonTable.Locales.HELP
    end
    if not self.SearchBox.Instructions then
      self.SearchBox.Instructions = self.SearchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
      self.SearchBox.Instructions:SetPoint("LEFT", 6, 0)
      self.SearchBox.Instructions:SetPoint("RIGHT", -20, 0)
      self.SearchBox.Instructions:SetJustifyH("LEFT")
    end
    if not self.SearchBox.clearButton then
      local clear = CreateFrame("Button", nil, self.SearchBox)
      clear:SetSize(14, 14)
      clear:SetPoint("RIGHT", -3, 0)
      clear:SetFrameLevel((self.SearchBox:GetFrameLevel() or 1) + 20)
      clear:RegisterForClicks("LeftButtonUp")
      clear:EnableMouse(true)
      if clear.SetHitRectInsets then clear:SetHitRectInsets(-4, -4, -4, -4) end
      clear:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
      self.SearchBox.clearButton = clear
    end
    if not self.SearchBox.IsInIMECompositionMode then
      self.SearchBox.IsInIMECompositionMode = function() return false end
    end
  end

  self:SetShown(addonTable.Config.Get(addonTable.Config.Options.SHOW_SEARCH_BOX))
  addonTable.CallbackRegistry:RegisterCallback("SettingChanged",  function(_, settingName)
    if settingName == addonTable.Config.Options.SHOW_SEARCH_BOX then
      self:SetShown(addonTable.Config.Get(addonTable.Config.Options.SHOW_SEARCH_BOX))
    end
  end)

  self.SearchBox.Instructions:SetWordWrap(false)
  self.SearchBox:HookScript("OnTextChanged", function(_, isUserInput)
    if isUserInput and not self.SearchBox:IsInIMECompositionMode() then
      local text = self.SearchBox:GetText()
      addonTable.CallbackRegistry:TriggerEvent("SearchTextChanged", text:lower())
    end
    local currentText = self.SearchBox:GetText() or ""
    if currentText == "" then
      self.SearchBox.Instructions:SetText(addonTable.Utilities.GetRandomSearchesText())
      self.SearchBox.Instructions:Show()
    else
      self.SearchBox.Instructions:Hide()
    end
  end)
  self.SearchBox:HookScript("OnKeyDown", function(_, key)
    if key == "LALT" or key == "RALT" or key == "ALT" then
      addonTable.CallbackRegistry:TriggerEvent("PropagateAlt")
    end
  end)
  self.SearchBox:HookScript("OnKeyUp", function(_, key)
    if key == "LALT" or key == "RALT" or key == "ALT" then
      addonTable.CallbackRegistry:TriggerEvent("PropagateAlt")
    end
  end)
  local function ClearSearch335()
    self.SearchBox:SetText("")
    self.SearchBox:ClearFocus()
    addonTable.CallbackRegistry:TriggerEvent("SearchTextChanged", "")
  end
  self.SearchBox.clearButton:SetScript("OnClick", ClearSearch335)
  if BAGANATOR_335 then
    self.SearchBox.clearButton:SetScript("OnMouseUp", function(_, button)
      if button == "LeftButton" then ClearSearch335() end
    end)
  end
  self.SearchBox.clearButton:SetShown((self.SearchBox:GetText() or "") ~= "")
  self.SearchBox:HookScript("OnTextChanged", function()
    self.SearchBox.clearButton:SetShown((self.SearchBox:GetText() or "") ~= "")
  end)

  if not self.GlobalSearchButton.Icon and self.GlobalSearchButton.GetName then
    self.GlobalSearchButton.Icon = _G[self.GlobalSearchButton:GetName() .. "Icon"]
  end
  if not self.GlobalSearchButton.Icon then
    self.GlobalSearchButton.Icon = self.GlobalSearchButton:CreateTexture(nil, "ARTWORK")
    self.GlobalSearchButton.Icon:SetTexture("Interface\\AddOns\\Baganator\\Assets\\Search.tga")
    self.GlobalSearchButton.Icon:SetWidth(14)
    self.GlobalSearchButton.Icon:SetHeight(14)
    self.GlobalSearchButton.Icon:SetPoint("CENTER")
  end

  self.GlobalSearchButton:Disable()
  self.GlobalSearchButton.Icon:SetDesaturated(true)

  addonTable.CallbackRegistry:RegisterCallback("SearchTextChanged",  function(_, text)
    self.SearchBox:SetText(text)
    addonTable.Compatibility.SetEnabled(self.GlobalSearchButton, text ~= "")
    self.GlobalSearchButton.Icon:SetDesaturated(not self.GlobalSearchButton:IsEnabled())
  end)

  self.HelpButton:SetScript("OnClick", function()
    addonTable.Help.ShowSearchDialog()
  end)

  if BAGANATOR_335 then
    -- Classic replacement for the modern MenuUtil saved-search dropdown.
    -- Keep the interaction close to modern Classic: flat saved-search rows and
    -- an inline name field instead of opening another red dialog.
    self.SavedSearchesButton:Show()

    local function CreateFlatButton335(parent, text)
      local button = CreateFrame("Button", nil, parent)
      button:SetHeight(20)
      if button.SetBackdrop then
        button:SetBackdrop({
          bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
          edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
          tile = true, tileSize = 8, edgeSize = 8,
          insets = {left = 2, right = 2, top = 2, bottom = 2},
        })
        button:SetBackdropColor(0.08, 0.08, 0.09, 0.98)
        button:SetBackdropBorderColor(0.28, 0.28, 0.30, 1)
      end
      local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      label:SetPoint("LEFT", 7, 0)
      label:SetPoint("RIGHT", -7, 0)
      label:SetJustifyH("CENTER")
      label:SetText(text or "")
      button.Label335 = label
      button:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then self:SetBackdropColor(0.16, 0.16, 0.18, 1) end
      end)
      button:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then self:SetBackdropColor(0.08, 0.08, 0.09, 0.98) end
      end)
      return button
    end

    local function EnsureSavedSearchMenu335()
      if self.savedSearchFrame335 then
        return self.savedSearchFrame335
      end

      local menu = CreateFrame("Frame", nil, self)
      menu:SetFrameStrata("DIALOG")
      menu:SetFrameLevel((self:GetFrameLevel() or 1) + 80)
      menu:SetWidth(190)
      menu:EnableMouse(true)
      if menu.SetBackdrop then
        menu:SetBackdrop({
          bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
          edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
          tile = true, tileSize = 16, edgeSize = 12,
          insets = {left = 3, right = 3, top = 3, bottom = 3},
        })
        menu:SetBackdropColor(0.015, 0.015, 0.02, 0.98)
        menu:SetBackdropBorderColor(0.40, 0.40, 0.44, 1)
      end

      menu.savedRows = {}

      menu.emptyText = menu:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
      menu.emptyText:SetPoint("TOPLEFT", 10, -10)
      menu.emptyText:SetPoint("TOPRIGHT", -10, -10)
      menu.emptyText:SetJustifyH("LEFT")
      menu.emptyText:SetText(addonTable.Locales.NOTHING_TO_SAVE or "No saved searches")

      menu.nameBox = CreateFrame("EditBox", nil, menu, "InputBoxTemplate")
      menu.nameBox:SetAutoFocus(false)
      menu.nameBox:SetHeight(20)
      menu.nameBox:SetPoint("LEFT", 10, 0)
      menu.nameBox:SetPoint("RIGHT", -10, 0)
      menu.nameBox:SetTextInsets(6, 6, 0, 0)
      menu.nameBox:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
      menu.nameBox:SetScript("OnEnterPressed", function(edit)
        local label = strtrim(edit:GetText() or "")
        local search = self.SearchBox:GetText() or ""
        if label ~= "" and search ~= "" then
          SaveSearch(label, search)
          menu:Hide()
        end
      end)

      menu.saveButton = CreateFlatButton335(menu, addonTable.Locales.SAVE_SEARCH)
      menu.saveButton:SetPoint("LEFT", 10, 0)
      menu.saveButton:SetPoint("RIGHT", -10, 0)
      menu.saveButton:SetScript("OnClick", function()
        local label = strtrim(menu.nameBox:GetText() or "")
        local search = self.SearchBox:GetText() or ""
        if label ~= "" and search ~= "" then
          SaveSearch(label, search)
          menu:Hide()
        end
      end)

      self.savedSearchFrame335 = menu
      return menu
    end

    local function GetSavedRow335(menu, index)
      if menu.savedRows[index] then
        return menu.savedRows[index]
      end

      local row = CreateFrame("Button", nil, menu)
      row:SetHeight(20)
      row:SetPoint("LEFT", 8, 0)
      row:SetPoint("RIGHT", -8, 0)
      row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

      local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      text:SetPoint("LEFT", 5, 0)
      text:SetPoint("RIGHT", -24, 0)
      text:SetJustifyH("LEFT")
      row.Text335 = text

      local delete = CreateFrame("Button", nil, row)
      delete:SetSize(18, 18)
      delete:SetPoint("RIGHT", -1, 0)
      local x = delete:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      x:SetPoint("CENTER", 0, 0)
      x:SetText("x")
      x:SetTextColor(1, 0.25, 0.20, 1)
      delete.Text335 = x
      delete:SetScript("OnEnter", function() x:SetTextColor(1, 0.65, 0.25, 1) end)
      delete:SetScript("OnLeave", function() x:SetTextColor(1, 0.25, 0.20, 1) end)
      row.Delete335 = delete

      menu.savedRows[index] = row
      return row
    end

    local function RebuildSavedSearchMenu335()
      local menu = EnsureSavedSearchMenu335()
      local list = addonTable.Config.Get(addonTable.Config.Options.SAVED_SEARCHES) or {}
      local y = -8

      for _, row in ipairs(menu.savedRows) do
        row:Hide()
      end
      menu.emptyText:Hide()
      menu.nameBox:Hide()
      menu.saveButton:Hide()

      for index, details in ipairs(list) do
        local entry = details
        local row = GetSavedRow335(menu, index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 8, y)
        row:SetPoint("TOPRIGHT", -8, y)
        row.Text335:SetText(entry.label)
        row:SetScript("OnClick", function()
          addonTable.CallbackRegistry:TriggerEvent("SearchTextChanged", entry.search)
          menu:Hide()
        end)
        row.Delete335:SetScript("OnClick", function()
          local saved = addonTable.Config.Get(addonTable.Config.Options.SAVED_SEARCHES) or {}
          local oldIndex = FindInTableIf(saved, function(a) return a.label == entry.label end)
          if oldIndex then table.remove(saved, oldIndex) end
          RebuildSavedSearchMenu335()
        end)
        row:Show()
        y = y - 21
      end

      local currentSearch = self.SearchBox:GetText() or ""
      if currentSearch ~= "" then
        if #list > 0 then y = y - 5 end
        menu.nameBox:ClearAllPoints()
        menu.nameBox:SetPoint("TOPLEFT", 10, y)
        menu.nameBox:SetPoint("TOPRIGHT", -10, y)
        if not menu.nameBox:HasFocus() then
          -- Keep the suggested label in sync with the live search while the
          -- saved-search popup is already open. On Wrath the popup is a custom
          -- frame rather than MenuUtil, so it does not rebuild automatically.
          menu.nameBox:SetText(currentSearch)
        end
        menu.nameBox:Show()
        y = y - 25

        menu.saveButton:ClearAllPoints()
        menu.saveButton:SetPoint("TOPLEFT", 10, y)
        menu.saveButton:SetPoint("TOPRIGHT", -10, y)
        menu.saveButton:Show()
        y = y - 22
      elseif #list == 0 then
        menu.emptyText:ClearAllPoints()
        menu.emptyText:SetPoint("TOPLEFT", 10, y - 2)
        menu.emptyText:SetPoint("TOPRIGHT", -10, y - 2)
        menu.emptyText:Show()
        y = y - 22
      end

      menu:SetHeight(math.max(34, -y + 6))
    end

    -- MenuUtil on modern Classic rebuilds the menu when its state changes.
    -- Our 3.3.5a replacement is a normal frame, so explicitly refresh it as
    -- the user edits/clears the main search box while the popup is visible.
    self.SearchBox:HookScript("OnTextChanged", function()
      local menu = self.savedSearchFrame335
      if menu and menu:IsShown() then
        RebuildSavedSearchMenu335()
      end
    end)

    self.SavedSearchesButton:SetScript("OnClick", function()
      local menu = EnsureSavedSearchMenu335()
      if menu:IsShown() then
        menu:Hide()
        return
      end
      menu:ClearAllPoints()
      menu:SetPoint("TOPRIGHT", self.SavedSearchesButton, "BOTTOMRIGHT", 0, -2)
      RebuildSavedSearchMenu335()
      menu:Show()
      if self.SearchBox:GetText() ~= "" then
        menu.nameBox:HighlightText()
        menu.nameBox:SetFocus()
      end
    end)
  elseif self.SavedSearchesButton.SetupMenu then
    self.SavedSearchesButton:SetupMenu(function(menu, rootDescription)
      local list = addonTable.Config.Get(addonTable.Config.Options.SAVED_SEARCHES)
      for _, details in ipairs(list) do
        local button = rootDescription:CreateButton(details.label, function()
          addonTable.CallbackRegistry:TriggerEvent("SearchTextChanged", details.search)
        end)
        if not InCombatLockdown() then
          button:AddInitializer(function(button, description, menu)
            local delete = MenuTemplates.AttachAutoHideButton(button, "transmog-icon-remove")
            delete:SetPoint("RIGHT")
            delete:SetSize(16, 16)
            delete.Texture:SetAtlas("transmog-icon-remove")
            delete:SetScript("OnClick", function()
              local list = addonTable.Config.Get(addonTable.Config.Options.SAVED_SEARCHES)
              local oldIndex = FindInTableIf(list, function(a) return a.label == details.label end)
              if oldIndex then
                table.remove(list, oldIndex)
              end
              menu:Close()
            end)
            MenuUtil.HookTooltipScripts(delete, function(tooltip)
              GameTooltip_SetTitle(tooltip, DELETE);
            end);
          end)
        end
      end
      if #list > 0 then
        rootDescription:CreateDivider()
      end
      if self.SearchBox:GetText() == "" then
        local text = rootDescription:CreateTitle(GRAY_FONT_COLOR:WrapTextInColorCode(addonTable.Locales.SAVE_SEARCH))
        text:SetTooltip(function(tooltip)
          tooltip:AddLine(addonTable.Locales.NOTHING_TO_SAVE)
        end)
      else
        local button = rootDescription:CreateButton(NORMAL_FONT_COLOR:WrapTextInColorCode(addonTable.Locales.SAVE_SEARCH), function()
          addonTable.Dialogs.ShowEditBox(addonTable.Locales.CHOOSE_A_LABEL_FOR_THIS_SEARCH, ACCEPT, CANCEL, function(name)
            SaveSearch(name, self.SearchBox:GetText())
          end)
        end)
      end
    end)

  else
    self.SavedSearchesButton:Hide()
  end

  addonTable.Skins.AddFrame("SearchBox", self.SearchBox)

  addonTable.CallbackRegistry:RegisterCallback("SetButtonsShown", function(_, shown)
    self.showButtons = shown
    if self:IsVisible() and self.sideSpacing then
      self:SetSpacing(self.sideSpacing)
    end
  end, self)
  self.showButtons = true
end

function BaganatorSearchWidgetMixin:OnShow()
  self.SearchBox.Instructions:SetText(addonTable.Utilities.GetRandomSearchesText())
  self.SearchBox.Instructions:SetShown((self.SearchBox:GetText() or "") == "")
end

function BaganatorSearchWidgetMixin:OnHide()
  if self.SearchBox:GetText() ~= "" then
    addonTable.CallbackRegistry:TriggerEvent("SearchTextChanged", "")
  end
  Syndicator.Search.ClearCache()
end

function BaganatorSearchWidgetMixin:SetSpacing(sideSpacing)
  self.sideSpacing = sideSpacing

  if BAGANATOR_335 and self.showButtons then
    self.SearchBox:ClearAllPoints()
    self.SearchBox:SetPoint("RIGHT", self:GetParent(), -sideSpacing - 106, 0)
    self.SearchBox:SetPoint("TOPLEFT", self:GetParent(), "TOPLEFT", sideSpacing + addonTable.Constants.ButtonFrameOffset + 5, -28)
    self.SavedSearchesButton:ClearAllPoints()
    self.SavedSearchesButton:SetPoint("LEFT", self.SearchBox, "RIGHT", 3, 0)
    self.GlobalSearchButton:ClearAllPoints()
    self.GlobalSearchButton:SetPoint("LEFT", self.SavedSearchesButton, "RIGHT", 3, 0)
    self.HelpButton:ClearAllPoints()
    self.HelpButton:SetPoint("LEFT", self.GlobalSearchButton, "RIGHT", 3, 0)
    self.SavedSearchesButton:Show()
    self.GlobalSearchButton:Show()
    self.HelpButton:Show()
    return
  end

  if self.showButtons then
    self.SearchBox:ClearAllPoints()
    self.SearchBox:SetPoint("RIGHT", self:GetParent(), -sideSpacing - 106, 0)
    self.SearchBox:SetPoint("TOPLEFT", self:GetParent(), "TOPLEFT", sideSpacing + addonTable.Constants.ButtonFrameOffset + 5, - 28)
    self.SavedSearchesButton:ClearAllPoints()
    self.SavedSearchesButton:SetPoint("LEFT", self.SearchBox, "RIGHT", 3, 0)
    self.GlobalSearchButton:ClearAllPoints()
    self.GlobalSearchButton:SetPoint("LEFT", self.SavedSearchesButton, "RIGHT", 3, 0)
    self.HelpButton:ClearAllPoints()
    self.HelpButton:SetPoint("LEFT", self.GlobalSearchButton, "RIGHT", 3, 0)

    self.SavedSearchesButton:Show()
    self.GlobalSearchButton:Show()
    self.HelpButton:Show()
  else
    self.SearchBox:ClearAllPoints()
    self.SearchBox:SetPoint("RIGHT", self:GetParent(), -sideSpacing, 0)
    self.SearchBox:SetPoint("TOPLEFT", self:GetParent(), "TOPLEFT", sideSpacing + addonTable.Constants.ButtonFrameOffset + 5, - 28)

    self.SavedSearchesButton:Hide()
    self.GlobalSearchButton:Hide()
    self.HelpButton:Hide()
  end
end
