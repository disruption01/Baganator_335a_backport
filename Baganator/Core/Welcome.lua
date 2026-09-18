---@class addonTableBaganator
local addonTable = select(2, ...)
local frame

function addonTable.ShowWelcome()
  addonTable.Config.Set(addonTable.Config.Options.SEEN_WELCOME, 1)
  if frame then
    frame:Show()
    return
  end

  frame = CreateFrame("Frame", "Baganator_WelcomeFrame", UIParent, "ButtonFrameTemplate")
  frame:Hide()
  Baganator335Compat.EnsureButtonFrame(frame)
  ButtonFrameTemplate_HidePortrait(frame)
  ButtonFrameTemplate_HideButtonBar(frame)
  frame.Inset:Hide()
  addonTable.Skins.AddFrame("ButtonFrame", frame)
  -- The stock 3.3.5a ButtonFrameTemplate does not provide the modern
  -- Baganator panel background here, so make the onboarding dialog match
  -- the rest of the 3.3.5a UI explicitly. Apply this after skin registration
  -- so a skin cannot leave the frame transparent.
  if BAGANATOR_335 and addonTable.Compatibility and addonTable.Compatibility.ApplyDarkBackdrop then
    addonTable.Compatibility.ApplyDarkBackdrop(frame)
  end
  frame:EnableMouse(true)
  frame:SetPoint("CENTER")
  frame:SetToplevel(true)

  frame:SetSize(570, 235)

  frame:SetTitle(addonTable.Locales.WELCOME_TO_BAGANATOR)

  local welcomeText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  welcomeText:SetText(addonTable.Locales.WELCOME_DESCRIPTION)
  welcomeText:SetPoint("LEFT")
  welcomeText:SetPoint("RIGHT")
  welcomeText:SetPoint("TOP", 0, -40)

  local singleBagHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  singleBagHeader:SetText(addonTable.Locales.SINGLE_BAG)
  singleBagHeader:SetPoint("LEFT", 24, 0)
  singleBagHeader:SetPoint("RIGHT", frame, "CENTER", -12, 0)
  singleBagHeader:SetPoint("TOP", 0, -72)

  local singleBagText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  singleBagText:SetText(addonTable.Locales.SINGLE_BAG_DESCRIPTION_2)
  singleBagText:SetPoint("LEFT", singleBagHeader)
  singleBagText:SetPoint("RIGHT", singleBagHeader)
  singleBagText:SetPoint("TOP", singleBagHeader, "BOTTOM", 0, -8)
  singleBagText:SetHeight(38)
  singleBagText:SetJustifyH("CENTER")
  singleBagText:SetJustifyV("TOP")

  local categoryGroupsHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  categoryGroupsHeader:SetText(addonTable.Locales.CATEGORY_GROUPS)
  categoryGroupsHeader:SetPoint("RIGHT", -24, 0)
  categoryGroupsHeader:SetPoint("LEFT", frame, "CENTER", 12, 0)
  categoryGroupsHeader:SetPoint("TOP", 0, -72)

  local categoryGroupsText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  categoryGroupsText:SetText(addonTable.Locales.CATEGORY_GROUPS_DESCRIPTION)
  categoryGroupsText:SetPoint("LEFT", categoryGroupsHeader)
  categoryGroupsText:SetPoint("RIGHT", categoryGroupsHeader)
  categoryGroupsText:SetPoint("TOP", categoryGroupsHeader, "BOTTOM", 0, -8)
  categoryGroupsText:SetHeight(38)
  categoryGroupsText:SetJustifyH("CENTER")
  categoryGroupsText:SetJustifyV("TOP")

  local function MakeChooseButton(value)
    local button = CreateFrame("Button", nil, frame, BAGANATOR_335 and "UIPanelButtonTemplate" or "UIPanelDynamicResizeButtonTemplate")
    button:SetText(addonTable.Locales.CHOOSE)
    if BAGANATOR_335 then button:SetSize(100, 22) elseif DynamicResizeButton_Resize then DynamicResizeButton_Resize(button) end
    button:SetScript("OnClick", function()
      addonTable.Config.Set(addonTable.Config.Options.BAG_VIEW_TYPE, value)
      addonTable.Config.Set(addonTable.Config.Options.BANK_VIEW_TYPE, value)
      frame:Hide()
    end)
    addonTable.Skins.AddFrame("Button", button)
    return button
  end
  local chooseSingle = MakeChooseButton("single")
  local chooseCategories = MakeChooseButton("category")
  -- Use a single deterministic anchor for each choice button. The previous
  -- CENTER + BOTTOM double-anchor stretched/repositioned the buttons on
  -- 3.3.5a and made them collide with the attribution line.
  chooseSingle:ClearAllPoints()
  chooseSingle:SetPoint("BOTTOM", frame, "BOTTOM", -142, 44)
  chooseCategories:ClearAllPoints()
  chooseCategories:SetPoint("BOTTOM", frame, "BOTTOM", 142, 44)

  local attribution = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  attribution:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
  attribution:SetWidth(510)
  attribution:SetJustifyH("CENTER")
  attribution:SetText("Original by |cffffffffplusmouse / The Mouse Nest|r  |  3.3.5a backport by |cffff7a00Disruption01|r")

  local categoryBag, singleBag

  frame:SetScript("OnShow", function ()
    addonTable.Config.Set(addonTable.Config.Options.BAG_VIEW_TYPE, "category")
    categoryBag = addonTable.ViewManagement.GetBackpackFrame()
    addonTable.Config.Set(addonTable.Config.Options.BAG_VIEW_TYPE, "single")
    singleBag = addonTable.ViewManagement.GetBackpackFrame()

    categoryBag:ClearAllPoints()
    categoryBag:SetPoint("LEFT", frame, "RIGHT", 20, 0)
    categoryBag:Show()
    categoryBag:UpdateForCharacter(Syndicator.API.GetCurrentCharacter(), true)
    singleBag:ClearAllPoints()
    singleBag:SetPoint("RIGHT", frame, "LEFT", -20, 0)
    singleBag:Show()
    singleBag:UpdateForCharacter(Syndicator.API.GetCurrentCharacter(), true)

    frame:Raise()
  end)

  frame:SetScript("OnHide", function()
    singleBag:Hide()
    categoryBag:Hide()
    addonTable.CallbackRegistry:TriggerEvent("ResetFramePositions")
    addonTable.CallbackRegistry:TriggerEvent("BagShow")
  end)

  frame:Show()
end
