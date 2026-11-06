## [0.3.5] - 2026-11-06

### Added
- Added a 15-second reversible layout preview in the in-game dashboard with an explicit `Keep layout` confirmation.
- Unconfirmed previews restore the prior disabled state. Confirmed previews invalidate stale timers so they cannot later disable a kept layout.
- Added runtime tests for timeout rollback, Keep confirmation, stale timer invalidation and slash-command interaction.

### Changed
- `/fmm enable`, `/fmm disable`, `/fmm apply` and `/fmm reset` now cancel or confirm an active preview rather than allowing a stale timer to override the user's explicit command.
- Bumped addon version and TOC metadata to `0.3.5`.
- Updated setup, feature-parity and test documentation.

### Verification
- `python tools/runtime_regression.py`: PASS, including 15-second preview rollback/Keep and slash-command invalidation.
- `node tools/regression.js`: 51 source regression assertions passed.
- `node tools/validate.js`: PASS.
- `git diff --check`: PASS.

### Remaining limitations
- Preview behavior is Lua 5.1 simulated; its visual presentation and real client timer behavior still require an in-client Forever test.

## [0.3.4] - 2026-11-06

### Added
- Added an explicitly opt-in Windows helper `watch` command. It places the WoW window, polls selected stable monitor device IDs, and triggers rollback if a selected display disappears.
- Added safe restore geometry: preserve the original rectangle when it intersects a connected display; otherwise center the restored window on the primary connected display.
- Added Ctrl+C restoration, configurable 250?10000 ms polling, and a helper `self-test` covering stable display identity, disconnect detection and fallback geometry.

### Changed
- Manual `restore` now uses the same off-screen-safe fallback when the original monitor is no longer connected.
- Bumped addon TOC/project documentation version to `0.3.4`.
- Updated helper instructions, feature parity, README and test matrix. Reconnect/reapply remains explicitly manual.

### Verification
- Windows helper Release build: 0 warnings, 0 errors.
- `ForeverMultiMonitor.WindowsHelper.exe self-test`: PASS.
- Safe negative-path tests for an unknown display and an invalid watch interval: expected exit code 2; no restore state created and no game window changed.
- `node tools/regression.js`: 49 source regression assertions passed.
- `git diff --check`: PASS.

### Remaining limitations
- No physical display was disconnected during testing. The watch loop, HWND restore and primary fallback still require a controlled live test. There is no automatic reconnect/reapply, display-selection GUI or helper-to-addon geometry handoff.

## [0.3.3] - 2026-11-06

### Fixed
- Updated wizard navigation labels through the custom button label FontStrings rather than relying on a button-level `SetText` method. This matches the control factory used by the rest of the options UI.
- Extended the runtime regression to verify Next, Back and Finish labels alongside wizard navigation and activation.

### Verification
- `python tools/runtime_regression.py`: PASS, including wizard control-label and navigation assertions.
- `node tools/regression.js`: 48 source regression assertions passed.
- `git diff --check`: PASS.

## [0.3.2] - 2026-11-06

### Added
- Replaced the static setup instruction page with a three-step guided flow: prepare the native Windows window, configure Mainhand side/width, and activate the in-game layout.
- Added live wizard controls backed by the same validated profile configuration as the dashboard and slash commands.
- Added Lua 5.1 runtime coverage for wizard navigation, Mainhand controls and activation; added a source regression for the guided setup contract.

### Changed
- Bumped addon version and TOC metadata to `0.3.2`.
- Updated README, setup instructions, feature-parity matrix and test matrix to describe the actual guided flow and its manual Windows-helper boundary.

### Verification
- `python tools/runtime_regression.py`: all Lua 5.1 syntax and mocked runtime scenarios passed, including the guided wizard controls and navigation.
- `node tools/validate.js`: PASS.
- `node tools/regression.js`: 48 source regression assertions passed.
- `git diff --check`: PASS.

### Remaining limitations
- The wizard does not enumerate/select Windows displays or exchange geometry with the helper. Native monitor selection remains an explicit CLI step. Full dashboard/theme/preview features and live Forever validation remain open.

## [0.3.1] - 2026-11-06

### Fixed
- Added explicit panel `OnHide` restoration so supported windows return to their captured original anchors and scale when closed.
- Unified panel show/hide handling behind one keyed desired-state reconciliation. Rapid visibility changes during combat now coalesce and apply only the latest shown/hidden state after combat.
- Added Lua 5.1 runtime regression coverage for hide/restore/reopen and both combat-deferred visibility orderings.

### Changed
- Bumped addon version and TOC metadata to `0.3.1`.
- Updated feature-parity and verification documentation to distinguish the implemented show/hide lifecycle from still-open focus and Escape integration.

### Verification
- `python tools/runtime_regression.py`: all Lua 5.1 syntax and mocked runtime scenarios passed, including new panel lifecycle and combat-convergence cases.
- `node tools/validate.js`: PASS.
- `node tools/regression.js`: 47 source regression assertions passed.
- `git diff --check`: PASS.

### Remaining limitations
- Focus ownership, Escape integration, panel-specific behavior, the actual Forever client and native WoW window placement/restore remain unverified or incomplete. This is not full Offhand parity.

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
- Panel family controllers still share a common placement primitive. Focus ownership, Escape integration, custom drag handles, transient HUD, Edit Mode and replacement-addon adapters remain open.
- The settings window remains a basic dashboard. The guided wizard covers window preparation, Mainhand configuration and activation, but does not provide display selection or helper handoff. Theme packs, custom backgrounds, preview/recovery UX and code-free media import remain open.
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