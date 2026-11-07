# Changelog

## Unreleased

- Updated the public guides to use the Forever MultiMonitor name and show the current setup and command paths.
- Repositioned the profile-name field and actions below the monitor controls so the dashboard rows do not collide.

## 0.4.1 - 2026-11-06

### Added

- Added off-screen panel recovery through the settings page and `/forevermultimonitor gather`.
- Registered the settings dashboard in the AddOns page and made `/forevermultimonitor` a direct opener.
- Added explicit single-screen ultrawide placement to the Windows helper.

### Fixed

- Failed layout changes restore the captured viewport, supported panel positions, raw mouse setting, and World Map Escape behavior.
- Failed panel placement restores its previous anchors and scale so the operation can be retried.
- Windows restore now places the game window on a connected display when its saved position is no longer visible.

## 0.4.0 - 2026-11-06

- Added exact monitor-rectangle handoff from the Windows helper to the addon.
- Added profile-scoped World Map Escape behavior, a non-overlapping default-bag layout, and Edit Mode-aware panel routing.
- Added native monitor calibration controls and status commands.

## 0.3.7 - 2026-11-06

- Added Midnight, Indigo, and Classic dashboard themes with per-profile background opacity controls.

## 0.3.6 - 2026-11-06

- Added `/forevermultimonitor diagnostics` for addon, panel, profile, geometry, and recovery information.

## 0.3.5 - 2026-11-06

- Added a 15-second reversible layout preview with an explicit Keep action.
- Explicit enable, disable, apply, and reset commands now cancel a pending preview timer.

## 0.3.4 - 2026-11-06

- Added opt-in Windows display-loss monitoring and safe window restoration.
- Added Ctrl+C recovery and a configurable polling interval to the helper.

## 0.3.3 - 2026-11-06

- Improved setup wizard navigation and its Next, Back, and Finish controls.

## 0.3.2 - 2026-11-06

- Added a three-step setup wizard for preparing the game window, configuring MainMonitor, and enabling the layout.

## 0.3.1 - 2026-11-06

- Supported panels now restore their captured position and scale when closed and route again when reopened.
- Rapid panel visibility changes during combat are applied in their latest requested state.

## 0.3.0 - 2026-11-06

- Added an in-game settings dashboard with layout controls and named profiles.
- Added the Windows helper for display enumeration, borderless placement, and explicit restore.
- Added supported Blizzard panel discovery and profile migration.

## 0.2.0 - 2026-11-06

- Added safe dynamic panel discovery, per-character panel-position saving, and raw mouse input control.

## 0.1.0 - 2026-11-06

- Initial Forever MultiMonitor addon with configurable MainMonitor geometry, WorldFrame placement, supported panel routing, and recovery after game display changes.
