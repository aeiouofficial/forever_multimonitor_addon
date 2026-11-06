# Architecture

## Failure and rollback contract (unreleased follow-up)

Applying the in-game layout requires a successful viewport update and, outside Edit Mode, successful routing of all visible supported panels. Panel routing is intentionally paused while Edit Mode is open and resumes on exit. Forever Professions-family frames and forbidden frames remain Blizzard-owned and are not hooked or moved by the generic router. If geometry, viewport application or panel routing fails, the addon disables the attempted layout and restores panel snapshots, viewport anchors, raw mouse and map Escape state; it does not record an applied layout. Panel restore retains its original snapshot when an anchor or scale operation fails, so a later retry remains possible. Deferred callbacks returning `false` are diagnosed without overwriting a more specific callback error. A failed enable is reverted instead of being saved as active; preview cannot be confirmed after a failed apply.

The Windows helper requires exactly two selected displays by default. The Beta 17 single-screen 32:9/32:10 mode is available only with explicit `--single-ultrawide`, exactly one display, and a validated absolute `--addon-dir`. Dual-display handoffs contain both exact physical rectangles; single-ultrawide handoffs carry an explicit mode marker and Lua derives the equal split from the profile's MainMonitor side. Active Forever topology is checked against `GetPhysicalScreenSize()` during every geometry calculation; a mismatch clears the stale topology and causes the existing layout rollback. The helper persists both original `WINDOWPLACEMENT` workspace coordinates and the original `GetWindowRect` screen rectangle. It uses the screen rectangle to assess visibility on connected monitors. Restoration passes the original workspace coordinates only to `SetWindowPlacement`; a fallback uses screen-coordinate `SetWindowPos`. If no monitor is enumerable, it restores the saved styles/placement without inventing a display fallback. Existing saved states without a screen rectangle remain supported via Windows' own placement adjustment. The helper reports success only after frame-style refresh completes.

## Runtime boundary

The addon runs inside WoW Forever's Lua sandbox. It arranges in-game frames and the 3D viewport, but cannot call Win32 APIs, enumerate physical displays, resize the game HWND or remove native window borders.

The standalone implementation has two separate components:

- **Lua addon:** logical MainMonitor/SecondMonitor1 viewport, supported panel routing, configuration, persistence and recovery.
- **Windows helper:** display enumeration and explicit one-shot native window placement/restoration. It is a standalone executable; no service, autostart, resident monitor or external protocol is used.

The helper makes the game window cover the selected display bounds. The addon then consumes the resulting combined logical `UIParent` canvas. Optional versioned data-only `RuntimeGeometry.lua` handoff is written to a selected addon directory by the helper and validated after `/reload`. There is no resident interprocess protocol.

## Addon modules

- `Bootstrap.lua`: namespace, guarded execution and keyed combat-deferred work.
- `Compat.lua`: runtime build, project and optional-API probes.
- `Config.lua`: account defaults, named profile migration/create/load/delete, profile validation and per-character position schema migration.
- `RawMouse.lua`: save/enable/restore of the user's `rawMouseEnable` CVar.
- `Geometry.lua`: logical canvas and MainMonitor/SecondMonitor1 rectangles.
- `RuntimeGeometry.lua` / `NativeGeometry.lua`: optional versioned monitor handoff, exact two-display rectangles, explicit single-ultrawide mode, overlap validation, and active screen-size checks.
- `MapEscape.lua`: reversible default World Map Escape-list state.
- `Viewport.lua`: WorldFrame anchors + layout-cache flag capture, transactional crop with rollback on partial anchor failure, and restoration. Failed viewport application prevents downstream panel routing in `Init.lua`.
- `PanelRegistry.lua`: supported frame names, one owner per family, protected-HUD/replacement-bag exclusions.
- `PanelControllers.lua`: family dispatch and nonoverlapping default-bag grid; other family adapters incomplete.
- `Panels.lua`: discovery and anchor snapshots, SecondMonitor1-rectangle clamping and effective-scale conversion, bounded bag reflow, Edit Mode pause/recovery.
- `Recovery.lua`: debounced login, world-entry and display/UI-scale recovery.
- `Commands.lua`: the `/forevermultimonitor` entry point, dashboard/wizard/gather/diagnostic commands, profile controls and status commands.
- `Options.lua`: legacy/modern WoW AddOns settings-category registration plus the branded slash opener; in-game dashboard, per-profile Midnight/Indigo/Classic theme presets and opacity, named profiles, three-step setup wizard, reversible preview and diagnostics.
- `Init.lua`: addon lifecycle and current-state event coordination.

## Geometry model

Manual geometry uses logical `UIParent` dimensions. A profile specifies MainMonitor side, width percentage, seam offset in UI units and panel scale. A validated native handoff maps each physical monitor rectangle into the logical canvas with separate horizontal and vertical ratios. Dual-display mode preserves the selected monitor rectangles; explicit single-ultrawide mode divides one selected display equally and uses the profile's MainMonitor side. Physical bezel width is not inferred or calibrated.

## Panel ownership and protected frames

Each registered frame family has one position owner: World Map, Social, Professions, Bags or ordinary panels. A common placement primitive currently performs the actual anchor/scale operation. Complete family-specific visibility, focus, Escape, transient HUD and replacement-addon adapters are still open. Protected HUD prefixes and known replacement-bag prefixes are excluded. Unknown frames remain untouched until explicitly registered.

Layout writes are deferred while `InCombatLockdown()` is true. Pending work is keyed so repeated apply/reset requests converge on the latest SavedVariables state. Pending work is retried on `PLAYER_REGEN_ENABLED`. The addon does not reparent Blizzard frames or alter secure attributes.

## Persistence

Account settings live in `ForeverMultiMonitorDB`. Per-character `ForeverMultiMonitorCharDB.panelPositions` stores schema-1 normalized center offsets for named frames that emit native `OnDragStop` events. Coordinates are relative to the logical UIParent canvas. Unknown future schemas are treated as read-only. The last applied logical geometry and client build are recorded for diagnostics.

## Windows helper

`WindowsHelper` is a .NET 10 Windows x64 executable using Win32 display/window APIs. `list` enumerates monitor device names/IDs, physical bounds, primary status and effective DPI. `place` resolves a visible WoW process window, stores its original style/ex-style and complete `WINDOWPLACEMENT`, removes standard border styles and positions the window on the rectangular union of selected displays. `restore` validates HWND/process identity and restores the original style and placement, using the primary connected display if the original rectangle is no longer usefully visible. If no display is enumerable, it restores saved styles/placement without selecting a nonexistent fallback. `watch` is an optional foreground polling mode that tracks selected display IDs and invokes safe restore on display loss or Ctrl+C. No resident process, service or autostart is installed; reconnect/reapply remains manual.

The restore state is stored next to the executable. The build script routes TEMP/TMP, .NET CLI home and NuGet cache into `.tmp` in the repository workspace. No external NuGet packages are used.

## Compatibility policy

The manifest targets `Interface: 16001` and declares `AllowLoadGameType: camelot`. Runtime diagnostics report client version/build/interface and probe optional APIs instead of assuming Retail and Forever expose identical APIs. A matching TOC interface alone is not runtime compatibility evidence.

## Verification boundary

- `tools/validate.js`: TOC references, Lua structure and workspace sandbox assertions.
- `tools/regression.js`: dependency-free source assertions.
- `tools/runtime_regression.py`: Lua 5.1 parser plus mocked frame, geometry, queue, persistence, raw-mouse and recovery scenarios.
- `WindowsHelper/build.ps1`: Windows helper build.
- `WindowsHelper.exe list`: local Windows display enumeration.

These checks do not prove secure-frame taint safety or real panel behavior. A live WoW native HWND placement/restoration roundtrip passed on 2026-11-06, but mixed-DPI UI alignment and physical hotplug remain unverified. The in-client release matrix remains a shipping gate. Detailed failure paths and mitigations: [AUDIT_2026-11-06.md](AUDIT_2026-11-06.md).
