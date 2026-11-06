# standalone setup

The addon and Windows helper perform different jobs. The helper spans the native game window across selected displays. The addon calls the 3D game view `MainMonitor` and the remaining panel area `SecondMonitor1`.

## 1. Prepare the game

Install the addon files into the active Forever client's `Interface\AddOns\ForeverMultiMonitor` directory before invoking the optional `--addon-dir` handoff. The handoff accepts an absolute path on any drive and validates that it contains this addon's TOC and `Core/RuntimeGeometry.lua`. Only copy the TOC and `Core` modules, not workspace build or temp folders.

1. Start WoW Forever and use **Windowed** mode (not Windowed Fullscreen).
2. Arrange the displays in Windows Display Settings as they are physically arranged.
3. Confirm the display resolution and scaling values. Mixed-DPI arrangements are enumerated by the helper, but pixel-perfect WoW behavior is not yet live-verified.
4. Keep the game in a normal, resizable window before applying placement.

## 2. Build and inspect the Windows helper

From the repository root:

```powershell
.\WindowsHelper\build.ps1
$helper = ".\WindowsHelper\bin\Release\net10.0-windows\ForeverMultiMonitor.WindowsHelper.exe"
& $helper list
```

`list` reports the Windows device name, stable monitor device ID, bounds, primary state and effective DPI. Device names can change after hardware or driver changes; always use the current output.

## 3. Span the WoW window

For normal spanning, select exactly two displays that should form the combined game canvas. Example only (the names on your machine may differ):

```powershell
& $helper place --monitors "\\.\DISPLAY5,\\.\DISPLAY1" --process auto
```

`--mainmonitor` selects the display assigned to `MainMonitor`; without it, the helper selects the primary member of the requested display set, or the first display if none is marked primary. `--addon-dir` is an explicit absolute installed-addon path on any drive. Together these options let the helper write versioned monitor geometry. After placement run `/reload`, then `/forevermultimonitor native status` and `/forevermultimonitor native apply`. The addon maps the selected `MainMonitor` and `SecondMonitor1` rectangles independently, including vertical offsets, stacked layouts, mixed resolutions and negative Windows coordinates. Gaps between selected rectangles remain inside the native WoW window and do not become part of either UI rectangle.

For the Beta 17 single-screen 32:9/32:10 workflow, select one display and opt in explicitly:

```powershell
$addonDir = Read-Host "Absolute path to the installed ForeverMultiMonitor addon folder"
& $helper place --monitors "\\.\DISPLAY5" --single-ultrawide --process auto --addon-dir $addonDir
```

The flag is required for one-display selection and requires `--addon-dir`; it writes `mode = "single-ultrawide"`. After placement, `/reload` and `/forevermultimonitor native apply` activate an equal 50/50 split. The addon profile's `MainMonitor` side chooses which half is the game view. Without the flag, `place` and `watch` require exactly two distinct displays; the helper never infers single-screen mode from resolution.

The helper locates a visible WoW process window, saves its original window styles and full `WINDOWPLACEMENT`, removes standard window borders and places it over the rectangular union of selected display bounds. `place` exits immediately.

For opt-in disconnect recovery, use `watch` instead of `place`; it performs placement and then polls the selected physical display IDs until a display disappears or you press Ctrl+C. On either event it restores the original window position if still visible, otherwise it moves the window onto the primary connected display. If Windows temporarily enumerates no displays, it restores the saved styles/placement without inventing a fallback monitor. The watcher does not automatically reapply after a display reconnects.

**Restore:**

```powershell
& $helper restore
```

Do not delete or move the helper executable or its `window-state.json` until restore succeeds. Do not run `place` again while a restore state exists. If WoW exits or recreates its HWND, automatic recovery is not possible; the helper retains the state file for diagnosis.

## 4. Configure the addon

1. Install this folder as `Interface/AddOns/ForeverMultiMonitor` under the live `_forever_` client.
2. Fully restart WoW after first installation.
3. Run `/forevermultimonitor status` and confirm the logical canvas has the expected combined width.
4. Open **Interface/Settings → AddOns → Forever MultiMonitor**, or type `/forevermultimonitor config`. Select **Setup wizard** for the three-step guided flow, or configure directly in the dashboard.
5. Choose the `MainMonitor` side and set its width, seam offset and panel scale. The native calibration button and map Escape option are also available.
6. Select a dashboard theme (Midnight, Indigo or Classic) and set background opacity between 50% and 100%; these values are stored per profile. The theme affects the options dashboard and wizard, not game panels.
7. Create or load a named profile in the profile row if you need separate display layouts.
8. Enable the layout and inspect the WorldFrame and supported panels. Use Apply after changing the native window arrangement.

Named profile commands remain available: `/forevermultimonitor profile list`, `/forevermultimonitor profile create Desk`, `/forevermultimonitor profile use Desk`, `/forevermultimonitor profile delete Desk`. The protected `Default` profile cannot be deleted.

Diagnostics are available at any time with `/forevermultimonitor diag` or `/forevermultimonitor diagnostics`; the command reports current panel ownership, active restore snapshots, deferred operations, preview state, geometry and the last captured error without changing the layout.

Slash-command fallback remains available:

```text
/forevermultimonitor side left
/forevermultimonitor width 50
/forevermultimonitor seam 0
/forevermultimonitor scale 1
/forevermultimonitor enable
```

## 5. Recovery

- `/forevermultimonitor disable` restores the captured in-session viewport and supported panel anchors/scales.
- `/forevermultimonitor reset` disables the layout and restores the current session's captured state.
- **Preview 15s** temporarily enables the layout; click **Keep layout** to confirm. If not confirmed within 15 seconds, the previous disabled state is restored. `/forevermultimonitor enable`, `/forevermultimonitor disable`, `/forevermultimonitor apply` and `/forevermultimonitor reset` invalidate the pending preview timer so it cannot later override an explicit command.
- The Windows helper's `restore` command restores the original native WoW window styles and placement.
- If the in-game UI becomes unusable, use `/reload` or disable the addon at character select.
- Back up Forever SavedVariables before testing development builds.

## Manual fallback

If the helper is not used, place the WoW window manually across the displays or use PowerToys FancyZones. This manual setup does not provide the helper's saved restore snapshot or hotplug recovery.

## Limitations

The `place` command is one-shot. The optional foreground `watch` command polls selected display IDs and rolls back when one disappears; it does not automatically reapply when a display reconnects. No service, autostart, GUI selector or external protocol is installed. Versioned, opt-in file-based handoff works via `--addon-dir` and `/reload`. `/forevermultimonitor gather` scans registered panels, `UIPanelWindows` and movable `UIParent` children; it skips protected/forbidden frames, tooltips and WorldFrame, and is also available from the dashboard. Live recovery behavior remains unverified. Forever in-client viewport, combat/taint behavior, protected HUD prompts, broader panel-family lifecycle, minimap/map-size, chat-bubble/popup handling, custom theme colors and full requested behavior coverage remain open. Built-in dashboard themes do not theme in-game Blizzard panels.
