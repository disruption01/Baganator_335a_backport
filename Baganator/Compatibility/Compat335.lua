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

-- Atlas compatibility must stay local to Baganator. Some 3.3.5a custom clients
-- ship partial SharedXML atlas support: SetAtlas exists, but many modern atlases
-- do not. Calling those methods directly can throw and abort a frame's OnLoad.
function addonTable.Compatibility.GetAtlasInfo(atlas)
  local cTexture = rawget(_G, "C_Texture")
  local getAtlasInfo = type(cTexture) == "table" and cTexture.GetAtlasInfo
  if type(getAtlasInfo) == "function" then
    local ok, info = pcall(getAtlasInfo, atlas)
    if ok then
      return info
    end
  end
  return nil
end



-- Do not rely on a custom client's global CreateFramePool implementation.
-- Some 3.3.5a UI packs ship an older/partial SharedXML Pools.lua where
-- CreateFramePool("Frame", parent) crashes when frameTemplate is nil while it
-- tries to build an internal frame name. Baganator intentionally creates
-- several anonymous/template-less pools, so keep this implementation private
-- to Baganator instead of replacing the client's global API.
function addonTable.Compatibility.CreateFramePool(frameType, parent, template, resetFunc, forbidden, onAcquire)
  local pool = {
    activeObjects = {},
    inactiveObjects = {},
    numActiveObjects = 0,
    frameType = frameType,
    parent = parent,
    frameTemplate = template,
  }

  local function DefaultReset(_, frame)
    if frame.Hide then frame:Hide() end
    if frame.ClearAllPoints then frame:ClearAllPoints() end
  end

  pool.resetterFunc = resetFunc or DefaultReset

  function pool:Acquire()
    local frame = table.remove(self.inactiveObjects)
    local isNew = false
    if not frame then
      local createType = self.frameType == "ItemButton" and "Button" or self.frameType
      frame = CreateFrame(createType, nil, self.parent, self.frameTemplate)
      isNew = true
    end

    self.activeObjects[frame] = true
    self.numActiveObjects = self.numActiveObjects + 1

    if onAcquire then
      onAcquire(frame, isNew)
    end
    if frame.Show then
      frame:Show()
    end

    return frame, isNew
  end

  function pool:Release(frame)
    if not frame or not self.activeObjects[frame] then return false end
    self.activeObjects[frame] = nil
    self.numActiveObjects = math.max(0, self.numActiveObjects - 1)
    if self.resetterFunc then
      self.resetterFunc(self, frame)
    end
    self.inactiveObjects[#self.inactiveObjects + 1] = frame
    return true
  end

  function pool:ReleaseAll()
    local frames = {}
    for frame in pairs(self.activeObjects) do
      frames[#frames + 1] = frame
    end
    for _, frame in ipairs(frames) do
      self:Release(frame)
    end
  end

  function pool:GetNumActive()
    return self.numActiveObjects
  end

  function pool:IsActive(frame)
    return not not self.activeObjects[frame]
  end

  function pool:EnumerateActive()
    return pairs(self.activeObjects)
  end

  function pool:EnumerateInactive()
    return ipairs(self.inactiveObjects)
  end

  function pool:GetTemplate()
    return self.frameTemplate
  end

  return pool
end

function addonTable.Compatibility.SetAtlas(texture, atlas, useAtlasSize, fallbackTexture)
  if not texture then return false end

  if type(texture.SetAtlas) == "function" then
    local ok = pcall(texture.SetAtlas, texture, atlas, useAtlasSize)
    if ok then
      return true
    end
  end

  if type(texture.SetTexture) == "function" then
    texture:SetTexture(fallbackTexture)
  end
  return false
end

