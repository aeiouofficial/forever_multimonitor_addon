# Forever MultiMonitor Windows Helper

A one-shot Windows process for monitor enumeration and reversible WoW window placement. It is independent from the addon and does not implement, launch, or communicate with Offhand Companion.

## Build

Run from the repository root or this directory:

```powershell
.\WindowsHelper\build.ps1
```

The script directs TEMP/TMP, the .NET CLI home and NuGet cache to `F:\forever_multimonitor_addon\.tmp`. Build output stays under `WindowsHelper\bin`; no third-party packages are used.

## Commands

```powershell
$helper = ".\WindowsHelper\bin\Release\net10.0-windows\ForeverMultiMonitor.WindowsHelper.exe"
& $helper list
& $helper place --monitors "\\.\DISPLAY5,\\.\DISPLAY1" --process auto
& $helper restore
```

`list` reports Windows display device names, device IDs, physical-pixel bounds, primary status and effective DPI. `place` selects the union bounds of the listed displays, locates a visible WoW process window, saves the original style and full `WINDOWPLACEMENT`, removes the standard border styles and applies the combined bounds. `restore` verifies that the saved HWND still belongs to the same process, restores the original styles and placement, then removes the state file.

The helper defaults to known WoW process names. Supply `--process Wow.exe` if the Forever executable uses a different name. Use only device names returned by `list`.

## Safety and limits

- Placement is explicitly one-shot; there is no service, autostart, tray resident, hotplug monitor or background process.
- The saved restore state is stored next to the executable. Keep that file and the executable together until `restore` succeeds.
- Do not run `place` a second time while a restore state exists. Restore first.
- If the game exits or the HWND is recreated, automatic recovery cannot restore the old HWND. The state file is retained for manual diagnosis; restart WoW and restore windowed mode manually if necessary.
- Selected monitor bounds are combined into one rectangular window. Gaps between vertically offset or non-adjacent displays remain part of that rectangle; inspect the coordinates reported by `list` before applying.
- The helper sets its own process DPI awareness. It does not change WoW's DPI-awareness mode or promise pixel-perfect behavior for every mixed-DPI game-client build.
- No WoW client window is moved during build or test. Run `place` only when intentionally testing the live game.
- The helper exposes the combined Windows canvas to WoW. `/fmm config` controls the in-game Mainhand/Offhand split independently.