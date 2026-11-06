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
lua.execute("ForeverMultiMonitorDB = { enabled = true, profile = { mainhandSide = 'right', mainhandWidthPercent = 63 }, profiles = { Saved = { mainhandSide = 'left', mainhandWidthPercent = 72 } } }; ForeverMultiMonitorCharDB = { panelPositions = { Legacy = { schema = 1, x = 0.1, y = -0.1 } } }")
lua.execute((ROOT / "Core" / "Config.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
addon.InitializeConfig(addon)
lua.execute("assert(ForeverMultiMonitor.db.activeProfile == 'Default', 'legacy settings were not migrated to Default profile'); assert(ForeverMultiMonitor.db.profile.mainMonitorSide == 'right' and ForeverMultiMonitor.db.profile.mainMonitorWidthPercent == 63, 'legacy MainMonitor values were not preserved'); assert(ForeverMultiMonitor.db.profile.mainhandSide == nil and ForeverMultiMonitor.db.profile.mainhandWidthPercent == nil, 'legacy MainMonitor keys remain active'); assert(ForeverMultiMonitor.db.profiles.Saved.mainMonitorSide == 'left' and ForeverMultiMonitor.db.profiles.Saved.mainMonitorWidthPercent == 72, 'inactive saved profile was not migrated'); local ok = ForeverMultiMonitor:CreateProfile('Work'); assert(ok, 'profile creation failed'); local duplicate = ForeverMultiMonitor:CreateProfile('work'); assert(not duplicate, 'case-insensitive duplicate profile name was accepted'); local invalid = ForeverMultiMonitor:CreateProfile('bad/name'); assert(not invalid, 'invalid profile name was accepted'); ForeverMultiMonitor:SetProfileValue('mainMonitorWidthPercent', 72); assert(ForeverMultiMonitor.db.profiles.Work.mainMonitorWidthPercent == 72, 'active profile was not saved'); assert(ForeverMultiMonitor:SetActiveProfile('Default'), 'Default profile could not be loaded'); assert(ForeverMultiMonitor:GetProfile().mainMonitorWidthPercent == 63, 'Default profile was overwritten'); assert(ForeverMultiMonitor:SetActiveProfile('Work'), 'Work profile could not be loaded'); assert(ForeverMultiMonitor:GetProfile().mainMonitorWidthPercent == 72, 'Work profile was not restored'); assert(not ForeverMultiMonitor:DeleteProfile('Work'), 'active profile was deleted'); assert(ForeverMultiMonitor:SetActiveProfile('Default'), 'could not return to Default'); assert(ForeverMultiMonitor:DeleteProfile('Work'), 'inactive profile could not be deleted'); assert(not ForeverMultiMonitor:DeleteProfile('Default'), 'Default profile must be protected')")
print("PASS Lua 5.1: legacy profile migration, create, save, switch and safe delete")
lua.execute("assert(ForeverMultiMonitor:GetProfile().themePreset == 'midnight', 'theme preset default missing'); assert(ForeverMultiMonitor:GetProfile().backgroundOpacity == 0.92, 'background opacity default missing'); ForeverMultiMonitor:SetProfileValue('themePreset', 'invalid-theme'); assert(ForeverMultiMonitor:GetProfile().themePreset == 'midnight', 'invalid theme was not rejected'); ForeverMultiMonitor:SetProfileValue('themePreset', 'indigo'); assert(ForeverMultiMonitor:GetProfile().themePreset == 'indigo', 'valid theme preset was not retained'); ForeverMultiMonitor:SetProfileValue('backgroundOpacity', 1.5); assert(ForeverMultiMonitor:GetProfile().backgroundOpacity == 1, 'opacity upper bound was not clamped'); ForeverMultiMonitor:SetProfileValue('backgroundOpacity', 0.2); assert(ForeverMultiMonitor:GetProfile().backgroundOpacity == 0.5, 'opacity lower bound was not clamped')")
print("PASS Lua 5.1: theme preset validation and opacity bounds")
lua.execute((ROOT / "Core" / "NativeGeometry.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute("""
ForeverMultiMonitorNativeGeometry = {
  schemaVersion = 1, source = "ForeverMultiMonitor.WindowsHelper", processId = 1234,
  generatedAtUtc = "2026-11-06T00:00:00Z",
  bounds = { left = -1920, top = 0, right = 1920, bottom = 1080 },
  displays = {
    { device = "DISPLAY1", deviceId = "monitor-a", name = "Left", primary = false, left = -1920, top = 0, right = 0, bottom = 1080, dpiX = 96, dpiY = 96 },
    { device = "DISPLAY2", deviceId = "monitor-b", name = "Primary", primary = true, left = 0, top = 0, right = 1920, bottom = 1080, dpiX = 120, dpiY = 120 },
  },
}
local nativeOK, nativeError = ForeverMultiMonitor:LoadNativeGeometry()
assert(nativeOK and ForeverMultiMonitor.nativeGeometry.displayCount == 2, "valid native geometry handoff was rejected: " .. tostring(nativeError))
assert(ForeverMultiMonitor.nativeGeometry.bounds.left == -1920, "negative physical coordinates were not preserved")
assert(ForeverMultiMonitor.nativeGeometry.displays[2].dpiX == 120, "per-display DPI was not preserved")
ForeverMultiMonitorNativeGeometry.schemaVersion = 99
local futureOK = ForeverMultiMonitor:LoadNativeGeometry()
assert(not futureOK and ForeverMultiMonitor.nativeGeometry == nil, "unknown native geometry schema was accepted")
ForeverMultiMonitorNativeGeometry.schemaVersion = 1
ForeverMultiMonitorNativeGeometry.displays[2].deviceId = "monitor-a"
local duplicateOK = ForeverMultiMonitor:LoadNativeGeometry()
assert(not duplicateOK and ForeverMultiMonitor.nativeGeometry == nil, "duplicate native display identity was accepted")
ForeverMultiMonitorNativeGeometry.displays[2].deviceId = "monitor-b"
ForeverMultiMonitorNativeGeometry.displays[3] = {
  device = "DISPLAY3", deviceId = "monitor-c", name = "Third", primary = false,
  left = 0, top = 0, right = 960, bottom = 1080, dpiX = 96, dpiY = 96,
}
local extraDisplayOK = ForeverMultiMonitor:LoadNativeGeometry()
assert(not extraDisplayOK and ForeverMultiMonitor.nativeGeometry == nil,
  "native handoff accepted an unsupported third display")
ForeverMultiMonitorNativeGeometry = nil
local manualOK = ForeverMultiMonitor:LoadNativeGeometry()
assert(not manualOK and ForeverMultiMonitor.nativeGeometryStatus == "manual", "missing handoff did not select manual fallback")
""")
print("PASS Lua 5.1: native geometry handoff schema, negative coordinates, mixed DPI and safe fallback")
lua.execute((ROOT / "Core" / "MapEscape.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute("""
ForeverMultiMonitor.db.enabled = true
UISpecialFrames = { "GameMenuFrame", "WorldMapFrame", "OtherDialog", "WorldMapFrame" }
ForeverMultiMonitor.MapEscape:Sync()
assert(#UISpecialFrames == 2 and UISpecialFrames[1] == "GameMenuFrame", "map ESC removal damaged other entries")
ForeverMultiMonitor.MapEscape:Sync()
assert(#UISpecialFrames == 2, "map ESC removal is not idempotent")
ForeverMultiMonitor:SetProfileValue("mapStaysOpenOnEscape", false)
ForeverMultiMonitor.MapEscape:Sync()
assert(#UISpecialFrames == 4 and UISpecialFrames[2] == "WorldMapFrame" and UISpecialFrames[4] == "WorldMapFrame", "map ESC original duplicate membership was not restored")
ForeverMultiMonitor:SetProfileValue("mapStaysOpenOnEscape", true)
ForeverMultiMonitor.MapEscape:Sync()
assert(#UISpecialFrames == 2, "map ESC toggle did not reapply")
ForeverMultiMonitor.db.enabled = false
ForeverMultiMonitor.MapEscape:Sync()
assert(#UISpecialFrames == 4 and UISpecialFrames[2] == "WorldMapFrame" and UISpecialFrames[4] == "WorldMapFrame", "disabling layout did not restore map ESC behavior")
ForeverMultiMonitor.MapEscape:Sync()
assert(#UISpecialFrames == 4, "map ESC restore duplicated entries")
""")
print("PASS Lua 5.1: map Escape behavior, profile toggle, duplicate suppression and exact restoration")

lua.execute("""
ForeverMultiMonitorNativeGeometry = {
 schemaVersion = 1, source = "ForeverMultiMonitor.WindowsHelper", processId = 1234,
 generatedAtUtc = "2026-11-06T00:00:00Z", mainMonitorDeviceId = "monitor-b",
 bounds = { left = -1920, top = 0, right = 2560, bottom = 1080 },
 displays = {
  { device = "Left", deviceId = "monitor-a", name = "Left", primary = false,
    left = -1920, top = 0, right = 0, bottom = 1080, dpiX = 96, dpiY = 96 },
  { device = "Right", deviceId = "monitor-b", name = "Right", primary = true,
    left = 0, top = 0, right = 2560, bottom = 1080, dpiX = 120, dpiY = 120 },
 }
}
assert(ForeverMultiMonitor:LoadNativeGeometry(), "valid calibration payload rejected")
local ok, message = ForeverMultiMonitor:UseNativeGeometry()
assert(ok and ForeverMultiMonitor:GetProfile().mainMonitorSide == "right", "calibration failed: " .. tostring(message))
assert(math.abs(ForeverMultiMonitor:GetProfile().mainMonitorWidthPercent - 57.14285714) < 0.01, "wrong mainMonitor ratio")
local selectedMonitorId = ForeverMultiMonitor.nativeGeometry.mainMonitorDeviceId
ForeverMultiMonitorNativeGeometry.mainhandDeviceId = selectedMonitorId
ForeverMultiMonitorNativeGeometry.mainMonitorDeviceId = nil
assert(ForeverMultiMonitor:LoadNativeGeometry(), "legacy native handoff field was not migrated")
assert(ForeverMultiMonitor.nativeGeometry.mainMonitorDeviceId == selectedMonitorId,
  "legacy native handoff did not populate the branded field")
local previousApply, previousActive = ForeverMultiMonitor.Apply, ForeverMultiMonitor.activeNativeGeometry
local previousEnabled, previousCombat = ForeverMultiMonitor.db.enabled, inCombat
ForeverMultiMonitor.Apply = function() return false end
ForeverMultiMonitor.db.enabled = true
inCombat = false
local applyFailed = ForeverMultiMonitor:UseNativeGeometry()
assert(applyFailed == false, "native topology activation reported success when enabled layout apply failed")
assert(ForeverMultiMonitor.activeNativeGeometry == previousActive,
  "failed native activation did not restore the previous active topology")
ForeverMultiMonitor.Apply, ForeverMultiMonitor.activeNativeGeometry = previousApply, previousActive
ForeverMultiMonitor.db.enabled, inCombat = previousEnabled, previousCombat
ForeverMultiMonitorNativeGeometry.displays[2].top = 100
ForeverMultiMonitorNativeGeometry.bounds.top = 0
assert(ForeverMultiMonitor:LoadNativeGeometry(), "valid staggered display union rejected")
local staggeredOK = ForeverMultiMonitor:UseNativeGeometry()
assert(staggeredOK, "staggered displays could not be explicitly activated")
assert(ForeverMultiMonitor.activeNativeGeometry.secondMonitor1.top == 0,
  "staggered secondMonitor1 did not preserve the unselected display rectangle")
ForeverMultiMonitorNativeGeometry = nil
ForeverMultiMonitor:LoadNativeGeometry()
""")
print("PASS Lua 5.1: native MainMonitor selection and offset topology activation")
lua.execute("assert(ForeverMultiMonitor.charDB.panelPositionSchema == 1, 'panel position schema was not initialized'); assert(ForeverMultiMonitor.charDB.panelPositions.Legacy.x == 0.1, 'existing position data was discarded')")
lua.execute("ForeverMultiMonitorCharDB = { panelPositionSchema = 2, panelPositions = { Keep = { schema = 2 } } }; ForeverMultiMonitor:InitializeConfig(); assert(ForeverMultiMonitor.charDB.panelPositionSchema == 2 and ForeverMultiMonitor.charDB.panelPositions.Keep ~= nil, 'future schema data was mutated')")
print("PASS Lua 5.1: character position schema migration and future-schema read-only handling")
lua.execute((ROOT / "Core" / "Geometry.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute("local left = ForeverMultiMonitor.Geometry:Calculate({ mainMonitorSide = 'left', mainMonitorWidthPercent = 50, seamUiUnits = 20 }); assert(left and left.mainMonitor.left == 0 and left.mainMonitor.right == 1490 and left.secondMonitor1.left == 1510 and left.secondMonitor1.right == 3000, 'left geometry mismatch'); local right = ForeverMultiMonitor.Geometry:Calculate({ mainMonitorSide = 'right', mainMonitorWidthPercent = 50, seamUiUnits = 20 }); assert(right and right.secondMonitor1.left == 0 and right.mainMonitor.left == 1510 and right.mainMonitor.right == 3000, 'right geometry mismatch'); local narrow = ForeverMultiMonitor.Geometry:Calculate({ mainMonitorSide = 'left', mainMonitorWidthPercent = 90, seamUiUnits = 20 }); assert(narrow and narrow.secondMonitor1.width > 0, '90 percent width lost secondMonitor1'); local invalid = ForeverMultiMonitor.Geometry:Calculate({ mainMonitorSide = 'left', mainMonitorWidthPercent = 50, seamUiUnits = 800 }); assert(invalid == nil, 'invalid seam should be rejected')")
print("PASS Lua 5.1: left/right geometry, seam, width limits and invalid geometry")
lua.execute("""
local oldEnabled = ForeverMultiMonitor.db.enabled
ForeverMultiMonitor.db.enabled = false
local function activateNative(bounds, displays, mainMonitorDeviceId)
  ForeverMultiMonitorNativeGeometry = {
    schemaVersion = 1, source = "ForeverMultiMonitor.WindowsHelper", processId = 1234,
    generatedAtUtc = "2026-11-06T00:00:00Z", mainMonitorDeviceId = mainMonitorDeviceId,
    bounds = bounds, displays = displays,
  }
  local loaded, loadError = ForeverMultiMonitor:LoadNativeGeometry()
  assert(loaded, "valid exact monitor rectangles rejected: " .. tostring(loadError))
  local activated, activationError = ForeverMultiMonitor:UseNativeGeometry()
  assert(activated, "valid exact monitor rectangles could not be activated: " .. tostring(activationError))
  local layout, geometryError = ForeverMultiMonitor.Geometry:Calculate(ForeverMultiMonitor:GetProfile())
  assert(layout, "active exact monitor rectangles did not produce geometry: " .. tostring(geometryError))
  return layout
end
local offset = activateNative(
  { left = -1920, top = -300, right = 3890, bottom = 1260 },
  {
    { device = "DISPLAY1", deviceId = "monitor-a", name = "Upper-left", primary = false,
      left = -1920, top = -300, right = 0, bottom = 780, dpiX = 96, dpiY = 96 },
    { device = "DISPLAY2", deviceId = "monitor-b", name = "Lower-right", primary = false,
      left = 50, top = 0, right = 3890, bottom = 1260, dpiX = 120, dpiY = 144 },
  },
  "MONITOR-B")
local sx, sy = 3000 / 5810, 900 / 1560
assert(math.abs(offset.mainMonitor.left - 1970 * sx) < 0.001
  and math.abs(offset.mainMonitor.right - 3000) < 0.001
  and math.abs(offset.mainMonitor.bottom) < 0.001
  and math.abs(offset.mainMonitor.top - 1260 * sy) < 0.001,
  "offset MainMonitor rectangle was not mapped from its physical four edges")
assert(math.abs(offset.secondMonitor1.left) < 0.001
  and math.abs(offset.secondMonitor1.right - 1920 * sx) < 0.001
  and math.abs(offset.secondMonitor1.bottom - 480 * sy) < 0.001
  and math.abs(offset.secondMonitor1.top - 900) < 0.001,
  "offset secondMonitor1 rectangle was not mapped from its physical four edges")
assert(math.abs(offset.secondMonitor1.centerY - ((offset.secondMonitor1.bottom + offset.secondMonitor1.top) / 2 - 450)) < 0.001,
  "secondMonitor1 center did not use the vertical offset")
local stacked = activateNative(
  { left = -200, top = -100, right = 1600, bottom = 1700 },
  {
    { device = "DISPLAY1", deviceId = "lower", name = "Lower MainMonitor", primary = true,
      left = -200, top = 800, right = 700, bottom = 1700, dpiX = 96, dpiY = 96 },
    { device = "DISPLAY2", deviceId = "upper", name = "Upper secondMonitor1", primary = false,
      left = -200, top = -100, right = 1600, bottom = 800, dpiX = 96, dpiY = 96 },
  },
  "lower")
assert(stacked.mainMonitor.left == 0 and stacked.mainMonitor.right == 1500
  and stacked.mainMonitor.bottom == 0 and stacked.mainMonitor.top == 450,
  "stacked MainMonitor rectangle was not mapped from physical bounds")
assert(stacked.secondMonitor1.left == 0 and stacked.secondMonitor1.right == 3000
  and stacked.secondMonitor1.bottom == 450 and stacked.secondMonitor1.top == 900,
  "stacked secondMonitor1 rectangle was not mapped from physical bounds")
local oldRuntime, oldPhysicalSize = ForeverMultiMonitor.runtime, GetPhysicalScreenSize
ForeverMultiMonitor.runtime = { isForever = true }
GetPhysicalScreenSize = function() return 1920, 1080 end
ForeverMultiMonitorNativeGeometry = {
  schemaVersion = 1, source = "ForeverMultiMonitor.WindowsHelper", processId = 1234,
  generatedAtUtc = "2026-11-06T00:00:00Z", mainMonitorDeviceId = "fresh-main",
  bounds = { left = 0, top = 0, right = 3000, bottom = 900 },
  displays = {
    { device = "DISPLAY1", deviceId = "fresh-main", name = "Main", primary = true,
      left = 0, top = 0, right = 1500, bottom = 900, dpiX = 96, dpiY = 96 },
    { device = "DISPLAY2", deviceId = "fresh-work", name = "SecondMonitor1", primary = false,
      left = 1500, top = 0, right = 3000, bottom = 900, dpiX = 96, dpiY = 96 },
  },
}
assert(ForeverMultiMonitor:LoadNativeGeometry(), "valid current-size handoff rejected")
local staleActivated = ForeverMultiMonitor:UseNativeGeometry()
assert(staleActivated == false and ForeverMultiMonitor.activeNativeGeometry == nil,
  "stale topology was activated after the physical game canvas changed")
GetPhysicalScreenSize = function() return 3000, 902 end
local nearSizeLoaded = ForeverMultiMonitor:LoadNativeGeometry()
assert(nearSizeLoaded, "near-size handoff did not reload")
assert(ForeverMultiMonitor:UseNativeGeometry(), "two-pixel physical-size tolerance was rejected")
local oldWidth, oldHeight = UIParent.GetWidth, UIParent.GetHeight
UIParent.GetWidth = function() return 1920 end
UIParent.GetHeight = function() return 1080 end
GetPhysicalScreenSize = function() return 1920, 1080 end
local staleLayout = ForeverMultiMonitor.Geometry:Calculate(ForeverMultiMonitor:GetProfile())
assert(staleLayout == nil and ForeverMultiMonitor.activeNativeGeometry == nil,
  "active dual-display topology was silently recalculated for a smaller disconnected canvas")
UIParent.GetWidth, UIParent.GetHeight = oldWidth, oldHeight
ForeverMultiMonitor.runtime, GetPhysicalScreenSize = oldRuntime, oldPhysicalSize
local singleModeRuntime, singleModePhysicalSize = ForeverMultiMonitor.runtime, GetPhysicalScreenSize
ForeverMultiMonitor.runtime = { isForever = true }
GetPhysicalScreenSize = function() return 5120, 1440 end
ForeverMultiMonitorNativeGeometry = {
  schemaVersion = 1, source = "ForeverMultiMonitor.WindowsHelper", processId = 1234,
  generatedAtUtc = "2026-11-06T00:00:00Z", mainMonitorDeviceId = "ultrawide",
  bounds = { left = 0, top = 0, right = 5120, bottom = 1440 },
  displays = {
    { device = "DISPLAY1", deviceId = "ultrawide", name = "Super Ultrawide", primary = true,
      left = 0, top = 0, right = 5120, bottom = 1440, dpiX = 96, dpiY = 96 },
  },
}
assert(not ForeverMultiMonitor:LoadNativeGeometry(), "a single selected display was accepted without explicit ultrawide mode")
ForeverMultiMonitorNativeGeometry.mode = "single-ultrawide"
assert(ForeverMultiMonitor:LoadNativeGeometry(), "explicit single-display ultrawide handoff was rejected")
local singleActivated, singleActivationError = ForeverMultiMonitor:UseNativeGeometry()
assert(singleActivated, "explicit single-display ultrawide mode could not be activated: " .. tostring(singleActivationError))
local singleLeft = ForeverMultiMonitor.Geometry:Calculate({ mainMonitorSide = "left", mainMonitorWidthPercent = 75, seamUiUnits = 0 })
local singleRight = ForeverMultiMonitor.Geometry:Calculate({ mainMonitorSide = "right", mainMonitorWidthPercent = 75, seamUiUnits = 0 })
assert(singleLeft and singleLeft.mainMonitor.left == 0 and singleLeft.mainMonitor.right == 1500
  and singleLeft.secondMonitor1.left == 1500 and singleLeft.secondMonitor1.right == 3000,
  "single-display mode did not produce the reference's explicit equal left split")
assert(singleRight and singleRight.mainMonitor.left == 1500 and singleRight.mainMonitor.right == 3000
  and singleRight.secondMonitor1.left == 0 and singleRight.secondMonitor1.right == 1500,
  "single-display mode did not honor the configured MainMonitor side at an equal split")
ForeverMultiMonitor.activeNativeGeometry = nil
ForeverMultiMonitor.runtime, GetPhysicalScreenSize = singleModeRuntime, singleModePhysicalSize
ForeverMultiMonitorNativeGeometry = {
  schemaVersion = 1, source = "ForeverMultiMonitor.WindowsHelper", processId = 1234,
  generatedAtUtc = "2026-11-06T00:00:00Z",
  bounds = { left = 0, top = 0, right = 3000, bottom = 900 },
  displays = {
    { device = "DISPLAY1", deviceId = "overlap-a", name = "A", primary = true,
      left = 0, top = 0, right = 2000, bottom = 900, dpiX = 96, dpiY = 96 },
    { device = "DISPLAY2", deviceId = "overlap-b", name = "B", primary = false,
      left = 1500, top = 0, right = 3000, bottom = 900, dpiX = 96, dpiY = 96 },
  },
}
local overlapOK = ForeverMultiMonitor:LoadNativeGeometry()
assert(not overlapOK and ForeverMultiMonitor.nativeGeometry == nil,
  "overlapping native display rectangles were accepted")
assert(not ForeverMultiMonitor:UseNativeGeometry(), "invalid overlapping topology was activated")
ForeverMultiMonitorNativeGeometry = nil
assert(not ForeverMultiMonitor:LoadNativeGeometry(), "missing handoff unexpectedly loaded exact topology")
local manual = ForeverMultiMonitor.Geometry:Calculate({ mainMonitorSide = "left", mainMonitorWidthPercent = 50, seamUiUnits = 20 })
assert(manual and manual.mainMonitor.bottom == 0 and manual.mainMonitor.top == 900
  and manual.secondMonitor1.bottom == 0 and manual.secondMonitor1.top == 900,
  "manual fallback no longer covers the full vertical canvas")
ForeverMultiMonitor.db.enabled = oldEnabled
""")
print("PASS Lua 5.1: exact offset/stacked topology, overlap rejection and manual fallback")
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
lua.execute("""
local prior = ForeverMultiMonitor.lastError
inCombat = true
ForeverMultiMonitor:RunWhenSafe(function() return false, "deferred refusal" end, "refusal")
inCombat = false
ForeverMultiMonitor:FlushPendingWork()
assert(ForeverMultiMonitor.lastError == "deferred refusal", "deferred callback refusal was lost")
ForeverMultiMonitor.lastError = prior
""")
print("PASS Lua 5.1: deferred callback false result is diagnosed")

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
  function f:SetPoint(...) local args = {...}; table.insert(self.points, args); if args[1] == "CENTER" then local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1; local frameScale = self.GetEffectiveScale and self:GetEffectiveScale() or parentScale; self.centerX = 1500 + (args[4] or 0) * frameScale / parentScale; self.centerY = 450 + (args[5] or 0) * frameScale / parentScale end end
  function f:SetAllPoints(target) self:ClearAllPoints(); self:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0); self:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0) end
  function f:GetScale() return self.scale end
  function f:GetEffectiveScale() local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1; return parentScale * self.scale end
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
ForeverMultiMonitor.runtime = { isForever = true }
ForeverMultiMonitor.GetProfile = function() return { panelScale = 0.8 } end
ForeverMultiMonitor.Geometry = { Calculate = function() return { secondMonitor1 = { width = 500, centerX = 700, centerY = 0 }, canvasWidth = 3000, canvasHeight = 900 } end }
ForeverMultiMonitor.ReportError = function(_, message, err) error(tostring(message) .. ": " .. tostring(err)) end
""")
lua.execute((ROOT / "Core" / "PanelRegistry.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute((ROOT / "Core" / "PanelControllers.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute((ROOT / "Core" / "Panels.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
addon.Panels.Initialize(addon.Panels)
lua.execute("""
local professions = makeFrame({}, 1)
professions.name = "ProfessionsFrame"
assert(ForeverMultiMonitor.Panels:DiscoverFrame(professions) == false,
  "Forever Professions was claimed by the generic panel router")
assert(ForeverMultiMonitor.Panels.hooked[professions] ~= true and #professions.points == 0,
  "Forever Professions was hooked or moved by default")
local forbidden = makeFrame({}, 1)
forbidden.name = "QuestLogFrame"
forbidden.IsForbidden = function() return true end
assert(ForeverMultiMonitor.Panels:DiscoverFrame(forbidden) == false,
  "forbidden Blizzard frame was claimed by the generic panel router")
assert(ForeverMultiMonitor.Panels.hooked[forbidden] ~= true and #forbidden.points == 0,
  "forbidden Blizzard frame was hooked or moved")
""")
print("PASS Lua 5.1: Forever Professions and forbidden frames remain Blizzard-owned")
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
assert(math.abs(wide.scale - 0.25) < 0.000001, "panel scale minimum overflowed the SecondMonitor1 secondMonitor1 width")
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
assert(math.abs(restoredPosition.centerX - 2030) < 0.001 and math.abs(restoredPosition.centerY - 600) < 0.001, "saved panel position was not clamped safely to SecondMonitor1 bounds")
print('PASS Lua 5.1: per-character drag position save and reapply')
local layout = {
  canvasWidth = 3000, canvasHeight = 900,
  secondMonitor1 = {
    left = 1500, right = 3000, width = 1500,
    bottom = 600, top = 900, height = 300,
    centerX = 750, centerY = 300,
  },
}
local lower = makeFrame({}, 1)
lower.name = "QuestLogFrame"
lower.shown = true
assert(ForeverMultiMonitor.Panels:Place(lower, layout, { x = 750, y = -500 }))
assert(math.abs(lower.centerY - 640) < 0.001,
  "panel below secondMonitor1 bottom was not clamped into the secondMonitor1 rectangle")
ForeverMultiMonitor.Panels:Restore(lower)
local upper = makeFrame({}, 1)
upper.name = "AchievementFrame"
upper.shown = true
assert(ForeverMultiMonitor.Panels:Place(upper, layout, { x = 750, y = 900 }))
assert(math.abs(upper.centerY - 860) < 0.001,
  "panel above secondMonitor1 top was not clamped into the secondMonitor1 rectangle")
ForeverMultiMonitor.Panels:Restore(upper)
local oldUiEffectiveScale = UIParent.GetEffectiveScale
UIParent.GetEffectiveScale = function() return 1 end
local scaled = makeFrame({}, 1)
scaled.name = "CommunitiesFrame"
scaled.shown = true
scaled.GetEffectiveScale = function(self) return 0.5 * self.scale end
assert(ForeverMultiMonitor.Panels:Place(scaled, layout, { x = 750, y = -500 }))
assert(scaled.points[1][4] == 1875 and scaled.points[1][5] == 425,
  "UIParent-space panel placement offsets were not converted to the frame scale: "
    .. tostring(scaled.points[1][4]) .. "," .. tostring(scaled.points[1][5]))
ForeverMultiMonitor.Panels:Restore(scaled)
UIParent.GetEffectiveScale = oldUiEffectiveScale
print("PASS Lua 5.1: panel clamping respects secondMonitor1 bottom and top")
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
assert(#lifecycle.points == 1 and lifecycle.scale < 1.1, "reopened panel was not routed into the SecondMonitor1 secondMonitor1")
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

lua.execute("""
local sourceGeometry = ForeverMultiMonitor.Geometry
local safeLayout = {
    canvasWidth = 3000, canvasHeight = 900,
    secondMonitor1 = { left = 1500, right = 3000, width = 1500, centerX = 750, centerY = 0 }
}
ForeverMultiMonitor.Geometry = { Calculate = function() return safeLayout end }
local bag1 = makeFrame({{"TOPLEFT", UIParent, "TOPLEFT", 15, -15}}, 1)
local bag2 = makeFrame({{"TOPLEFT", UIParent, "TOPLEFT", 25, -25}}, 1)
bag1.name = "ContainerFrame1"
bag2.name = "ContainerFrame2"
_G.ContainerFrame1, _G.ContainerFrame2 = bag1, bag2
ShowUIPanel(bag1)
ShowUIPanel(bag2)
assert(bag1.centerX < bag2.centerX, "default bag windows overlap instead of reflowing in the secondMonitor1")
assert(bag1.centerX > 1500 and bag2.centerX < 3000, "default bags left the SecondMonitor1 canvas")
bag2.shown = false
bag2.hooks.OnHide[1](bag2)
assert(#bag2.points == 1 and bag2.scale == 1, "hidden bag did not restore its anchor and scale")
bag2.shown = true
bag2.hooks.OnShow[1](bag2)
assert(bag1.centerX < bag2.centerX, "bag reopening failed to reflow")
local combined = makeFrame({}, 1)
combined.name = "ContainerFrameCombinedBags"
_G.ContainerFrameCombinedBags = combined
combined.shown = true
ForeverMultiMonitor.Panels:ReconcileBags(safeLayout)
assert(#bag1.points == 1 and bag1.scale == 1, "combined bag mode did not restore separate bag anchors")
combined.shown = false
ForeverMultiMonitor.Panels:ReconcileBags(safeLayout)
assert(bag1.centerX < bag2.centerX, "closing combined bags did not reflow default bags")
bag1.shown = false
bag2.shown = false
ForeverMultiMonitor.Panels:ReconcileFrame(bag1)
ForeverMultiMonitor.Panels:ReconcileFrame(bag2)
ForeverMultiMonitor.Geometry = sourceGeometry
_G.ContainerFrame1, _G.ContainerFrame2, _G.ContainerFrameCombinedBags = nil, nil, nil
""")
print("PASS Lua 5.1: individual/combined bag grid routing, reflow and restoration")
lua.execute("""
local layout = {
  canvasWidth = 3000, canvasHeight = 900,
  secondMonitor1 = {
    left = 1500, right = 3000, width = 1500,
    bottom = 600, top = 900, height = 300,
    centerX = 750, centerY = 300,
  },
}
local bag1, bag2 = makeFrame({}, 1), makeFrame({}, 1)
bag1.name, bag2.name = "ContainerFrame1", "ContainerFrame2"
bag1.shown, bag2.shown = true, true
_G.ContainerFrame1, _G.ContainerFrame2 = bag1, bag2
assert(ForeverMultiMonitor.PanelControllers:Get("bags"):Apply(bag1, layout), "first stacked-secondMonitor1 bag placement failed")
assert(ForeverMultiMonitor.PanelControllers:Get("bags"):Apply(bag2, layout), "second stacked-secondMonitor1 bag placement failed")
assert(math.abs(bag1.centerY - 750) < 0.001 and math.abs(bag2.centerY - 750) < 0.001,
  "bag grid used the full-canvas vertical center instead of the secondMonitor1 rectangle")
assert(bag1.centerX < bag2.centerX, "stacked-secondMonitor1 bags did not retain separate grid columns")
ForeverMultiMonitor.Panels:Restore(bag1)
ForeverMultiMonitor.Panels:Restore(bag2)
_G.ContainerFrame1, _G.ContainerFrame2 = nil, nil
""")
print("PASS Lua 5.1: bag grid uses secondMonitor1 vertical bounds")

lua.execute("""
local manager = CreateFrame("Frame", "EditModeManagerFrame")
assert(manager.hooks.OnShow and manager.hooks.OnHide, "late Edit Mode discovery did not install lifecycle hooks")
local editPanel = makeFrame({{"TOPLEFT", UIParent, "TOPLEFT", 12, -12}}, 1)
editPanel.name = "SpellBookFrame"
ForeverMultiMonitor.Panels:DiscoverFrame(editPanel, false)
editPanel.shown = true
manager.shown = true
manager.hooks.OnShow[1](manager)
ForeverMultiMonitor.Panels:Apply({
  canvasWidth = 3000, canvasHeight = 900,
  secondMonitor1 = { left = 1500, right = 3000, width = 1500, centerX = 750, centerY = 0 }
})
assert(#editPanel.points == 1 and editPanel.points[1][1] == "TOPLEFT", "Edit Mode guard modified a panel")
local calls = 0
ForeverMultiMonitor.ScheduleRecovery = function(_, reason)
  assert(reason == "EDIT_MODE_EXIT", "wrong Edit Mode recovery reason")
  calls = calls + 1
end
manager.shown = false
manager.hooks.OnHide[1](manager)
assert(calls == 1, "Edit Mode exit did not schedule safe recovery")
ForeverMultiMonitor.Panels:Apply({
  canvasWidth = 3000, canvasHeight = 900,
  secondMonitor1 = { left = 1500, right = 3000, width = 1500, centerX = 750, centerY = 0 }
})
assert(editPanel.points[1][1] == "CENTER", "panel did not route after Edit Mode closed")
ForeverMultiMonitor.Panels:Restore(editPanel)
editPanel.shown = false
_G.EditModeManagerFrame = nil
""")
print("PASS Lua 5.1: Edit Mode pause, recovery trigger, resumed routing and restoration")

print("PASS Lua 5.1: late panel discovery, idempotent hooks, routing and multi-anchor/scale restore")
print("PASS Lua 5.1: anchorless restore and ToggleFrame global-name discovery")

# Exercise viewport snapshot lifecycle.
lua.execute("WorldFrame = makeFrame({{\"TOPLEFT\", UIParent, \"TOPLEFT\", 0, 0}, {\"BOTTOMRIGHT\", UIParent, \"BOTTOMRIGHT\", 0, 0}}, 1); WorldFrame.userPlaced = true; function WorldFrame:IsUserPlaced() return self.userPlaced end; function WorldFrame:SetUserPlaced(flag) self.userPlaced = flag end")
lua.execute((ROOT / "Core" / "Viewport.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute("""
local layout = { canvasWidth = 3000, canvasHeight = 900, mainMonitor = { left = 0, right = 1500, bottom = 0, top = 900 } }
ForeverMultiMonitor.Viewport:Apply(layout)
assert(#WorldFrame.points == 2, "viewport apply did not set expected bounds")
assert(WorldFrame.userPlaced == false, "cropped WorldFrame was left layout-cache persistent")
assert(WorldFrame.points[1][1] == "BOTTOMLEFT" and WorldFrame.points[1][2] == UIParent
  and WorldFrame.points[1][3] == "BOTTOMLEFT" and WorldFrame.points[1][4] == 0 and WorldFrame.points[1][5] == 0,
  "WorldFrame lower-left edge was not anchored to UIParent coordinates")
assert(WorldFrame.points[2][1] == "TOPRIGHT" and WorldFrame.points[2][2] == UIParent
  and WorldFrame.points[2][3] == "BOTTOMLEFT" and WorldFrame.points[2][4] == 1500 and WorldFrame.points[2][5] == 900,
  "WorldFrame upper-right edge was not anchored to UIParent coordinates")
ForeverMultiMonitor.Viewport:Restore()
assert(#WorldFrame.points == 2, "viewport did not restore original anchors")
assert(WorldFrame.userPlaced == true, "pre-existing WorldFrame cache flag was not restored")
assert(ForeverMultiMonitor.Viewport.originalPoints == nil, "viewport snapshot was not invalidated")
local oldEffectiveScale = UIParent.GetEffectiveScale
UIParent.GetEffectiveScale = function() return 1 end
WorldFrame.GetEffectiveScale = function() return 0.5 end
local invalid, invalidMessage = ForeverMultiMonitor.Viewport:Apply({
  canvasWidth = 3000, canvasHeight = 900,
  mainMonitor = { left = -1, right = 1500, bottom = 100, top = 700 },
})
assert(invalid == false and string.find(invalidMessage or "", "Invalid MainMonitor geometry"),
  "viewport accepted MainMonitor edges outside the canvas")
assert(ForeverMultiMonitor.Viewport.originalPoints == nil, "invalid viewport geometry captured a restore snapshot")
local exact = {
  canvasWidth = 3000, canvasHeight = 900,
  mainMonitor = { left = 500, right = 1500, bottom = 100, top = 700 },
}
assert(ForeverMultiMonitor.Viewport:Apply(exact), "four-edge viewport application failed")
assert(#WorldFrame.points == 2
  and WorldFrame.points[1][1] == "BOTTOMLEFT" and WorldFrame.points[1][2] == UIParent
  and WorldFrame.points[1][3] == "BOTTOMLEFT" and WorldFrame.points[1][4] == 1000 and WorldFrame.points[1][5] == 200
  and WorldFrame.points[2][1] == "TOPRIGHT" and WorldFrame.points[2][2] == UIParent
  and WorldFrame.points[2][3] == "BOTTOMLEFT" and WorldFrame.points[2][4] == 3000 and WorldFrame.points[2][5] == 1400,
  "viewport did not crop all four edges with UIParent-to-WorldFrame scale conversion")
assert(ForeverMultiMonitor.Viewport:Restore(), "exact viewport snapshot did not restore")
UIParent.GetEffectiveScale = oldEffectiveScale
WorldFrame.GetEffectiveScale = nil
""")
print("PASS Lua 5.1: viewport apply/restore and snapshot invalidation")
lua.execute("""
local originalSetPoint = WorldFrame.SetPoint
local attempts = 0
WorldFrame.SetPoint = function(self, ...)
  attempts = attempts + 1
  if attempts == 2 then error("injected second-anchor failure") end
  return originalSetPoint(self, ...)
end
local ok, err = ForeverMultiMonitor.Viewport:Apply({mainMonitor = {left = 0, right = 1500}, canvasWidth = 3000})
assert(not ok and string.find(err, "restored"), "failed viewport apply was counted as success")
assert(#WorldFrame.points == 2 and WorldFrame.points[1][1] == "TOPLEFT" and WorldFrame.points[2][1] == "BOTTOMRIGHT", "viewport failure lost original anchors")
assert(WorldFrame.userPlaced == true, "failed viewport apply damaged original user-placed state")
WorldFrame.SetPoint = originalSetPoint
ForeverMultiMonitor.Viewport:Restore()
""")
print("PASS Lua 5.1: injected second-anchor failure rolls back viewport without changing cache state")
lua.execute("""
-- An initially anchorless WorldFrame must remain anchorless on restore.
WorldFrame.points = {}
local layout = {mainMonitor = {left = 0, right = 1500}, canvasWidth = 3000}
assert(ForeverMultiMonitor.Viewport:Apply(layout))
assert(ForeverMultiMonitor.Viewport:Restore())
assert(#WorldFrame.points == 0, "anchorless WorldFrame baseline was replaced with synthetic anchors")
-- Restoration failure must retain the original snapshot and existing cropped geometry.
WorldFrame.points = {{"TOPLEFT", 0, 0}, {"BOTTOMRIGHT", -100, 0}}
assert(ForeverMultiMonitor.Viewport:Apply(layout))
local originalSetPoint = WorldFrame.SetPoint
local attempts = 0
WorldFrame.SetPoint = function(self, ...)
  attempts = attempts + 1
  if attempts == 1 then error("injected restore anchor failure") end
  return originalSetPoint(self, ...)
end
local ok, message = ForeverMultiMonitor.Viewport:Restore()
assert(ok == false and string.find(message, "restoration failed"), "failed restore reported success")
assert(ForeverMultiMonitor.Viewport.originalPoints ~= nil, "failed restore discarded recovery snapshot")
assert(#WorldFrame.points == 2 and WorldFrame.points[2][1] == "TOPRIGHT"
  and WorldFrame.points[2][4] == 1500 and WorldFrame.points[2][5] == 900,
  "failed restore did not recover the active viewport")
WorldFrame.SetPoint = originalSetPoint
assert(ForeverMultiMonitor.Viewport:Restore(), "retry restore failed")
assert(#WorldFrame.points == 2 and WorldFrame.points[2][2] == -100, "retry restore lost original viewport")
""")
print("PASS Lua 5.1: anchorless baseline and injected restore failure/retry")
lua.execute("""
local failing = makeFrame({{"TOPLEFT", UIParent, "TOPLEFT", 25, -40}}, 1.1)
failing.name = "WorldMapFrame"
failing.shown = true
local originalSetPoint = failing.SetPoint
local report = ForeverMultiMonitor.ReportError
local lastFailure = nil
ForeverMultiMonitor.ReportError = function(_, context, reason) lastFailure = context .. ": " .. tostring(reason) end
local fails = 0
failing.SetPoint = function(self, ...)
  fails = fails + 1
  if fails == 1 then error("injected panel anchor failure") end
  return originalSetPoint(self, ...)
end
local layout = {canvasWidth = 3000, canvasHeight = 900, secondMonitor1 = {left = 1500, right = 3000, width = 1500, centerX = 750, centerY = 0}}
local ok = ForeverMultiMonitor.Panels:Place(failing, layout)
assert(not ok and lastFailure and string.find(lastFailure, "rolled back"), "panel anchor failure was not reported as rolled back")
assert(#failing.points == 1 and failing.points[1][1] == "TOPLEFT" and failing.scale == 1.1, "panel rollback lost original anchor or scale")
ForeverMultiMonitor.ReportError = report
""")
print("PASS Lua 5.1: injected panel placement failure restores original scale and anchor")
lua.execute("""
local frame = makeFrame({{"TOPLEFT", UIParent, "TOPLEFT", 25, -40}}, 1.1)
frame.name, frame.shown = "CharacterFrame", true
local layout = {canvasWidth = 3000, canvasHeight = 900, secondMonitor1 = {left = 1500, right = 3000, width = 1500, centerX = 750, centerY = 0}}
assert(ForeverMultiMonitor.Panels:Place(frame, layout))
local routedPoint, routedScale = frame.points[1][1], frame.scale
local originalSetPoint = frame.SetPoint
local report = ForeverMultiMonitor.ReportError
local failure
ForeverMultiMonitor.ReportError = function(_, context, reason) failure = context .. ": " .. tostring(reason) end
local calls = 0
frame.SetPoint = function(self, ...)
  calls = calls + 1
  if calls == 1 then error("injected restore anchor failure") end
  return originalSetPoint(self, ...)
end
local ok = ForeverMultiMonitor.Panels:Restore(frame)
assert(ok == false, "failed panel restore was counted as success")
assert(failure and string.find(failure, "injected restore anchor failure"), "restore failure was not diagnosed")
assert(frame.points[1][1] == routedPoint and frame.scale == routedScale, "failed restore lost routed panel state")
assert(ForeverMultiMonitor.Panels.originalPoints[frame] ~= nil, "failed restore discarded retry snapshot")
assert(ForeverMultiMonitor.Panels:Restore(frame), "panel restore retry failed")
assert(frame.points[1][1] == "TOPLEFT" and frame.scale == 1.1, "panel restore retry lost original state")
ForeverMultiMonitor.ReportError = report
""")
print("PASS Lua 5.1: failed panel restore rolls back and retains retry snapshot")

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
ForeverMultiMonitor.Viewport = { Apply = function() applied = applied + 1; return true end, Restore = function() restored = restored + 1; return true end }
ForeverMultiMonitor.Panels = { Apply = function() return true end, RestoreAll = function() panelRestores = panelRestores + 1; return true end }
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
lua.execute("""
local previousApply = ForeverMultiMonitor.Viewport.Apply
local previousReport = ForeverMultiMonitor.ReportError
local previousPanelApply = ForeverMultiMonitor.Panels.Apply
local previousRawRestore = ForeverMultiMonitor.RawMouse.Restore
local diagnostics, panelCalls, rawRestores = nil, 0, 0
ForeverMultiMonitor.Viewport.Apply = function() return false, "injected viewport refusal" end
ForeverMultiMonitor.ReportError = function(_, context, reason) diagnostics = tostring(context) .. ": " .. tostring(reason) end
ForeverMultiMonitor.Panels.Apply = function() panelCalls = panelCalls + 1; return true end
ForeverMultiMonitor.RawMouse.Restore = function() rawRestores = rawRestores + 1; return true end
ForeverMultiMonitor.db.enabled = true
local applicationSucceeded = ForeverMultiMonitor:Apply()
assert(applicationSucceeded == false, "public Apply falsely reported success after viewport refusal")
assert(panelCalls == 0 and rawRestores == 1, "failed viewport was followed by panel routing or left raw mouse on")
assert(diagnostics and string.find(diagnostics, "injected viewport refusal"), "viewport refusal not diagnosed")
ForeverMultiMonitor.Viewport.Apply = previousApply
ForeverMultiMonitor.ReportError = previousReport
ForeverMultiMonitor.Panels.Apply = previousPanelApply
ForeverMultiMonitor.RawMouse.Restore = previousRawRestore
""")
print("PASS Lua 5.1: false viewport result stops panel routing and restores input state")
lua.execute("""
local viewportApply, viewportRestore = ForeverMultiMonitor.Viewport.Apply, ForeverMultiMonitor.Viewport.Restore
local panelApply, panelRestore = ForeverMultiMonitor.Panels.Apply, ForeverMultiMonitor.Panels.RestoreAll
local rawRestore = ForeverMultiMonitor.RawMouse.Restore
local mapSync = ForeverMultiMonitor.MapEscape.Sync
local report = ForeverMultiMonitor.ReportError
local oldEnabled, oldError, oldErrorGeneration = ForeverMultiMonitor.db.enabled, ForeverMultiMonitor.lastError, ForeverMultiMonitor.errorGeneration
local restores, panelRestores, rawRestores, mapSyncs = 0, 0, 0, 0
ForeverMultiMonitor.ReportError = function(self, context, reason)
  self.lastError = tostring(reason)
  self.errorGeneration = (self.errorGeneration or 0) + 1
end
ForeverMultiMonitor.Viewport.Apply = function() error("injected detailed WorldFrame failure") end
ForeverMultiMonitor.Viewport.Restore = function() restores = restores + 1; return true end
ForeverMultiMonitor.Panels.Apply = function() return true end
ForeverMultiMonitor.Panels.RestoreAll = function() panelRestores = panelRestores + 1; return true end
ForeverMultiMonitor.RawMouse.Restore = function() rawRestores = rawRestores + 1; return true end
ForeverMultiMonitor.MapEscape.Sync = function() mapSyncs = mapSyncs + 1; return true end
ForeverMultiMonitor.db.enabled = true
local applied = ForeverMultiMonitor:Apply()
assert(applied == false and not ForeverMultiMonitor.db.enabled,
  "failed direct reapply left the persisted enabled state active")
assert(restores == 1 and panelRestores == 1 and rawRestores == 1 and mapSyncs == 1,
  "failed direct reapply did not roll back all layout-owned state")
assert(string.find(ForeverMultiMonitor.lastError or "", "injected detailed WorldFrame failure"),
  "generic operation rejection replaced the detailed viewport error")
ForeverMultiMonitor.Viewport.Apply, ForeverMultiMonitor.Viewport.Restore = viewportApply, viewportRestore
ForeverMultiMonitor.Panels.Apply, ForeverMultiMonitor.Panels.RestoreAll = panelApply, panelRestore
ForeverMultiMonitor.RawMouse.Restore = rawRestore
ForeverMultiMonitor.MapEscape.Sync = mapSync
ForeverMultiMonitor.ReportError = report
ForeverMultiMonitor.db.enabled, ForeverMultiMonitor.lastError, ForeverMultiMonitor.errorGeneration = oldEnabled, oldError, oldErrorGeneration
""")
print("PASS Lua 5.1: failed direct reapply disables and fully rolls back without masking root error")
lua.execute("""
local calculate = ForeverMultiMonitor.Geometry.Calculate
local viewportRestore = ForeverMultiMonitor.Viewport.Restore
local panelsRestore = ForeverMultiMonitor.Panels.RestoreAll
local rawRestore = ForeverMultiMonitor.RawMouse.Restore
local mapSync = ForeverMultiMonitor.MapEscape.Sync
local report = ForeverMultiMonitor.ReportError
local oldEnabled = ForeverMultiMonitor.db.enabled
ForeverMultiMonitor.ReportError = function(self, context, reason) self.lastError = tostring(reason) end
ForeverMultiMonitor.Geometry.Calculate = function() return nil, "injected invalid geometry" end
ForeverMultiMonitor.Viewport.Restore = function() return true end
ForeverMultiMonitor.Panels.RestoreAll = function() return true end
ForeverMultiMonitor.RawMouse.Restore = function() return true end
ForeverMultiMonitor.MapEscape.Sync = function() return true end
ForeverMultiMonitor.db.enabled = true
local applied = ForeverMultiMonitor:Apply()
assert(applied == false and not ForeverMultiMonitor.db.enabled,
  "invalid geometry during reapply left the layout enabled")
ForeverMultiMonitor.Geometry.Calculate = calculate
ForeverMultiMonitor.Viewport.Restore = viewportRestore
ForeverMultiMonitor.Panels.RestoreAll = panelsRestore
ForeverMultiMonitor.RawMouse.Restore = rawRestore
ForeverMultiMonitor.MapEscape.Sync = mapSync
ForeverMultiMonitor.ReportError = report
ForeverMultiMonitor.db.enabled = oldEnabled
""")
print("PASS Lua 5.1: invalid direct reapply disables and restores the previous layout")
lua.execute("""
local viewportApply, viewportRestore = ForeverMultiMonitor.Viewport.Apply, ForeverMultiMonitor.Viewport.Restore
local panelRestore, rawRestore = ForeverMultiMonitor.Panels.RestoreAll, ForeverMultiMonitor.RawMouse.Restore
local mapSync = ForeverMultiMonitor.MapEscape.Sync
local report = ForeverMultiMonitor.ReportError
local oldEnabled, oldError, oldErrorGeneration = ForeverMultiMonitor.db.enabled, ForeverMultiMonitor.lastError, ForeverMultiMonitor.errorGeneration
local restores, panelRestores, rawRestores, mapSyncs = 0, 0, 0, 0
ForeverMultiMonitor.ReportError = function(self, context, reason)
  self.lastError = tostring(reason)
  self.errorGeneration = (self.errorGeneration or 0) + 1
end
ForeverMultiMonitor.Viewport.Apply = function() error("injected post-combat viewport failure") end
ForeverMultiMonitor.Viewport.Restore = function() restores = restores + 1; return true end
ForeverMultiMonitor.Panels.RestoreAll = function() panelRestores = panelRestores + 1; return true end
ForeverMultiMonitor.RawMouse.Restore = function() rawRestores = rawRestores + 1; return true end
ForeverMultiMonitor.MapEscape.Sync = function() mapSyncs = mapSyncs + 1; return true end
ForeverMultiMonitor.db.enabled = true
inCombat = true
ForeverMultiMonitor:Apply()
inCombat = false
ForeverMultiMonitor:FlushPendingWork()
assert(not ForeverMultiMonitor.db.enabled, "failed deferred reapply persisted enabled state")
assert(restores == 1 and panelRestores == 1 and rawRestores == 1 and mapSyncs >= 1,
  "failed deferred reapply skipped rollback")
ForeverMultiMonitor.Viewport.Apply, ForeverMultiMonitor.Viewport.Restore = viewportApply, viewportRestore
ForeverMultiMonitor.Panels.RestoreAll, ForeverMultiMonitor.RawMouse.Restore = panelRestore, rawRestore
ForeverMultiMonitor.MapEscape.Sync = mapSync
ForeverMultiMonitor.ReportError = report
ForeverMultiMonitor.db.enabled, ForeverMultiMonitor.lastError, ForeverMultiMonitor.errorGeneration = oldEnabled, oldError, oldErrorGeneration
""")
print("PASS Lua 5.1: failed combat-deferred reapply rolls back current enabled state")
lua.execute("""
local panelApply = ForeverMultiMonitor.Panels.Apply
local rawRestore = ForeverMultiMonitor.RawMouse.Restore
local recordLayout = ForeverMultiMonitor.RecordAppliedLayout
local report = ForeverMultiMonitor.ReportError
local previousRestored, previousPanelRestores = restored, panelRestores
local records, rawRestores = 0, 0
ForeverMultiMonitor.Panels.Apply = function() return false end
ForeverMultiMonitor.RawMouse.Restore = function() rawRestores = rawRestores + 1; return true end
ForeverMultiMonitor.RecordAppliedLayout = function() records = records + 1 end
ForeverMultiMonitor.ReportError = function() end
ForeverMultiMonitor.db.enabled = true
local ok = ForeverMultiMonitor:Apply()
assert(ok == false, "failed panel routing was reported as successful layout")
assert(records == 0, "failed panel routing recorded an applied layout")
assert(rawRestores > 0, "failed panel routing did not restore raw mouse")
ForeverMultiMonitor.Panels.Apply = panelApply
ForeverMultiMonitor.RawMouse.Restore = rawRestore
ForeverMultiMonitor.RecordAppliedLayout = recordLayout
ForeverMultiMonitor.ReportError = report
ForeverMultiMonitor.db.enabled = true
restored, panelRestores = previousRestored, previousPanelRestores
""")
print("PASS Lua 5.1: failed panel routing rejects layout without recording success")
lua.execute("""
local viewportApply = ForeverMultiMonitor.Viewport.Apply
local report = ForeverMultiMonitor.ReportError
local previousRestored, previousPanelRestores = restored, panelRestores
ForeverMultiMonitor.ReportError = function() end
ForeverMultiMonitor.Viewport.Apply = function() return false, "injected enable refusal" end
ForeverMultiMonitor.db.enabled = false
local enabled = ForeverMultiMonitor:SetEnabled(true)
assert(enabled == false, "SetEnabled reported success despite viewport refusal")
assert(ForeverMultiMonitor.db.enabled == false, "failed enable left invalid desired state active")
ForeverMultiMonitor.Viewport.Apply = viewportApply
ForeverMultiMonitor.ReportError = report
restored, panelRestores = previousRestored, previousPanelRestores
""")
print("PASS Lua 5.1: enable reports the actual apply result")

lua.execute("C_Timer = { After = function(delay, callback) recoveryDelay = delay; recoveryCallback = callback end }")
lua.execute((ROOT / "Core" / "Recovery.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute("""
ForeverMultiMonitor.db.enabled = true
local restoredBeforeRecovery, panelsBeforeRecovery = restored, panelRestores
inCombat = true
ForeverMultiMonitor:ScheduleRecovery("runtime-test")
assert(recoveryDelay == 0.5, "recovery debounce interval changed")
ForeverMultiMonitor.db.enabled = false
recoveryCallback()
inCombat = false
ForeverMultiMonitor:FlushPendingWork()
assert(restored == restoredBeforeRecovery + 1 and panelRestores == panelsBeforeRecovery + 1,
  "recovery did not honor disabled state: " .. tostring(restored) .. "/" .. tostring(panelRestores))
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
  function f:SetBackdropColor(...) self.backdropColor = {...} end
  function f:SetBackdropBorderColor(...) self.backdropBorderColor = {...} end
  function f:SetTextColor(...) self.textColor = {...} end
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
ForeverMultiMonitor.db = { enabled = false, activeProfile = "Default", profile = { mainMonitorSide = "left", mainMonitorWidthPercent = 50, seamUiUnits = 0, panelScale = 1, rawMouseEnabled = true }, profiles = { Default = { mainMonitorSide = "left", mainMonitorWidthPercent = 50, seamUiUnits = 0, panelScale = 1, rawMouseEnabled = true } } }
ForeverMultiMonitor.GetProfile = function(self) return self.db.profile end
ForeverMultiMonitor.Geometry = { Calculate = function() return { canvasWidth = 3000, canvasHeight = 900, secondMonitor1 = { width = 1500 } } end }
ForeverMultiMonitor.charDB = { panelPositionSchema = 1, panelPositions = {} }
applyCount, resetCount, rawSyncCount = 0, 0, 0
ForeverMultiMonitor.Apply = function() applyCount = applyCount + 1; return true end
ForeverMultiMonitor.Reset = function() resetCount = resetCount + 1; return true end
ForeverMultiMonitor.RawMouse.Sync = function() rawSyncCount = rawSyncCount + 1 end
""")
gather_module = ROOT / "Core" / "Gather.lua"
assert gather_module.exists(), "Core/Gather.lua recovery module is missing"
lua.execute(gather_module.read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute((ROOT / "Core" / "Options.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute((ROOT / "Core" / "Commands.lua").read_text(encoding="utf-8-sig"), "ForeverMultiMonitor", addon)
lua.execute("""
assert(SLASH_FOREVERMULTIMONITOR1 == "/forevermultimonitor", "branded slash command is not registered")
assert(SLASH_FOREVERMULTIMONITOR2 == nil and SLASH_FOREVERMULTIMONITOR3 == nil
  and SLASH_FOREVERMULTIMONITOR4 == nil and SLASH_FOREVERMULTIMONITOR5 == nil,
  "non-canonical slash aliases must not be registered")
local dashboardToggles, wizardOpens, diagnosticLines, commandMessages = 0, 0, 0, {}
local oldToggle, oldShowWizard, oldPrint = ForeverMultiMonitor.Options.Toggle,
  ForeverMultiMonitor.Options.ShowWizard, ForeverMultiMonitor.Print
local oldEnabled, oldPreview, oldKeep = ForeverMultiMonitor.db.enabled,
  ForeverMultiMonitor.Options.previewActive, ForeverMultiMonitor.Options.KeepPreview
ForeverMultiMonitor.Options.Toggle = function() dashboardToggles = dashboardToggles + 1 end
ForeverMultiMonitor.Options.ShowWizard = function() wizardOpens = wizardOpens + 1 end
ForeverMultiMonitor.Print = function(_, message)
  diagnosticLines = diagnosticLines + 1
  commandMessages[#commandMessages + 1] = message
end
ForeverMultiMonitor:HandleCommand("")
ForeverMultiMonitor:HandleCommand("   ")
assert(dashboardToggles == 2, "empty slash command did not open the dashboard")
ForeverMultiMonitor:HandleCommand("help")
assert(string.find(table.concat(commandMessages, "\\n"), "/forevermultimonitor", 1, true),
  "help does not show the branded command")
ForeverMultiMonitor:HandleCommand("wizard")
assert(wizardOpens == 1, "wizard command did not open the existing setup wizard")
ForeverMultiMonitor:HandleCommand("diag")
assert(diagnosticLines > 0, "diag alias did not invoke read-only diagnostics")
ForeverMultiMonitor.db.enabled = true
ForeverMultiMonitor.Options.previewActive = true
ForeverMultiMonitor.Options.KeepPreview = function() return false end
ForeverMultiMonitor:HandleCommand("apply")
for _, message in ipairs(commandMessages) do
  assert(message ~= "Layout preview confirmed.", "failed preview was reported as confirmed")
end
ForeverMultiMonitor.db.enabled, ForeverMultiMonitor.Options.previewActive = oldEnabled, oldPreview
ForeverMultiMonitor.Options.KeepPreview = oldKeep
ForeverMultiMonitor.Options.Toggle = oldToggle
ForeverMultiMonitor.Options.ShowWizard = oldShowWizard
ForeverMultiMonitor.Print = oldPrint
""")
print("PASS Lua 5.1: branded slash command, empty dashboard, wizard and diagnostics")
lua.execute("""
local registry = ForeverMultiMonitor.PanelRegistry
for _, name in ipairs(registry:GetKnownNames()) do _G[name] = nil end
assert(registry:Register("WorldFrame", "generic", "test-canvas"), "test WorldFrame registration failed")
assert(registry:Register("GameTooltip", "generic", "test-tooltip"), "test tooltip registration failed")
assert(registry:Register("ForeverMultiMonitorCanvas", "generic", "test-canvas"), "test canvas registration failed")
local oldScale = UIParent.GetEffectiveScale
local oldCalculate = ForeverMultiMonitor.Geometry.Calculate
UIParent.GetEffectiveScale = function() return 0.5 end
ForeverMultiMonitor.Geometry.Calculate = function()
  return {
    canvasWidth = 2000, canvasHeight = 900,
    mainMonitor = { left = 0, right = 1000, bottom = 0, top = 900, width = 1000, height = 900 },
    secondMonitor1 = { left = 1000, right = 2000, bottom = 0, top = 900, width = 1000, height = 900 },
  }
end
local function frame(name, left, top, width, height, shown, protected, forbidden)
  local value = { name = name, shown = shown ~= false, protected = protected, forbidden = forbidden }
  function value:GetName() return self.name end
  function value:IsShown() return self.shown end
  function value:IsMovable() return self.movable == true end
  function value:IsProtected() return self.protected == true end
  function value:IsForbidden() return self.forbidden == true end
  function value:GetEffectiveScale() return 1 end
  function value:GetLeft() return left end
  function value:GetTop() return top end
  function value:GetWidth() return width end
  function value:GetHeight() return height end
  return value
end
WorldMapFrame = frame("WorldMapFrame", -75, 400, 100, 100, true)
CharacterFrame = frame("CharacterFrame", -50, 400, 100, 100, true)
SpellBookFrame = frame("SpellBookFrame", 400, 10, 100, 100, true)
QuestLogFrame = frame("QuestLogFrame", 1200, 400, 100, 100, true)
GuildFrame = frame("GuildFrame", 10, 400, 20, 100, true)
AuctionHouseFrame = frame("AuctionHouseFrame", -500, 400, 100, 100, false)
FriendsFrame = frame("FriendsFrame", -500, 400, 100, 100, true, true)
CommunitiesFrame = frame("CommunitiesFrame", -500, 400, 100, 100, true, false, true)
GameTooltip = frame("GameTooltip", -500, 400, 100, 100, true)
ForeverMultiMonitorCanvas = frame("ForeverMultiMonitorCanvas", -500, 400, 100, 100, true)
WorldFrame = frame("WorldFrame", -500, 400, 100, 100, true)
UnregisteredWindow = frame("UnregisteredWindow", -500, 400, 100, 100, true)
UnregisteredPanel = frame("UnregisteredPanel", -500, 400, 100, 100, true)
UnregisteredMovable = frame("UnregisteredMovable", -500, 400, 100, 100, true)
UnregisteredMovable.movable = true
ProtectedMovable = frame("ProtectedMovable", -500, 400, 100, 100, true, true)
ProtectedMovable.movable = true
UIPanelWindows = { UnregisteredPanel = { area = "left" } }
UIParent.children = { UnregisteredMovable, ProtectedMovable, UnregisteredWindow }
UIParent.GetChildren = function(self) return unpack(self.children) end
local oldPlace = ForeverMultiMonitor.Panels.Place
local placed = {}
ForeverMultiMonitor.Panels.Place = function(_, target, layout)
  placed[target] = layout
  return true
end
local moved, skipped = ForeverMultiMonitor.Gather:Run()
assert(moved == 5, "gather must rescue inaccessible registered, UIPanelWindows and movable frames: " .. tostring(moved))
local placedCount = 0
for target, layout in pairs(placed) do
  placedCount = placedCount + 1
  assert(target == WorldMapFrame or target == SpellBookFrame or target == QuestLogFrame
    or target == UnregisteredPanel or target == UnregisteredMovable,
    "gather moved an accessible, hidden, protected, forbidden, tooltip, canvas or unknown frame")
  assert(layout.secondMonitor1 == layout.mainMonitor, "gather did not target the MainMonitor rectangle")
end
assert(placedCount == 5, "gather called placement for an ineligible frame")
local oldPlaced = placedCount
ForeverMultiMonitor.Gather:Run()
placedCount = 0
for _ in pairs(placed) do placedCount = placedCount + 1 end
assert(placedCount == oldPlaced, "repeat gather did not remain deterministic")
inCombat = true
local combatMoved = ForeverMultiMonitor.Gather:Run()
placedCount = 0
for _ in pairs(placed) do placedCount = placedCount + 1 end
assert(combatMoved == false and placedCount == oldPlaced, "gather moved windows during combat")
inCombat = false
ForeverMultiMonitor.Panels.Place = oldPlace
ForeverMultiMonitor.Geometry.Calculate = oldCalculate
UIParent.GetEffectiveScale = oldScale
""")
print("PASS Lua 5.1: gather rescues only inaccessible eligible panels into MainMonitor, scale-aware and combat-safe")
lua.execute("""
local oldRun, oldPrint = ForeverMultiMonitor.Gather.Run, ForeverMultiMonitor.Print
local messages = {}
ForeverMultiMonitor.Gather.Run = function() return 2, 1 end
ForeverMultiMonitor.Print = function(_, message) messages[#messages + 1] = message end
ForeverMultiMonitor:HandleCommand("gather")
assert(messages[#messages] == "Gathered 2 off-screen window(s); skipped 1.", "gather command did not report its result")
ForeverMultiMonitor.Gather.Run = oldRun
ForeverMultiMonitor.Print = oldPrint
""")
print("PASS Lua 5.1: gather slash command reports recovery result")
lua.execute("""
local previousSettings = Settings
local previousLegacyAdd = InterfaceOptions_AddCategory
local previousLegacyOpen = InterfaceOptionsFrame_OpenToCategory
local registered, opened = nil, nil
Settings = nil
InterfaceOptions_AddCategory = function(panel) registered = panel end
InterfaceOptionsFrame_OpenToCategory = function(panel)
  opened = panel
  panel:Show()
end
ForeverMultiMonitor.Options.categoryRegistered = nil
local registeredOK = ForeverMultiMonitor.Options:RegisterCategory()
assert(registeredOK, "AddOns category registration failed: " .. tostring(registeredOK))
assert(registered == ForeverMultiMonitor.Options.frame and registered.name == "Forever MultiMonitor",
  "legacy WoW AddOns settings category was not registered during addon load")
assert(ForeverMultiMonitor.Options:OpenSettings() and opened == registered and registered:IsShown(),
  "registered AddOns settings category did not open the options frame")
registered:Hide()
Settings = previousSettings
InterfaceOptions_AddCategory = previousLegacyAdd
InterfaceOptionsFrame_OpenToCategory = previousLegacyOpen
""")
print("PASS Lua 5.1: legacy AddOns category registration and open path")
lua.execute("""
local previousSettings = Settings
local registeredFrame, registeredName, addedCategory, openedCategoryId = nil, nil, nil, nil
Settings = {
  RegisterCanvasLayoutCategory = function(frame, name)
    registeredFrame, registeredName = frame, name
    return { ID = 42 }
  end,
  RegisterAddOnCategory = function(category) addedCategory = category end,
  OpenToCategory = function(categoryId) openedCategoryId = categoryId end,
}
ForeverMultiMonitor.Options.categoryRegistered = nil
ForeverMultiMonitor.Options.settingsCategory = nil
ForeverMultiMonitor.Options.legacyCategory = nil
assert(ForeverMultiMonitor.Options:RegisterCategory(), "modern AddOns settings category registration failed")
assert(registeredFrame == ForeverMultiMonitor.Options.frame and registeredName == "Forever MultiMonitor"
  and addedCategory.ID == 42, "modern AddOns settings category used the wrong canvas/name")
assert(ForeverMultiMonitor.Options:OpenSettings() and openedCategoryId == 42,
  "modern settings category did not open to its registered ID")
ForeverMultiMonitor.Options.frame:Hide()
Settings = previousSettings
""")
print("PASS Lua 5.1: modern Settings category registration and open path")
lua.execute("""
ForeverMultiMonitor:HandleCommand("diagnostics")
ForeverMultiMonitor.Options:Create()
local previousHandleCommand = ForeverMultiMonitor.HandleCommand
local settingsGatherCommand = nil
ForeverMultiMonitor.HandleCommand = function(_, command) settingsGatherCommand = command end
assert(ForeverMultiMonitor.Options.gatherButton and ForeverMultiMonitor.Options.gatherButton.scripts.OnClick,
  "settings-page Gather button is missing its click handler")
ForeverMultiMonitor.Options.gatherButton.scripts.OnClick()
assert(settingsGatherCommand == "gather", "settings-page Gather button did not invoke the shared command")
ForeverMultiMonitor.HandleCommand = previousHandleCommand
assert(ForeverMultiMonitor.Options.themeButton.label.text == "Theme: Midnight", "default theme label missing")
ForeverMultiMonitor.Options.themeButton.scripts.OnClick()
assert(ForeverMultiMonitor.db.profile.themePreset == "indigo" and ForeverMultiMonitor.Options.themeButton.label.text == "Theme: Indigo", "theme cycle did not update profile/UI")
ForeverMultiMonitor.Options.backgroundOpacitySlider.slider:SetValue(0.7)
assert(ForeverMultiMonitor.db.profile.backgroundOpacity == 0.7, "background opacity slider did not update profile")
assert(ForeverMultiMonitor.Options.frame.backdropColor[4] == 0.7, "background opacity was not applied to the options backdrop")
local applyBeforeOpacityRelease = applyCount
ForeverMultiMonitor.Options.backgroundOpacitySlider.slider.scripts.OnMouseUp()
assert(applyCount == applyBeforeOpacityRelease, "theme opacity change unexpectedly reapplied the game layout")
assert(not ForeverMultiMonitor.Options.frame:IsShown(), "options window should start hidden")
ForeverMultiMonitor.Options:Toggle()
assert(ForeverMultiMonitor.Options.frame:IsShown(), "options window did not open")
ForeverMultiMonitor.Options.profileNameInput:SetText("Travel")
ForeverMultiMonitor.Options.profileNewButton.scripts.OnClick()
assert(ForeverMultiMonitor.db.activeProfile == "Travel", "new profile was not activated")
ForeverMultiMonitor.Options.widthSlider.slider:SetValue(68)
ForeverMultiMonitor.Options.profileNameInput:SetText("Default")
ForeverMultiMonitor.Options.profileLoadButton.scripts.OnClick()
assert(ForeverMultiMonitor.db.activeProfile == "Default" and ForeverMultiMonitor.db.profile.mainMonitorWidthPercent == 50, "profile load did not restore saved settings")
ForeverMultiMonitor.Options.profileNameInput:SetText("Travel")
ForeverMultiMonitor.Options.profileDeleteButton.scripts.OnClick()
assert(ForeverMultiMonitor.db.profiles.Travel == nil, "inactive profile delete failed")
ForeverMultiMonitor.Options.sideRight.scripts.OnClick()
assert(ForeverMultiMonitor.db.profile.mainMonitorSide == "right", "side control did not update shared config")
ForeverMultiMonitor.Options.widthSlider.slider:SetValue(65)
assert(ForeverMultiMonitor.db.profile.mainMonitorWidthPercent == 65, "width slider did not update shared config")
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
ForeverMultiMonitor.Options:StartPreview()
assert(ForeverMultiMonitor.db.enabled and ForeverMultiMonitor.Options.keepPreviewButton:IsShown(), "Preview did not temporarily enable the layout")
assert(recoveryDelay == 15, "Preview timeout must be 15 seconds")
local stalePreviewCallback = recoveryCallback
ForeverMultiMonitor.Options:KeepPreview()
assert(ForeverMultiMonitor.db.enabled and not ForeverMultiMonitor.Options.keepPreviewButton:IsShown(), "Keep preview did not confirm the layout")
stalePreviewCallback()
assert(ForeverMultiMonitor.db.enabled, "stale preview timeout reverted a confirmed layout")
ForeverMultiMonitor:SetEnabled(false)
ForeverMultiMonitor.Options:StartPreview()
local expiryCallback = recoveryCallback
expiryCallback()
assert(not ForeverMultiMonitor.db.enabled and not ForeverMultiMonitor.Options.keepPreviewButton:IsShown(), "unconfirmed preview did not restore the previous disabled state")
ForeverMultiMonitor.Options:StartPreview()
local commandPreviewCallback = recoveryCallback
ForeverMultiMonitor:HandleCommand("enable")
commandPreviewCallback()
assert(ForeverMultiMonitor.db.enabled and not ForeverMultiMonitor.Options.previewActive, "slash enable did not cancel a pending preview rollback")
ForeverMultiMonitor:HandleCommand("disable")
ForeverMultiMonitor.Options:StartPreview()
local applyPreviewCallback = recoveryCallback
ForeverMultiMonitor:HandleCommand("apply")
applyPreviewCallback()
assert(ForeverMultiMonitor.db.enabled and not ForeverMultiMonitor.Options.previewActive, "slash apply did not confirm the active preview")
ForeverMultiMonitor:HandleCommand("disable")
ForeverMultiMonitor.Options:StartPreview()
local wizardPreviewCallback = recoveryCallback
ForeverMultiMonitor.Options:ShowWizard()
wizardPreviewCallback()
assert(not ForeverMultiMonitor.db.enabled and not ForeverMultiMonitor.Options.previewActive, "opening the wizard did not restore the previous disabled state")
assert(ForeverMultiMonitor.Options.wizard:IsShown() and not ForeverMultiMonitor.Options.settings:IsShown(), "setup page did not replace settings page")
assert(ForeverMultiMonitor.Options.wizard.backdropColor[4] == 0.7, "wizard did not inherit the active theme opacity")
assert(ForeverMultiMonitor.Options.wizard.next ~= nil and ForeverMultiMonitor.Options.wizard.next.label.text == "Next", "guided wizard is missing its forward action")
ForeverMultiMonitor.Options.wizard.next.scripts.OnClick()
assert(ForeverMultiMonitor.Options.wizardStep == 2 and ForeverMultiMonitor.Options.wizard.back.label.text == "Back", "wizard did not advance to MainMonitor configuration")
ForeverMultiMonitor.Options.wizard.sideRight.scripts.OnClick()
assert(ForeverMultiMonitor.db.profile.mainMonitorSide == "right", "wizard side selection did not update shared config")
ForeverMultiMonitor.Options.wizard.widthSlider.slider:SetValue(70)
assert(ForeverMultiMonitor.db.profile.mainMonitorWidthPercent == 70, "wizard width control did not update shared config")
ForeverMultiMonitor.Options.wizard.next.scripts.OnClick()
assert(ForeverMultiMonitor.Options.wizardStep == 3 and ForeverMultiMonitor.Options.wizard.next.label.text == "Finish", "wizard did not advance to apply step")
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
lua.execute("""
ForeverMultiMonitor:SetEnabled(false)
local apply = ForeverMultiMonitor.Apply
ForeverMultiMonitor.Apply = function() return false end
local preview = ForeverMultiMonitor.Options:StartPreview()
assert(preview == false and not ForeverMultiMonitor.Options.previewActive and not ForeverMultiMonitor.db.enabled,
  "failed preview left a confirmation timer or enabled state active")
ForeverMultiMonitor.Apply = apply
""")
print("PASS Lua 5.1: failed preview cannot be confirmed")
