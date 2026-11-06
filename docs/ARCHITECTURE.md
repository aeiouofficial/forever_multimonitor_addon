# Architecture

## Runtime boundary

The addon runs inside WoW Forever's Lua sandbox. It can arrange in-game frames and the 3D viewport, but it cannot call Win32 APIs, enumerate Windows displays, resize the game HWND, remove native borders, or set the process window position. Those capabilities are outside the WoW addon API.

The companion-free workflow therefore has two independent layers:

- **Windows layer:** PowerToys FancyZones or manual window placement spans the ordinary window across the selected displays.
- **Addon layer:** the addon uses the resulting UIParent canvas dimensions to split Mainhand and Offhand, constrain the world viewport, and reposition supported UI panels.

No hidden executable, service, local socket, named pipe, or Companion protocol is part of this project.

## Modules

- `Bootstrap.lua`: shared addon namespace, guarded execution and combat-deferred work.
- `Compat.lua`: runtime build, project and optional-API probes.
- `Config.lua`: account defaults, validation and profile normalization.
- `Geometry.lua`: logical canvas and Mainhand/Offhand rectangles.
- `Viewport.lua`: WorldFrame anchor capture, apply and restore.
- `Panels.lua`: Blizzard frame registry, show hooks and bag discovery hooks.
- `Recovery.lua`: debounced login, world-entry and display/UI-scale recovery.
- `Commands.lua`: slash-command interface.
- `Init.lua`: addon lifecycle and event coordination.

## Geometry model

The implementation uses the logical dimensions of UIParent, not Windows physical-pixel coordinates. A profile specifies Mainhand side, width percentage, seam offset in UI units and panel scale. The remaining canvas is the Offhand workspace. Physical bezel width and mixed-DPI display topology are not inferred.

## Protected frames

Layout writes are deferred while `InCombatLockdown()` is true. Pending work is retried on `PLAYER_REGEN_ENABLED`. The addon does not reparent Blizzard frames or alter secure attributes. The panel registry is best-effort and limited to known default Blizzard frame globals. Replacement UI addons and dynamically created frames require explicit adapters and live testing.

## Persistence

Account settings live in `ForeverMultiMonitorDB`; the per-character SavedVariables table is reserved for future character overrides. The last successfully applied logical geometry and client build are recorded for diagnostics. Defaults are applied without overwriting existing account values. SavedVariables are the only persistence source; no Companion bridge or external persistence channel is used.

## Compatibility policy

The manifest targets `Interface: 16001` and declares `AllowLoadGameType: camelot`. At runtime, the addon reports the client version/build/interface and probes optional APIs instead of assuming Retail and Forever expose identical APIs. A matching TOC interface alone is not runtime compatibility evidence.
