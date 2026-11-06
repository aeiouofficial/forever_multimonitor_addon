# Verification Matrix

Target: WoW Forever launch client `1.60.1.70790`, interface `16001`, game type `camelot`.

## Automated local checks

| Area | Command | Current result |
|---|---|---|
| Manifest / Lua structure / workspace restrictions | `node tools/validate.js` | PASS; 17 TOC Lua modules |
| Source regression assertions | `node tools/regression.js` | PASS; 67 checks, including branded command registration, monitor naming, migration, Gather candidates and topology checks |
| Lua 5.1 syntax and mocked runtime | `.tmp/python312-runtime/python.exe tools/runtime_regression.py` | PASS; all 17 Lua files parsed and all mocked runtime scenarios passed, including profile/native-handoff migration, Gather candidate sources and legacy/modern AddOns category registration/open paths |
| Windows helper compile | `dotnet build WindowsHelper/ForeverMultiMonitor.WindowsHelper.csproj --configuration Release --no-restore` | PASS; .NET 10 Release build, 0 warnings / 0 errors |
| Windows helper self-test | `WindowsHelper.exe self-test` | PASS; explicit two/single-display selection, zero-display rollback, native handoff schema and absolute addon-path contract |
| Windows display enumeration | `ForeverMultiMonitor.WindowsHelper.exe list` | PASS on development PC; two displays reported with device IDs, bounds and DPI |
| Native WoW window placement/restore | `place` / `restore` against actual WoW | PASS on 2026-11-06: Wow.exe PID 16016, DISPLAY5 (2560x1080) + DISPLAY1 (1920x1080) -> 4480x1080, then safe restore onto primary because original stored position was insufficiently visible; no state file retained |
| WoW in-client behavior | Manual matrix below | NOT RUN; installation and client reload must be verified separately |

Lua mocks are not a substitute for the Forever client. Windows display enumeration is a local Windows test, not proof of WoW window placement or mixed-DPI behavior.

## In-client release tests — not yet run

Native HWND test success is **not** an in-client WorldFrame/UI test. All rows below remain open until verified inside Forever 1.60.1.70790. The live 2026-11-06 helper test used an already running client, and performed no addon installation, slash commands or combat interaction.

| Area | Test | Pass criteria |
|---|---|---|
| Loading | Cold launch with addon enabled | No Lua errors; addon appears in AddOns |
| Compatibility | `/forevermultimonitor status` | Runtime version/build/interface match the target client |
| Diagnostics | `/forevermultimonitor diag` | Registered/discovered/assigned/excluded panel counts, active restore snapshots, pending operations, preview state, geometry and last error are reported without changing state |
| Loading | `/reload` and relog | No Lua errors; settings and per-character positions persist |
| GUI | Interface/Settings → AddOns → Forever MultiMonitor | Registered settings category opens the dashboard; legacy and modern API registration are runtime-mocked, but the real client page is still open |
| Slash UI entry | `/forevermultimonitor` and `/forevermultimonitor config` | The single branded command opens or toggles the dashboard; `/forevermultimonitor wizard` opens the setup wizard |
| GUI | Enable/disable control | Same result as `/forevermultimonitor enable` and `/forevermultimonitor disable` |
| GUI | Preview for 15 seconds; Keep or allow timeout | Keep leaves layout enabled; timeout restores the previous disabled state; stale timers cannot undo a confirmed layout |
| GUI | Cycle Midnight/Indigo/Classic and adjust background opacity | Profile stores theme/opacity; dashboard and wizard update; opacity changes do not reapply game geometry |
| GUI | Side, width, seam and scale controls | Saved values match `/forevermultimonitor status`; Apply updates the layout |
| GUI | Raw mouse toggle | Previous CVar value is restored correctly |
| Profiles | Create a named profile, change settings, load Default and reload the named profile | Each profile retains its own validated values across reload |
| Profiles | Delete inactive profile / attempt to delete Default or active profile | Only inactive non-Default profiles can be deleted |
| Setup | Complete wizard: window instructions, MainMonitor side/width, enable, Back/Next/Finish | Controls update the shared profile; activation matches dashboard behavior; navigation preserves values |
| Recovery | Enter world / zone transition | Enabled layout reapplies once after UI settles |
| Recovery | Change UI scale / game-window size | Geometry recalculates without anchor drift |
| Viewport | MainMonitor left and right | 3D world is confined to the configured MainMonitor region |
| Viewport | Disable/reset | Original WorldFrame anchors are restored |
| Combat | Apply while in combat | No protected-action error; operation is deferred |
| Combat | Change settings and disable/enable during combat | Latest desired state is applied once after combat |
| Map | Open/close/reopen World Map | Map is usable in SecondMonitor1 and restores correctly |
| Panel lifecycle | Open, close and reopen each supported panel; repeat hide/show transitions during combat | Hidden panels restore original anchors/scale; reopened panels route again; after combat only the latest visibility state is applied |
| Recovery | Put a registered panel, a `UIPanelWindows` frame and a movable `UIParent` child off-screen; run `/forevermultimonitor gather` or click the settings button | Eligible windows are gathered into MainMonitor while protected/forbidden frames, tooltips and WorldFrame remain untouched; Lua runtime covers each candidate source |
| Character | Open/close Character panel | Panel routes and restores correctly |
| Bags | Open each supported default bag mode | No duplicate, hidden or stuck frames |
| Replacement bags | Test each supported replacement-bag addon | Replacement frames remain untouched until a dedicated adapter exists |
| Drag | Drag a supported panel, reload and reopen | Saved normalized position is reapplied without clipping |
| Escape/focus | Open several routed panels and press Escape | Expected close order and keyboard focus are preserved |
| Raw mouse | Original CVar 0/1, enable then disable/logout | Original value is restored without overwriting a pre-enabled state |
| Regression | Disable addon | Viewport and supported panels return to baseline |

## Additional Windows helper scenarios — still open

| Area | Test | Pass criteria |
|---|---|---|
| Enumeration | Run `list` with one/two/multiple displays | Device names/IDs, physical bounds, primary state and DPI match Windows Display Settings |
| Selection validation | Unknown or duplicate display name | Helper refuses placement without changing the game window |
| Selection cardinality | Default `place`/`watch` with one or three-plus displays; repeat with two displays | Default mode rejects unsupported counts before moving WoW; exactly two displays remain accepted |
| Single ultrawide | One selected display with and without `--single-ultrawide`; repeat with two and three displays while flag is set | Only explicit one-display mode is accepted, requires `--addon-dir`, emits `single-ultrawide`, and activates an equal 50/50 MainMonitor/workspace split |
| Process detection | Run `place` with game closed or wrong process name | Helper refuses placement and creates no restore state |
| Placement | Select two adjacent displays | WoW window covers the expected combined rectangle and is borderless |
| Mixed DPI | Select displays with different scaling | No clipping/offset; record actual WoW DPI behavior |
| Asymmetric topology | Use different resolutions / vertical offsets | Resulting union bounds are documented; unused gaps are expected where topology is non-rectangular |
| Restore | Place then run `restore` | Original styles, size, position and show state are restored; state file is removed |
| Safety | Run `place` while restore state exists | Second placement is refused |
| Failure recovery | Close/recreate WoW HWND before restore | Helper refuses to modify an unrelated HWND and retains restore state |
| Hotplug | Run `watch`, disconnect a selected display, then reconnect it | Watch restores saved styles/placement on loss, uses a connected-primary fallback when possible, and requires explicit reapply after reconnect; physical test still pending |
| Active topology loss | Apply native geometry, disconnect/rearrange a selected display so the Forever physical canvas changes | Addon rejects stale active topology, disables the invalid layout, and restores the full-window viewport; reconnect and explicit native reapply are required |

## Environment capture

Record the following with each live test:

- `/dump GetBuildInfo()`
- `/dump WOW_PROJECT_ID, WOW_PROJECT_CAMELOT`
- `/forevermultimonitor status`
- Display device names, bounds, resolution and Windows scaling per display
- WoW process executable name and window mode
- Other addons that replace bags, map or character UI
- Exact steps and first Lua/Windows error, including trace/correlation ID if one is logged

## Release gate

Do not claim full requested behavior support until every required in-client and helper row is passed on the current Forever build, all parity rows have evidence, and known unsupported APIs/features are explicitly bounded. Automated local tests are necessary, not sufficient.
