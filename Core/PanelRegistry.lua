local _, Addon = ...

local Registry = {}
Addon.PanelRegistry = Registry

local definitions = {}
local function isForeverProfessionsFrame(name)
    return name == "TradeSkillFrame" or name == "CraftFrame"
        or name:match("^Professions") ~= nil
        or name:match("^Profession") ~= nil
        or name:match("TradeSkill") ~= nil
end

local EXCLUDED_PREFIXES = {
    { prefix = "EditMode", reason = "protected" },
    { prefix = "ActionButton", reason = "protected" },
    { prefix = "MultiBar", reason = "protected" },
    { prefix = "CompactRaidFrame", reason = "protected" },
    { prefix = "PartyFrame", reason = "protected" },
    { prefix = "PlayerFrame", reason = "protected" },
    { prefix = "TargetFrame", reason = "protected" },
    { prefix = "PetActionBar", reason = "protected" },
    { prefix = "StanceBar", reason = "protected" },
    { prefix = "Possess", reason = "protected" },
    { prefix = "Vehicle", reason = "protected" },
    { prefix = "Boss", reason = "protected" },
    { prefix = "Bagnon", reason = "replacement-bags" },
    { prefix = "Baganator", reason = "replacement-bags" },
    { prefix = "AdiBags", reason = "replacement-bags" },
    { prefix = "BetterBags", reason = "replacement-bags" },
    { prefix = "ArkInventory", reason = "replacement-bags" },
    { prefix = "ARKINV_", reason = "replacement-bags" },
}

function Registry:Register(globalName, controller, family)
    if type(globalName) ~= "string" or globalName == "" or type(controller) ~= "string" or controller == "" then
        return false, "invalid panel registration"
    end
    if definitions[globalName] then
        return false, "panel already has a position owner"
    end
    definitions[globalName] = {
        name = globalName,
        controller = controller,
        family = family or "ordinary",
        route = true,
    }
    return true
end

function Registry:Classify(frame)
    if not frame or not frame.GetName then return nil end
    local name = frame:GetName()
    if type(name) ~= "string" or name == "" then return nil end

    if Addon.runtime and Addon.runtime.isForever and isForeverProfessionsFrame(name) then
        return {
            name = name,
            controller = nil,
            family = "forever-professions",
            route = false,
            reason = "Blizzard-owned on Forever; movement is disabled by default",
        }
    end

    for _, excluded in ipairs(EXCLUDED_PREFIXES) do
        if name:sub(1, #excluded.prefix) == excluded.prefix then
            return {
                name = name,
                controller = nil,
                family = excluded.reason,
                route = false,
                reason = excluded.reason,
            }
        end
    end
    return definitions[name]
end

function Registry:GetKnownNames()
    local names = {}
    for name in pairs(definitions) do names[#names + 1] = name end
    table.sort(names)
    return names
end

Registry:Register("WorldMapFrame", "world-map", "world-map")
Registry:Register("CharacterFrame", "generic", "character")
Registry:Register("SpellBookFrame", "generic", "spellbook")
Registry:Register("QuestLogFrame", "generic", "quest-log")
Registry:Register("ProfessionsFrame", "professions", "professions")
Registry:Register("AuctionHouseFrame", "generic", "auction-house")
Registry:Register("FriendsFrame", "social", "social")
Registry:Register("CommunitiesFrame", "social", "social")
Registry:Register("GuildFrame", "social", "social")
Registry:Register("SocialFrame", "social", "social")
Registry:Register("PVEFrame", "generic", "group-finder")
Registry:Register("CollectionsJournal", "generic", "collections")
Registry:Register("EncounterJournal", "generic", "encounters")
Registry:Register("AchievementFrame", "generic", "achievements")
Registry:Register("ContainerFrame1", "bags", "bags")
Registry:Register("ContainerFrame2", "bags", "bags")
Registry:Register("ContainerFrame3", "bags", "bags")
Registry:Register("ContainerFrame4", "bags", "bags")
Registry:Register("ContainerFrame5", "bags", "bags")
Registry:Register("ContainerFrame6", "bags", "bags")
Registry:Register("ContainerFrame7", "bags", "bags")
Registry:Register("ContainerFrame8", "bags", "bags")
Registry:Register("ContainerFrame9", "bags", "bags")
Registry:Register("ContainerFrame10", "bags", "bags")
Registry:Register("ContainerFrameCombinedBags", "bags", "bags")
Registry:Register("BankFrame", "bags", "bank")
Registry:Register("ReagentBankFrame", "bags", "bank")
Registry:Register("GuildBankFrame", "bags", "guild-bank")
