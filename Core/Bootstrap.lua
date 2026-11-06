local addonName, namespace = ...

namespace = namespace or {}
_G.ForeverMultiMonitor = namespace

namespace.name = addonName
namespace.version = "0.4.1"
namespace.pendingCallbacks = {}
namespace.pendingCallbackKeys = {}
namespace.lastError = nil
namespace.errorGeneration = 0

function namespace:Print(message)
    local prefix = "|cff79b8ffForever MultiMonitor|r "
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(message))
    elseif print then
        print("Forever MultiMonitor: " .. tostring(message))
    end
end

function namespace:ReportError(context, err)
    self.lastError = tostring(err)
    self.errorGeneration = (self.errorGeneration or 0) + 1
    self:Print(tostring(context) .. ": " .. tostring(err))
end

function namespace:RunWhenSafe(callback, key)
    if type(callback) ~= "function" then
        return false
    end

    if InCombatLockdown and InCombatLockdown() then
        if key and self.pendingCallbackKeys[key] then
            self.pendingCallbacks[self.pendingCallbackKeys[key]] = callback
        else
            self.pendingCallbacks[#self.pendingCallbacks + 1] = callback
            if key then
                self.pendingCallbackKeys[key] = #self.pendingCallbacks
            end
        end
        return false
    end

    local errorGeneration = self.errorGeneration or 0
    local ok, result, reason = pcall(callback)
    if not ok then
        self:ReportError("Operation failed", result)
        return false
    end
    if result == false and (self.errorGeneration or 0) == errorGeneration then
        self:ReportError("Operation rejected", reason or "callback returned false")
        return false
    end
    if result == false then return false end
    return true
end

function namespace:FlushPendingWork()
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local callbacks = self.pendingCallbacks
    self.pendingCallbacks = {}
    self.pendingCallbackKeys = {}

    for index, callback in ipairs(callbacks) do
        local errorGeneration = self.errorGeneration or 0
        local ok, result, reason = pcall(callback)
        if not ok then
            self:ReportError("Deferred operation " .. tostring(index) .. " failed", result)
        elseif result == false and (self.errorGeneration or 0) == errorGeneration then
            self:ReportError("Deferred operation " .. tostring(index) .. " rejected", reason or "callback returned false")
        end
    end
end
