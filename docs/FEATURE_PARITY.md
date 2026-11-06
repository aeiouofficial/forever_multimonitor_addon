# Offhand feature-parity assessment

This project aims to reproduce the user-facing in-game workflow without requiring the Offhand Companion. It does not copy Offhand source code. The public Offhand repository's license is All Rights Reserved and expressly restricts derivatives and forking; implementation here is independently authored from public behavior and API documentation.

This matrix separates addon capabilities from operating-system capabilities.

| Capability | Addon-only feasibility | Current project state |
|---|---|---|
| Mainhand / Offhand viewport split | Yes, through WorldFrame/UI anchoring | Initial controller; live test pending |
| Route map, bags, character and other native panels | Yes, subject to frame protection and UI ownership | Initial registry; incomplete |
| Panel persistence across reloads and sessions | Yes, through SavedVariables and native frame state | Not implemented beyond account profile and recovery geometry |
| Setup wizard and configuration UI | Yes | Not implemented |
| HUD / Edit Mode layout integration | Partly; depends on Forever's exposed protected APIs | Runtime capability probe only |
| Combat-safe deferred frame changes | Yes, within Blizzard's protected-action rules | Initial deferral mechanism |
| Physical monitor enumeration and exact rectangles | No supported WoW Lua API | Not available |
| Native HWND resize, move and border removal | No supported WoW Lua API | Not available |
| Automatic native window span / restore | No supported WoW Lua API | Delegated to FancyZones/manual setup |
| Exact mixed-DPI and asymmetric monitor topology | Not inferable from UIParent canvas alone | Not available |
| Display disconnect / reconnect recovery | Not possible without OS-level window access | Not available |
| Single ultrawide physical display split | Logical split is possible; physical monitor detection is not | Not implemented |

## What FancyZones replaces

FancyZones can snap the WoW window to zones spanning multiple monitors when **Allow zones to span across monitors** is enabled. Microsoft documents that all connected monitors must use the same DPI scaling for this mode. FancyZones is a window-placement utility; it does not provide Offhand's exact topology protocol, native-window recovery logic, or addon panel routing.

## Release definition

The project must not claim exact Offhand parity until:

1. Every feasible addon-side feature has a named implementation and regression test.
2. Every Windows-only feature has an explicitly accepted FancyZones/manual equivalent or is marked unavailable.
3. The current Forever live client passes the full test matrix, including cold launch, reload, combat lockdown, monitor changes and panel lifecycle.
4. A feature-by-feature comparison against the public Offhand documentation shows no unaccounted user-facing behavior.
