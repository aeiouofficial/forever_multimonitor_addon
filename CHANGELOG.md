## [Unreleased] - 2026-11-06

### Behavior contract and naming
- Pinned the requested behavior contract to version 2.1.2 Beta 17, package file 9029504, Forever interface 16001 and paired helper compatibility beta.13. The comparison package is not part of this project; no package source or assets were copied.
- Standardized the public layout names to `MainMonitor` and `SecondMonitor1`. The addon now registers only `/forevermultimonitor`; its settings, help text, tests and setup guides use the same command. The Windows helper's selector is `--mainmonitor`.
- Migrated saved profile values and older native geometry handoffs to the current field names while retaining existing user settings.
- Expanded Gather to scan registered panels, `UIPanelWindows`, and movable `UIParent` children with protected/forbidden and tooltip exclusions; added a dashboard button that invokes the same command path.
- This 0.4.1 implementation remains a partial standalone subset. README records the remaining gaps; local mock/build checks do not establish full live-client acceptance.

### Fixed
- Failed direct and post-combat reapply now disables the persisted layout and rolls back panels, viewport, raw mouse and World Map Escape state. `RunWhenSafe` preserves a callback's detailed error instead of replacing it with a generic rejection. Added Lua 5.1 fault injection for viewport exceptions and invalid geometry.
- Forever Professions-family frames remain Blizzard-owned by default, and forbidden frames are not hooked or routed. Added Lua 5.1 ownership-boundary checks.
- Normal span requires exactly two selected displays; the explicit `--single-ultrawide` mode requires exactly one. An absolute `--addon-dir` on any drive, including C:, is accepted only when both expected addon files exist.
- Panel restoration now rolls back a failed anchor/scale change, retains its original snapshot for retry, and reports the failure. Layout apply treats any panel-routing failure as a failure, disables the attempted layout and restores viewport, panels and raw mouse.
- Deferred callbacks that return `false` now report their reason. Enable/reset/apply commands report actual outcomes; a failed enable no longer persists as active, and preview cannot start or be confirmed after a failed apply.
- The dashboard is registered in WoW's AddOns settings page through the legacy or modern settings API and opens from the branded slash command.
- Windows restore visibility is checked against the saved screen rectangle. Fallback is placed with screen-coordinate `SetWindowPos` after restoring `WINDOWPLACEMENT`; frame styles are refreshed on restore. Existing state files without a saved screen rectangle remain restorable through Windows' native placement adjustment.

### Verification
- Fresh local verification: 67 source regression checks PASS; structural validator PASS for 17 TOC Lua modules; Lua 5.1 syntax/runtime suite PASS, including profile/native-handoff migration, all Gather candidate sources, and legacy/modern settings-category mocks; .NET 10 Release build PASS with 0 warnings and 0 errors; helper self-test PASS for two/single-display selection, zero-display rollback, handoff schema and path validation; staged and unstaged `git diff --check` PASS.
- Real in-client AddOns-page visibility, slash openers, layout behavior, mixed-DPI alignment and physical disconnect/reconnect remain open shipping gates. The live WoW UI automation pipe is unavailable, so the installed addon has not been clicked or exercised in-client.

## [0.4.1] - 2026-11-06

### Fixed after critical audit
- Distinguish a successful protected pcall from an actual true viewport application; failed viewport apply now prevents panel routing and raw-mouse activation.
- Transactional WorldFrame cropping: if the second anchor or another layout operation raises, attempt to restore the exact prior anchors and user-placement flag, and preserve the prior applied state when rollback succeeds.
- Transactional panel placement: capture immediate anchors/scale, roll back a failed SetPoint or SetScale operation and report the error.
- Restore all original WorldMapFrame UISpecialFrames memberships, including repeated entries, without introducing duplicates on repeated disable.
- Added targeted Lua 5.1 fault-injection scenarios for second-anchor failure, panel placement failure and false viewport results.
- Made native helper restore-state creation collision-resistant: a unique temporary file is moved into place without overwrite, so concurrent `place` launches cannot replace the first recovery state.

### Verification / release gate
- Source/manifest checks, Lua 5.1 runtime scenarios and helper Release build PASS; helper self-test PASS.
- **Live native HWND place/restore PASS on 2026-11-06**: Wow.exe window placed across 2560x1080 + 1920x1080 = 4480x1080, restored via safe primary-display fallback because original position was not sufficiently visible.
- Still blocked for full shipment: WoW addon cold-load/reload, taint/combat, UI family behavior, physical hotplug and mixed-DPI logical viewport placement have not been measured in client. Do not claim full behavior parity.
- Full issue/impact/evidence record: [docs/AUDIT_2026-11-06.md](docs/AUDIT_2026-11-06.md).

## [0.4.0] - 2026-11-06

### Implemented
- Validated data-only Windows-helper-to-Lua monitor geometry, atomic file handoff via --addon-dir, optional --mainmonitor, two aligned horizontal displays auto-calibration, and manual fallback for unsupported topologies.
- Profile-scoped reversible World Map Escape-list handling, with slash command and GUI toggle.
- WorldFrame user-placement flag preservation and original-anchor recovery, including logout recovery attempt.
- Bounded default-bag grid, offscreen drag-position clamping, Edit Mode panel-routing pause and exit-triggered recovery.
- In-game native calibration button and status commands; addon version bumped to 0.4.0.
- Native helper expanded with pure handoff schema/escaping self-test; preserved existing hotplug rollback and restore safeguards.

### Local verification
- 54 source regression checks PASS; 16 Lua modules syntax-parsed with Lua 5.1-compatible parser.
- Lua 5.1 mocked runtime PASS for map Escape, geometry validation/calibration, bags, Edit Mode and viewport state restoration.
- .NET 10 Windows helper Release build 0 warnings, 0 errors; helper self-test PASS; both Windows displays enumerated.
- These are **not** a substitute for testing the real Forever client. Live WoW HWND placement and in-client layout/secure-frame tests remain open.

### Release gates
- Native window placement/restore and mixed-DPI coordinate alignment against the actual running WoW client remain unverified.
- The requested feature set remains incomplete: keyboard/gamepad focus, protected HUD layout creation, advanced panel family adaptations, chat/tooltips/bubbles, custom background media import, full GUI display selection and localization remain open.
- No persistent external helper service/protocol was added. No files were deliberately written to C:; development work and temp/cache roots are under the F: workspace.

## [0.3.7] - 2026-11-06

### Added
- Added per-profile dashboard theme presets: Midnight, Indigo and Classic.
- Added a background-opacity slider (50% to 100%) applied to the options dashboard and setup wizard.
- Added config validation/migration defaults for theme preset and opacity; theme changes do not trigger a game-layout reapply.
- Added Lua 5.1 runtime coverage for preset validation, opacity bounds, profile/UI synchronization, wizard theme inheritance and no-layout-reapply behavior.

### Changed
- Updated the runtime addon version constant to `0.3.7` to match the TOC and release docs.
- Updated README, setup, feature-parity and test documentation. Custom background files and code-free user-media import remain open and are not claimed as implemented.

### Verification
- `python tools/runtime_regression.py`: PASS, including theme migration, validation, UI application and wizard inheritance.
- `node tools/regression.js`: 53 source regression assertions passed.
- `node tools/validate.js`: PASS.
- `git diff --check`: PASS.

### Remaining limitations
- Theme rendering has only been exercised in the Lua frame mock. Live Forever UI visuals remain unverified. Presets affect the addon dashboard/wizard only, not Blizzard panels or game UI; custom image import is not implemented.

## [0.3.6] - 2026-11-06

### Added
- Added `/forevermultimonitor diagnostics` to report addon/client versions, geometry, active profile, registered/hooked/assigned/excluded panel counts, active restore snapshots, deferred operations, preview state and last error.
- Added runtime invocation and source regression coverage for the diagnostics command.

### Fixed
- Updated the runtime addon version constant to `0.3.6` so `/forevermultimonitor diagnostics` reports the same version as the TOC and release docs.

### Changed
- Added diagnostics to command help, README, setup and test matrix.

### Verification
- `python tools/runtime_regression.py`: PASS, including diagnostics invocation.
- `node tools/regression.js`: 52 source regression assertions passed.
- `node tools/validate.js`: PASS.
- `git diff --check`: PASS.

### Remaining limitations
- Diagnostics are chat output and do not yet provide a persistent in-game diagnostic panel or exported support bundle.

## [0.3.5] - 2026-11-06

### Added
- Added a 15-second reversible layout preview in the in-game dashboard with an explicit `Keep layout` confirmation.
- Unconfirmed previews restore the prior disabled state. Confirmed previews invalidate stale timers so they cannot later disable a kept layout.
- Added runtime tests for timeout rollback, Keep confirmation, stale timer invalidation and slash-command interaction.

### Changed
- `/forevermultimonitor enable`, `/forevermultimonitor disable`, `/forevermultimonitor apply` and `/forevermultimonitor reset` now cancel or confirm an active preview rather than allowing a stale timer to override the user's explicit command.
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
- Added Ctrl+C restoration, configurable 250 to 10000 ms polling, and a helper `self-test` covering stable display identity, disconnect detection and fallback geometry.

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
- Replaced the static setup instruction page with a three-step guided flow: prepare the native Windows window, configure MainMonitor side/width, and activate the in-game layout.
- Added live wizard controls backed by the same validated profile configuration as the dashboard and slash commands.
- Added Lua 5.1 runtime coverage for wizard navigation, MainMonitor controls and activation; added a source regression for the guided setup contract.

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
- Focus ownership, Escape integration, panel-specific behavior, the actual Forever client and native WoW window placement/restore remain unverified or incomplete. Full behavior parity is not established.

## [0.3.0] - 2026-11-06

### Added
- Added `/forevermultimonitor config`, an in-game settings window for enable/disable, MainMonitor side, MainMonitor width, seam offset, panel scale, raw-mouse behavior and named profile create/load/delete.
- Added an in-window setup guide that explains the Windows-window and in-game-layout boundary.
- Added a standalone Windows helper project with display enumeration (device names/IDs, bounds, primary state and DPI), WoW process-window discovery, one-shot combined-window placement, borderless style changes and explicit restore from a saved full `WINDOWPLACEMENT`.
- Added a workspace-local helper build script; .NET CLI home, temporary directories and package cache are redirected to `.tmp`.
- Added geometry boundary runtime tests for left/right placement, seam handling, width limits and invalid canvas geometry.
- Added named profile migration from legacy settings, profile creation/switching, active/default deletion guards and SavedVariables persistence.
- Fixed panel scaling so the SecondMonitor1 workspace width/height fit takes precedence over the configured preferred scale; added a regression case for oversized native panels.
- Added named `CreateFrame` post-hook discovery for supported registered Blizzard panels created after addon initialization.

### Changed
- Bumped addon version and TOC metadata to `0.3.0`.
- Updated setup, architecture, parity and test documentation to distinguish implemented, simulated, locally exercised and live-unverified behavior.
- The Windows helper is explicitly one-shot; no service, tray resident, startup registration, network access, telemetry or external protocol is introduced.

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
- The settings window remains a basic dashboard. The guided wizard covers window preparation, MainMonitor configuration and activation, but does not provide display selection or helper handoff. Theme packs, custom backgrounds, preview/recovery UX and code-free media import remain open.
- The full requested user-facing feature set is incomplete. Do not mark this release verified until every row in `docs/FEATURE_PARITY.md` and `docs/TEST_MATRIX.md` has implementation and evidence.

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
- Added raw-mouse behavior: default-on profile setting, original `rawMouseEnable` CVar capture, safe restore on disable/logout, and `/forevermultimonitor rawmouse on|off` control.

### Tests
- Added dependency-free regression assertions for combat queue semantics, dynamic discovery, hook idempotency, snapshot lifecycle, recovery coalescing and error isolation.
- Added `tools/runtime_regression.py` for Lua 5.1 parsing and mocked runtime tests.
- Pinned test-only dependencies in `tools/requirements-test.txt`; documented installation and cache locations under `.tmp` in the workspace.

### Limitations
- No live Forever client test has been performed. Static parsing and simulated runtime tests do not prove secure-frame behavior, frame-hook availability or runtime panel correctness.
- Dynamic discovery covers registered Blizzard UI panel entry points and known bag toggles; it does not claim to discover every arbitrary third-party frame.
- Family-specific panel lifecycle adapters, GUI, setup wizard, themes, Edit Mode integration and native Windows control were not included in this version.
- No external process or external protocol is included.

## [0.1.0] - 2026-11-06

### Added
- Initial Forever-only addon scaffold targeting Interface 16001 and Camelot.
- Runtime build/interface/project and optional-API diagnostics.
- Account SavedVariables defaults and profile validation.
- Manual logical-canvas geometry for left/right MainMonitor layouts.
- Initial WorldFrame viewport controller with anchor capture and restoration.
- Initial panel adapters for map, character, spellbook, quest, professions, auction, social, collections, encounter, achievement and bag/bank frames.
- Bag-toggle discovery hooks for supported Blizzard global functions.
- Debounced recovery after login, world entry, UI-scale and display-size changes.
- Combat-deferred operations and `/forevermultimonitor` command interface.
- Architecture, feature-parity assessment, setup, test matrix and local structural validation.

### Limitations
- No native Windows window management, display enumeration, borderless mode, or automatic physical topology detection.
- No external helper process or external protocol.
- The requested behavior set is incomplete. In-client viewport, protected-frame, panel, persistence and recovery behavior remains unverified.
