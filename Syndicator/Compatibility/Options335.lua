if not SYNDICATOR_335 then return end
local _, addonTable = ...

-- Replace the modern Settings/ScrollBox options page with a small Wrath-native panel.
function addonTable.Options.Initialize()
  local panel = CreateFrame("Frame", "SyndicatorOptions335", UIParent)
  panel.name = addonTable.Locales.SYNDICATOR or "Syndicator"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText((addonTable.Locales.SYNDICATOR or "Syndicator") .. " - 3.3.5a")

  local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  text:SetWidth(560)
  text:SetJustifyH("LEFT")
  text:SetText("Backport compatibility panel. Core inventory tracking and tooltips use the original Syndicator data model; modern ScrollBox settings are disabled on 3.3.5a.")

  local credits = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  credits:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -18)
  credits:SetWidth(560)
  credits:SetJustifyH("LEFT")
  credits:SetJustifyV("TOP")
  local version = GetAddOnMetadata("Syndicator", "Version") or "1.0.2"
  credits:SetText(
    "Original Syndicator by plusmouse (The Mouse Nest).\n" ..
    "World of Warcraft 3.3.5a backport and compatibility work by Disruption01.\n" ..
    "Disruption01 release: " .. version .. "  |  Upstream base: Syndicator 279.\n" ..
    "Project: github.com/disruption01/Baganator_335a_backport\n" ..
    "Discord: discord.gg/eJ5MaVNnBm  |  Support: linktr.ee/disruption01"
  )

  if InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(panel) end
  Syndicator.OptionsCategory = {frame=panel, GetID=function(self) return self.frame end}
end
