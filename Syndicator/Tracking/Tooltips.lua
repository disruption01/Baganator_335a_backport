---@class addonTableSyndicator
local addonTable = select(2, ...)

addonTable.Tooltips = {}

local LibBattlePetTooltipLine = LibStub("LibBattlePetTooltipLine-1-0")

-- Some custom 3.3.5a clients expose the modern named font-color globals but
-- without the ColorMixin methods expected by current Syndicator code. Keep
-- the normal/native path untouched when WrapTextInColorCode exists, and use
-- a private wrapper only for incomplete color objects. Do not mutate or
-- replace the client globals.
local function MakeSafeColorWrapper(color, fallbackR, fallbackG, fallbackB)
  if color ~= nil then
    local ok, method = pcall(function() return color.WrapTextInColorCode end)
    if ok and type(method) == "function" then
      return color
    end
  end

  local r, g, b = fallbackR, fallbackG, fallbackB
  if type(color) == "table" then
    r = tonumber(color.r or color[1]) or r
    g = tonumber(color.g or color[2]) or g
    b = tonumber(color.b or color[3]) or b
  else
    local ok, getRGB = pcall(function() return color and color.GetRGB end)
    if ok and type(getRGB) == "function" then
      local rgbOK, cr, cg, cb = pcall(getRGB, color)
      if rgbOK then
        r = tonumber(cr) or r
        g = tonumber(cg) or g
        b = tonumber(cb) or b
      end
    end
  end

  local function ToByte(value)
    value = math.max(0, math.min(1, tonumber(value) or 1))
    return math.floor(value * 255 + 0.5)
  end

  local prefix = ("|cff%02x%02x%02x"):format(ToByte(r), ToByte(g), ToByte(b))
  return {
    WrapTextInColorCode = function(_, text)
      return prefix .. tostring(text) .. "|r"
    end,
  }
end

local SafeLinkFontColor = MakeSafeColorWrapper(LINK_FONT_COLOR, 0.00, 0.66, 1.00)
local SafeWhiteFontColor = MakeSafeColorWrapper(WHITE_FONT_COLOR, 1.00, 1.00, 1.00)
local SafeTransmogrifyFontColor = MakeSafeColorWrapper(TRANSMOGRIFY_FONT_COLOR, 0.70, 0.20, 1.00)
local SafePassiveSpellFontColor = MakeSafeColorWrapper(PASSIVE_SPELL_FONT_COLOR, 0.77, 0.12, 0.23)

local function CharacterAndRealmComparator(a, b)
  if a.realmNormalized == b.realmNormalized then
    return a.character < b.character
  else
    return a.realmNormalized < b.realmNormalized
  end
end

local function GuildAndRealmComparator(a, b)
  if a.realmNormalized == b.realmNormalized then
    return a.guild < b.guild
  else
    return a.realmNormalized < b.realmNormalized
  end
end

local function IsBoA(itemLink)
  if itemLink:match("battlepet:") then
    return true
  end

  local tooltipData
  if addonTable.Constants.IsClassic then
    tooltipData = addonTable.Utilities.DumpClassicTooltip(function(tooltip) tooltip:SetHyperlink(itemLink) end)
  else
    tooltipData = C_TooltipInfo.GetHyperlink(itemLink)
  end

  if not tooltipData then
    return false
  end

  for _, line in ipairs(tooltipData.lines) do
    if tIndexOf(addonTable.Constants.AccountBoundTooltipLines, line.leftText) ~= nil then
      return true
    end
  end

  return false
end

function addonTable.Tooltips.AddItemLines(tooltip, summaries, itemLink)
  if itemLink == nil then
    return
  end

  local success, key = pcall(addonTable.Utilities.GetItemKey, itemLink)

  if not success then
    return
  end

  local connectedRealmsOnly = addonTable.Config.Get("tooltips_connected_realms_only_2")
  local factionOnly = addonTable.Config.Get("tooltips_faction_only")
  if IsBoA(itemLink) then
    connectedRealmsOnly = false
    factionOnly = false
  end
  local tooltipInfo = summaries:GetTooltipInfo(key, connectedRealmsOnly, factionOnly)

  -- Remove any equipped information from the tooltip if the option is disabled
  -- (and remove the character if it has none of the items not equipped)
  if not addonTable.Config.Get("show_equipped_items_in_tooltips") then
    for _, char in ipairs(tooltipInfo.characters) do
      char.equipped = 0
    end
  end

  if addonTable.Config.Get("tooltips_sort_by_name") then
    table.sort(tooltipInfo.characters, CharacterAndRealmComparator)
    table.sort(tooltipInfo.guilds, GuildAndRealmComparator)
  else
    table.sort(tooltipInfo.characters, function(a, b)
      local left = a.bags + a.bank + a.mail + a.equipped + a.void + a.auctions
      local right = b.bags + b.bank + b.mail + b.equipped + b.void + b.auctions
      if left == right then
        return CharacterAndRealmComparator(a, b)
      else
        return left > right
      end
    end)
    table.sort(tooltipInfo.guilds, function(a, b)
      if a.bank == b.bank then
        return GuildAndRealmComparator(a, b)
      else
        return a.bank > b.bank
      end
    end)
  end

  if not addonTable.Config.Get(addonTable.Config.Options.SHOW_GUILD_BANKS_IN_TOOLTIPS) then
    tooltipInfo.guilds = {}
  end

  if #tooltipInfo.characters == 0 and #tooltipInfo.guilds == 0 and tooltipInfo.warband[1] == 0 then
    return
  end

  -- Used to ease adding to battle pet tooltip which doesn't have AddDoubleLine
  local function AddDoubleLine(left, right, ...)
    if tooltip.AddDoubleLine then
      tooltip:AddDoubleLine(left, right, ...)
    elseif tooltip.PetType then
      LibBattlePetTooltipLine:AddDoubleLine(tooltip, left, right)
    end
  end

  local result = "  "
  local totals = 0
  local seenRealms = {}

  for index, s in ipairs(tooltipInfo.characters) do
    totals = totals + s.bags + s.bank + s.mail + s.equipped + s.void + s.auctions
    seenRealms[s.realmNormalized] = true
  end
  for index, s in ipairs(tooltipInfo.guilds) do
    totals = totals + s.bank
    seenRealms[s.realmNormalized] = true
  end
  totals = totals + tooltipInfo.warband[1]
  seenRealms[GetNormalizedRealmName() or ""] = true -- ensure realm name is shown for a different realm

  local realmCount = 0
  for realm in pairs(seenRealms) do
    realmCount = realmCount + 1
  end
  local appendRealm = false
  if realmCount > 1 then
    appendRealm = true
  end

  if totals == 0 then
    return
  end

  local blankLineAdded = false
  if addonTable.Config.Get(addonTable.Config.Options.SHOW_BLANK_LINE_BEFORE_INVENTORY) then
    tooltip:AddLine(" ")
    blankLineAdded = true
  end

  if not addonTable.Config.Get(addonTable.Config.Options.SHOW_TOTAL_LINE_AFTER_CHARACTERS) then
    AddDoubleLine(addonTable.Locales.INVENTORY, SafeLinkFontColor:WrapTextInColorCode(addonTable.Locales.TOTAL_X:format(SafeWhiteFontColor:WrapTextInColorCode(totals))))
  end

  local charactersShown = 0
  for _, s in ipairs(tooltipInfo.characters) do
    local entries = {}
    if s.bags > 0 then
      table.insert(entries, addonTable.Locales.BAGS_X:format(SafeWhiteFontColor:WrapTextInColorCode(s.bags)))
    end
    if s.bank > 0 then
      table.insert(entries, addonTable.Locales.BANK_X:format(SafeWhiteFontColor:WrapTextInColorCode(s.bank)))
    end
    if s.mail > 0 then
      table.insert(entries, addonTable.Locales.MAIL_X:format(SafeWhiteFontColor:WrapTextInColorCode(s.mail)))
    end
    if s.equipped > 0 then
      table.insert(entries, addonTable.Locales.EQUIPPED_X:format(SafeWhiteFontColor:WrapTextInColorCode(s.equipped)))
    end
    if s.void > 0 then
      table.insert(entries, addonTable.Locales.VOID_X:format(SafeWhiteFontColor:WrapTextInColorCode(s.void)))
    end
    if s.auctions > 0 then
      table.insert(entries, addonTable.Locales.AUCTIONS_X:format(SafeWhiteFontColor:WrapTextInColorCode(s.auctions)))
    end
    local character = s.character
    if appendRealm then
      character = character .. "-" .. s.realmNormalized
    end
    if s.className then
      local classColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[s.className]
      if classColor then
        local colorStr = classColor.colorStr
        if not colorStr then
          colorStr = ("ff%02x%02x%02x"):format(
            math.floor((classColor.r or 1) * 255 + 0.5),
            math.floor((classColor.g or 1) * 255 + 0.5),
            math.floor((classColor.b or 1) * 255 + 0.5)
          )
        end
        character = "|c" .. colorStr .. character .. "|r"
      end
    end
    if addonTable.Config.Get(addonTable.Config.Options.SHOW_CHARACTER_RACE_ICONS) and s.race then
      character = addonTable.Utilities.GetCharacterIcon(s.race, s.sex) .. " " .. character
    end
    if #entries > 0 then
      if charactersShown >= addonTable.Config.Get("tooltips_character_limit") then
        tooltip:AddLine("  ...")
        break
      end
      AddDoubleLine("  " .. character, SafeLinkFontColor:WrapTextInColorCode(strjoin(", ", unpack(entries))))
      charactersShown = charactersShown + 1
    end
  end

  for index = 1, math.min(#tooltipInfo.guilds, addonTable.Config.Get("tooltips_character_limit")) do
    local s = tooltipInfo.guilds[index]
    local output = addonTable.Locales.GUILD_X:format(SafeWhiteFontColor:WrapTextInColorCode(s.bank))
    local guild = SafeTransmogrifyFontColor:WrapTextInColorCode(s.guild)
    if appendRealm then
      guild = guild .. "-" .. s.realmNormalized
    end
    if addonTable.Config.Get(addonTable.Config.Options.SHOW_CHARACTER_RACE_ICONS) then
      guild = addonTable.Utilities.GetGuildIcon() .. " " .. guild
    end
    AddDoubleLine("  " .. guild, SafeLinkFontColor:WrapTextInColorCode(output))
  end
  if #tooltipInfo.guilds > addonTable.Config.Get("tooltips_character_limit") then
    tooltip:AddLine("  ...")
  end
  if tooltipInfo.warband[1] > 0 then
    local icon = ""
    if addonTable.Config.Get(addonTable.Config.Options.SHOW_CHARACTER_RACE_ICONS) then
      icon = addonTable.Utilities.GetWarbandIcon() .. " "
    end
    AddDoubleLine("  " .. icon .. SafePassiveSpellFontColor:WrapTextInColorCode(addonTable.Locales.WARBAND), SafeLinkFontColor:WrapTextInColorCode(addonTable.Locales.BANK_X:format(SafeWhiteFontColor:WrapTextInColorCode(tooltipInfo.warband[1]))))
  end

  if addonTable.Config.Get(addonTable.Config.Options.SHOW_TOTAL_LINE_AFTER_CHARACTERS) then
    if addonTable.Config.Get(addonTable.Config.Options.SHOW_BLANK_LINE_BEFORE_INVENTORY) and not blankLineAdded then
      tooltip:AddLine(" ")
    end
    AddDoubleLine(addonTable.Locales.INVENTORY, SafeLinkFontColor:WrapTextInColorCode(addonTable.Locales.TOTAL_X:format(SafeWhiteFontColor:WrapTextInColorCode(totals))))
  end

  if addonTable.Constants.IsClassic then
    tooltip:Show()
  end
end

function addonTable.Tooltips.AddCurrencyLines(tooltip, currencyID)
  if tIndexOf(addonTable.Constants.SharedCurrencies, currencyID) ~= nil then
    return
  end

  local summary = addonTable.Tracking.GetCurrencyTooltipData(currencyID, addonTable.Config.Get("tooltips_connected_realms_only_2"), addonTable.Config.Get("tooltips_faction_only"))

  if addonTable.Config.Get("tooltips_sort_by_name") then
    table.sort(summary, CharacterAndRealmComparator)
  else
    table.sort(summary, function(a, b)
      if a.quantity == b.quantity then
        return CharacterAndRealmComparator(a, b)
      else
        return a.quantity > b.quantity
      end
    end)
  end

  local quantity = 0
  local seenRealms = {}

  for index, s in ipairs(summary) do
    quantity = quantity + s.quantity
    seenRealms[s.realmNormalized] = true
  end
  seenRealms[GetNormalizedRealmName() or ""] = true -- ensure realm name is shown for a different realm

  if quantity == 0 then -- nothing to show
    return
  end

  local realmCount = 0
  for realm in pairs(seenRealms) do
    realmCount = realmCount + 1
  end
  local appendRealm = false
  if realmCount > 1 then
    appendRealm = true
  end

  tooltip:AddDoubleLine(addonTable.Locales.ALL_CHARACTERS_COLON, SafeWhiteFontColor:WrapTextInColorCode(FormatLargeNumber(quantity)))
  for index = 1, math.min(#summary, addonTable.Config.Get("tooltips_character_limit")) do
    local s = summary[index]
    local character = s.character
    if appendRealm then
      character = character .. "-" .. s.realmNormalized
    end
    if s.className then
      character = "|c" .. (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[s.className].colorStr .. character .. "|r"
    end
    if addonTable.Config.Get(addonTable.Config.Options.SHOW_CHARACTER_RACE_ICONS) and s.race then
      character = addonTable.Utilities.GetCharacterIcon(s.race, s.sex) .. " " .. character
    end
    tooltip:AddDoubleLine("  " .. character, SafeWhiteFontColor:WrapTextInColorCode(FormatLargeNumber(s.quantity)))
  end
  if #summary > addonTable.Config.Get("tooltips_character_limit") then
    tooltip:AddLine("  ...")
  end

  if addonTable.Constants.IsClassic then
    tooltip:Show()
  end
end
