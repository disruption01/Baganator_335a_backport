---@class addonTableBaganator
local addonTable = select(2, ...)
function addonTable.Help.GetKeywordGroups()
  local searchTerms = Syndicator.API.GetSearchKeywords()
  local groupsList = {}
  local groups = {}
  local seenInGroup = {}
  for _, term in ipairs(searchTerms) do
    groups[term.group] = groups[term.group] or {}
    seenInGroup[term.group] = seenInGroup[term.group] or {}

    if not seenInGroup[term.group][term.keyword] then
      table.insert(groups[term.group], term.keyword)
      seenInGroup[term.group][term.keyword] = true
    end
  end

  return groups
end

local frame

function addonTable.Help.ShowSearchDialog()
  if frame then
    frame:SetShown(not frame:IsShown())
    frame:Raise()
    return
  end

  local groups = addonTable.Help.GetKeywordGroups()
  local text = ""
  for _, key in ipairs(addonTable.Constants.KeywordGroupOrder) do
    if groups[key] then
      table.sort(groups[key])
      text = text .. "==" .. key .. "\n" .. table.concat(groups[key], ", ") .. "\n"
    end
  end

  frame = CreateFrame("Frame", "Baganator_SearchHelpFrame", UIParent)
  Baganator335Compat.EnsureButtonFrame(frame)
  if BAGANATOR_335 then addonTable.Compatibility.ApplyDarkBackdrop(frame) end
  ButtonFrameTemplate_HidePortrait(frame)
  ButtonFrameTemplate_HideButtonBar(frame)
  frame.Inset:Hide()
  addonTable.Skins.AddFrame("ButtonFrame", frame)
  frame:EnableMouse(true)
  frame:SetPoint("CENTER")
  frame:SetToplevel(true)
  table.insert(UISpecialFrames, frame:GetName())

  frame:RegisterForDrag("LeftButton")
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:SetScript("OnDragStart", function()
    frame:StartMoving()
    frame:SetUserPlaced(false)
  end)
  frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    frame:SetUserPlaced(false)
  end)
  frame.CloseButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  frame:SetTitle(addonTable.Locales.HELP_COLON_SEARCH)
  frame:SetSize(430, 500)

  if BAGANATOR_335 then
    frame.ScrollBox = CreateFrame("ScrollFrame", nil, frame)
    frame.ScrollBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -32)
    frame.ScrollBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
    frame.ScrollBox.Content = CreateFrame("Frame", nil, frame.ScrollBox)
    frame.ScrollBox.Content:SetWidth(375)
    frame.ScrollBox.Content:SetHeight(1)
    frame.ScrollBox:SetScrollChild(frame.ScrollBox.Content)
    frame.ScrollBar = CreateFrame("Slider", nil, frame, "UIPanelScrollBarTemplate")
    frame.ScrollBar:SetPoint("TOPRIGHT", -8, -38)
    frame.ScrollBar:SetPoint("BOTTOMRIGHT", -8, 16)
    frame.ScrollBar:SetMinMaxValues(0, 1)
    frame.ScrollBar:SetValueStep(20)

    local function SetHelpScroll335(value)
      local minVal, maxVal = frame.ScrollBar:GetMinMaxValues()
      value = math.max(minVal or 0, math.min(maxVal or 0, tonumber(value) or 0))
      if frame.ScrollBox.SetVerticalScroll then frame.ScrollBox:SetVerticalScroll(value) end
      if frame.ScrollBar.GetValue and frame.ScrollBar:GetValue() ~= value then frame.ScrollBar:SetValue(value) end
    end
    local function MouseWheelHelp335(_, delta)
      SetHelpScroll335((frame.ScrollBar:GetValue() or 0) - (delta or 0) * 32)
    end

    frame.SetHelpScroll335 = SetHelpScroll335
    frame.MouseWheelHelp335 = MouseWheelHelp335
    frame.ScrollBar:SetScript("OnValueChanged", function(_, value) SetHelpScroll335(value) end)
    frame.ScrollBox:EnableMouse(true)
    frame.ScrollBox:EnableMouseWheel(true)
    frame.ScrollBox:SetScript("OnMouseWheel", MouseWheelHelp335)
    frame.ScrollBox.Content:EnableMouseWheel(true)
    frame.ScrollBox.Content:SetScript("OnMouseWheel", MouseWheelHelp335)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", MouseWheelHelp335)
  else
    frame.ScrollBox = CreateFrame("Frame", nil, frame, "WowScrollBox")
    frame.ScrollBox:SetPoint("TOP", 0, -25)
    frame.ScrollBox:SetPoint("LEFT", addonTable.Constants.ButtonFrameOffset + 20, 0)
    frame.ScrollBox.Content = CreateFrame("Frame", nil, frame.ScrollBox, "ResizeLayoutFrame")
    frame.ScrollBox.Content.scrollable = true
    frame.ScrollBar = CreateFrame("Frame", nil, frame, "MinimalScrollBar")
    frame.ScrollBar:SetPoint("TOPRIGHT", -10, -30)
    frame.ScrollBar:SetPoint("BOTTOMRIGHT", -10, 10)
    addonTable.Skins.AddFrame("TrimScrollBar", frame.ScrollBar)
    frame.ScrollBox:SetPoint("RIGHT", frame.ScrollBar, "LEFT", -10, 0)
    frame.ScrollBox:SetPoint("BOTTOM", 0, 5)
  end

  local lines = {
    { type = "header", text = addonTable.Locales.HELP_SEARCH_OPERATORS},
    { type = "content", text = addonTable.Locales.HELP_SEARCH_OPERATORS_LINE_1_V2},
    { type = "content", text = addonTable.Locales.HELP_SEARCH_OPERATORS_LINE_2_V2},
    { type = "content", text = addonTable.Locales.HELP_SEARCH_OPERATORS_LINE_3},
    { type = "header", text = addonTable.Locales.HELP_SEARCH_ITEM_LEVEL},
    { type = "content", text = addonTable.Locales.HELP_SEARCH_ITEM_LEVEL_LINE_1},
    { type = "content", text = addonTable.Locales.HELP_SEARCH_ITEM_LEVEL_LINE_2},
    { type = "header", text = addonTable.Locales.HELP_SEARCH_KEYWORDS},
    { type = "content", text = addonTable.Locales.HELP_SEARCH_KEYWORDS_LINE_1},
    { type = "content", text = addonTable.Locales.HELP_SEARCH_KEYWORDS_LINE_2},
  }
  for _, key in ipairs(addonTable.Constants.KeywordGroupOrder) do
    if groups[key] then
      table.insert(lines, {type = "header_2", text = key})
      table.insert(lines, {type = "copy_content", text = table.concat(groups[key], ", ")})
    end
  end

  local lastRegion
  for _, l in ipairs(lines) do
    local font, offsetY = "GameFontHighlight", -8
    local region
    if l.type == "copy_content" then
      -- Allow copying keywords
      local editBox = CreateFrame("EditBox", nil, frame.ScrollBox.Content)
      editBox:SetFontObject(font)
      editBox:SetText(l.text)
      editBox:SetAutoFocus(false)
      -- Keep the edit box's text the same
      editBox:SetScript("OnTextChanged", function()
        if editBox:GetText() ~= l.text then
          local pos = editBox:GetCursorPosition()
          editBox:SetText(l.text)
          editBox:SetCursorPosition(pos)
          editBox:ClearFocus()
        end
      end)
      -- Automatically highlight the word clicked
      editBox:SetScript("OnEditFocusGained", function()
        editBox:SetScript("OnCursorChanged", function()
          local charPos = editBox:GetCursorPosition() + 1
          local startHighlight, endHighlight = charPos, charPos
          while startHighlight > 1 and l.text:sub(startHighlight - 1, startHighlight - 1) ~= "," do
            startHighlight = startHighlight - 1
          end
          -- Highlight all of first word
          if startHighlight == 1 then
            startHighlight = 0
          end

          local len = l.text:len()
          while endHighlight <= len and l.text:sub(endHighlight, endHighlight) ~= "," do
            endHighlight = endHighlight + 1
          end
          if endHighlight ~= len then
            endHighlight = endHighlight - 1
          end
          editBox:HighlightText(startHighlight, endHighlight)
        end)
        editBox:SetScript("OnKeyDown", function(_, key)
          if IsControlKeyDown() and key == "C" then
            C_Timer.After(0, function()
              editBox:ClearHighlightText()
              editBox:ClearFocus()
            end)
          end
        end)
      end)
      editBox:SetScript("OnEditFocusLost", function()
        editBox:ClearHighlightText()
        editBox:SetScript("OnCursorChanged", nil)
      end)

      editBox:SetScript("OnEscapePressed", function()
        editBox:ClearFocus()
      end)
      if BAGANATOR_335 and frame.MouseWheelHelp335 then
        editBox:EnableMouseWheel(true)
        editBox:SetScript("OnMouseWheel", frame.MouseWheelHelp335)
      end
      editBox:SetPoint("LEFT")
      editBox:SetPoint("RIGHT")
      editBox:SetSpacing(3)
      editBox:SetMultiLine(true)
      region = editBox
    else
      if l.type == "header" then
        offsetY = - 18
        font = "GameFontNormalLarge"
      elseif l.type == "header_2" then
        offsetY = - 15
        font = BAGANATOR_335 and "GameFontNormal" or "GameFontNormalMed1"
      end
      local fontString = frame.ScrollBox.Content:CreateFontString(nil, "ARTWORK", font)
      fontString:SetText(l.text)
      fontString:SetJustifyH("LEFT")
      fontString:SetPoint("LEFT")
      fontString:SetPoint("RIGHT")
      if l.type == "content" then
        fontString:SetSpacing(3)
      end
      region = fontString
    end

    if lastRegion then
      region:SetPoint("TOP", lastRegion, "BOTTOM", 0, offsetY)
    else
      region:SetPoint("TOP", 0, -10)
    end
    lastRegion = region
  end
  if BAGANATOR_335 then
    local function RefreshHelpScroll335(reset)
      local bottom = lastRegion and lastRegion:GetBottom()
      local top = frame.ScrollBox.Content:GetTop()
      local measured = (top and bottom) and (top - bottom + 20) or nil
      local height = math.max(1, measured or 900)
      frame.ScrollBox.Content:SetHeight(height)
      if frame.ScrollBox.UpdateScrollChildRect then frame.ScrollBox:UpdateScrollChildRect() end
      local visible = frame.ScrollBox:GetHeight() or 1
      local maxScroll = math.max(0, height - visible)
      frame.ScrollBar:SetMinMaxValues(0, maxScroll)
      if frame.ScrollBar.SetValueStep then frame.ScrollBar:SetValueStep(32) end
      if reset then
        frame.SetHelpScroll335(0)
      else
        frame.SetHelpScroll335(frame.ScrollBar:GetValue() or 0)
      end
      if maxScroll > 0 then frame.ScrollBar:Show() else frame.ScrollBar:Hide() end
    end
    -- Wrath does not always recalculate a ScrollFrame's child rect immediately
    -- after wrapped FontStrings change height. Refresh on the next frame and once
    -- more shortly afterwards so the range is never left at 0.
    C_Timer.After(0, function() RefreshHelpScroll335(true) end)
    C_Timer.After(0.05, function() if frame and frame:IsShown() then RefreshHelpScroll335(false) end end)
  else
    frame.ScrollBox.Content.OnCleaned = function()
      frame.ScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately);
    end
    C_Timer.After(0, function() frame.ScrollBox.Content:MarkDirty() end)
    ScrollUtil.InitScrollBoxWithScrollBar(frame.ScrollBox, frame.ScrollBar, CreateScrollBoxLinearView(0, 20, 0, 0))
    frame.ScrollBox:SetPanExtent(50)
  end
  frame:Raise()
end
