"""Runtime regression tests using the WoW-compatible Lua 5.1 runtime from Lupa."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
from luaparser import ast

ROOT = Path(__file__).resolve().parents[1]
for lua_file in sorted((ROOT / 'Core').glob('*.lua')):
    ast.parse(lua_file.read_text(encoding='utf-8-sig'))
    print('PASS Lua 5.1 syntax parse:', lua_file.relative_to(ROOT))
lua = LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()
g.inCombat = True
lua.execute("""
InCombatLockdown = function() return inCombat end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
UIParent = { GetWidth = function() return 3000 end, GetHeight = function() return 900 end, GetCenter = function() return 1500, 450 end }
""")

addon_namespace = lua.table()
lua.execute((ROOT / "Core" / "Bootstrap.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon_namespace)
addon = g.ForeverMultiMonitor
lua.execute("ForeverMultiMonitorDB = { enabled = true, profile = { mainhandSide = 'right' } }; ForeverMultiMonitorCharDB = { panelPositions = { Legacy = { schema = 1, x = 0.1, y = -0.1 } } }")
lua.execute((ROOT / "Core" / "Config.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
addon.InitializeConfig(addon)
lua.execute("assert(ForeverMultiMonitor.db.activeProfile == 'Default', 'legacy settings were not migrated to Default profile'); local ok = ForeverMultiMonitor:CreateProfile('Work'); assert(ok, 'profile creation failed'); local duplicate = ForeverMultiMonitor:CreateProfile('work'); assert(not duplicate, 'case-insensitive duplicate profile name was accepted'); local invalid = ForeverMultiMonitor:CreateProfile('bad/name'); assert(not invalid, 'invalid profile name was accepted'); ForeverMultiMonitor:SetProfileValue('mainhandWidthPercent', 72); assert(ForeverMultiMonitor.db.profiles.Work.mainhandWidthPercent == 72, 'active profile was not saved'); assert(ForeverMultiMonitor:SetActiveProfile('Default'), 'Default profile could not be loaded'); assert(ForeverMultiMonitor:GetProfile().mainhandWidthPercent == 50, 'Default profile was overwritten'); assert(ForeverMultiMonitor:SetActiveProfile('Work'), 'Work profile could not be loaded'); assert(ForeverMultiMonitor:GetProfile().mainhandWidthPercent == 72, 'Work profile was not restored'); assert(not ForeverMultiMonitor:DeleteProfile('Work'), 'active profile was deleted'); assert(ForeverMultiMonitor:SetActiveProfile('Default'), 'could not return to Default'); assert(ForeverMultiMonitor:DeleteProfile('Work'), 'inactive profile could not be deleted'); assert(not ForeverMultiMonitor:DeleteProfile('Default'), 'Default profile must be protected')")
print("PASS Lua 5.1: named profile migration, create, save, switch and safe delete")
lua.execute("assert(ForeverMultiMonitor.charDB.panelPositionSchema == 1, 'panel position schema was not initialized'); assert(ForeverMultiMonitor.charDB.panelPositions.Legacy.x == 0.1, 'existing position data was discarded')")
lua.execute("ForeverMultiMonitorCharDB = { panelPositionSchema = 2, panelPositions = { Keep = { schema = 2 } } }; ForeverMultiMonitor:InitializeConfig(); assert(ForeverMultiMonitor.charDB.panelPositionSchema == 2 and ForeverMultiMonitor.charDB.panelPositions.Keep ~= nil, 'future schema data was mutated')")
print("PASS Lua 5.1: character position schema migration and future-schema read-only handling")
lua.execute((ROOT / "Core" / "Geometry.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute("local left = ForeverMultiMonitor.Geometry:Calculate({ mainhandSide = 'left', mainhandWidthPercent = 50, seamUiUnits = 20 }); assert(left and left.mainhand.left == 0 and left.mainhand.right == 1490 and left.workspace.left == 1510 and left.workspace.right == 3000, 'left geometry mismatch'); local right = ForeverMultiMonitor.Geometry:Calculate({ mainhandSide = 'right', mainhandWidthPercent = 50, seamUiUnits = 20 }); assert(right and right.workspace.left == 0 and right.mainhand.left == 1510 and right.mainhand.right == 3000, 'right geometry mismatch'); local narrow = ForeverMultiMonitor.Geometry:Calculate({ mainhandSide = 'left', mainhandWidthPercent = 90, seamUiUnits = 20 }); assert(narrow and narrow.workspace.width > 0, '90 percent width lost workspace'); local invalid = ForeverMultiMonitor.Geometry:Calculate({ mainhandSide = 'left', mainhandWidthPercent = 50, seamUiUnits = 800 }); assert(invalid == nil, 'invalid seam should be rejected')")
print("PASS Lua 5.1: left/right geometry, seam, width limits and invalid geometry")
lua.execute("rawMouseValue = '0'; function GetCVar(name) if name == 'rawMouseEnable' then return rawMouseValue end end; function SetCVar(name, value) if name ~= 'rawMouseEnable' then error('unexpected CVar') end; rawMouseValue = tostring(value) end")
lua.execute((ROOT / "Core" / "RawMouse.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute("ForeverMultiMonitor.db.enabled = true; ForeverMultiMonitor.RawMouse:Sync(); assert(rawMouseValue == '1' and ForeverMultiMonitor.db.rawMousePrevious == '0', 'raw mouse was not enabled with original value saved'); ForeverMultiMonitor.RawMouse:Sync(); assert(ForeverMultiMonitor.db.rawMousePrevious == '0', 'repeated enable overwrote original CVar'); ForeverMultiMonitor:SetProfileValue('rawMouseEnabled', false); ForeverMultiMonitor.RawMouse:Sync(); assert(rawMouseValue == '0' and not ForeverMultiMonitor.db.rawMouseOwned, 'raw mouse original value was not restored'); ForeverMultiMonitor:SetProfileValue('rawMouseEnabled', true); rawMouseValue = '1'; ForeverMultiMonitor.RawMouse:Sync(); assert(ForeverMultiMonitor.db.rawMousePrevious == '1', 'pre-enabled raw mouse state was not remembered'); ForeverMultiMonitor.RawMouse:Restore(); assert(rawMouseValue == '1', 'pre-enabled raw mouse state was not preserved'); rawMouseValue = '0'")
print("PASS Lua 5.1: raw mouse CVar save/enable/restore and pre-enabled state")
lua.execute("ForeverMultiMonitor.db.rawMouseOwned = true; ForeverMultiMonitor.db.rawMousePrevious = nil; rawMouseValue = '0'; ForeverMultiMonitor.RawMouse:Enable(); assert(rawMouseValue == '0', 'incomplete ownership state overwrote CVar'); ForeverMultiMonitor.db.rawMouseOwned = nil")
print("PASS Lua 5.1: malformed raw-mouse ownership fails safe without changing CVar")

# Queue behavior: keyed desired state is coalesced; independent work is retained.
lua.execute("""
local calls = {}
ForeverMultiMonitor:RunWhenSafe(function() table.insert(calls, "stale") end, "layout-state")
ForeverMultiMonitor:RunWhenSafe(function() table.insert(calls, "latest") end, "layout-state")
ForeverMultiMonitor:RunWhenSafe(function() table.insert(calls, "independent") end)
inCombat = false
ForeverMultiMonitor:FlushPendingWork()
assert(table.concat(calls, ",") == "latest,independent", table.concat(calls, ","))
""")
print("PASS Lua 5.1: combat queue coalesces keyed state and preserves independent work")

# Install secure-hook and frame mocks, then exercise a frame created after addon load.
lua.execute("""
local secureHooks = {}
function hooksecurefunc(name, callback)
  secureHooks[name] = secureHooks[name] or {}
  table.insert(secureHooks[name], callback)
end
function ShowUIPanel(frame)
  frame.shown = true
  for _, callback in ipairs(secureHooks.ShowUIPanel or {}) do callback(frame) end
end
function ToggleFrame(frameOrName)
  local frame = type(frameOrName) == "string" and _G[frameOrName] or frameOrName
  if frame then
    frame.shown = true
    for _, callback in ipairs(secureHooks.ToggleFrame or {}) do callback(frameOrName) end
  end
end
function makeFrame(initialPoints, initialScale)
  local f = { points = initialPoints or {}, scale = initialScale or 1, shown = false, hooks = {}, centerX = 1500, centerY = 450 }
  function f:GetNumPoints() return #self.points end
  function f:GetPoint(i) local p = self.points[i]; if p then return p[1], p[2], p[3], p[4], p[5] end end
  function f:HookScript(name, callback) self.hooks[name] = self.hooks[name] or {}; table.insert(self.hooks[name], callback) end
  function f:IsShown() return self.shown end
  function f:ClearAllPoints() self.points = {} end
  function f:SetPoint(...) local args = {...}; table.insert(self.points, args); if args[1] == "CENTER" then self.centerX = 1500 + (args[4] or 0); self.centerY = 450 + (args[5] or 0) end end
  function f:SetAllPoints(target) self:ClearAllPoints(); self:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0); self:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0) end
  function f:GetScale() return self.scale end
  function f:GetCenter() return self.centerX, self.centerY end
  function f:SetScale(value) self.scale = value end
  function f:GetWidth() return 200 end
  function f:GetHeight() return 100 end
  function f:GetName() return self.name end
  return f
end
function CreateFrame(frameType, globalName)
  local frame = makeFrame({}, 1)
  frame.frameType = frameType
  frame.name = globalName
  if globalName then _G[globalName] = frame end
  for _, callback in ipairs(secureHooks.CreateFrame or {}) do callback(frameType, globalName) end
  return frame
end
ForeverMultiMonitor.db = { enabled = true }
ForeverMultiMonitor.charDB = { panelPositionSchema = 1, panelPositions = {} }
ForeverMultiMonitor.GetProfile = function() return { panelScale = 0.8 } end
ForeverMultiMonitor.Geometry = { Calculate = function() return { workspace = { width = 500, centerX = 700, centerY = 0 }, canvasWidth = 3000, canvasHeight = 900 } end }
ForeverMultiMonitor.ReportError = function(_, message, err) error(tostring(message) .. ": " .. tostring(err)) end
""")
lua.execute((ROOT / "Core" / "PanelRegistry.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute((ROOT / "Core" / "PanelControllers.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute((ROOT / "Core" / "Panels.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
addon.Panels.Initialize(addon.Panels)
lua.execute("local ok = ForeverMultiMonitor.PanelRegistry:Register('WorldMapFrame', 'generic', 'duplicate'); assert(not ok, 'registry allowed two position owners for one frame')")
print("PASS Lua 5.1: registry rejects duplicate frame ownership")
lua.execute("""
local first = makeFrame({{"TOPLEFT", UIParent, "TOPLEFT", 12, -20}, {"BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -30, 40}}, 1.25)
first.name = "WorldMapFrame"
ShowUIPanel(first)
assert(#first.hooks.OnShow == 1, "late ShowUIPanel frame did not receive one hook")
assert(#first.points == 1 and first.scale < 1.25, "late panel was not routed/scaled")
ForeverMultiMonitor.Panels:Restore(first)
assert(#first.points == 2, "multi-anchor state was not restored")
assert(first.scale == 1.25, "original scale was not restored")
assert(ForeverMultiMonitor.Panels.originalPoints[first] == nil, "stale panel snapshot remained")
ForeverMultiMonitor.Panels:Initialize()
ShowUIPanel(first)
assert(#first.hooks.OnShow == 1, "repeated initialization installed duplicate hooks")
local wide = makeFrame({}, 1)
wide.name = "AuctionHouseFrame"
wide.GetWidth = function() return 2000 end
wide.GetHeight = function() return 100 end
ShowUIPanel(wide)
assert(math.abs(wide.scale - 0.25) < 0.000001, "panel scale minimum overflowed the Offhand workspace width")
ForeverMultiMonitor.Panels:Restore(wide)
local empty = makeFrame({}, 1)
empty.name = "CharacterFrame"
ShowUIPanel(empty)
ForeverMultiMonitor.Panels:Restore(empty)
assert(#empty.points == 0, "restore invented an anchor for an originally anchorless frame")
first.centerX, first.centerY = 1800, 600
first.hooks.OnDragStop[1](first)
local saved = ForeverMultiMonitor.charDB.panelPositions.WorldMapFrame
assert(saved and math.abs(saved.x - 0.1) < 0.000001 and math.abs(saved.y - (1 / 6)) < 0.000001, "drag-stop position was not normalized and saved")
local restoredPosition = makeFrame({}, 1)
restoredPosition.name = "WorldMapFrame"
ShowUIPanel(restoredPosition)
assert(math.abs(restoredPosition.centerX - 1800) < 0.001 and math.abs(restoredPosition.centerY - 600) < 0.001, "saved panel position was not reapplied")
print('PASS Lua 5.1: per-character drag position save and reapply')
inCombat = true
first.centerX = 2100
first.hooks.OnDragStop[1](first)
assert(math.abs(ForeverMultiMonitor.charDB.panelPositions.WorldMapFrame.x - 0.1) < 0.000001, 'position changed during combat')
inCombat = false
ForeverMultiMonitor:FlushPendingWork()
assert(math.abs(ForeverMultiMonitor.charDB.panelPositions.WorldMapFrame.x - 0.2) < 0.000001, 'deferred drag position was not saved after combat')
print('PASS Lua 5.1: combat-safe deferred drag position save')
local created = CreateFrame("Frame", "CollectionsJournal")
created.shown = true
assert(#created.hooks.OnShow == 1, "CreateFrame post-hook did not discover a late registered frame")
ShowUIPanel(created)
assert(#created.points == 1, "CreateFrame-discovered frame was not routed")
local late = makeFrame({}, 1)
late.name = "FriendsFrame"
_G.LateRuntimePanel = late
ToggleFrame("LateRuntimePanel")
assert(#late.hooks.OnShow == 1 and #late.points == 1, "ToggleFrame name discovery failed")
local protected = makeFrame({}, 1)
protected.name = "ActionButton1"
ShowUIPanel(protected)
assert(protected.hooks.OnShow == nil and #protected.points == 0, "protected HUD frame was routed")
local replacementBag = makeFrame({}, 1)
replacementBag.name = "BagnonFrame"
ShowUIPanel(replacementBag)
assert(replacementBag.hooks.OnShow == nil and #replacementBag.points == 0, "replacement bag frame was routed")
local unknown = makeFrame({}, 1)
unknown.name = "UnknownAddonPanel"
ShowUIPanel(unknown)
assert(unknown.hooks.OnShow == nil and #unknown.points == 0, "unregistered frame was routed")
""")
lua.execute("""
local lifecycle = makeFrame({{"TOPLEFT", UIParent, "TOPLEFT", 40, -50}, {"BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 70}}, 1.1)
lifecycle.name = "QuestLogFrame"
ShowUIPanel(lifecycle)
assert(#lifecycle.hooks.OnHide == 1, "supported panel did not receive an OnHide lifecycle hook")
lifecycle.shown = false
lifecycle.hooks.OnHide[1](lifecycle)
assert(#lifecycle.points == 2 and lifecycle.scale == 1.1, "hidden panel did not restore its original geometry")
assert(ForeverMultiMonitor.Panels.originalPoints[lifecycle] == nil, "hidden panel retained a stale geometry snapshot")
lifecycle.shown = true
lifecycle.hooks.OnShow[1](lifecycle)
assert(#lifecycle.points == 1 and lifecycle.scale < 1.1, "reopened panel was not routed into the Offhand workspace")
inCombat = true
lifecycle.shown = false
lifecycle.hooks.OnHide[1](lifecycle)
lifecycle.shown = true
lifecycle.hooks.OnShow[1](lifecycle)
inCombat = false
ForeverMultiMonitor:FlushPendingWork()
assert(#lifecycle.points == 1 and lifecycle.scale < 1.1, "combat hide/show did not converge on the latest shown state")
inCombat = true
lifecycle.shown = false
lifecycle.hooks.OnHide[1](lifecycle)
inCombat = false
ForeverMultiMonitor:FlushPendingWork()
assert(#lifecycle.points == 2 and lifecycle.scale == 1.1, "combat hide did not converge on the latest hidden state")
""")
print("PASS Lua 5.1: panel hide restores original geometry and reopen routes it again")

print("PASS Lua 5.1: late panel discovery, idempotent hooks, routing and multi-anchor/scale restore")
print("PASS Lua 5.1: anchorless restore and ToggleFrame global-name discovery")

# Exercise viewport snapshot lifecycle.
lua.execute("WorldFrame = makeFrame({{\"TOPLEFT\", UIParent, \"TOPLEFT\", 0, 0}, {\"BOTTOMRIGHT\", UIParent, \"BOTTOMRIGHT\", 0, 0}}, 1)")
lua.execute((ROOT / "Core" / "Viewport.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute("""
local layout = { mainhand = { left = 0, right = 1500 } }
ForeverMultiMonitor.Viewport:Apply(layout)
assert(#WorldFrame.points == 2, "viewport apply did not set expected bounds")
ForeverMultiMonitor.Viewport:Restore()
assert(#WorldFrame.points == 2, "viewport did not restore original anchors")
assert(ForeverMultiMonitor.Viewport.originalPoints == nil, "viewport snapshot was not invalidated")
""")
print("PASS Lua 5.1: viewport apply/restore and snapshot invalidation")

# Exercise current desired state after combat, including recovery timer firing while disabled.
lua.execute("""
function CreateFrame()
  local f = {}
  function f:RegisterEvent() end
  function f:SetScript(_, callback) self.onEvent = callback end
  return f
end
applied, restored, panelRestores = 0, 0, 0
ForeverMultiMonitor.db = { enabled = true }
ForeverMultiMonitor.charDB = { panelPositionSchema = 1, panelPositions = {} }
ForeverMultiMonitor.GetProfile = function() return {} end
ForeverMultiMonitor.InitializeConfig = function() end
ForeverMultiMonitor.Geometry = { Calculate = function() return { canvasWidth=3000, canvasHeight=1000 } end }
ForeverMultiMonitor.Viewport = { Apply = function() applied = applied + 1 end, Restore = function() restored = restored + 1 end }
ForeverMultiMonitor.Panels = { Apply = function() end, RestoreAll = function() panelRestores = panelRestores + 1 end }
ForeverMultiMonitor.RecordAppliedLayout = function() end
""")
lua.execute((ROOT / "Core" / "Init.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute("""
inCombat = true
ForeverMultiMonitor:Apply()
ForeverMultiMonitor.db.enabled = false
ForeverMultiMonitor:Reset()
inCombat = false
ForeverMultiMonitor:FlushPendingWork()
assert(applied == 0, "stale apply executed after disable")
assert(restored == 1 and panelRestores == 1, "latest disabled state was not restored")
inCombat = true
ForeverMultiMonitor:Reset()
ForeverMultiMonitor.db.enabled = true
inCombat = true
ForeverMultiMonitor:Apply()
inCombat = false
ForeverMultiMonitor:FlushPendingWork()
assert(applied == 1 and restored == 1, "latest enabled state did not win")
""")
print("PASS Lua 5.1: combat apply/disable and reset/enable converge on latest state")

lua.execute("C_Timer = { After = function(delay, callback) recoveryDelay = delay; recoveryCallback = callback end }")
lua.execute((ROOT / "Core" / "Recovery.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute("""
ForeverMultiMonitor.db.enabled = true
inCombat = true
ForeverMultiMonitor:ScheduleRecovery("runtime-test")
assert(recoveryDelay == 0.5, "recovery debounce interval changed")
ForeverMultiMonitor.db.enabled = false
recoveryCallback()
inCombat = false
ForeverMultiMonitor:FlushPendingWork()
assert(restored == 2 and panelRestores == 2, "recovery did not honor disabled state")
ForeverMultiMonitor.db.enabled = true
ForeverMultiMonitor.RawMouse:Sync()
assert(rawMouseValue == "1", "raw mouse did not sync with active layout")
ForeverMultiMonitor.frame.onEvent(ForeverMultiMonitor.frame, "PLAYER_LOGOUT")
assert(rawMouseValue == "0", "PLAYER_LOGOUT did not restore original raw mouse CVar")
print("PASS Lua 5.1: PLAYER_LOGOUT restores raw mouse CVar")
""")
print("PASS Lua 5.1: delayed recovery respects a disable that occurs during combat")
print("PASS all Lua 5.1 runtime regression scenarios")
# Exercise the in-game options window against a small frame/widget mock.
lua.execute("""
local function widget()
  local f = { scripts = {}, shown = false }
  function f:SetSize() end
  function f:SetPoint() end
  function f:SetFrameStrata() end
  function f:SetMovable() end
  function f:SetClampedToScreen() end
  function f:EnableMouse() end
  function f:RegisterForDrag() end
  function f:StartMoving() end
  function f:StopMovingOrSizing() end
  function f:SetScript(name, callback) self.scripts[name] = callback end
  function f:SetNormalTexture() end
  function f:SetPushedTexture() end
  function f:SetHighlightTexture() end
  function f:SetThumbTexture() end
  function f:SetBackdrop() end
  function f:SetOrientation() end
  function f:SetMinMaxValues() end
  function f:SetValueStep() end
  function f:SetObeyStepOnDrag() end
  function f:SetAllPoints() end
  function f:SetColorTexture() end
  function f:SetJustifyH() end
  function f:SetJustifyV() end
  function f:SetFont() end
  function f:SetFontObject() end
  function f:SetTextInsets() end
  function f:SetAutoFocus() end
  function f:ClearFocus() end
  function f:SetText(value) self.text = value end
  function f:GetText() return self.text end
  function f:SetValue(value) self.value = value; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end end
  function f:IsShown() return self.shown end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  function f:CreateFontString() return widget() end
  function f:CreateTexture() return widget() end
  return f
end
UIParent = widget()
function UIParent:GetWidth() return 3000 end
function UIParent:GetHeight() return 900 end
function UIParent:GetCenter() return 1500, 450 end
function CreateFrame(kind, name, parent) local f = widget(); f.kind = kind; f.name = name; if name then _G[name] = f end; return f end
UISpecialFrames = {}
GameFontNormal = {}
STANDARD_TEXT_FONT = "mock-font"
ForeverMultiMonitor.db = { enabled = false, activeProfile = "Default", profile = { mainhandSide = "left", mainhandWidthPercent = 50, seamUiUnits = 0, panelScale = 1, rawMouseEnabled = true }, profiles = { Default = { mainhandSide = "left", mainhandWidthPercent = 50, seamUiUnits = 0, panelScale = 1, rawMouseEnabled = true } } }
ForeverMultiMonitor.GetProfile = function(self) return self.db.profile end
ForeverMultiMonitor.Geometry = { Calculate = function() return { canvasWidth = 3000, canvasHeight = 900, workspace = { width = 1500 } } end }
ForeverMultiMonitor.charDB = { panelPositionSchema = 1, panelPositions = {} }
applyCount, resetCount, rawSyncCount = 0, 0, 0
ForeverMultiMonitor.Apply = function() applyCount = applyCount + 1 end
ForeverMultiMonitor.Reset = function() resetCount = resetCount + 1 end
ForeverMultiMonitor.RawMouse.Sync = function() rawSyncCount = rawSyncCount + 1 end
""")
lua.execute((ROOT / "Core" / "Options.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute("""
ForeverMultiMonitor.Options:Create()
assert(not ForeverMultiMonitor.Options.frame:IsShown(), "options window should start hidden")
ForeverMultiMonitor.Options:Toggle()
assert(ForeverMultiMonitor.Options.frame:IsShown(), "options window did not open")
ForeverMultiMonitor.Options.profileNameInput:SetText("Travel")
ForeverMultiMonitor.Options.profileNewButton.scripts.OnClick()
assert(ForeverMultiMonitor.db.activeProfile == "Travel", "new profile was not activated")
ForeverMultiMonitor.Options.widthSlider.slider:SetValue(68)
ForeverMultiMonitor.Options.profileNameInput:SetText("Default")
ForeverMultiMonitor.Options.profileLoadButton.scripts.OnClick()
assert(ForeverMultiMonitor.db.activeProfile == "Default" and ForeverMultiMonitor.db.profile.mainhandWidthPercent == 50, "profile load did not restore saved settings")
ForeverMultiMonitor.Options.profileNameInput:SetText("Travel")
ForeverMultiMonitor.Options.profileDeleteButton.scripts.OnClick()
assert(ForeverMultiMonitor.db.profiles.Travel == nil, "inactive profile delete failed")
ForeverMultiMonitor.Options.sideRight.scripts.OnClick()
assert(ForeverMultiMonitor.db.profile.mainhandSide == "right", "side control did not update shared config")
ForeverMultiMonitor.Options.widthSlider.slider:SetValue(65)
assert(ForeverMultiMonitor.db.profile.mainhandWidthPercent == 65, "width slider did not update shared config")
ForeverMultiMonitor.Options.seamSlider.slider:SetValue(18)
assert(ForeverMultiMonitor.db.profile.seamUiUnits == 18, "seam slider did not update shared config")
ForeverMultiMonitor.Options.scaleSlider.slider:SetValue(0.9)
assert(ForeverMultiMonitor.db.profile.panelScale == 0.9, "scale slider did not update shared config")
ForeverMultiMonitor.Options.rawMouseButton.scripts.OnClick()
assert(ForeverMultiMonitor.db.profile.rawMouseEnabled == false and rawSyncCount == 1, "raw mouse toggle did not sync")
ForeverMultiMonitor.Options.enabledButton.scripts.OnClick()
assert(ForeverMultiMonitor.db.enabled and applyCount == 1, "enable button did not use shared state")
ForeverMultiMonitor.Options.scaleSlider.slider.scripts.OnMouseUp()
assert(applyCount == 2, "slider release did not apply active layout")
ForeverMultiMonitor.Options.applyButton.scripts.OnClick()
assert(applyCount == 3, "Apply button did not invoke the shared layout apply")
ForeverMultiMonitor.Options.resetButton.scripts.OnClick()
assert(not ForeverMultiMonitor.db.enabled and resetCount == 1, "Reset button did not restore through shared state")
ForeverMultiMonitor.Options:ShowWizard()
assert(ForeverMultiMonitor.Options.wizard:IsShown() and not ForeverMultiMonitor.Options.settings:IsShown(), "setup page did not replace settings page")
assert(ForeverMultiMonitor.Options.wizard.next ~= nil, "guided wizard is missing its forward action")
ForeverMultiMonitor.Options.wizard.next.scripts.OnClick()
assert(ForeverMultiMonitor.Options.wizardStep == 2, "wizard did not advance to Mainhand configuration")
ForeverMultiMonitor.Options.wizard.sideRight.scripts.OnClick()
assert(ForeverMultiMonitor.db.profile.mainhandSide == "right", "wizard side selection did not update shared config")
ForeverMultiMonitor.Options.wizard.widthSlider.slider:SetValue(70)
assert(ForeverMultiMonitor.db.profile.mainhandWidthPercent == 70, "wizard width control did not update shared config")
ForeverMultiMonitor.Options.wizard.next.scripts.OnClick()
assert(ForeverMultiMonitor.Options.wizardStep == 3, "wizard did not advance to apply step")
ForeverMultiMonitor.Options.wizard.enableButton.scripts.OnClick()
assert(ForeverMultiMonitor.db.enabled, "wizard activation action did not enable the layout")
ForeverMultiMonitor.Options.wizard.back.scripts.OnClick()
assert(ForeverMultiMonitor.Options.wizardStep == 2, "wizard Back did not restore previous step")
ForeverMultiMonitor.Options.wizard.next.scripts.OnClick()
ForeverMultiMonitor.Options.wizard.next.scripts.OnClick()
assert(not ForeverMultiMonitor.Options.wizard:IsShown() and ForeverMultiMonitor.Options.settings:IsShown(), "wizard Finish did not return to settings")
ForeverMultiMonitor.Options:Toggle()
assert(not ForeverMultiMonitor.Options.frame:IsShown(), "options window did not close")
""")
print("PASS Lua 5.1: options window controls, shared config, wizard navigation and visibility")