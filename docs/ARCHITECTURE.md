# Architecture

## Runtime boundary

The addon runs inside WoW Forever's Lua sandbox. It arranges in-game frames and the 3D viewport, but cannot call Win32 APIs, enumerate physical displays, resize the game HWND or remove native window borders.

The companion-free implementation has two separate components:

- **Lua addon:** logical Mainhand/Offhand viewport, supported panel routing, configuration, persistence and recovery.
- **Windows helper:** display enumeration and explicit one-shot native window placement/restoration. It is a standalone executable; no service, autostart, resident monitor or Companion protocol is used.

The helper makes the game window cover the selected display bounds. The addon then consumes the resulting combined logical `UIParent` canvas. No direct helper-to-addon protocol currently exists.

## Addon modules

- `Bootstrap.lua`: namespace, guarded execution and keyed combat-deferred work.
- `Compat.lua`: runtime build, project and optional-API probes.
- `Config.lua`: account defaults, named profile migration/create/load/delete, profile validation and per-character position schema migration.
- `RawMouse.lua`: save/enable/restore of the user's `rawMouseEnable` CVar.
- `Geometry.lua`: logical canvas and Mainhand/Offhand rectangles.
- `Viewport.lua`: WorldFrame anchor capture, apply and restore.
- `PanelRegistry.lua`: supported frame names, one owner per family, protected-HUD/replacement-bag exclusions.
- `PanelControllers.lua`: explicit family dispatch; actual family-specific lifecycle behavior remains incomplete.
- `Panels.lua`: discovery hooks, in-session anchor/scale snapshots, per-character normalized drag-position persistence and restoration.
- `Recovery.lua`: debounced login, world-entry and display/UI-scale recovery.
- `Commands.lua`: slash-command interface, including `/fmm config`.
- `Options.lua`: in-game dashboard, per-profile Midnight/Indigo/Classic theme presets and opacity, named profiles, three-step setup wizard, reversible preview and diagnostic integration.
- `Init.lua`: addon lifecycle and current-state event coordination.

## Geometry model

The addon uses logical `UIParent` dimensions, not physical-pixel monitor coordinates. A profile specifies Mainhand side, width percentage, seam offset in UI units and panel scale. The remaining canvas is the Offhand workspace. Physical bezel width and mixed-DPI monitor topology are not inferred.

## Panel ownership and protected frames

Each registered frame family has one position owner: World Map, Social, Professions, Bags or ordinary panels. A common placement primitive currently performs the actual anchor/scale operation. Complete family-specific visibility, focus, Escape, transient HUD and replacement-addon adapters are still open. Protected HUD prefixes and known replacement-bag prefixes are excluded. Unknown frames remain untouched until explicitly registered.

Layout writes are deferred while `InCombatLockdown()` is true. Pending work is keyed so repeated apply/reset requests converge on the latest SavedVariables state. Pending work is retried on `PLAYER_REGEN_ENABLED`. The addon does not reparent Blizzard frames or alter secure attributes.

## Persistence

Account settings live in `ForeverMultiMonitorDB`. Per-character `ForeverMultiMonitorCharDB.panelPositions` stores schema-1 normalized center offsets for named frames that emit native `OnDragStop` events. Coordinates are relative to the logical UIParent canvas. Unknown future schemas are treated as read-only. The last applied logical geometry and client build are recorded for diagnostics.

## Windows helper

`WindowsHelper` is a .NET 10 Windows x64 executable using Win32 display/window APIs. `list` enumerates monitor device names/IDs, physical bounds, primary status and effective DPI. `place` resolves a visible WoW process window, stores its original style/ex-style and complete `WINDOWPLACEMENT`, removes standard border styles and positions the window on the rectangular union of selected displays. `restore` validates HWND/process identity and restores the original style and placement, using the primary connected display if the original rectangle is no longer usefully visible. `watch` is an optional foreground polling mode that tracks the selected stable display IDs and invokes safe restore on display loss or Ctrl+C. No resident process, service or autostart is installed; reconnect/reapply remains manual.

The restore state is stored next to the executable. The build script routes TEMP/TMP, .NET CLI home and NuGet cache into `.tmp` in the repository workspace. No external NuGet packages are used.

## Compatibility policy

The manifest targets `Interface: 16001` and declares `AllowLoadGameType: camelot`. Runtime diagnostics report client version/build/interface and probe optional APIs instead of assuming Retail and Forever expose identical APIs. A matching TOC interface alone is not runtime compatibility evidence.

## Verification boundary

- `tools/validate.js`: TOC references, Lua structure and workspace sandbox assertions.
- `tools/regression.js`: dependency-free source assertions.
- `tools/runtime_regression.py`: Lua 5.1 parser plus mocked frame, geometry, queue, persistence, raw-mouse and recovery scenarios.
- `WindowsHelper/build.ps1`: Windows helper build.
- `WindowsHelper.exe list`: local Windows display enumeration.

These checks do not prove secure-frame taint safety, real panel behavior or native WoW window placement. The in-client and live-window matrices remain release gates.