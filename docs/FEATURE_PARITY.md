# Offhand feature-parity assessment

Target: the public user-facing Offhand workflow, excluding the Companion process itself. The project is independently implemented; no Offhand source or Companion protocol is copied. A feature is not considered complete merely because a module or command exists.

| Capability | Required layer | Current implementation | Evidence / release state |
|---|---|---|---|
| Mainhand/Offhand viewport split | Lua addon | Left/right logical-canvas split, width and seam configuration | Lua 5.1 geometry simulation; Forever live test open |
| WorldFrame capture/apply/restore | Lua addon | Anchor snapshot, viewport placement and restore | Lua 5.1 simulation; Forever live test open |
| Route map, character, spellbook, quest, professions, auction, social, collections, encounters, achievements and bags | Lua addon | Explicit registry; generic placement primitive shared by registered family controllers | Lua 5.1 simulation; family-specific adapters/live tests open |
| Dynamic panel discovery | Lua addon | `ShowUIPanel`, `ToggleFrame`, named `CreateFrame`, bag toggles and addon-load scans | Lua 5.1 mock; real client hook behavior open |
| Panel ownership / protected HUD exclusions | Lua addon | One registered owner per known family; protected HUD and replacement-bag prefixes excluded | Lua 5.1 mock; compatibility with actual UI replacements open |
| Panel anchor/scale restore | Lua addon | Original in-session anchors and scale captured once and restored | Lua 5.1 mock; live test open |
| Panel drag position persistence | Lua addon | Normalized per-character save/reapply when native `OnDragStop` fires | Lua 5.1 mock; supported frame drag behavior open |
| Panel lifecycle, Escape and focus | Lua addon | `OnShow` routes; `OnHide` restores original anchors/scale; keyed combat-safe reconciliation converges on latest visibility state. Focus ownership and Escape integration remain incomplete | Lua 5.1 runtime simulation; live lifecycle/focus/Escape tests open |
| Combat-safe operations | Lua addon | Keyed queue converges on current SavedVariables state after combat | Lua 5.1 runtime simulation; live combat test open |
| Recovery after login/world/UI scale/display-size changes | Lua addon | Debounced recovery and generation checks | Lua 5.1 runtime simulation; live client test open |
| Raw mouse input | Lua addon | Saves previous `rawMouseEnable`, enables while active and restores on disable/logout | Lua 5.1 simulation; real Forever CVar behavior open |
| In-game options dashboard | Lua addon | `/fmm config`: enable, side, width, seam, scale, raw mouse, profile controls, apply/reset | Lua parse/source tests; in-client visual/input test open |
| Setup wizard | Lua addon | Basic instruction page inside options window | Source/parse checks; not a full guided stateful wizard |
| Named profiles / profile switching | Lua addon | Legacy settings migrate to `Default`; named profiles can be created, saved, loaded and deleted with active/default protection | Lua 5.1 runtime simulation; live UI/reload test open |
| Themes / custom backgrounds / media import | Lua addon | Not implemented | Open |
| Edit Mode / protected HUD integration | Lua addon | Not implemented; Forever API support not established | Open; no secure-frame bypass planned |
| Gamepad/Mainhand behavior, chat bubbles, popup/menu bounds, transient HUD | Lua addon | Not implemented as a complete compatibility layer | Open |
| Ultrawide presets / aspect and bezel calibration | Lua addon | Basic width and seam controls only; no 21:9/32:9 presets | Partial |
| Physical display enumeration | Windows helper | Device names/IDs, physical bounds, primary flag and effective DPI | Built and executed on development PC; target system matrix open |
| Native WoW window discovery | Windows helper | Visible top-level window lookup by known process names or explicit process | Compiled; live WoW process test open |
| Native HWND resize / borderless placement | Windows helper | One-shot rectangular union of selected display bounds and border-style removal | Compiled; not executed against live WoW |
| Original native window restoration | Windows helper | Saves style/ex-style and full `WINDOWPLACEMENT`; explicit `restore` command | Compiled; round-trip live window test open |
| Mixed DPI / asymmetric / stacked monitor geometry | Windows helper | Reports DPI and monitor bounds; union rectangle used for placement | Enumeration exercised; real WoW mixed-DPI placement unverified |
| Display disconnect/reconnect / hotplug rollback | Windows helper | Not implemented; helper is one-shot | Open |
| Direct helper-to-addon geometry handoff | Integration | Not implemented; addon reads the resulting combined `UIParent` canvas and retains manual geometry controls | Open |
| Resident monitoring / auto-start / Companion process | Excluded | No service, tray resident, auto-start, Companion or Companion protocol | Intentional scope boundary |
| Full Offhand feature parity | Both | Not achieved | Release gate open |

## Hard technical boundary

WoW addon Lua cannot enumerate Windows monitors, inspect physical monitor identities, resize/move the native WoW HWND or remove its native borders. Those operations require an OS-side process. `WindowsHelper` currently handles display enumeration and one-shot window placement/restoration. It is not a drop-in Companion replacement: it has no hotplug watcher, resident process, display-selection GUI or direct data protocol to Lua.

The helper combines selected monitor bounds into a single rectangle. Non-adjacent or vertically offset displays can leave unused areas inside that rectangle. Mixed-DPI behavior also depends on the WoW process DPI-awareness mode, which the helper does not change.

## Release gate

Do not claim Offhand parity until:

1. Every feasible addon-side feature has a named implementation and behavioral regression test.
2. Every Windows-only feature has a tested implementation in the separate helper, including topology and hotplug rollback.
3. Every public Offhand user-facing feature is represented above with implementation and evidence.
4. The actual Forever client passes cold launch, reload, combat, Escape, drag, panel lifecycle, persistence, UI-scale and display-change tests.
5. The helper passes native placement/restore tests against the real WoW process and supported monitor topologies.
6. Static, simulated, local Windows and live-client evidence remain separately labelled. Only live-verified behavior satisfies the release gate.

## What FancyZones replaces

FancyZones can assist with manual positioning of a native WoW window across monitors. It does not provide Offhand-specific display identity, exact native geometry protocol, borderless control or hotplug recovery. It is an optional manual fallback, not feature parity.