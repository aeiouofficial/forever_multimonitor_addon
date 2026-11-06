# Forever MultiMonitor

Split the World of Warcraft: Forever interface across **MainMonitor** and **SecondMonitor1**. Keep the game view on MainMonitor while supported interface panels use the second display. Configure the layout from the in-game settings page or `/forevermultimonitor`.

The optional Windows helper spans the WoW window across selected displays, restores its previous window state, and can watch for a selected display disconnect.

## Compatibility

- World of Warcraft: Forever, build `1.60.1.70790` (interface `16001`, game type `camelot`).
- Windows helper requires Windows and the .NET 10 desktop runtime.

## Features

- Adjust MainMonitor side, width, seam, panel scale, and raw mouse input.
- Route supported Blizzard panels and default bags to SecondMonitor1; save supported panel positions per character.
- Recover eligible off-screen panels from the settings page or `/forevermultimonitor gather`.
- Configure named profiles, dashboard themes, and background opacity; use the setup wizard and reversible layout preview.
- Use the optional Windows helper for display enumeration, borderless spanning, restore, and opt-in disconnect recovery.

Protected HUD elements remain under Blizzard's control. Move action bars and other protected frames with Blizzard Edit Mode. Third-party panels are not moved unless a dedicated adapter supports them.

## Addon commands

- `/forevermultimonitor` — toggle the in-game settings window
- `/forevermultimonitor help` — list available commands
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

## Windows helper

Build from the repository root:

```powershell
.\WindowsHelper\build.ps1
```

The executable is created under `WindowsHelper\bin\Release\net10.0-windows`. For complete placement and recovery instructions, see [Windows helper documentation](WindowsHelper/README.md).

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

## Limits

The addon cannot resize the native WoW window or enumerate Windows displays. Use the optional helper to span and restore the game window. Its `watch` mode restores the window when a selected display disconnects; after reconnecting a display, check the current display list and run placement again. Protected HUD frames remain under Blizzard Edit Mode, and only supported Blizzard panels are routed by the addon.

Read the [setup guide](docs/SETUP.md) before spanning and the [changelog](CHANGELOG.md) for feature updates.
