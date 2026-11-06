# Forever MultiMonitor

A standalone, companion-free multi-monitor workspace for **World of Warcraft: Forever**. The project is an independent implementation of the public user-facing Offhand workflow; it does not copy Offhand source or implement its Companion process/protocol.

> **Development status: 0.4.1.** The addon core, basic in-game settings window and Windows helper with one-shot placement plus opt-in hotplug watch are implemented and locally tested. This is not yet a complete or live-verified Offhand replacement. No untested feature is represented as complete.

## Target client

- WoW Forever launch build: `1.60.1.70790`
- Addon interface: `16001`
- Forever game type: `camelot`
- Addon install folder: `_forever_/Interface/AddOns/ForeverMultiMonitor`
- Local workspace: `F:\forever_multimonitor_addon`

The TOC interface number is a load contract, not proof of API behavior. Protected-frame behavior and every panel adapter still require tests in the actual Forever client.

## Components

### Lua addon

- Mainhand/Offhand split of the logical `UIParent` canvas, with left/right side, width and seam controls.
- WorldFrame viewport capture/apply/restore, with temporary layout-cache suppression and original state recovery.
- Registered panels, dynamic discovery through safe entry points, and independent default-bag grid placement.
- Protected HUD and known replacement-bag exclusions; unknown third-party frames remain untouched.
- Combat-deferred, keyed desired-state queue and debounced recovery.
- Per-character normalized drag positions for supported frames exposing native `OnDragStop`; saved positions are kept inside the active Offhand workspace.
- Panel scaling is constrained by the actual Offhand workspace and canvas height, even when that requires going below the preferred scale setting.
- Supported panel visibility lifecycle: `OnShow` routes into the workspace; `OnHide` restores original anchors and scale. Show/hide changes share a keyed desired-state operation so combat-deferred work converges on the latest visibility state.
- Raw-mouse CVar save/enable/restore, including logout recovery; profile-scoped default-map Escape persistence and restoration.
- In-game settings window with per-profile Midnight/Indigo/Classic dashboard themes, 50?100% background opacity, three-step setup wizard and a 15-second reversible preview with explicit Keep confirmation: `/fmm config`.

### Windows helper

`WindowsHelper` is a separate Windows executable. It enumerates displays (device name/ID, physical bounds, primary flag and effective DPI), places a visible WoW process window across selected display bounds, applies borderless styles, and saves the original style and full `WINDOWPLACEMENT` for explicit restore. `watch` is an optional, explicitly launched polling mode: it detects loss of a selected physical display and restores the original window state, falling back to the primary connected display if the original rectangle is no longer visible. It is not a service, does not start automatically, and does not use a network connection or Companion protocol.

The helper spans selected displays and optionally writes a versioned, data-only native geometry snapshot into the installed addon via `--addon-dir` and `--mainhand`. After `/reload`, `/fmm native apply` calibrates a two-display horizontal layout; other topologies use manual controls. Monitor selection remains CLI-only.

## Current implementation status

| Area | Status | Evidence |
|---|---|---|
| Forever manifest / Camelot metadata | Implemented, Interface 16001 | Structural validator |
| Config validation / per-character position schema | Implemented | Lua 5.1 runtime simulation |
| Mainhand/Offhand logical geometry | Implemented for left/right and seam limits | Lua 5.1 runtime simulation; live client pending |
| WorldFrame viewport | Transactional apply, rollback after anchor failure, original user-placed flag preservation; failed application blocks panel routing | Lua 5.1 fault-injection regression PASS; in-client render pending |
| Panel registry / ownership | Default bag grid + other registered families | Lua 5.1 simulation; family-specific non-bag adapters incomplete |
| Dynamic panel discovery | `ShowUIPanel`, `ToggleFrame`, named `CreateFrame`, bag hooks and addon-load scans | Lua 5.1 simulation; live client pending |
| Combat / recovery | Keyed latest-state queue and debounced recovery | Lua 5.1 runtime simulation |
| Panel visibility lifecycle | Show routes; hide restores original anchors/scale; combat deferral coalesces latest visibility state | Lua 5.1 runtime simulation; live panel tests pending |
| Drag-position persistence | Normalized per-character save/reapply for supported native drag-stop events | Lua 5.1 runtime simulation; panel-specific live tests pending |
| Raw mouse | Original `rawMouseEnable` value is saved and restored | Lua 5.1 runtime simulation; live input test pending |
| In-game options | Enable, side, width, seam, scale, raw mouse, named profiles, three-step setup wizard, 15-second preview/rollback, Keep confirmation, dashboard theme presets/opacity and `/fmm diagnostics` | Lua 5.1 runtime simulation; in-client visual/input test pending |
| Windows display enumeration | Device names/IDs, bounds, primary flag and DPI | Built helper; enumerated connected displays on the development PC |
| Native window placement | One-shot borderless placement, explicit restore and optional hotplug watch with safe fallback | Live WoW HWND 4480x1080 place/restore PASS on aligned 2560+1920 monitors; original offscreen window used primary fallback; hotplug/mixed-DPI rendering pending |
| Named profiles | Create, load, save, delete; legacy settings migrate to protected `Default` profile | Lua 5.1 runtime simulation; live UI/reload test pending |
| Dashboard themes | Midnight, Indigo and Classic presets with per-profile 50?100% background opacity; applies to dashboard and wizard only | Lua 5.1 runtime simulation; live visual test pending |
| Custom backgrounds / user media import | Not implemented; no code-free media-pack importer or file validation pipeline | Open |
| Edit Mode, protected HUD, Escape/focus and advanced panel lifecycle | Edit Mode pause/recover, default map Escape option and protected HUD exclusion; focus and actual HUD layout creation remain open | Simulated; live tests pending |
| Display hotplug monitoring / automatic rollback | Opt-in watcher detects selected-display loss and restores to the original visible rectangle or primary-display fallback; automatic reconnect/reapply is not implemented | Helper self-test; physical disconnect test open |
| Native geometry handoff | Atomic helper-generated Lua data file, schema validation, two-display calibration | C# / Lua simulated, no live WoW test |
| Full Offhand feature parity | Not achieved | Release gate open |

## Addon commands

- `/fmm` — command help
- `/fmm config` — open the in-game settings window
- `/fmm profile list|create <name>|use <name>|delete <name>` - manage named layouts
- `/fmm status` — report client, canvas and active profile
- `/fmm diagnostics` — report panel discovery/ownership, restore snapshots, queued operations, preview state and last error
- `/fmm apply` — apply the current layout
- `/fmm enable` / `/fmm disable` — activate/deactivate
- `/fmm side left|right` — choose Mainhand side
- `/fmm width 25-90` — Mainhand share of the logical canvas
- `/fmm seam 0-100` — seam offset in logical UI units
- `/fmm scale 0.5-1.5` — requested panel scale
- `/fmm mapescape on|off` — default World Map Escape behavior while the layout is enabled
- `/fmm native status|apply` — status and optional physical Mainhand calibration
- `/fmm rawmouse on|off` — raw mouse input while layout is active
- `/fmm reset` — disable and restore captured viewport/panel state

## Build and run the Windows helper

Build from the repository root:

```powershell
.\WindowsHelper\build.ps1
```

The build script directs TEMP/TMP, .NET CLI home and NuGet cache to `.tmp` inside this workspace. No external NuGet packages are used. The executable is created under `WindowsHelper\bin\Release\net10.0-windows`.

Example:

```powershell
$helper = ".\WindowsHelper\bin\Release\net10.0-windows\ForeverMultiMonitor.WindowsHelper.exe"
& $helper list
# Option A: one-shot placement, then restore when finished
& $helper place --monitors "\\.\DISPLAY5,\\.\DISPLAY1" --process auto
& $helper restore
# Option B instead of place: keep watching for display loss until Ctrl+C
& $helper watch --monitors "\\.\DISPLAY5,\\.\DISPLAY1" --process auto --interval-ms 1000
```

Use only display names returned by `list`. `place` refuses to overwrite an existing restore state. Keep the executable and its `window-state.json` together until `restore` succeeds. Read [Windows helper documentation](WindowsHelper/README.md) before placing a live game window.

## Verification

Dependency-free checks:

```powershell
node tools/validate.js
node tools/regression.js
```

Lua 5.1 parser and mocked runtime tests (test-only dependencies; cache stays in workspace):

```powershell
New-Item -ItemType Directory -Force .tmp | Out-Null
$env:TEMP = (Resolve-Path .tmp).Path
$env:TMP = $env:TEMP
$env:PIP_CACHE_DIR = Join-Path $env:TEMP "pip-cache"
python -m pip install --target (Join-Path $env:TEMP "python") -r tools/requirements-test.txt
$env:PYTHONPATH = Join-Path $env:TEMP "python"
python tools/runtime_regression.py
```

`WindowsHelper/build.ps1` builds the native helper. `list` and `self-test` are safe to run during verification; `place` and `watch` are deliberately not run automatically because they change the live WoW window.

At the current checkpoint, 54 source regression assertions, Lua 5.1 syntax parsing and mocked runtime scenarios, including named profile migration/switching, theme preset/opacity controls, options profile controls and the guided wizard, panel hide/restore/reopen and combat visibility convergence, pass; the Windows helper builds with zero warnings/errors and its display enumeration was exercised. **WoW HWND place/restore was exercised successfully on 2026-11-06, but the addon has NOT passed the in-client test matrix.** Expanded Lua 5.1 tests cover map Escape, calibration, bag grid, Edit Mode pause, viewport persistence and injected anchor errors; no physical hotplug or mixed-DPI in-game alignment test has been performed. See [the test matrix](docs/TEST_MATRIX.md) and [critical audit](docs/AUDIT_2026-11-06.md) before calling the project release-ready.

## Technical boundary

WoW Lua cannot enumerate physical Windows monitors, change the native WoW HWND style, or move/resize that window. Those operations belong to `WindowsHelper`. The helper provides opt-in hotplug monitoring but no resident controller, graphical display selector or direct helper-to-addon data channel. Automatic reconnect/reapply remains open. The addon consumes the resulting combined canvas through `UIParent`, optionally imports a verified native topology data file after `/reload`, and retains manual geometry controls.

See [Architecture](docs/ARCHITECTURE.md), [Feature Parity](docs/FEATURE_PARITY.md), [Setup](docs/SETUP.md), [Test Matrix](docs/TEST_MATRIX.md), and [Changelog](CHANGELOG.md).