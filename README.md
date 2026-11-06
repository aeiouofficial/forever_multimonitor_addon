# Forever MultiMonitor

A standalone, companion-free dual-monitor workspace addon for **World of Warcraft: Forever**.

> Status: early development. This repository is not yet feature-equivalent to Offhand and must not be treated as a finished replacement.

## Target client

- WoW Forever launch client: **1.60.1.70790**
- Addon interface: **16001**
- Forever game type: **Camelot**
- Addon folder: `_forever_/Interface/AddOns/ForeverMultiMonitor`

The interface number is the addon loading contract, not proof that every API behaves as expected. Every protected-frame operation and panel adapter requires in-client validation against the live Forever build.

## Design goal

Deliver the in-game functionality of a two-monitor workspace without requiring a separate Offhand Companion process. Windows window placement is delegated to the operating system:

1. Configure WoW in **Windowed** mode.
2. Use PowerToys FancyZones (or manual window placement) to span the WoW window over the two displays.
3. Keep Windows display scaling consistent when FancyZones spans zones across monitors.
4. Configure the Mainhand monitor and workspace split in this addon.
5. The addon narrows the 3D viewport to Mainhand and routes supported UI panels into the Offhand workspace.

The addon cannot itself resize the native Windows window, remove its borders, enumerate physical displays, or recover native window geometry. Those functions require OS-level window control and are not available to WoW Lua. FancyZones is therefore a setup dependency for convenient spanning, not an embedded Companion replacement.

## Current implementation status

| Area | Status |
|---|---|
| Forever manifest / load metadata | Scaffolded for Interface 16001 / Camelot |
| Saved account configuration | Implemented |
| Manual canvas geometry | Implemented; logical UI units only |
| Mainhand viewport | Initial implementation; requires live validation |
| Map / character / bags / other panel routing | Initial frame adapters; requires live validation |
| Dynamic bag discovery | Initial hooks; requires live validation |
| Automatic display topology detection | Not available to addon-only Lua |
| Native borderless window control | Not available to addon-only Lua |
| Companion-free startup recovery | Partial; requires cold-launch testing |
| Setup wizard / full options UI / localization | Not implemented |
| Feature parity with Offhand | Not achieved |

## Commands

- `/fmm` — help
- `/fmm status` — report canvas and active profile
- `/fmm apply` — apply viewport and panel layout
- `/fmm enable` / `/fmm disable` — toggle the layout
- `/fmm side left|right` — choose Mainhand side
- `/fmm width 25-90` — set Mainhand share of the canvas
- `/fmm seam 0-100` — set seam offset in logical UI units
- `/fmm scale 0.5-1.5` — set requested panel scale
- `/fmm reset` — disable and restore captured viewport and panel positions

## Development

Run `node tools/validate.js` to execute the dependency-free structural validator (Node.js required). It checks TOC references, Lua block/delimiter balance and sandbox restrictions; it is not a complete Lua parser.

See [Architecture](docs/ARCHITECTURE.md), [Feature Parity](docs/FEATURE_PARITY.md), [Windows Setup](docs/SETUP.md), [Test Matrix](docs/TEST_MATRIX.md), and [Changelog](CHANGELOG.md).

No GitHub Actions are configured or required. Local validation is performed from this workspace.
