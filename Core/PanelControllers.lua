local _, Addon = ...

local Controllers = {}
Addon.PanelControllers = Controllers
Controllers.items = {}

local function genericController(id)
    return {
        id = id,
        Apply = function(_, frame, layout)
            return Addon.Panels:Place(frame, layout)
        end,
        Restore = function(_, frame)
            return Addon.Panels:Restore(frame)
        end,
    }
end

for _, id in ipairs({ "generic", "world-map", "social", "professions" }) do
    Controllers.items[id] = genericController(id)
end

-- Blizzard's separate container frames are independently positioned rather than
-- all being centered on the same spot. Combined bags and bank remain single panels.
Controllers.items.bags = {
    id = "bags",
    Apply = function(_, frame, layout)
        local name = frame.GetName and frame:GetName() or ""
        if type(name) ~= "string" or not name:match("^ContainerFrame%d+$") then
            return Addon.Panels:Place(frame, layout)
        end
        local combined = _G.ContainerFrameCombinedBags
        if combined and combined.IsShown and combined:IsShown() then
            return Addon.Panels:Restore(frame)
        end

        local visible, maxWidth, maxHeight = {}, 1, 1
        for index = 1, 10 do
            local candidate = _G["ContainerFrame" .. index]
            if candidate and candidate.IsShown and candidate:IsShown() then
                visible[#visible + 1] = candidate
                maxWidth = math.max(maxWidth, candidate.GetWidth and candidate:GetWidth() or 0)
                maxHeight = math.max(maxHeight, candidate.GetHeight and candidate:GetHeight() or 0)
            end
        end
        if #visible == 0 then return Addon.Panels:Place(frame, layout) end

        local columns = #visible >= 2 and layout.workspace.width >= maxWidth * 1.1 and 2 or 1
        local rows = math.ceil(#visible / columns)
        local index = 1
        for i, candidate in ipairs(visible) do
            if candidate == frame then index = i; break end
        end
        local col = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        local cellWidth = layout.workspace.width / columns
        local cellHeight = layout.canvasHeight / rows
        local profile = Addon:GetProfile()
        local effectiveScale = math.min(profile.panelScale or 1,
            cellWidth / maxWidth, cellHeight / maxHeight)
        local x = layout.workspace.left + (col + 0.5) * cellWidth - layout.canvasWidth / 2
        local y = layout.canvasHeight / 2 - (row + 0.5) * cellHeight
        return Addon.Panels:Place(frame, layout, { x = x, y = y, scale = effectiveScale })
    end,
    Restore = function(_, frame)
        return Addon.Panels:Restore(frame)
    end,
}

function Controllers:Get(id)
    return self.items[id]
end
