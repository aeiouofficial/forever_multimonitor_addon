local _, Addon = ...

local Controllers = {}
Addon.PanelControllers = Controllers
Controllers.items = {}

local function createController(id)
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

for _, id in ipairs({ "generic", "world-map", "social", "professions", "bags" }) do
    Controllers.items[id] = createController(id)
end

function Controllers:Get(id)
    return self.items[id]
end