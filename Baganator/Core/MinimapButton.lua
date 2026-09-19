---@class addonTableBaganator
local addonTable = select(2, ...)

addonTable.MinimapButton = addonTable.MinimapButton or {}

local button

local function AddTooltipLine(text, r, g, b)
  GameTooltip:AddLine(text, r or 1, g or 1, b or 1, true)
end

function addonTable.MinimapButton.Initialize()
  if not BAGANATOR_335 or button then
    return
  end

  -- Keep a conventional, globally named minimap button so legacy button
  -- collectors such as MinimapButtonButton can discover it.
  button = CreateFrame("Button", "BaganatorMinimapButton", Minimap)
  button:SetWidth(32)
  button:SetHeight(32)
  button:SetFrameStrata("HIGH")
  button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 10)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  -- Do not use the top-left corner: on the 3.3.5a minimap it collides with
  -- Blizzard's tracking/time controls and can look as if the button is absent.
  -- The middle-left edge is clear on the stock 3.3.5a minimap and remains easy
  -- for minimap-button collector addons to find/reparent.
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "LEFT", -5, 0)

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetWidth(20)
  background:SetHeight(20)
  background:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\AddOns\\Baganator\\Assets\\logo.tga")
  icon:SetWidth(18)
  icon:SetHeight(18)
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:Show()
  button.Icon = icon

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(53)
  border:SetHeight(53)
  border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  border:Show()

  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      addonTable.CallbackRegistry:TriggerEvent("ShowCustomise")
    else
      addonTable.Credits335.ShowDialog()
    end
  end)

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    local version = GetAddOnMetadata("Baganator", "Version") or "1.0.2"
    GameTooltip:AddLine("Baganator |cffff7a00v" .. version .. "|r")
    AddTooltipLine("Original addon by plusmouse / The Mouse Nest", 1, 1, 1)
    AddTooltipLine("WoW 3.3.5a backport by Disruption01", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    AddTooltipLine("GitHub: github.com/disruption01/Baganator_335a_backport", 0.72, 0.82, 1)
    AddTooltipLine("Discord: discord.gg/eJ5MaVNnBm", 0.72, 0.82, 1)
    AddTooltipLine("Support: linktr.ee/disruption01", 0.72, 0.82, 1)
    GameTooltip:AddLine(" ")
    AddTooltipLine("Left-click: About & Credits", 0.2, 1, 0.2)
    AddTooltipLine("Right-click: Settings", 0.2, 1, 0.2)
    GameTooltip:Show()
  end)

  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  button:Show()
end
