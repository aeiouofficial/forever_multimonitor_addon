local _, Addon = ...

local MapEscape = { removed = false, originalIndex = nil, removedIndices = {} }
Addon.MapEscape = MapEscape

local function findIndex()
    if type(UISpecialFrames) ~= "table" then return nil end
    for index, value in ipairs(UISpecialFrames) do
        if value == "WorldMapFrame" then return index end
    end
    return nil
end

function MapEscape:Restore()
    if not self.removed then return false end
    if type(UISpecialFrames) ~= "table" then return false end
    if not findIndex() then
        -- Restore every entry that was present before the addon took ownership.
        for _, originalIndex in ipairs(self.removedIndices) do
            table.insert(UISpecialFrames, math.min(originalIndex, #UISpecialFrames + 1), "WorldMapFrame")
        end
    end
    self.removed = false
    self.originalIndex = nil
    self.removedIndices = {}
    return true
end

function MapEscape:Sync()
    if type(UISpecialFrames) ~= "table" then return false end
    local profile = Addon.db and Addon:GetProfile() or nil
    local enabled = Addon.db and Addon.db.enabled
        and profile and profile.mapStaysOpenOnEscape ~= false

    if enabled then
        -- Matches the posted ESC macro without executing it again after reload.
        local found = {}
        for index = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[index] == "WorldMapFrame" then
                table.insert(found, 1, index)
                table.remove(UISpecialFrames, index)
            end
        end
        if #found > 0 then
            self.removed = true
            if #self.removedIndices == 0 then self.removedIndices = found end
            self.originalIndex = self.removedIndices[1]
        end
    else
        self:Restore()
    end
    return true
end
