# Forever MultiMonitor Behavior Closeout Plan

> **For agentic workers:** execute these tasks in order. Each code task must add or preserve a failing regression before the implementation and rerun the focused test plus the repository gates.

**Goal:** Implement and verify the requested versioned behavior contract while keeping Forever MultiMonitor's product names, commands and helper interface unique. Preserve explicit live-client boundaries and do not copy external source or media.

**Architecture:** Keep WoW UI state in Lua. Keep monitor enumeration and native HWND operations in the standalone Windows helper. Transfer only a versioned data-only geometry marker through the explicit addon path; normal two-display geometry carries exact monitor rectangles, while the explicitly selected single-ultrawide mode derives an equal split in Lua.

**Tech Stack:** Lua 5.1 / WoW Forever APIs, .NET 10 Windows helper, Node.js source-regression checks, Python 3.12 test harness with Lua 5.1 runtime.

**Spec:** `docs/superpowers/specs/2026-11-06-forever-multimonitor-parity-design.md`, with the selected versioned contract recorded in `docs/FEATURE_PARITY.md`.

## Global Constraints

- Preserve the staged and unstaged worktree contents, the staged `Core/Bootstrap.lua` change, and the untracked workspace file.
- Keep source and documentation changes under `F:\forever_multimonitor_addon`; the user explicitly authorized deploying the addon package to the live Forever AddOns folder.
- Default spanning accepts exactly two distinct displays. One-display mode requires the explicit `--single-ultrawide` flag and an addon handoff path.
- A live display disconnect must not remap an active two-display layout onto a smaller canvas.
- Do not claim full parity from static, simulated, or helper-only checks; the Forever client and physical hotplug remain release gates.
- Do not copy the reference package's source or media.

## Review Focus

- A temporary zero-display enumeration must not throw before restoring WoW's saved window styles.
- A previously active topology must be invalidated if the current physical screen no longer matches the handoff.
- Stacked or offset monitor rectangles must preserve all four physical edges and the correct vertical workspace bounds.
- UIParent-space panel positions must remain correct under nested/effective frame scale and short workspace height.
- One display must never activate ultrawide mode without its explicit mode marker.

## Tasks

- [x] Add a zero-connected-display helper rollback self-test and make restore proceed without inventing a fallback monitor.
- [x] Map exact two-display rectangles, including offset/stacked layouts; reject overlapping or stale-size handoffs and rollback failed activation.
- [x] Revalidate an already-active native topology after a display-size change; clear stale geometry and run the failed-apply rollback instead of remapping to a smaller canvas.
- [x] Clamp panels and bag grids to the actual workspace rectangle and convert offsets by effective scale.
- [x] Prevent slash `/forevermultimonitor apply` from announcing preview confirmation after `KeepPreview()` fails; strengthen the anchorless restore regression.
- [x] Add explicit single-ultrawide mode across helper validation, native handoff, and equal-split geometry; keep one-display default rejected.
- [x] Register only `/forevermultimonitor`, remove unbranded aliases, and verify wizard/gather/diagnostic subcommands.
- [x] Standardize layout fields and labels as `MainMonitor` and `SecondMonitor1`; migrate existing profile and native handoff values.
- [x] Register the dashboard in the legacy or modern AddOns settings page and verify both category/open paths.
- [x] Reconcile README, architecture, setup, feature-parity, audit, test matrix, design handoff, and changelog with the implementation and fresh local check outputs.
- [x] Run Lua runtime regression, source regression, structural validator, .NET Release build, helper self-test and both staged/unstaged `git diff --check`.
- [x] Extend Gather to `UIPanelWindows` and movable `UIParent` children, fail closed on protected/forbidden frames, and add a settings-page button using the same command path.
- [x] Refresh the installed package after branding and Gather changes; SHA-256 matches for the TOC and all 17 Lua modules.
- [ ] Preserve the shipping gate as open until actual Forever in-client behavior and physical monitor disconnect/reconnect are verified.

## Execution Findings

- The addon TOC and 17 Lua modules were refreshed in the live Forever AddOns folder; all 18 copied file hashes matched the workspace. WoW was already running, so a full restart is needed to load the updated command, settings, and Gather button.
- The game process is running, but native UI automation could not attach: the computer-use pipe returned “failed to connect”; no in-game click, slash command or settings-page verification was executed.
- A physical disconnect / GPU reset cannot be simulated by the local pure self-test. The helper's zero-display branch is verified in-process only.
- Gather now considers registry entries, `UIPanelWindows`, and movable `UIParent` children. Lua runtime checks cover the three candidate sources and protected/forbidden/tooltip exclusions; live recovery remains open.
- The helper does not provide a GUI display selector or cold-launch recovery bridge. Those remain explicit gaps unless implemented and verified in the real client.
