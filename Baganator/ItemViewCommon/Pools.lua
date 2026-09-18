---@class addonTableBaganator
local addonTable = select(2, ...)
local classicCachedObjectCounter = 0

-- Stock 3.3.5a has no reliable FramePool_HideAndClearAnchors helper. More
-- importantly, recycled item buttons can keep anchors/visual state from the
-- previous layout. That is catastrophic when a fresh character creates a new
-- bag/bank layout: a recycled button can be simultaneously anchored to its old
-- and new positions and stretch its icon over the entire view. Reset every bit
-- of layout-sensitive state before an object is returned to a Baganator pool.
local function ResetBaganatorPooledFrame(_, frame)
  if not frame then return end
  if frame.Hide then frame:Hide() end
  if frame.ClearAllPoints then frame:ClearAllPoints() end
  if frame.SetScale then frame:SetScale(1) end

  frame.__bgr335BagID = nil
  frame.__bgr335SlotID = nil
  frame.__bgr335ItemIDOrLink = nil
  frame.BGR = nil
  frame.count = nil
  frame.readable = nil

  local name = frame.GetName and frame:GetName()
  local icon = frame.icon or frame.IconTexture or (name and (_G[name .. "IconTexture"] or _G[name .. "Icon"]))
  if icon then
    if icon.SetTexture then icon:SetTexture(nil) end
    if icon.SetVertexColor then icon:SetVertexColor(1, 1, 1, 1) end
    if icon.SetAlpha then icon:SetAlpha(1) end
  end

  local count = frame.Count or frame.CountText or (name and (_G[name .. "Count"] or _G[name .. "CountText"]))
  if count and count.SetText then count:SetText("") end
  if frame.IconBorder and frame.IconBorder.Hide then frame.IconBorder:Hide() end
  if frame.searchOverlay and frame.searchOverlay.Hide then frame.searchOverlay:Hide() end
  if frame.ItemContextOverlay and frame.ItemContextOverlay.Hide then frame.ItemContextOverlay:Hide() end
  if frame.NewItemTexture and frame.NewItemTexture.Hide then frame.NewItemTexture:Hide() end
  if frame.BattlepayItemTexture and frame.BattlepayItemTexture.Hide then frame.BattlepayItemTexture:Hide() end
  if frame.bagTypeIcon then
    if frame.bagTypeIcon.SetTexture then frame.bagTypeIcon:SetTexture(nil) end
    if frame.bagTypeIcon.SetAlpha then frame.bagTypeIcon:SetAlpha(1) end
    if frame.bagTypeIcon.Hide then frame.bagTypeIcon:Hide() end
  end
  frame.tooltipHeader = nil
  if frame.cornerPlugins then
    for _, widget in pairs(frame.cornerPlugins) do
      if widget and widget.Hide then widget:Hide() end
    end
  end
end

function addonTable.ItemViewCommon.GetCachedItemButtonPool(self)
  if addonTable.Constants.IsRetail then
    return CreateFramePool("ItemButton", self, "BaganatorRetailCachedItemButtonTemplate", nil, false, function(b) b:UpdateTextures() end)
  else
    return CreateObjectPool(function()
      classicCachedObjectCounter = classicCachedObjectCounter + 1
      local b = CreateFrame("Button", "BGRCachedItemButton" .. classicCachedObjectCounter, self, "BaganatorClassicCachedItemButtonTemplate")
      b:UpdateTextures()
      return b
    end, ResetBaganatorPooledFrame)
  end
end

function addonTable.ItemViewCommon.GetLiveItemButtonPool(self)
  if addonTable.Constants.IsRetail then
    return CreateFramePool("ItemButton", self, "BaganatorRetailLiveContainerItemButtonTemplate", nil, false, function(b) b:UpdateTextures() end)
  else
    return CreateObjectPool(function()
      classicCachedObjectCounter = classicCachedObjectCounter + 1
      local b = CreateFrame("Button", "BGRLiveItemButton" .. classicCachedObjectCounter, self, "BaganatorClassicLiveContainerItemButtonTemplate")
      b:UpdateTextures()
      return b
    end, ResetBaganatorPooledFrame)
  end
end

function addonTable.ItemViewCommon.GetLiveGuildItemButtonPool(parent)
  if addonTable.Constants.IsRetail then
    return CreateFramePool("ItemButton", parent, "BaganatorRetailLiveGuildItemButtonTemplate", nil, false, function(b) b:UpdateTextures() end)
  else
    return CreateObjectPool(function()
      classicCachedObjectCounter = classicCachedObjectCounter + 1
      local b = CreateFrame("Button", "BGRLiveItemButton" .. classicCachedObjectCounter, parent, "BaganatorClassicLiveGuildItemButtonTemplate")
      b:UpdateTextures()
      return b
    end, ResetBaganatorPooledFrame)
  end
end

function addonTable.ItemViewCommon.GetTabButtonPool(parent)
  if addonTable.Constants.IsRetail then
    return CreateFramePool("Button", parent, "BaganatorRetailTabButtonTemplate")
  else
    return CreateObjectPool(function()
      classicCachedObjectCounter = classicCachedObjectCounter + 1
      return CreateFrame("Button", "BGRItemViewCommonTabButton" .. classicCachedObjectCounter, parent, "BaganatorClassicTabButtonTemplate")
    end, ResetBaganatorPooledFrame)
  end
end

function addonTable.ItemViewCommon.GetSideTabButtonPool(parent)
  return CreateObjectPool(function()
    classicCachedObjectCounter = classicCachedObjectCounter + 1
    return CreateFrame("Button", "BGRItemViewCommonTabButton" .. classicCachedObjectCounter, parent, "BaganatorRightSideTabButtonTemplate")
  end, ResetBaganatorPooledFrame)
end
