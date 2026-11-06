# Forever MultiMonitor Windows Helper

A standalone Windows executable for monitor enumeration and reversible WoW window placement, with a one-shot mode and an explicitly launched hotplug-watch mode. It is independent from the addon and does not implement, launch, or communicate with Offhand Companion.

## Build

Run from the repository root or this directory:

```powershell
.\WindowsHelper\build.ps1
```

The script directs TEMP/TMP, the .NET CLI home and NuGet cache to `F:\forever_multimonitor_addon\.tmp`. Build output stays under `WindowsHelper\bin`; no third-party packages are used.

## Commands

Optional `--addon-dir <absolute-addon-path>` and `--mainhand <selected-display-name>` enable a generated data-only Lua monitor snapshot. With these arguments, reload WoW after placement and run `/fmm native apply`. Path validation refuses writing to C: and requires an actual installed addon manifest.

```powershell
$helper = ".\WindowsHelper\bin\Release\net10.0-windows\ForeverMultiMonitor.WindowsHelper.exe"
& $helper list
# Option A: one-shot placement and explicit restore
& $helper place --monitors "\\.\DISPLAY5,\\.\DISPLAY1" --process auto
& $helper restore
# Option B instead of place: opt-in hotplug watch until Ctrl+C
& $helper watch --monitors "\\.\DISPLAY5,\\.\DISPLAY1" --process auto --interval-ms 1000
# Pure geometry/identity self-test; does not move a live window
& $helper self-test
```

`list` reports Windows display device names, device IDs, physical-pixel bounds, primary status and effective DPI. `place` selects the union bounds of the listed displays, locates a visible WoW process window, saves the original style and full `WINDOWPLACEMENT`, removes the standard border styles and applies the combined bounds. `restore` verifies that the saved HWND still belongs to the same process, restores the original styles and placement, then removes the state file. If the original rectangle is no longer visible on any connected display, restore centers the window on the primary connected display. `watch` performs placement and then polls selected stable display IDs; on selected-display loss it runs the same safe rollback. Ctrl+C also restores and exits. `--interval-ms` accepts 250 to 10000 ms (default 1000). `self-test` exercises display identity detection and safe-restore geometry without touching a live window.

The helper defaults to known WoW process names. Supply `--process Wow.exe` if the Forever executable uses a different name. Use only device names returned by `list`.

## Safety and limits

- `place` is one-shot. `watch` is opt-in and remains in the foreground only while the user has launched it; there is no service, autostart, tray resident or automatic background process.
- The saved restore state is stored next to the executable. Keep that file and the executable together until `restore` succeeds.
- Do not run `place` a second time while a restore state exists. Restore first. Competing helper invocations cannot overwrite a previously committed state file; the second process fails instead.
- If the game exits or the HWND is recreated, automatic recovery cannot restore the old HWND. The state file is retained for manual diagnosis; restart WoW and restore windowed mode manually if necessary.
- The watcher detects selected-display loss by polling. It does not automatically reapply placement when a disconnected display returns; rerun `place` or `watch` after checking `list`.
- Selected monitor bounds are combined into one rectangular window. Gaps between vertically offset or non-adjacent displays remain part of that rectangle; inspect the coordinates reported by `list` before applying.
- The helper sets its own process DPI awareness. It does not change WoW's DPI-awareness mode or promise pixel-perfect behavior for every mixed-DPI game-client build.
- No WoW client window is moved during build or pure self-test. A controlled 2026-11-06 live test explicitly invoked `place` across DISPLAY5 + DISPLAY1 (4480x1080), followed immediately by `restore`. Restore selected the documented primary-screen fallback because the original saved rectangle was not sufficiently visible. The test did not validate WoW's in-game UI or hotplug behavior.
- The helper exposes the combined Windows canvas to WoW. `/fmm config` controls the Mainhand/Offhand split. A validated two-display handoff is available when explicitly requested, not automatically.