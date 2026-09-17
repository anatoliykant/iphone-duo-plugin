# Changelog

All notable changes to this plugin are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Each release is a `version` bump in `.claude-plugin/plugin.json` plus a matching git tag; Claude Code
pins installed copies to that version, so `claude plugin update` is what moves a user forward.

## [0.10.0] — 2026-09-17

Line-by-line re-check of both skills against the live HIG page
[Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)
on 2026-09-16 (change log still "September 9, 2026 — New page").

### Added

- `hig-design-review` — nine Duo design rules for HIG guidance that had no checklist entry, so the
  set is now D1–D27 (ids are stable; new rules append). D19 controls stay near the content they
  affect · D20 Split View puts each app's controls on its outer edge, layouts are asymmetric ·
  D21 bars do not mirror in right-to-left languages · D22 toolbar vs tab bar under compression ·
  D23 full-width background with inset content is allowed (guards against a false D8/D13 finding) ·
  D24 alerts, context menus, sheets and split views adapt to the fold by themselves · D25 split vs
  overlay arrangement · D26 navigation stays outside an arrangement view · D27 games.
- `iphone-duo` — `bars-and-toolbars.md` §"Not everything belongs on the bar" (a control that acts on
  another column stays with that column); the outer camera is vertically aligned with the side
  controls; `arrangements-and-reserved-regions.md` records that an overlay arrangement can collapse
  its secondary view, tagged PROSE because Apple publishes no spelling for it.

### Fixed

- `hig-design-review` — five citations that pointed at text Apple never published: a fabricated
  quote in the Figma comment template ("content and controls that span the fold become harder to
  see"), the same invention in the example findings row, a "Support Split View" best practice that
  does not exist, D9 anchored to the hardware "Anatomy" section instead of "Follow the standard
  placement order for toolbar items", and D10–D12 labelled "HIG Do" although the page has no
  Do/Don't blocks at all. Every rule now quotes the page verbatim or paraphrases without quotes,
  and the report template says so.
- `hig-design-review` — the games guidance moved out of "What Apple does **not** say" (Apple does
  say it) into rule D27, with the two clauses that were missing: keep text and control sizes
  consistent when resizing, and fill unavoidable padding with artwork.
- `hig-design-review` — D17 now carries the HIG's own wording for the outer camera region
  ("expands into the Dynamic Island for Live Activities") and its alignment with the side controls.
- Both skills — every tech-talk citation re-checked against the official Apple transcripts of the
  six "Get ready for iPhone Duo" talks (111461–111466). All 46 VERBATIM code blocks matched Apple's
  46 sample-code blocks exactly, at the same timecodes, with none missing on either side, and every
  cited timecode landed on the right chapter. Twenty prose quotes turned out to be paraphrases
  wearing quotation marks and now carry the speaker's own sentence plus the exact timecode — among
  them the reserved-region and displacement definitions, the arrangement definition, the fold
  avoidance behavior, the safe-area guidance, the SDK tiers, the Device Hub controls, and the
  camera-direction passage. Where Apple has no matching sentence the quotation marks are gone.
- `iphone-duo` — the `UIRequiresFullScreen` paragraph attributed its quote to a WWDC26 278 chapter
  title that does not exist; session 278 is "Modernize your UIKit app" and the sentence is spoken at
  6:00 inside the chapter "Full-screen mode for games". Quote and anchor corrected, and the session's
  own "no longer opts your app fully out of resizing" replaces the second-hand caption note.
- `hig-design-review` — D14 said the talk calls fold-spanning content "a photo spread across a
  book's spine"; 111463 1:44 actually shows "this photo spread across the two pages", which when
  folded "no longer reads as one continuous image". 111466 9:51 says "curve region", not "hinge".
- `iphone-duo` — the source table claimed the talk pages carry "chapter text + Code sections (not
  transcripts)". They carry the full official transcript inline in the HTML; `testing-and-sources.md`
  now has a §Read a talk recipe that pulls transcript and sample code with two greps, no JavaScript.
  Consequences recorded: `PROSE` now means "spoken in Apple's official transcript", the six
  `CAPTION` spellings are confirmed wrong by that transcript, `UIWindowSceneActivationAction` was a
  truncated caption rather than an Apple misspelling, `ArrangementStyle` joins the PROSE table, and
  the transcript's singular "reservedRegion method" is flagged as losing to the Code section's
  `reservedRegions(kind:)`.

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

[0.10.0]: https://github.com/anatoliykant/iphone-duo-plugin/releases/tag/v0.10.0
[0.9.0]: https://github.com/anatoliykant/iphone-duo-plugin/releases/tag/v0.9.0
