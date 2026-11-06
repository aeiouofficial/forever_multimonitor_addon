# Forever MultiMonitor

A standalone multi-monitor workspace for **World of Warcraft: Forever**. The addon, settings, commands and Windows helper use the Forever MultiMonitor name and its own interface.

> **Development status: 0.4.1.** The addon core, in-game settings window and Windows helper with one-shot placement plus opt-in hotplug watch are implemented and locally tested. The requested feature set has not passed live in-game verification. No untested feature is represented as complete.

## Behavior contract and current status

The selected behavior contract is package version **2.1.2 Beta 17**, CurseForge file **9029504**, Forever interface **16001**, paired helper compatibility release **beta.13**. The package was used only to compare observable behavior; its source and assets are not part of this project. Later Beta 20/26 releases and the package's mutable `Unreleased` section do not replace the selected version contract.

The inspected package license permits personal, non-commercial in-game use and prohibits redistribution, repackaging, or derivative copies. This project remains independently implemented and does not copy package source or media.

**The requested feature set is incomplete.** The local implementation validates exact physical game/workspace rectangles for offset and stacked displays and has an explicitly selected single-screen ultrawide mode. Remaining gaps include Forever cold-launch SavedVariables recovery; player-confirmed protected Edit Mode fallback/restore prompts; broader panel-family lifecycle and open-state persistence beyond current routing/default bags; minimap/map-size and popup/chat-bubble behavior; custom theme colors and cross-character profile copy. The Windows helper is a CLI; it does not provide a graphical display selector, cold-launch bridge, or automatic span workflow.

The installed copy under the live Forever AddOns directory was hash-checked, but the settings and layout have not been verified in-game. In-game settings visibility, layout behavior, combat/taint, physical hotplug and mixed-DPI UI verification remain open.

The latest local checks passed: 67 source regression checks, validation of 17 TOC Lua modules, the Lua 5.1 runtime suite and the Windows helper Release build. See [the test matrix](docs/TEST_MATRIX.md) for the checks and remaining live-client gates.

## Target client

- WoW Forever launch build: `1.60.1.70790`
- Addon interface: `16001`
- Forever game type: `camelot`
- Addon install folder: `_forever_/Interface/AddOns/ForeverMultiMonitor`
- Local workspace: `F:\forever_multimonitor_addon`

The TOC interface number is a load contract, not proof of API behavior. Protected-frame behavior and every panel adapter still require tests in the actual Forever client.

## Components

### Lua addon

- MainMonitor/SecondMonitor1 split of the logical `UIParent` canvas, with left/right side, width and seam controls.
- WorldFrame viewport capture/apply/restore, with temporary layout-cache suppression and original state recovery.
- Registered panels, dynamic discovery through safe entry points, and independent default-bag grid placement.
- Forever Professions-family frames and forbidden frames remain Blizzard-owned; the generic panel router does not hook or move them.
- Protected HUD and known replacement-bag exclusions; unknown third-party frames remain untouched.
- Combat-deferred, keyed desired-state queue and debounced recovery.
- Per-character normalized drag positions for supported frames exposing native `OnDragStop`; saved positions are kept inside the active SecondMonitor1 workspace.
- Panel scaling is constrained by the actual SecondMonitor1 workspace and canvas height, even when that requires going below the preferred scale setting.
- Supported panel visibility lifecycle: `OnShow` routes into the workspace; `OnHide` restores original anchors and scale. Show/hide changes share a keyed desired-state operation so combat-deferred work converges on the latest visibility state.
- Gather recovers off-screen registered panels, `UIPanelWindows`, and movable `UIParent` children when their title edge is inaccessible; protected, forbidden, tooltip and world frames are excluded. The action is available from settings and `/forevermultimonitor gather`.
- Raw-mouse CVar save/enable/restore, including logout recovery; profile-scoped default-map Escape persistence and restoration.
- In-game settings window registered in the WoW AddOns settings page, also reachable with `/forevermultimonitor config`; includes per-profile Midnight/Indigo/Classic dashboard themes, background opacity from 50% to 100%, a three-step setup wizard and a 15-second reversible preview with explicit Keep confirmation.

### Windows helper

`WindowsHelper` is a separate Windows executable. It enumerates displays (device name/ID, physical bounds, primary flag and effective DPI), places a visible WoW process window across selected display bounds, applies borderless styles, and saves the original style and full `WINDOWPLACEMENT` for explicit restore. `watch` is an optional, explicitly launched polling mode: it detects loss of a selected physical display and restores the original window state, falling back to the primary connected display if the original rectangle is no longer visible. It is not a service, does not start automatically, and does not use a network connection or external protocol.

The helper spans exactly two selected displays by default and optionally writes exact versioned native geometry into the installed addon via an explicitly selected absolute `--addon-dir` on any drive. Use `--mainmonitor` to select the display used by MainMonitor. After `/reload`, `/forevermultimonitor native apply` supports offset, stacked and asymmetric two-display rectangles. Single-screen 32:9/32:10 mode requires `--single-ultrawide`, exactly one selected display and `--addon-dir`; it creates an equal split controlled by the addon's MainMonitor side. Monitor selection remains CLI-only. Active native geometry is rejected after Forever reports a different physical canvas; the addon then rolls back instead of compressing stale dual-display settings onto one screen.

## Current implementation status

| Area | Status | Evidence |
|---|---|---|
| Forever manifest / Camelot metadata | Implemented, Interface 16001 | Structural validator |
| Config validation / per-character position schema | Implemented | Lua 5.1 runtime simulation |
| MainMonitor/SecondMonitor1 logical geometry | Implemented for left/right and seam limits | Lua 5.1 runtime simulation; live client pending |
| WorldFrame viewport | Transactional apply, rollback after anchor failure, original user-placed flag preservation; failed application blocks panel routing | Lua 5.1 fault-injection regression PASS; in-client render pending |
| Panel registry / ownership | Default bag grid + other registered families | Lua 5.1 simulation; family-specific non-bag adapters incomplete |
| Dynamic panel discovery | `ShowUIPanel`, `ToggleFrame`, named `CreateFrame`, bag hooks and addon-load scans | Lua 5.1 simulation; live client pending |
| Combat / recovery | Keyed latest-state queue and debounced recovery | Lua 5.1 runtime simulation |
| Panel visibility lifecycle | Show routes; hide restores original anchors/scale; combat deferral coalesces latest visibility state | Lua 5.1 runtime simulation; live panel tests pending |
| Drag-position persistence | Normalized per-character save/reapply for supported native drag-stop events | Lua 5.1 runtime simulation; panel-specific live tests pending |
| Gather off-screen UI | Registry panels, `UIPanelWindows`, and movable `UIParent` children are filtered and moved into MainMonitor | Lua 5.1 runtime simulation; live panel recovery test pending |
| Raw mouse | Original `rawMouseEnable` value is saved and restored | Lua 5.1 runtime simulation; live input test pending |
| In-game options | AddOns settings category plus slash openers, enable, side, width, seam, scale, raw mouse, named profiles, setup wizard, preview/rollback, theme presets/opacity and diagnostics | Lua 5.1 legacy/modern registration simulation; real Forever settings page/input test pending |
| Windows display enumeration | Device names/IDs, bounds, primary flag and DPI | Built helper; enumerated connected displays on the development PC |
| Native window placement | One-shot borderless placement across exactly two selected displays, explicit restore and optional hotplug watch with safe fallback | Earlier live WoW HWND 4480x1080 place/restore used aligned 2560+1920 monitors; original offscreen window used primary fallback; hotplug/mixed-DPI rendering pending |
| Named profiles | Create, load, save, delete; legacy settings migrate to protected `Default` profile | Lua 5.1 runtime simulation; live UI/reload test pending |
| Dashboard themes | Midnight, Indigo and Classic presets with per-profile background opacity from 50% to 100%; applies to dashboard and wizard only | Lua 5.1 runtime simulation; live visual test pending |
| Custom theme colors | Not implemented; only the built-in palettes are available | Open against Beta 17 |
| Edit Mode, protected HUD, Escape/focus and advanced panel lifecycle | Edit Mode pause/recover, default map Escape option and protected HUD exclusion; focus and actual HUD layout creation remain open | Simulated; live tests pending |
| Display hotplug monitoring / automatic rollback | Opt-in watcher detects selected-display loss and restores to the original visible rectangle or primary-display fallback; automatic reconnect/reapply is not implemented | Helper self-test; physical disconnect test open |
| Native geometry handoff | Atomic helper-generated Lua data file; exact two-display rectangles or explicit single-ultrawide mode; active Forever screen-size validation; explicit absolute addon paths on any drive | C# / Lua simulated, no live WoW geometry test |
| Complete requested feature coverage | Not achieved | Release gate open |

## Addon commands

- `/forevermultimonitor` — toggle the in-game settings window
- `/forevermultimonitor config` — toggle the settings window
- `/forevermultimonitor wizard` — open the setup wizard
- `/forevermultimonitor gather` — return eligible off-screen panels to MainMonitor
- `/forevermultimonitor diag` — print runtime, panel, geometry and error diagnostics
- `/forevermultimonitor profile list|create <name>|use <name>|delete <name>` - manage named layouts
- `/forevermultimonitor status` — report client, canvas and active profile
- `/forevermultimonitor diagnostics` — report panel discovery/ownership, restore snapshots, queued operations, preview state and last error
- `/forevermultimonitor apply` — apply the current layout
- `/forevermultimonitor enable` / `/forevermultimonitor disable` — activate/deactivate
- `/forevermultimonitor side left|right` — choose MainMonitor side
- `/forevermultimonitor width 25-90` — MainMonitor share of the logical canvas
- `/forevermultimonitor seam 0-100` — seam offset in logical UI units
- `/forevermultimonitor scale 0.5-1.5` — requested panel scale
- `/forevermultimonitor mapescape on|off` — default World Map Escape behavior while the layout is enabled
- `/forevermultimonitor native status|apply` — status and optional physical MainMonitor calibration
- `/forevermultimonitor rawmouse on|off` — raw mouse input while layout is active
- `/forevermultimonitor reset` — disable and restore captured viewport/panel state

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

At the current checkpoint, `node tools/regression.js` passes 67 source checks; `node tools/validate.js` passes for 17 TOC Lua modules; the Lua 5.1 parser/runtime suite passes profile and native-handoff migration, branded command registration, settings-category opening, Gather candidate discovery and safety filters, geometry rollback and panel lifecycle; the Windows helper Release build has 0 warnings/errors and its self-test passes two/single-display validation, handoff schema and zero-display recovery. **The addon has not passed the in-client test matrix.** The game has not been restarted since installation, so settings-page visibility, slash openers, layout behavior, combat/taint, physical hotplug and mixed-DPI UI alignment remain unverified. See [the test matrix](docs/TEST_MATRIX.md) and [critical audit](docs/AUDIT_2026-11-06.md) before calling the project release-ready.

## Technical boundary

WoW Lua cannot enumerate physical Windows monitors, change the native WoW HWND style, or move/resize that window. Those operations belong to `WindowsHelper`. The helper provides opt-in hotplug monitoring but no resident controller, graphical display selector or direct helper-to-addon data channel. Automatic reconnect/reapply remains open. The addon consumes the resulting combined canvas through `UIParent`, optionally imports a verified native topology data file after `/reload`, and retains manual geometry controls.

See [Architecture](docs/ARCHITECTURE.md), [Feature Parity](docs/FEATURE_PARITY.md), [Setup](docs/SETUP.md), [Test Matrix](docs/TEST_MATRIX.md), and [Changelog](CHANGELOG.md).
