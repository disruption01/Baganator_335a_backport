---@class addonTableBaganator
local addonTable = select(2, ...)
local addonName = ...

function addonTable.CustomiseDialog.Initialize()
  if BAGANATOR_335 then
    -- 3.3.5a uses a small native settings UI instead of trying to emulate the
    -- entire modern Settings/MenuUtil stack.  Grow this in tested batches.
    local classicFrame

    local function CopyShallow(source)
      local result = {}
      if type(source) == "table" then
        for k, v in pairs(source) do result[k] = v end
      end
      return result
    end

    local function SetAutoOpenOption(key, value)
      local data = CopyShallow(addonTable.Config.Get(addonTable.Config.Options.AUTO_OPEN) or {})
      data[key] = value and true or false
      addonTable.Config.Set(addonTable.Config.Options.AUTO_OPEN, data)
    end

    local function GetAutoOpenOption(key, fallback)
      local data = addonTable.Config.Get(addonTable.Config.Options.AUTO_OPEN) or {}
      if data[key] == nil then return fallback end
      return data[key]
    end

    local function BuildClassicSettings()
      local frame = CreateFrame("Frame", "Baganator335CustomiseDialog", UIParent)
      frame:SetSize(540, 410)
      frame:SetPoint("CENTER")
      frame:SetFrameStrata("DIALOG")
      frame:EnableMouse(true)
      frame:SetMovable(true)
      frame:RegisterForDrag("LeftButton")
      Baganator335Compat.EnsureButtonFrame(frame)
      addonTable.Compatibility.ApplyDarkBackdrop(frame)
      frame:SetTitle(addonTable.Locales.CUSTOMISE_BAGANATOR)
      frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
      frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
      table.insert(UISpecialFrames, frame:GetName())

      frame.Views335 = {}
      frame.Tabs335 = {}
      frame.Refreshers335 = {}

      local function RegisterRefresher(func)
        table.insert(frame.Refreshers335, func)
        func()
      end

      local function RefreshControls()
        for _, func in ipairs(frame.Refreshers335) do func() end
      end
      frame.RefreshControls335 = RefreshControls

      local function MakeView()
        local view = CreateFrame("Frame", nil, frame)
        view:SetPoint("TOPLEFT", 16, -64)
        view:SetPoint("BOTTOMRIGHT", -16, 16)
        view:Hide()
        table.insert(frame.Views335, view)
        return view
      end

      local function ShowTab(index)
        for i, view in ipairs(frame.Views335) do view:SetShown(i == index) end
        for i, tab in ipairs(frame.Tabs335) do
          if tab.Label335 then
            tab.Label335:SetTextColor(i == index and 1 or 0.82, i == index and 0.82 or 0.82, 0, 1)
          end
          if tab.SetButtonState then tab:SetButtonState(i == index and "PUSHED" or "NORMAL") end
        end
        frame.CurrentTab335 = index
        RefreshControls()
      end

      local function MakeTab(text, index)
        local tab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        tab:SetSize(112, 24)
        if index == 1 then
          tab:SetPoint("TOPLEFT", 18, -32)
        else
          tab:SetPoint("LEFT", frame.Tabs335[index - 1], "RIGHT", 4, 0)
        end
        tab:SetText(text)
        tab.Label335 = tab:GetFontString()
        tab:SetScript("OnClick", function() ShowTab(index) end)
        frame.Tabs335[index] = tab
        return tab
      end

      local function MakeCheck(parent, labelText, y, getter, setter)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", 16, y)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
        label:SetText(labelText)
        cb.Label335 = label
        cb:SetScript("OnClick", function(self)
          setter(self:GetChecked() and true or false)
        end)
        RegisterRefresher(function() cb:SetChecked(getter() and true or false) end)
        return cb
      end

      local function MakeOptionCheck(parent, labelText, y, option)
        return MakeCheck(parent, labelText, y,
          function() return addonTable.Config.Get(option) end,
          function(value) addonTable.Config.Set(option, value) end)
      end

      local function MakeStepper(parent, labelText, y, option, minValue, maxValue)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("TOPLEFT", 20, y - 4)
        label:SetWidth(245)
        label:SetJustifyH("LEFT")
        label:SetText(labelText)

        local minus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        minus:SetSize(28, 22)
        minus:SetPoint("TOPLEFT", 300, y)
        minus:SetText("-")

        local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        valueText:SetPoint("LEFT", minus, "RIGHT", 12, 0)
        valueText:SetWidth(54)
        valueText:SetJustifyH("CENTER")

        local plus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        plus:SetSize(28, 22)
        plus:SetPoint("LEFT", valueText, "RIGHT", 12, 0)
        plus:SetText("+")

        local function Clamp(value)
          value = tonumber(value) or minValue
          if value < minValue then value = minValue end
          if value > maxValue then value = maxValue end
          return value
        end
        minus:SetScript("OnClick", function()
          addonTable.Config.Set(option, Clamp((addonTable.Config.Get(option) or minValue) - 1))
        end)
        plus:SetScript("OnClick", function()
          addonTable.Config.Set(option, Clamp((addonTable.Config.Get(option) or minValue) + 1))
        end)
        RegisterRefresher(function()
          valueText:SetText(tostring(Clamp(addonTable.Config.Get(option))))
        end)
      end

      MakeTab(addonTable.Locales.GENERAL or "General", 1)
      MakeTab(addonTable.Locales.LAYOUT or "Layout", 2)
      MakeTab(addonTable.Locales.AUTO_OPEN or "Auto Open", 3)
      MakeTab(addonTable.Locales.SORTING or "Sorting", 4)

      -- Phase 1: deliberately limited to settings that map cleanly to Wrath.
      local general = MakeView()
      MakeOptionCheck(general, addonTable.Locales.LOCK_WINDOWS or "Lock windows", -4, addonTable.Config.Options.LOCK_FRAMES)
      MakeOptionCheck(general, addonTable.Locales.SEARCH_BOX or "Show search box", -38, addonTable.Config.Options.SHOW_SEARCH_BOX)
      MakeOptionCheck(general, addonTable.Locales.REDUCE_UI_SPACING or "Reduce UI spacing", -72, addonTable.Config.Options.REDUCE_SPACING)

      local reset = CreateFrame("Button", nil, general, "UIPanelButtonTemplate")
      reset:SetSize(170, 24)
      reset:SetPoint("TOPLEFT", 20, -122)
      reset:SetText(addonTable.Locales.RESET_POSITIONS or "Reset frame positions")
      reset:SetScript("OnClick", function() addonTable.CallbackRegistry:TriggerEvent("ResetFramePositions") end)

      -- Visible attribution for the original projects and the 3.3.5a compatibility work.
      local creditsHeader = general:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      creditsHeader:SetPoint("TOPLEFT", 20, -174)
      creditsHeader:SetText("Credits")

      local credits = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      credits:SetPoint("TOPLEFT", creditsHeader, "BOTTOMLEFT", 0, -6)
      credits:SetWidth(480)
      credits:SetJustifyH("LEFT")
      credits:SetJustifyV("TOP")
      local backportVersion = GetAddOnMetadata("Baganator", "Version") or "1.0.0"
      credits:SetText(
        "Original Baganator and Syndicator by plusmouse (The Mouse Nest).\n" ..
        "World of Warcraft 3.3.5a backport and compatibility work by Disruption01.\n" ..
        "Disruption01 release: " .. backportVersion .. "  |  Upstream bases: Baganator 823-2-ged5d1c8, Syndicator 279.\n" ..
        "GitHub: github.com/disruption01/Baganator_335a_backport\n" ..
        "Discord: discord.gg/eJ5MaVNnBm  |  Support: linktr.ee/disruption01"
      )

      local layout = MakeView()
      MakeStepper(layout, addonTable.Locales.BAG_COLUMNS or "Bag columns", -4, addonTable.Config.Options.BAG_VIEW_WIDTH, 1, 24)
      MakeStepper(layout, addonTable.Locales.BANK_COLUMNS or "Bank columns", -42, addonTable.Config.Options.BANK_VIEW_WIDTH, 1, 42)
      MakeStepper(layout, addonTable.Locales.GUILD_BANK_COLUMNS or "Guild bank columns", -80, addonTable.Config.Options.GUILD_VIEW_WIDTH, 1, 42)
      MakeOptionCheck(layout, (addonTable.Locales.BLANK_SPACE or "Blank space") .. " - " .. (addonTable.Locales.AT_THE_TOP or "At the top"), -126, addonTable.Config.Options.BAG_EMPTY_SPACE_AT_TOP)
      MakeOptionCheck(layout, addonTable.Locales.WHEN_HOLDING_ALT or "Only show buttons while holding Alt", -160, addonTable.Config.Options.SHOW_BUTTONS_ON_ALT)

      local autoOpen = MakeView()
      local autoEntries = {
        {addonTable.Locales.BANK or "Bank", "bank", true},
        {GUILD_BANK or "Guild Bank", "guild_bank", false},
        {MERCHANT or addonTable.Locales.VENDOR or "Vendor", "merchant", true},
        {MAIL_LABEL or addonTable.Locales.MAIL or "Mail", "mail", false},
        {AUCTION_HOUSE or "Auction House", "auction_house", false},
        {TRADE or "Trade", "trade_partner", false},
        {addonTable.Locales.CRAFTING_WINDOW or "Crafting Window", "tradeskill", false},
        {addonTable.Locales.CHARACTER_PANEL or "Character Panel", "character_panel", false},
      }
      for i, details in ipairs(autoEntries) do
        local entry = details
        local col = (i > 4) and 1 or 0
        local row = ((i - 1) % 4)
        local x = col == 0 and 16 or 265
        local y = -4 - row * 42
        local cb = CreateFrame("CheckButton", nil, autoOpen, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", x, y)
        local label = autoOpen:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
        label:SetText(entry[1])
        cb:SetScript("OnClick", function(self) SetAutoOpenOption(entry[2], self:GetChecked()) end)
        RegisterRefresher(function() cb:SetChecked(GetAutoOpenOption(entry[2], entry[3])) end)
      end

      local sorting = MakeView()
      MakeOptionCheck(sorting, addonTable.Locales.SHOW_SORT_BUTTON or "Show sort button", -4, addonTable.Config.Options.SHOW_SORT_BUTTON)
      MakeOptionCheck(sorting, addonTable.Locales.SORT_ON_OPEN or "Sort on open", -38, addonTable.Config.Options.AUTO_SORT_ON_OPEN)
      MakeOptionCheck(sorting, addonTable.Locales.REVERSE_GROUPS_SORT_ORDER or "Reverse groups sort order", -72, addonTable.Config.Options.REVERSE_GROUPS_SORT_ORDER)
      MakeOptionCheck(sorting, (addonTable.Locales.ARRANGE_ITEMS or "Arrange items") .. " - " .. (addonTable.Locales.FROM_THE_BOTTOM or "From the bottom"), -106, addonTable.Config.Options.SORT_START_AT_BOTTOM)
      MakeStepper(sorting, addonTable.Locales.IGNORED_BAG_SLOTS or "Ignored bag slots", -154, addonTable.Config.Options.SORT_IGNORE_BAG_SLOTS_COUNT, 0, 240)
      MakeStepper(sorting, addonTable.Locales.IGNORED_BANK_SLOTS or "Ignored bank slots", -192, addonTable.Config.Options.SORT_IGNORE_BANK_SLOTS_COUNT, 0, 500)

      frame:SetScript("OnShow", function()
        ShowTab(frame.CurrentTab335 or 1)
      end)
      ShowTab(1)
      return frame
    end

    addonTable.CallbackRegistry:RegisterCallback("ShowCustomise", function()
      if not classicFrame then classicFrame = BuildClassicSettings() end
      classicFrame:SetShown(not classicFrame:IsShown())
      if classicFrame:IsShown() then
        classicFrame:Raise()
        classicFrame:RefreshControls335()
      end
    end)

    addonTable.CallbackRegistry:RegisterCallback("SettingChanged", function()
      if classicFrame and classicFrame:IsShown() then classicFrame:RefreshControls335() end
    end)

    function addonTable.CustomiseDialog.IsDialogOpen()
      return classicFrame and classicFrame:IsShown() or false
    end
    return
  end
  local customiseDialog = {} -- Stored by skin applied

  addonTable.CallbackRegistry:RegisterCallback("ShowCustomise", function(_, index)
    for _, dialog in pairs(customiseDialog) do
      dialog:Hide()
    end

    local currentSkinKey = addonTable.Config.Get(addonTable.Config.Options.CURRENT_SKIN)
    if not customiseDialog[currentSkinKey] then
      customiseDialog[currentSkinKey] = CreateFrame("Frame", "BaganatorCustomiseDialogFrame" .. currentSkinKey, UIParent, "BaganatorCustomiseDialogTemplate")
      customiseDialog[currentSkinKey]:SetPoint("CENTER")
      table.insert(UISpecialFrames, customiseDialog[currentSkinKey]:GetName())
      customiseDialog[currentSkinKey].CloseButton:SetScript("OnClick", function()
        customiseDialog[currentSkinKey]:Hide()
      end)
    end
    for key, dialog in pairs(customiseDialog) do
      if key ~= currentSkinKey and dialog:IsShown() then
        dialog:Hide()
        customiseDialog[currentSkinKey]:Hide()
        customiseDialog[currentSkinKey]:SetIndex(customiseDialog[key].lastIndex)
        customiseDialog[currentSkinKey]:ClearAllPoints()
        for i = 1, dialog:GetNumPoints() do
          customiseDialog[currentSkinKey]:SetPoint(dialog:GetPoint(i))
        end
      end
    end

    customiseDialog[currentSkinKey]:RefreshOptions()
    customiseDialog[currentSkinKey]:SetShown(not customiseDialog[currentSkinKey]:IsShown())
    customiseDialog[currentSkinKey]:Raise()
    if index then
      customiseDialog[currentSkinKey]:SetIndex(3)
    end
  end)

  function addonTable.CustomiseDialog.IsDialogOpen()
    for _, dialog in pairs(customiseDialog) do
      if dialog:IsShown() then
        return true
      end
    end
    return false
  end

  -- Create shortcut to open Baganator options from the Bliizzard addon options
  -- panel
  do
    local optionsFrame = CreateFrame("Frame")

    local instructions = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge3")
    instructions:SetPoint("CENTER", optionsFrame)
    instructions:SetText(WHITE_FONT_COLOR:WrapTextInColorCode(addonTable.Locales.TO_OPEN_OPTIONS_X))

    local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
    local versionText = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    versionText:SetPoint("CENTER", optionsFrame, 0, 28)
    versionText:SetText(WHITE_FONT_COLOR:WrapTextInColorCode(addonTable.Locales.VERSION_COLON_X:format(version)))

    local header = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge3")
    header:SetScale(3)
    header:SetPoint("CENTER", optionsFrame, 0, 30)
    header:SetText(LINK_FONT_COLOR:WrapTextInColorCode(addonTable.Locales.BAGANATOR))

    local template = "SharedButtonLargeTemplate"
    if not C_XMLUtil.GetTemplateInfo(template) then
      template = "UIPanelDynamicResizeButtonTemplate"
    end
    local button = CreateFrame("Button", nil, optionsFrame, template)
    button:SetText(addonTable.Locales.OPEN_OPTIONS)
    button.padding = 60
    DynamicResizeButton_Resize(button)
    button:SetPoint("CENTER", optionsFrame, 0, -30)
    button:SetScale(2)
    button:SetScript("OnClick", function()
      addonTable.CallbackRegistry:TriggerEvent("ShowCustomise")
    end)


    optionsFrame.OnCommit = function() end
    optionsFrame.OnDefault = function() end
    optionsFrame.OnRefresh = function() end

    local category = Settings.RegisterCanvasLayoutCategory(optionsFrame, addonTable.Locales.BAGANATOR)
    category.ID = addonTable.Locales.BAGANATOR
    Settings.RegisterAddOnCategory(category)
  end
end
