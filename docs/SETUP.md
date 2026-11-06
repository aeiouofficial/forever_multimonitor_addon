# Companion-free Windows setup

This guide covers the Windows window-placement portion only. The addon cannot change the native WoW window size or style.

## 1. Prepare WoW

1. Start the WoW Forever client and set Display Mode to **Windowed** (not Windowed Fullscreen).
2. Set the Windows display arrangement to match the physical monitor arrangement.
3. For FancyZones spanning, use the same Windows display scaling percentage on both monitors.
4. Keep the WoW window at a normal, resizable window size before assigning zones.

## 2. Configure PowerToys FancyZones

1. Open PowerToys → FancyZones → Layout editor.
2. Enable **Allow zones to span across monitors**. Microsoft requires all connected monitors to use the same DPI scaling for this mode.
3. Create or choose a custom layout whose combined zone area covers both displays. A Canvas layout can be used to shape a zone across the combined desktop.
4. Drag the WoW window. Hold **Shift** (the default activation setting) to show zones while dragging.
5. If the target requires multiple adjacent zones, activate the first zone and hold **Ctrl** while continuing to drag to select multiple zones. Alternatively, drop into a zone already spanning both monitors.
6. Confirm that the WoW client window covers the intended combined desktop area.

PowerToys/FancyZones is an external Windows feature. This addon does not automate its configuration or control the native WoW window.

## 3. Configure the addon

1. Install this folder as `Interface/AddOns/ForeverMultiMonitor` under the live `_forever_` client.
2. Fully restart WoW after first installation.
3. Run `/fmm status` and confirm the logical canvas is the expected combined width.
4. Set the Mainhand display side and approximate width, for example `/fmm side left` and `/fmm width 50`.
5. Run `/fmm enable` to activate the viewport and panel layout. Use `/fmm apply` to reapply it after changing the window or monitor arrangement.

## 4. Recovery

- `/fmm disable` restores the captured viewport and supported panel positions.
- `/fmm reset` disables the layout and restores the current session's captured positions.
- If the game UI becomes unusable, use `/reload` or disable the addon at character select.
- Back up the Forever SavedVariables before testing builds.

## Limitations

FancyZones aligns a native window to Windows zones. It does not understand WoW's internal viewport or UI panels. The addon controls those separately. Automatic monitor enumeration, automatic HWND resize, border removal, native-window recovery and exact physical-pixel topology are not provided by this addon-only design.
