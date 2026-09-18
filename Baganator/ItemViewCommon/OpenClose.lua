---@class addonTableBaganator
local addonTable = select(2, ...)
local IT = Enum.PlayerInteractionType

local event_drivers = {
  BANKFRAME_OPENED = { option = "bank", isOpen = true, default = true },
  BANKFRAME_CLOSED = { option = "bank", isOpen = false, default = true },
  TRADE_SKILL_SHOW = { option = "tradeskill", isOpen = true, default = false },
  TRADE_SKILL_CLOSE = { option = "tradeskill", isOpen = false, default = false },
  SOCKET_INFO_UPDATE = { option = "sockets", isOpen = true, default = false },
  SOCKET_INFO_CLOSE = { option = "sockets", isOpen = false, default = false },
}
if BAGANATOR_335 then
  event_drivers.GUILDBANKFRAME_OPENED = { option = "guild_bank", isOpen = true, default = false }
  event_drivers.GUILDBANKFRAME_CLOSED = { option = "guild_bank", isOpen = false, default = false }
  event_drivers.AUCTION_HOUSE_SHOW = { option = "auction_house", isOpen = true, default = false }
  event_drivers.AUCTION_HOUSE_CLOSED = { option = "auction_house", isOpen = false, default = false }
  event_drivers.MAIL_SHOW = { option = "mail", isOpen = true, default = false }
  event_drivers.MAIL_CLOSED = { option = "mail", isOpen = false, default = false }
  event_drivers.MERCHANT_SHOW = { option = "merchant", isOpen = true, default = true }
  event_drivers.MERCHANT_CLOSED = { option = "merchant", isOpen = false, default = true }
  event_drivers.TRADE_SHOW = { option = "trade_partner", isOpen = true, default = false }
  event_drivers.TRADE_CLOSED = { option = "trade_partner", isOpen = false, default = false }
end
local interactions = {
  [IT.GuildBanker] = { option = "guild_bank", default = false },
  [IT.Auctioneer] = {option = "auction_house", default = addonTable.Constants.IsRetail },
  [IT.MailInfo] = {option = "mail", default = false },
  [IT.Merchant] = {option = "merchant", default = true },
  [IT.TradePartner] = {option = "trade_partner", default = false },
  [IT.ScrappingMachine] = {option = "scrapping_machine", default = true },
  [IT.Soulbind] = {option = "forge_of_bonds", default = false },
  [IT.ItemUpgrade] = {option = "item_upgrade", default = true },
  [IT.ItemInteraction] = {option = "item_interaction", default = true },
}

local frames = {
  ["CharacterFrame"] = { option = "character_panel", default = false },
}

local function CheckOption(option)
  return addonTable.Config.Get(addonTable.Config.Options.AUTO_OPEN)[option]
end

BaganatorOpenCloseMixin = {}

function BaganatorOpenCloseMixin:OnLoad()
  self.autoOpened = false

  local data = addonTable.Config.Get(addonTable.Config.Options.AUTO_OPEN)

  for _, details in pairs(event_drivers) do
    if data[details.option] == nil then
      data[details.option] = details.default
    end
  end

  for _, details in pairs(interactions) do
    if data[details.option] == nil then
      data[details.option] = details.default
    end
  end

  for _, details in pairs(frames) do
    if data[details.option] == nil then
      data[details.option] = details.default
    end
  end

  if not BAGANATOR_335 then
    self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
  end

  for event in pairs(event_drivers) do
    if type(event) == "string" then
      self:RegisterEvent(event)
    end
  end

  CharacterFrame:HookScript("OnShow", function()
    local details = frames["CharacterFrame"]
    self:ApplyState(details, true)
  end)
  CharacterFrame:HookScript("OnHide", function()
    local details = frames["CharacterFrame"]
    self:ApplyState(details, false)
  end)
end

function BaganatorOpenCloseMixin:IsBagShown()
  return addonTable.ViewManagement.GetBackpackFrame():IsShown()
end

function BaganatorOpenCloseMixin:ApplyState(details, state)
  if not CheckOption(details.option) then
    return
  end
  if self:IsBagShown() and not self.autoOpened then
    return
  end
  if state then
    addonTable.CallbackRegistry:TriggerEvent("BagShow")
    self.autoOpened = true
  else
    addonTable.CallbackRegistry:TriggerEvent("BagHide")
    self.autoOpened = false
  end
end

function BaganatorOpenCloseMixin:OnEvent(eventName, ...)
  if eventName == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or eventName == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    local interactionType = ...
    local details = interactions[interactionType]
    if not details then
      return
    end
    self:ApplyState(details, eventName == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
  else
    local details = event_drivers[eventName]
    self:ApplyState(details, details.isOpen)
  end
end


function addonTable.InitializeOpenClose()
  local frame = CreateFrame("Frame")
  Mixin(frame, BaganatorOpenCloseMixin)
  frame:SetScript("OnEvent", frame.OnEvent)
  frame:OnLoad()
end
