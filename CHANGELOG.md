## [0.3.0] - 2026-11-06

### Added
- Added `/fmm config`, an in-game settings window for enable/disable, Mainhand side, Mainhand width, seam offset, panel scale, raw-mouse behavior and named profile create/load/delete.
- Added an in-window setup guide that explains the Windows-window and in-game-layout boundary.
- Added a standalone Windows helper project with display enumeration (device names/IDs, bounds, primary state and DPI), WoW process-window discovery, one-shot combined-window placement, borderless style changes and explicit restore from a saved full `WINDOWPLACEMENT`.
- Added a workspace-local helper build script; .NET CLI home, temporary directories and package cache are redirected to `.tmp`.
- Added geometry boundary runtime tests for left/right placement, seam handling, width limits and invalid canvas geometry.
- Added named profile migration from legacy settings, profile creation/switching, active/default deletion guards and SavedVariables persistence.
- Fixed panel scaling so the Offhand workspace width/height fit takes precedence over the configured preferred scale; added a regression case for oversized native panels.
- Added named `CreateFrame` post-hook discovery for supported registered Blizzard panels created after addon initialization.

### Changed
- Bumped addon version and TOC metadata to `0.3.0`.
- Updated setup, architecture, parity and test documentation to distinguish implemented, simulated, locally exercised and live-unverified behavior.
- The Windows helper is explicitly one-shot; no service, tray resident, startup registration, network access, telemetry or Companion protocol is introduced.

### Verification
- `node tools/regression.js`: 47 source regression assertions passed.
- `node tools/validate.js`: manifest, 13 TOC Lua modules, structural Lua and workspace-sandbox checks passed.
- `tools/runtime_regression.py`: all 13 Lua modules parsed with Lua 5.1; mocked geometry, named profiles, combat queue, frame discovery/ownership, viewport restore, drag persistence, raw-mouse ownership, recovery and options-window/profile/wizard scenarios passed.
- `dotnet build WindowsHelper/ForeverMultiMonitor.WindowsHelper.csproj --configuration Release`: succeeded with 0 warnings and 0 errors.
- Windows helper `list` command executed on the development PC and returned the connected display device names, bounds and DPI values.
- `git diff --check` passed at the current local checkpoint.

### Known limitations — not release-ready
- No live WoW Forever client test has been performed. In-game visual layout, protected-frame behavior, secure hooks, panel focus/Escape behavior, combat lockdown and raw-mouse behavior remain unverified in the actual client.
- The native helper's `place` and `restore` commands have not been executed against the live WoW window. Only build/help/display enumeration were exercised.
- The helper uses a rectangular union of selected monitor bounds. It does not yet monitor display hotplug, automatically roll back on disconnect, provide a graphical display selector or communicate through a helper-to-addon protocol.
- The helper sets its own DPI awareness; mixed-DPI behavior of the WoW process is not proven. The current development machine reports 2560x1080 at 96 DPI and 1920x1080 at 120 DPI, but no live game-window placement was attempted.
- Panel family controllers still share a common placement primitive. Complete panel-specific lifecycle, focus, Escape, custom drag handles, transient HUD, Edit Mode and replacement-addon adapters remain open.
- The settings window is a basic control surface and setup guide, not the complete Offhand dashboard/wizard. Theme packs, custom backgrounds, preview/recovery UX and code-free media import remain open.
- Full Offhand user-facing feature parity is not achieved. Do not mark this release verified until every row in `docs/FEATURE_PARITY.md` and `docs/TEST_MATRIX.md` has real implementation and evidence.

## [0.2.0] - 2026-11-06

### Changed
- Replaced the single combat-deferred callback slot with a keyed queue that preserves independent operations and coalesces repeated requests.
- Apply and reset now converge on the latest enabled/configuration state after combat instead of applying stale pre-combat geometry.
- Added dynamic panel discovery through supported `ShowUIPanel` and `ToggleFrame` post-hooks, in addition to known bag-toggle entry points and addon-load scans.
- Added an explicit panel registry and exclusive controller ownership for World Map, Social, Professions, Bags and ordinary panels; protected HUD and replacement bag prefixes are excluded from generic routing.
- Made panel hook installation idempotent and isolated routing failures per frame.
- Invalidated viewport and panel snapshots after successful restoration so the next activation captures the actual current baseline.
- Preserved an originally anchorless panel as anchorless during restoration instead of inventing a center anchor.
- Prevented scan-only panel discovery from placing the same visible panel twice during a single apply pass.
- Added schema-versioned, normalized per-character panel position persistence for frames that expose native OnDragStop events; saved positions are reapplied after subsequent opens.
- Made recovery a single debounced operation per generation and routed it through the current enabled state, including a disable during combat.
- Added raw-mouse behavior: default-on profile setting, original `rawMouseEnable` CVar capture, safe restore on disable/logout, and `/fmm rawmouse on|off` control.

### Tests
- Added dependency-free regression assertions for combat queue semantics, dynamic discovery, hook idempotency, snapshot lifecycle, recovery coalescing and error isolation.
- Added `tools/runtime_regression.py` for Lua 5.1 parsing and mocked runtime tests.
- Pinned test-only dependencies in `tools/requirements-test.txt`; documented installation and cache locations under `.tmp` in the workspace.

### Limitations
- No live Forever client test has been performed. Static parsing and simulated runtime tests do not prove secure-frame behavior, frame-hook availability or runtime panel correctness.
- Dynamic discovery covers registered Blizzard UI panel entry points and known bag toggles; it does not claim to discover every arbitrary third-party frame.
- Family-specific panel lifecycle adapters, GUI, setup wizard, themes, Edit Mode integration and native Windows control were not included in this version.
- No Companion process or Companion protocol is included.

## [0.1.0] - 2026-11-06

### Added
- Initial Forever-only addon scaffold targeting Interface 16001 and Camelot.
- Runtime build/interface/project and optional-API diagnostics.
- Account SavedVariables defaults and profile validation.
- Manual logical-canvas geometry for left/right Mainhand layouts.
- Initial WorldFrame viewport controller with anchor capture and restoration.
- Initial panel adapters for map, character, spellbook, quest, professions, auction, social, collections, encounter, achievement and bag/bank frames.
- Bag-toggle discovery hooks for supported Blizzard global functions.
- Debounced recovery after login, world entry, UI-scale and display-size changes.
- Combat-deferred operations and `/fmm` command interface.
- Architecture, feature-parity assessment, setup, test matrix and local structural validation.

### Limitations
- No native Windows window management, display enumeration, borderless mode, or automatic physical topology detection.
- No companion process or Companion protocol.
- Not feature-equivalent to Offhand. In-client viewport, protected-frame, panel, persistence and recovery behavior remains unverified.