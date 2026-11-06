# Forever MultiMonitor

A standalone, companion-free multi-monitor workspace for **World of Warcraft: Forever**. The project is an independent implementation of the public user-facing Offhand workflow; it does not copy Offhand source or implement its Companion process/protocol.

> **Development status: 0.3.2.** The addon core, basic in-game settings window and one-shot Windows window helper are implemented and locally tested. This is not yet a complete or live-verified Offhand replacement. No untested feature is represented as complete.

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
- WorldFrame viewport capture, apply and restore.
- Registered panel families and dynamic discovery through supported Blizzard panel entry points, bag toggles and named `CreateFrame` calls.
- Protected HUD and known replacement-bag exclusions; unknown third-party frames remain untouched.
- Combat-deferred, keyed desired-state queue and debounced recovery.
- Per-character normalized drag positions for supported frames exposing native `OnDragStop`.
- Panel scaling is constrained by the actual Offhand workspace and canvas height, even when that requires going below the preferred scale setting.
- Supported panel visibility lifecycle: `OnShow` routes into the workspace; `OnHide` restores original anchors and scale. Show/hide changes share a keyed desired-state operation so combat-deferred work converges on the latest visibility state.
- Raw-mouse CVar save/enable/restore, including logout recovery.
- In-game settings window and a three-step guided setup wizard covering native-window preparation, Mainhand side/width configuration and layout activation: `/fmm config`.

### Windows helper

`WindowsHelper` is a separate one-shot Windows executable. It enumerates displays (device name/ID, physical bounds, primary flag and effective DPI), places a visible WoW process window across the selected display bounds, applies borderless styles, and saves the original style and full `WINDOWPLACEMENT` for explicit restore. It does not stay resident, install a service, start automatically, use a network connection or communicate with Companion.

The helper makes the native window cover the selected displays. The addon then uses the resulting logical canvas and controls the in-game Mainhand/Offhand split. Monitor selection is currently a command-line operation, not part of the Lua UI.

## Current implementation status

| Area | Status | Evidence |
|---|---|---|
| Forever manifest / Camelot metadata | Implemented, Interface 16001 | Structural validator |
| Config validation / per-character position schema | Implemented | Lua 5.1 runtime simulation |
| Mainhand/Offhand logical geometry | Implemented for left/right and seam limits | Lua 5.1 runtime simulation; live client pending |
| WorldFrame viewport | Capture/apply/restore implemented | Lua 5.1 frame simulation; live client pending |
| Panel registry / ownership | Registered Blizzard families; shared placement primitive | Lua 5.1 simulation; family-specific adapters incomplete |
| Dynamic panel discovery | `ShowUIPanel`, `ToggleFrame`, named `CreateFrame`, bag hooks and addon-load scans | Lua 5.1 simulation; live client pending |
| Combat / recovery | Keyed latest-state queue and debounced recovery | Lua 5.1 runtime simulation |
| Panel visibility lifecycle | Show routes; hide restores original anchors/scale; combat deferral coalesces latest visibility state | Lua 5.1 runtime simulation; live panel tests pending |
| Drag-position persistence | Normalized per-character save/reapply for supported native drag-stop events | Lua 5.1 runtime simulation; panel-specific live tests pending |
| Raw mouse | Original `rawMouseEnable` value is saved and restored | Lua 5.1 runtime simulation; live input test pending |
| In-game options | Enable, side, width, seam, scale, raw mouse, named profiles, apply/reset and a three-step setup wizard with Mainhand controls and activation | Lua 5.1 runtime simulation; in-client visual/input test pending |
| Windows display enumeration | Device names/IDs, bounds, primary flag and DPI | Built helper; enumerated connected displays on the development PC |
| Native window placement | One-shot combined bounds, borderless styles and explicit full placement restore | .NET build; placement/restore not run against WoW |
| Named profiles | Create, load, save, delete; legacy settings migrate to protected `Default` profile | Lua 5.1 runtime simulation; live UI/reload test pending |
| Themes and custom backgrounds | Not implemented as a complete feature set | Open |
| Edit Mode, protected HUD, Escape/focus and advanced panel lifecycle | Not implemented as a complete feature set | Open |
| Display hotplug monitoring / automatic rollback | Not implemented; helper is one-shot | Open |
| Full Offhand feature parity | Not achieved | Release gate open |

## Addon commands

- `/fmm` — command help
- `/fmm config` — open the in-game settings window
- `/fmm profile list|create <name>|use <name>|delete <name>` - manage named layouts
- `/fmm status` — report client, canvas and active profile
- `/fmm apply` — apply the current layout
- `/fmm enable` / `/fmm disable` — activate/deactivate
- `/fmm side left|right` — choose Mainhand side
- `/fmm width 25-90` — Mainhand share of the logical canvas
- `/fmm seam 0-100` — seam offset in logical UI units
- `/fmm scale 0.5-1.5` — requested panel scale
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
& $helper place --monitors "\\.\DISPLAY5,\\.\DISPLAY1" --process auto
& $helper restore
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

`WindowsHelper/build.ps1` builds the native helper. `list` is safe to run during verification; `place` is deliberately not run automatically because it changes the live WoW window.

At the current checkpoint, 48 source regression assertions, Lua 5.1 syntax parsing and mocked runtime scenarios, including named profile migration/switching, options profile controls and the guided wizard, panel hide/restore/reopen and combat visibility convergence, pass; the Windows helper builds with zero warnings/errors and its display enumeration was exercised. **No WoW client live test or native window place/restore test has been performed.** See [the test matrix](docs/TEST_MATRIX.md) before calling the project release-ready.

## Technical boundary

WoW Lua cannot enumerate physical Windows monitors, change the native WoW HWND style, or move/resize that window. Those operations belong to `WindowsHelper`. The helper does not yet provide hotplug monitoring, a resident controller, a graphical display selector or a direct helper-to-addon data channel. The addon consumes the resulting combined canvas through `UIParent` and retains a manual geometry fallback.

See [Architecture](docs/ARCHITECTURE.md), [Feature Parity](docs/FEATURE_PARITY.md), [Setup](docs/SETUP.md), [Test Matrix](docs/TEST_MATRIX.md), and [Changelog](CHANGELOG.md).