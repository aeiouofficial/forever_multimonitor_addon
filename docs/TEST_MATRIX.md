# Verification Matrix

Target: WoW Forever launch client `1.60.1.70790`, interface `16001`, game type `camelot`.

## Automated local checks

| Area | Command | Current result |
|---|---|---|
| Manifest / Lua structure / workspace restrictions | `node tools/validate.js` | PASS; 13 TOC Lua modules |
| Source regression assertions | `node tools/regression.js` | PASS; 52 assertions |
| Lua 5.1 syntax and mocked runtime | `python tools/runtime_regression.py` | PASS; geometry, named profiles, options window, combat, panel registry/discovery, show/hide restoration, combat visibility convergence, preview timeout/Keep/command invalidation, diagnostics command, anchors, persistence, raw mouse and recovery scenarios |
| Windows helper compile | `WindowsHelper/build.ps1` | PASS; .NET 10 Release build, 0 warnings / 0 errors |
| Windows hotplug pure self-test | `ForeverMultiMonitor.WindowsHelper.exe self-test` | PASS; stable display identity, missing-display detection, safe primary fallback, partial-visibility handling and exact visible-position restore |
| Windows display enumeration | `ForeverMultiMonitor.WindowsHelper.exe list` | PASS on development PC; two displays reported with device IDs, bounds and DPI |
| Native WoW window placement/restore | `place` / `restore` against actual WoW | NOT RUN; requires intentional live-window test |
| WoW in-client behavior | Manual matrix below | NOT RUN |

Lua mocks are not a substitute for the Forever client. Windows display enumeration is a local Windows test, not proof of WoW window placement or mixed-DPI behavior.

## In-client release tests — not yet run

| Area | Test | Pass criteria |
|---|---|---|
| Loading | Cold launch with addon enabled | No Lua errors; addon appears in AddOns |
| Compatibility | `/fmm status` | Runtime version/build/interface match the target client |
| Diagnostics | `/fmm diagnostics` | Registered/discovered/assigned/excluded panel counts, active restore snapshots, pending operations, preview state, geometry and last error are reported without changing state |
| Loading | `/reload` and relog | No Lua errors; settings and per-character positions persist |
| GUI | `/fmm config` | Settings window opens, remains movable, closes with Escape and reopens |
| GUI | Enable/disable control | Same result as `/fmm enable` and `/fmm disable` |
| GUI | Preview for 15 seconds; Keep or allow timeout | Keep leaves layout enabled; timeout restores the previous disabled state; stale timers cannot undo a confirmed layout |
| GUI | Side, width, seam and scale controls | Saved values match `/fmm status`; Apply updates the layout |
| GUI | Raw mouse toggle | Previous CVar value is restored correctly |
| Profiles | Create a named profile, change settings, load Default and reload the named profile | Each profile retains its own validated values across reload |
| Profiles | Delete inactive profile / attempt to delete Default or active profile | Only inactive non-Default profiles can be deleted |
| Setup | Complete wizard: window instructions, Mainhand side/width, enable, Back/Next/Finish | Controls update the shared profile; activation matches dashboard behavior; navigation preserves values |
| Recovery | Enter world / zone transition | Enabled layout reapplies once after UI settles |
| Recovery | Change UI scale / game-window size | Geometry recalculates without anchor drift |
| Viewport | Mainhand left and right | 3D world is confined to the configured Mainhand region |
| Viewport | Disable/reset | Original WorldFrame anchors are restored |
| Combat | Apply while in combat | No protected-action error; operation is deferred |
| Combat | Change settings and disable/enable during combat | Latest desired state is applied once after combat |
| Map | Open/close/reopen World Map | Map is usable in Offhand and restores correctly |
| Panel lifecycle | Open, close and reopen each supported panel; repeat hide/show transitions during combat | Hidden panels restore original anchors/scale; reopened panels route again; after combat only the latest visibility state is applied |
| Character | Open/close Character panel | Panel routes and restores correctly |
| Bags | Open each supported default bag mode | No duplicate, hidden or stuck frames |
| Replacement bags | Test each supported replacement-bag addon | Replacement frames remain untouched until a dedicated adapter exists |
| Drag | Drag a supported panel, reload and reopen | Saved normalized position is reapplied without clipping |
| Escape/focus | Open several routed panels and press Escape | Expected close order and keyboard focus are preserved |
| Raw mouse | Original CVar 0/1, enable then disable/logout | Original value is restored without overwriting a pre-enabled state |
| Regression | Disable addon | Viewport and supported panels return to baseline |

## Windows helper tests — not yet run against WoW

| Area | Test | Pass criteria |
|---|---|---|
| Enumeration | Run `list` with one/two/multiple displays | Device names/IDs, physical bounds, primary state and DPI match Windows Display Settings |
| Selection validation | Unknown or duplicate display name | Helper refuses placement without changing the game window |
| Process detection | Run `place` with game closed or wrong process name | Helper refuses placement and creates no restore state |
| Placement | Select two adjacent displays | WoW window covers the expected combined rectangle and is borderless |
| Mixed DPI | Select displays with different scaling | No clipping/offset; record actual WoW DPI behavior |
| Asymmetric topology | Use different resolutions / vertical offsets | Resulting union bounds are documented; unused gaps are expected where topology is non-rectangular |
| Restore | Place then run `restore` | Original styles, size, position and show state are restored; state file is removed |
| Safety | Run `place` while restore state exists | Second placement is refused |
| Failure recovery | Close/recreate WoW HWND before restore | Helper refuses to modify an unrelated HWND and retains restore state |
| Hotplug | Run `watch`, disconnect a selected display, then reconnect it | Watch restores safely on disconnect; reconnect/reapply remains manual; physical test still pending |

## Environment capture

Record the following with each live test:

- `/dump GetBuildInfo()`
- `/dump WOW_PROJECT_ID, WOW_PROJECT_CAMELOT`
- `/fmm status`
- Display device names, bounds, resolution and Windows scaling per display
- WoW process executable name and window mode
- Other addons that replace bags, map or character UI
- Exact steps and first Lua/Windows error, including trace/correlation ID if one is logged

## Release gate

Do not claim full Offhand support until every required in-client and helper row is passed on the current Forever build, all parity rows have evidence, and known unsupported APIs/features are explicitly bounded. Automated local tests are necessary, not sufficient.