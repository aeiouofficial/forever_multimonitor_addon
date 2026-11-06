local addonName, namespace = ...

namespace = namespace or {}
_G.ForeverMultiMonitor = namespace

namespace.name = addonName
namespace.version = "0.1.0"
namespace.pendingWork = false
namespace.pendingCallback = nil
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

function namespace:RunWhenSafe(callback)
    if type(callback) ~= "function" then
        return false
    end

    if InCombatLockdown and InCombatLockdown() then
        self.pendingWork = true
        self.pendingCallback = callback
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
    if not self.pendingWork then
        return
    end

    local callback = self.pendingCallback
    self.pendingWork = false
    self.pendingCallback = nil

    if callback then
        self:RunWhenSafe(callback)
    end
end
