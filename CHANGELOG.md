# Changelog

All notable changes to this plugin are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Each release is a `version` bump in `.claude-plugin/plugin.json` plus a matching git tag; Claude Code
pins installed copies to that version, so `claude plugin update` is what moves a user forward.

## [0.9.0] — 2026-09-14

First public release.

### Added

- Skill `iphone-duo` — adapting Swift apps (UIKit + SwiftUI) to iPhone Duo: size classes, vertical
  bars, reserved regions, arrangement views, hinge, multiple scenes, dual front cameras, Split View,
  adaptive layout and state continuity. Seven reference files, Apple's 13-step migration order, and a
  status tag (VERBATIM / PROSE / CAPTION / EXISTING) on every new symbol.
- Skill `hig-design-review` — reviewing Figma or Sketch mockups against the Human Interface
  Guidelines before implementation: general iOS checks plus the iPhone Duo rules D1–D18, with live
  HIG citations, a Ready / Not ready verdict and optional Figma comments.
- Agent `iphone-duo-audit` — read-only readiness audit that runs the 23-category grep checklist over
  an iOS codebase and returns a severity-ranked report with `file:line` and fix pointers.

### Notes

- Research date 2026-09-10; statuses re-checked against the iOS 27.0 SDK (Xcode 27.0 RC) on
  2026-09-14. The Xcode 27.1 beta had not shipped, so no iOS 27.1 symbol carries an official
  availability annotation yet — the skills say so and gate new APIs behind a toolchain check.

[0.9.0]: https://github.com/anatoliykant/iphone-duo-plugin/releases/tag/v0.9.0
