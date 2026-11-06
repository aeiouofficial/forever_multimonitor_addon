# Forever MultiMonitor Windows Helper

A standalone Windows executable for monitor enumeration and reversible WoW window placement, with a one-shot mode and an explicitly launched hotplug-watch mode. It belongs to Forever MultiMonitor and hands geometry to the addon only through the explicit versioned file handoff.

## Build

Run from the repository root or this directory:

```powershell
.\WindowsHelper\build.ps1
```

Build output stays under `WindowsHelper\bin`; no third-party packages are used.

## Commands

Optional `--addon-dir <absolute-addon-path>` and `--mainmonitor <selected-display-name>` enable a generated data-only Lua monitor snapshot. The path must be absolute and point to the installed addon directory containing `ForeverMultiMonitor.toc` and `Core/RuntimeGeometry.lua`; an explicitly selected C: path is valid when those files exist and are writable. `--single-ultrawide` requires this handoff path and emits `mode = "single-ultrawide"`; reload WoW after placement and run `/forevermultimonitor native apply`.

```powershell
$helper = ".\WindowsHelper\bin\Release\net10.0-windows\ForeverMultiMonitor.WindowsHelper.exe"
& $helper list
# Normal spanning across exactly two selected displays, then explicit restore
& $helper place --monitors "\\.\DISPLAY5,\\.\DISPLAY1" --process auto
& $helper restore
# Opt-in hotplug watch until Ctrl+C
& $helper watch --monitors "\\.\DISPLAY5,\\.\DISPLAY1" --process auto --interval-ms 1000
# Pure geometry/identity self-test; does not move a live window
& $helper self-test
```

`list` reports Windows display device names, IDs, physical-pixel bounds, primary status and effective DPI. Without `--single-ultrawide`, normal `place` and `watch` spanning require exactly two distinct connected displays. With the explicit flag, exactly one display is accepted; zero, two, or three-plus displays are rejected. The flag requires `--addon-dir` and marks the generated handoff as `single-ultrawide` so the addon can apply the selected 50/50 split. It is intended for one-screen 32:9/32:10 layouts; the helper does not infer this mode from monitor dimensions. Unmarked handoffs retain dual-display behavior. `place` selects the union bounds of the selected display or displays, locates a visible WoW process window, saves the original style and full `WINDOWPLACEMENT`, removes the standard border styles and applies the combined bounds. `restore` verifies that the saved HWND still belongs to the same process, restores the original styles and placement, then removes the state file. If the original rectangle is no longer visible on any connected display, restore centers the window on the primary connected display. `watch` performs placement and then polls selected stable display IDs; on selected-display loss it runs the same safe rollback. Ctrl+C also restores and exits. `--interval-ms` accepts 250 to 10000 ms (default 1000). `self-test` checks both display-selection modes, the handoff marker and addon-path contract, display identity, and safe-restore geometry without touching a live window.

For single-screen mode, add `--single-ultrawide --addon-dir <absolute-addon-path>` to `place` or `watch` and pass exactly one device name returned by `list`.

The helper defaults to known WoW process names. Supply `--process Wow.exe` if the Forever executable uses a different name. Use only device names returned by `list`.

## Safety and limits

Restore decisions use the captured screen rectangle. `WINDOWPLACEMENT` keeps its original workspace coordinates, and any primary-display fallback is applied in screen coordinates after the placement restore. Older saved states without a screen rectangle remain readable and rely on Windows' native off-screen placement adjustment. The helper refreshes non-client frame styles after restore.

If Windows temporarily enumerates zero connected displays, `watch` restores the saved styles and `WINDOWPLACEMENT` without a screen-position fallback because there is no connected display to target.

- `place` is one-shot. `watch` is opt-in and remains in the foreground only while the user has launched it; there is no service, autostart, tray resident or automatic background process.
- The saved restore state is stored next to the executable. Keep that file and the executable together until `restore` succeeds.
- Do not run `place` a second time while a restore state exists. Restore first. Competing helper invocations cannot overwrite a previously committed state file; the second process fails instead.
- If the game exits or the HWND is recreated, automatic recovery cannot restore the old HWND. The state file is retained for manual diagnosis; restart WoW and restore windowed mode manually if necessary.
- The watcher detects selected-display loss by polling. It does not automatically reapply placement when a disconnected display returns; rerun `place` or `watch` after checking `list`.
- Selected monitor bounds are combined into one rectangular window. Gaps between vertically offset or non-adjacent displays remain part of that rectangle; inspect the coordinates reported by `list` before applying.
- The helper sets its own process DPI awareness. It does not change WoW's DPI-awareness mode or promise pixel-perfect behavior for every mixed-DPI game-client build.
- The pure self-test checks helper geometry and identity handling without moving a WoW window. `place` and `watch` change the live WoW window; use `restore` before exiting the helper session.
- The helper exposes the combined Windows canvas to WoW. `/forevermultimonitor config` controls the `MainMonitor`/`SecondMonitor1` layout. A validated two-display handoff is available when explicitly requested, not automatically.
