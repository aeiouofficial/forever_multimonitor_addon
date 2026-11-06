# Changelog

All notable changes are documented here.

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
