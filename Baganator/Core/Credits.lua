---@class addonTableBaganator
local addonTable = select(2, ...)

if not BAGANATOR_335 then
  return
end

addonTable.Credits335 = addonTable.Credits335 or {}

local CREDITS = addonTable.Credits335

CREDITS.URLS = {
  upstreamProject = "https://www.curseforge.com/wow/addons/baganator",
  upstreamDiscord = "https://discord.gg/P2YwS8pM2N",
  upstreamSupport = "https://linktr.ee/plusmouse",
  github = "https://github.com/disruption01/Baganator_335a_backport",
  discord = "https://discord.gg/eJ5MaVNnBm",
  support = "https://linktr.ee/disruption01",
}

local function GetVersion()
  return GetAddOnMetadata("Baganator", "Version") or "1.0.2"
end
CREDITS.GetVersion = GetVersion

local function AddCopyRow(parent, labelText, url, y)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", 22, y)
  label:SetWidth(112)
  label:SetJustifyH("LEFT")
  label:SetText(labelText)

  local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  value:SetPoint("LEFT", label, "RIGHT", 4, 0)
  value:SetWidth(290)
  value:SetJustifyH("LEFT")
  value:SetText(url)

  local copy = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  copy:SetSize(58, 20)
  copy:SetPoint("LEFT", value, "RIGHT", 4, 0)
  copy:SetText("Copy")
  copy:SetScript("OnClick", function()
    addonTable.Dialogs.ShowCopy(url)
  end)

  return copy
end

function CREDITS.Populate(parent, compact)
  if parent.Baganator335CreditsPopulated then
    return
  end
  parent.Baganator335CreditsPopulated = true

  local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 20, -4)
  title:SetText("Credits & Attribution")

  local originalHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  originalHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
  originalHeader:SetText("Original project")

  local original = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  original:SetPoint("TOPLEFT", originalHeader, "BOTTOMLEFT", 0, -6)
  original:SetWidth(480)
  original:SetJustifyH("LEFT")
  original:SetText("Baganator and Syndicator by |cffffffffplusmouse / The Mouse Nest|r")

  local backportHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  backportHeader:SetPoint("TOPLEFT", original, "BOTTOMLEFT", 0, -16)
  backportHeader:SetText("3.3.5a backport")

  local backport = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  backport:SetPoint("TOPLEFT", backportHeader, "BOTTOMLEFT", 0, -6)
  backport:SetWidth(480)
  backport:SetJustifyH("LEFT")
  backport:SetText(
    "Compatibility work maintained by |cffff7a00Disruption01|r\n" ..
    "World of Warcraft 3.3.5a - build 12340  |  Release |cffff7a00v" .. GetVersion() .. "|r"
  )

  local firstY = compact and -130 or -142
  AddCopyRow(parent, "Upstream project", CREDITS.URLS.upstreamProject, firstY)
  AddCopyRow(parent, "Upstream Discord", CREDITS.URLS.upstreamDiscord, firstY - 27)
  AddCopyRow(parent, "Upstream Linktree", CREDITS.URLS.upstreamSupport, firstY - 54)
  AddCopyRow(parent, "GitHub", CREDITS.URLS.github, firstY - 92)
  AddCopyRow(parent, "Discord", CREDITS.URLS.discord, firstY - 119)
  AddCopyRow(parent, "Support / Linktree", CREDITS.URLS.support, firstY - 146)
end

local creditsDialog
function CREDITS.ShowDialog()
  if not creditsDialog then
    creditsDialog = CreateFrame("Frame", "Baganator335CreditsDialog", UIParent)
    creditsDialog:SetSize(560, 370)
    creditsDialog:SetPoint("CENTER")
    creditsDialog:SetFrameStrata("DIALOG")
    creditsDialog:SetToplevel(true)
    creditsDialog:EnableMouse(true)
    creditsDialog:SetMovable(true)
    creditsDialog:RegisterForDrag("LeftButton")
    Baganator335Compat.EnsureButtonFrame(creditsDialog)
    addonTable.Compatibility.ApplyDarkBackdrop(creditsDialog)
    creditsDialog:SetTitle("Baganator - About & Credits")
    creditsDialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    creditsDialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    table.insert(UISpecialFrames, creditsDialog:GetName())

    local content = CreateFrame("Frame", nil, creditsDialog)
    content:SetPoint("TOPLEFT", 12, -34)
    content:SetPoint("BOTTOMRIGHT", -12, 46)
    CREDITS.Populate(content, true)

    local bagsButton = CreateFrame("Button", nil, creditsDialog, "UIPanelButtonTemplate")
    bagsButton:SetSize(110, 22)
    bagsButton:SetPoint("BOTTOMLEFT", 18, 14)
    bagsButton:SetText("Toggle Bags")
    bagsButton:SetScript("OnClick", function()
      ToggleAllBags()
    end)

    local settingsButton = CreateFrame("Button", nil, creditsDialog, "UIPanelButtonTemplate")
    settingsButton:SetSize(120, 22)
    settingsButton:SetPoint("LEFT", bagsButton, "RIGHT", 8, 0)
    settingsButton:SetText("Credits Settings")
    settingsButton:SetScript("OnClick", function()
      if addonTable.CustomiseDialog and addonTable.CustomiseDialog.ShowCredits335 then
        creditsDialog:Hide()
        addonTable.CustomiseDialog.ShowCredits335()
      else
        addonTable.CallbackRegistry:TriggerEvent("ShowCustomise")
      end
    end)
  end

  creditsDialog:SetShown(not creditsDialog:IsShown())
  if creditsDialog:IsShown() then
    creditsDialog:Raise()
  end
end
