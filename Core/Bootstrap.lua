local addonName, namespace = ...

namespace = namespace or {}
_G.ForeverMultiMonitor = namespace

namespace.name = addonName
namespace.version = "0.3.6"
namespace.pendingCallbacks = {}
namespace.pendingCallbackKeys = {}
namespace.lastError = nil

function namespace:Print(message)
    local prefix = "|cff79b8ffForeverMultiMonitor|r "
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(message))
    elseif print then
        print("ForeverMultiMonitor: " .. tostring(message))
    end
end

function namespace:ReportError(context, err)
    self.lastError = tostring(err)
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

    local ok, err = pcall(callback)
    if not ok then
        self:ReportError("Operation failed", err)
        return false
    end
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
        local ok, err = pcall(callback)
        if not ok then
            self:ReportError("Deferred operation " .. tostring(index) .. " failed", err)
        end
    end
end
