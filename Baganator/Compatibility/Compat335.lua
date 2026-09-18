if not BAGANATOR_335 then return end
local _, addonTable = ...
addonTable.Compatibility = addonTable.Compatibility or {}
addonTable.Compatibility.Is335 = true


-- WoW 3.3.5a buttons commonly expose Enable()/Disable(), but not SetEnabled(bool).
function addonTable.Compatibility.SetEnabled(frame, state)
  if not frame then return end
  state = not not state
  if frame.SetEnabled then
    return frame:SetEnabled(state)
  end
  if state then
    if frame.Enable then frame:Enable() end
  else
    if frame.Disable then frame:Disable() end
  end
  frame.enabled = state
end


function addonTable.Compatibility.ApplyDarkBackdrop(frame)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  if frame.SetBackdropColor then frame:SetBackdropColor(0.025, 0.02, 0.04, 1) end
  if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0.22, 0.22, 0.22, 1) end
end
