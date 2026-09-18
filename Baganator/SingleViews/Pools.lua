---@class addonTableBaganator
local addonTable = select(2, ...)
function addonTable.SingleViews.GetCollapsingBagSectionsPool(self)
  return CreateObjectPool(function(pool)
    local details = {
      live = CreateFrame("Frame", nil, self, "BaganatorLiveBagLayoutTemplate"),
      cached = CreateFrame("Frame", nil, self, "BaganatorCachedBagLayoutTemplate"),
      divider = CreateFrame("Frame", nil, self, "BaganatorBagDividerTemplate"),
      button = CreateFrame("Button", nil, self, "BaganatorTooltipIconButtonTemplate"),
    }
    local button = details.button
    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button:SetPoint("CENTER")
    button.Icon:SetSize(17, 17)
    button.Icon:SetPoint("CENTER")
    button:HookScript("OnEnter", function(self)
      addonTable.CallbackRegistry:TriggerEvent("HighlightBagItems", button.bagIDsToUse)

      if self.tooltipHeader then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipHeader)
        if self.tooltipText then
          GameTooltip:AddLine(self.tooltipText, 1, 1, 1, true)
        end
        GameTooltip:Show()
      end
    end)
    button:HookScript("OnLeave", function(self)
      addonTable.CallbackRegistry:TriggerEvent("ClearHighlightBag")

      GameTooltip:Hide()
    end)
    button:SetScript("OnShow", function(self)
      addonTable.CallbackRegistry:RegisterCallback("SearchMonitorComplete", self.CheckResults, self)
      addonTable.CallbackRegistry:RegisterCallback("SpecialBagToggled", self.CheckResults, self)
    end)
    button:SetScript("OnHide", function(self)
      addonTable.CallbackRegistry:UnregisterCallback("SearchMonitorComplete", self)
      addonTable.CallbackRegistry:UnregisterCallback("SpecialBagToggled", self)
      self.fadeAnimation:Stop()
      if self.Icon then self.Icon:SetAlpha(1) end
    end)
    -- Wrath's Alpha animation uses SetChange() and has no SetFromAlpha/
    -- SetToAlpha/SetTarget methods. Create the animation group on the icon
    -- itself so the same visual pulse works on both old and modern clients.
    button.fadeAnimation = button.Icon:CreateAnimationGroup()
    button.fadeAnimation:SetLooping("REPEAT")
    do
      local fade1 = button.fadeAnimation:CreateAnimation("Alpha")
      if fade1.SetFromAlpha and fade1.SetToAlpha then
        fade1:SetFromAlpha(1)
        fade1:SetToAlpha(0.4)
      elseif fade1.SetChange then
        fade1:SetChange(-0.6)
      end
      fade1:SetDuration(0.5)
      fade1:SetOrder(1)
      if fade1.SetSmoothing then fade1:SetSmoothing("IN_OUT") end

      local fade2 = button.fadeAnimation:CreateAnimation("Alpha")
      if fade2.SetFromAlpha and fade2.SetToAlpha then
        fade2:SetFromAlpha(0.4)
        fade2:SetToAlpha(1)
      elseif fade2.SetChange then
        fade2:SetChange(0.6)
      end
      fade2:SetDuration(0.5)
      fade2:SetOrder(2)
      if fade2.SetSmoothing then fade2:SetSmoothing("IN_OUT") end
    end
    function button:CheckResults(text)
      self.fadeAnimation:Stop()
      if self.Icon then self.Icon:SetAlpha(1) end
      text = text or button.lastSearch
      button.lastSearch = text
      if text == "" or not addonTable.Config.Get(addonTable.Config.Options.HIDE_SPECIAL_CONTAINER)[details.key] then
        return
      end
      local layout = details.live:IsShown() and details.live or details.cached
      for _, button in ipairs(layout.buttons) do
        if button.BGR and button.BGR.matchesSearch and (button.BGR.contextMatch == nil or button.BGR.contextMatch) then
          self.fadeAnimation:Play()
          return -- done
        end
      end
    end

    return details
  end,
  function(pool, details)
    details.live:Deallocate()
    details.live:Hide()
    details.live:ClearAllPoints()
    details.cached:Hide()
    details.cached:ClearAllPoints()
    details.divider:Hide()
    details.divider:ClearAllPoints()
    details.button:Hide()
    details.button:ClearAllPoints()
  end)
end
