# Forever MultiMonitor behavior-parity assessment

Target contract: package version **2.1.2 Beta 17**, CurseForge file **9029504**, Forever Interface **16001**, paired helper compatibility release **beta.13**. The inspected package is kept outside tracked project files and is not a dependency or deliverable. Its shipped TOC, README and observed behavior define the versioned comparison; later Beta 20/26 releases and the mutable `Unreleased` changelog do not replace it. This repository is independently implemented and contains no copied package source or media. The selected workflow includes externally managed topology and Forever cold-launch recovery; those gaps remain visible below.

| Capability | Required layer | Current implementation | Evidence / release state |
|---|---|---|---|
| MainMonitor/SecondMonitor1 viewport split | Lua addon | Left/right logical-canvas split, width and seam configuration | Lua 5.1 geometry simulation; Forever live test open |
| Exact MainMonitor/SecondMonitor1 rectangles | Addon + topology provider | Versioned dual-display handoff maps each selected monitor's four physical edges, including negative, asymmetric, vertically offset and stacked arrangements; active topology is rejected when Forever's physical canvas changes. An explicitly marked single-ultrawide handoff creates an equal 50/50 split | Lua 5.1 simulation covers offset/stacked geometry, overlap, physical-size mismatch and 2px tolerance; live geometry/rendering remains open |
| WorldFrame capture/apply/restore | Lua addon | Anchor snapshot, transactional placement and rollback after partial anchor failure, original user-placed flag restoration | Lua 5.1 injection PASS; Forever in-client test open |
| Route map, character, spellbook, quest, professions, auction, social, collections, encounters, achievements and bags | Lua addon | Registry and generic placement; specific nonoverlapping default-bag grid. Other family adapters incomplete | Lua 5.1 simulation; live tests open |
| Dynamic panel discovery | Lua addon | `ShowUIPanel`, `ToggleFrame`, named `CreateFrame`, bag toggles and addon-load scans | Lua 5.1 mock; real client hook behavior open |
| Panel ownership / protected HUD exclusions | Lua addon | One registered owner per known family; protected HUD and replacement-bag prefixes excluded | Lua 5.1 mock; compatibility with actual UI replacements open |
| Panel anchor/scale restore | Lua addon | Original in-session anchors and scale captured once and restored | Lua 5.1 mock; live test open |
| Panel drag position persistence | Lua addon | Normalized per-character save/reapply when native `OnDragStop` fires | Lua 5.1 mock; supported frame drag behavior open |
| Panel lifecycle, Escape and focus | Lua addon | Combat-safe show/hide, default-map Escape persistence, reversible ESC list membership; UI/gamepad focus remains incomplete | Lua 5.1 runtime simulation; live tests open |
| Persistent panel open state | Addon + Forever recovery | Supported panel positions persist, but open/closed state is not saved/restored as a workspace set across relog/cold launch | Selected workflow expects eligible panels and open state to return; live reload/cold-launch gap |
| Combat-safe operations | Lua addon | Keyed queue converges on current SavedVariables state after combat | Lua 5.1 runtime simulation; live combat test open |
| Recovery after login/world/UI scale/display-size changes | Lua addon | Debounced recovery and generation checks | Lua 5.1 runtime simulation; live client test open |
| Raw mouse input | Lua addon | Saves previous `rawMouseEnable`, enables while active and restores on disable/logout | Lua 5.1 simulation; real Forever CVar behavior open |
| In-game options dashboard | Lua addon | Legacy/modern AddOns settings category and the single `/forevermultimonitor` command; enable, side, width, seam, scale, raw mouse, profile controls, apply/reset, 15-second preview/Keep and diagnostics | Lua 5.1 category/open-path and runtime checks; in-client settings navigation/visual/input test open |
| Setup wizard | Lua addon | Three-step stateful flow: native-window preparation instructions, live MainMonitor side/width controls, layout activation and finish/back navigation | Lua 5.1 runtime simulation; in-client visual and native-helper handoff tests open |
| Off-screen panel recovery (`/forevermultimonitor gather`) | Lua addon | Command and settings button gather shown windows from the registry, `UIPanelWindows`, and movable `UIParent` children when their title edges are inaccessible; protected/forbidden frames, tooltips and WorldFrame are excluded | Lua 5.1 runtime covers all candidate sources and safety filters; live recovery test remains open |
| Named profiles / profile switching | Lua addon | Legacy settings migrate to `Default`; named profiles can be created, saved, loaded and deleted with active/default protection | Lua 5.1 runtime simulation; live UI/reload test open |
| Dashboard theme presets / opacity | Lua addon | Midnight, Indigo and Classic palettes; per-profile background opacity from 50% to 100%; dashboard and wizard only | Lua 5.1 runtime simulation; in-client visual test open |
| Custom theme colors | Lua addon | Built-in Warcraft-style presets and opacity exist; per-profile custom background/border RGB controls remain absent | Open |
| Edit Mode / protected HUD integration | Lua addon | Explicitly pauses panel routing while Edit Mode is shown and schedules recovery on exit; no protected HUD layout creation | Simulated, live client open |
| Forever protected HUD recovery | Addon + Blizzard Edit Mode | Protected HUD frames remain Blizzard-owned; player-confirmed Use Modern / Restore saved layout prompts are absent | Selected workflow documents those player-confirmed recovery choices; unplug/replug flow open |
| Forever Professions ownership | Lua addon | Professions frame is now excluded from generic routing by default on Forever; no experimental build-consent movement UI | Lua guard regression; real Forever crash/load-on-demand behavior remains unverified |
| Gamepad/MainMonitor behavior, chat bubbles, popup/menu bounds, transient HUD | Lua addon | Not implemented as a complete compatibility layer | Open |
| Map/minimap, chat-bubble and popup behavior | Lua addon | World Map can be routed, but minimap docking/map-size controls, bubble anchoring and full transient popup seam handling are absent | Beta 17 ships dedicated subsystems; local runtime has no equivalent; live tests open |
| Ultrawide presets / aspect and bezel calibration | Addon + topology provider | Explicit one-screen 32:9/32:10 helper mode splits the physical display 50/50 and honors MainMonitor side; 21:9 presets and physical bezel measurement/calibration are not implemented | Lua/helper pure checks; physical ultrawide and bezel alignment unverified |
| Physical display enumeration | Windows helper | Device names/IDs, physical bounds, primary flag and effective DPI | Built and executed on development PC; target system matrix open |
| Native WoW window discovery | Windows helper | Visible top-level window lookup by known process names or explicit process | Compiled; live WoW process test open |
| Native HWND resize / borderless placement | Windows helper | One-shot rectangular union of selected display bounds and border-style removal | PASS live Wow.exe HWND place at 4480x1080 on 2026-11-06; mixed-DPI UI alignment not tested |
| Original native window restoration | Windows helper | Saves style/ex-style and full `WINDOWPLACEMENT`; explicit `restore` command | PASS live restore; original position insufficiently visible, safety fallback selected primary monitor |
| Mixed DPI / asymmetric / stacked monitor geometry | Windows helper | Reports DPI and monitor bounds; union rectangle used for placement | Enumeration exercised; real WoW mixed-DPI placement unverified |
| Display disconnect/reconnect / hotplug rollback | Windows helper + addon | Opt-in polling `watch` tracks selected display IDs; on loss it restores the saved window style/placement and uses a connected-primary fallback when available. If enumeration returns no displays, it restores without inventing a monitor fallback. Addon invalidates an active native topology on physical-canvas mismatch and rolls back; reconnect/reapply remains explicit | Pure helper and Lua regression checks; physical disconnect/reconnect and live in-game prompt behavior remain open |
| Direct helper-to-addon geometry handoff | Integration | Versioned, atomic, data-only `RuntimeGeometry.lua` generated via `--addon-dir`; dual-display and explicit single-ultrawide modes are independently validated after `/reload`, and stale active Forever topology is rejected | Lua/helper pure checks; live handoff and disconnect test open |
| Native span topology / selection UI | Windows helper | CLI helper requires exactly two displays by default, supports exactly one only with explicit `--single-ultrawide`, and writes exact geometry to a validated absolute addon path. It has no GUI selector, resident auto-span/reapply, cold-launch bridge or external protocol | Helper and Lua pure checks; real window geometry and live UI acceptance open |
| Cold-launch Forever state recovery | Helper + addon persistence | Not implemented; addon SavedVariables are used normally and helper is one-shot/optional watcher, but no bridge snapshots/restores saved state around Forever cold launches | Known Beta 17 workflow gap; full client launch/reload tests are mandatory |
| Profiles across characters | Lua addon | Named profiles and three built-in dashboard themes exist; copying profile settings across characters is not implemented | Partial against Beta 17; UI/reload tests open |
| External topology workflow | Helper + addon | Windows helper has no dashboard, hotkey, GUI display selector, auto-span, cold-launch recovery bridge or active missing-monitor UI prompts | Not implemented; full workflow remains incomplete |
| Complete requested feature coverage | Both | Not achieved | Release gate open |

## Hard technical boundary

WoW addon Lua cannot enumerate Windows monitors, inspect physical monitor identities, resize/move the native WoW HWND or remove its native borders. Those operations require an OS-side process. `WindowsHelper` handles display enumeration, two-display one-shot window placement, explicit restore and opt-in hotplug rollback. It is not a drop-in external helper replacement: it has no resident process, display-selection GUI, exact arbitrary topology rectangles, cold-launch snapshot bridge or direct external protocol.

The helper places WoW over the selected monitor-bounds union. Non-adjacent or vertically offset displays can leave unused areas inside the native window; the addon maps each selected physical rectangle separately, but it cannot remove those unused pixels from the HWND. Mixed-DPI alignment still depends on the Forever client's physical/logical scaling and is not live-verified.

## Release gate

Do not claim full behavior parity until:

1. Every Beta 17 addon-side behavior has an implementation and behavior regression test; every unsupported API/client case is fail-safe and documented.
2. The external-process-dependent panel-open state/cold-start recovery and player-confirmed protected HUD recovery workflows have a compatible implementation or remain explicit blockers.
3. The actual Forever client passes cold launch, `/reload`, combat/taint, Escape, drag, panel lifecycle, persistence, UI-scale, missing-display, and reconnect tests.
4. The helper passes native placement/restore tests against the real WoW process on adjacent, vertically stacked, offset, mixed-resolution and mixed-DPI layouts.
5. Static, simulated, local Windows and live-client evidence remain separately labelled. Only live-verified behavior satisfies the release gate.

## What FancyZones replaces

FancyZones can assist with manual positioning of a native WoW window across monitors. It does not provide the addon's display identity, exact native geometry handoff, borderless control or hotplug recovery. It is an optional manual fallback, not feature parity.
