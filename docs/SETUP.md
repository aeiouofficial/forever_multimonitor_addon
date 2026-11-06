# Companion-free setup

The addon and the Windows helper perform different jobs. The Windows helper spans the native game window across selected displays. The addon divides the resulting in-game canvas into Mainhand and Offhand.

## 1. Prepare the game

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

Select the displays that should form the combined game canvas. Example only (the names on your machine may differ):

```powershell
& $helper place --monitors "\\.\DISPLAY5,\\.\DISPLAY1" --process auto
```

The helper locates a visible WoW process window, saves its original window styles and full `WINDOWPLACEMENT`, removes standard window borders and places it over the rectangular union of the selected display bounds. `place` exits immediately.

For opt-in disconnect recovery, use `watch` instead of `place`; it performs placement and then polls the selected physical display IDs until a display disappears or you press Ctrl+C. On either event it restores the original window position if still visible, otherwise it moves the window onto the primary connected display. It does not automatically reapply after a display reconnects.

**Restore:**

```powershell
& $helper restore
```

Do not delete or move the helper executable or its `window-state.json` until restore succeeds. Do not run `place` again while a restore state exists. If WoW exits or recreates its HWND, automatic recovery is not possible; the helper retains the state file for diagnosis.

## 4. Configure the addon

1. Install this folder as `Interface/AddOns/ForeverMultiMonitor` under the live `_forever_` client.
2. Fully restart WoW after first installation.
3. Run `/fmm status` and confirm the logical canvas has the expected combined width.
4. Open `/fmm config` and select **Setup wizard** for the three-step guided flow, or configure directly in the dashboard.
5. Choose Mainhand left/right and set the width, seam offset and panel scale.
6. Create or load a named profile in the profile row if you need separate display layouts.
7. Enable the layout and inspect the WorldFrame and supported panels. Use Apply after changing the native window arrangement.

Named profile commands remain available: `/fmm profile list`, `/fmm profile create Desk`, `/fmm profile use Desk`, `/fmm profile delete Desk`. The protected `Default` profile cannot be deleted.

Slash-command fallback remains available:

```text
/fmm side left
/fmm width 50
/fmm seam 0
/fmm scale 1
/fmm enable
```

## 5. Recovery

- `/fmm disable` restores the captured in-session viewport and supported panel anchors/scales.
- `/fmm reset` disables the layout and restores the current session's captured state.
- The Windows helper's `restore` command restores the original native WoW window styles and placement.
- If the in-game UI becomes unusable, use `/reload` or disable the addon at character select.
- Back up Forever SavedVariables before testing development builds.

## Manual fallback

If the helper is not used, place the WoW window manually across the displays or use PowerToys FancyZones. FancyZones can help with manual placement but is not an automatic Offhand replacement and does not provide the helper's explicit restore snapshot.

## Limitations

The `place` command is one-shot. The optional foreground `watch` command polls selected display IDs and rolls back when one disappears; it does not automatically reapply when a display reconnects. No service or autostart is installed and no Companion-like protocol is used. The helper combines selected monitor bounds into one rectangle; gaps between non-adjacent or vertically offset displays remain inside that rectangle. The wizard guides the user through native-window preparation, Mainhand side/width configuration and activation, but Windows display enumeration and placement remain manual helper CLI operations; there is no integrated display selector or direct helper-to-addon handoff. Complete panel focus/Escape lifecycle, themes, custom backgrounds, Edit Mode and full Offhand parity remain open.
