# Changelog

All notable changes to this plugin are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Each release is a `version` bump in `.claude-plugin/plugin.json` plus a matching git tag; Claude Code
pins installed copies to that version, so `claude plugin update` is what moves a user forward.

## [1.0.0] — 2026-09-21

First release verified against a real SDK. Xcode 27.1 beta 1 (27A9269) shipped on 2026-09-18 with the
iOS 27.1 SDK and the iPhone Duo simulator, and Apple published the developer article "Preparing your
app for iPhone Duo", two camera articles, the September 2026 `documentation/updates` sections, the
Xcode 27.1 beta release notes and two iPhone Duo Group Labs. Every Duo symbol in the references now
carries an availability annotation read from the SDK, so the plugin no longer reasons about APIs it
has never seen — which is what 0.x was waiting on.

### Added

- **`SDK(27.1 β1)` provenance tag** alongside VERBATIM / PROSE / CAPTION / EXISTING: where a name came
  from, and whether it has been confirmed in a shipping SDK.
- **Arrangement API that the talk never showed**: `ArrangementViewStyle` (the protocol behind the
  transcript's "ArrangementStyle"), `makeBody(configuration:)`, `ArrangementViewStyleConfiguration`,
  `overlayArrangementEdge(_:)`, the four `splitArrangementLayout*` sizing modifiers, the
  `splitArrangementAxis` environment value, `UIArrangementViewState` (`zIndex`, `splitAxis`,
  `isHidden`), `UIArrangement` / `UISplitArrangement.Dimension` / `DimensionRange`, and
  `UIViewController.arrangementViewController`.
- **Reserved regions beyond the frame**: `margins`, `isActive`, the opaque `ReservedRegion.ID`, and the
  SwiftUI query's third argument `layoutDirectionBehavior:` (defaults to `.mirrors`).
- **Hinge types**: `DeviceHinge` / `DeviceHingeContext` (SwiftUICore), `UIHinge`,
  `UIHingeInteraction(updateHandler:)` and all four statuses — previously "verify these spellings".
- **The UIKit path for scene accessories**, from Apple's article:
  `UISceneAccessory.cameraCapture(sceneConfiguration:userInfo:)`, `registerSceneAccessory(_:)` →
  `UISceneAccessoryRegistration`, the `windowCameraCaptureAccessory` role, `sceneAccessoryUserInfo`,
  and the rule that Split View withdraws the accessory.
- **The camera article's code**, which the talk only gestured at: the virtual front camera
  (`isVirtualDevice`, `activePrimaryConstituent`), resolving an `AVCaptureDeviceDescriptor` on a
  capture actor, and deciding mirroring from the direction map rather than from `position`.
- **Sheet placement**: `presentationPlacement(_:)` / `UISheetPresentationController.preferredPlacement`
  (iOS 27.0) decides whether an inner-display sheet gets horizontal or vertical bars.
- **`UIView.LayoutRegion.bar(onEdge:extent:)`** — ask the system where it would have drawn its bar
  instead of measuring, for the apps that genuinely cannot use a container bar.
- **`backgroundExtensionEffect()` / `UIBackgroundExtensionView`** for hero art under a vertical bar.
- **Two design rules, so the set is D1–D29**: D28 (a pose change moves elements, it does not rebuild
  the screen — Apple names "designing for every pose" as the biggest mistake they have seen) and D29
  (tabs stay inside a sheet when the tabs choose the sheet's content).
- **A recipe for reading a Meet with Apple lab** — those pages carry no transcript, only HLS caption
  segments — plus the Duo simulator identifiers, now that they exist.
- **A toolchain gate that runs first and reports as a warning**, in the skill, the audit checklist and
  the agent. It probes each installed Xcode's iOS SDK for `UIHingeInteraction.h` and
  `UIViewReservedRegion.h` rather than comparing version numbers — **Xcode 27.2 beta 1 (27B5019j,
  2026-09-16) shipped two days before 27.1 beta 1 (27A9269, 2026-09-18) and is on a different build
  train**, so a `>= 27.1` test passes a toolchain with no Duo APIs. It also covers the common split
  where the Duo SDK is installed but some other Xcode is active, and answers it with
  `DEVELOPER_DIR=…`, which needs no admin rights, instead of `sudo xcode-select -s`. Enumeration
  combines the usual folders with Spotlight, so an Xcode on another volume is found. Nothing in the
  gate launches Xcode: versions come from `Contents/version.plist`, because `Contents/Info.plist`
  reports `DTPlatformVersion = 27.0` even in the 27.1 beta, and running `xcodebuild` under a
  never-opened Xcode can demand `sudo xcodebuild -license`.

### Changed

- `testing-and-sources.md` is rewritten around an installed 27.1: Device Hub poses **and the
  transitions between them**, camera apps launching in Simulator without a camera, the beta's known
  issues, and iPhone Mirroring promoted to Apple's first-choice proxy when 27.1 is absent.
- The freshness protocol now watches for the iOS 27.1 RC dropping "beta" from the annotations, rather
  than for the beta itself.
- Both skills cite the developer article alongside the HIG, and the labs where an Apple engineer says
  something the written docs do not.

### Fixed

- **"Inspectors do not get their own bar"** — they do, horizontally, says the article.
- **"Apple never uses letterboxing"** — the HIG never does, but an Apple engineer walks through the
  whole letterbox progression in lab 285. The claim is now attributed to the lab.
- **`UIViewReservedRegion` was tagged PROSE**; it is a real ObjC class whose Swift name is
  `UIView.ReservedRegion`, refined from `-reservedRegionsOfKind:options:` — which is also why a grep
  for `reservedRegions` in the UIKit headers returns nothing.
- **`CameraCaptureAccessory` was filed under AVFoundation**; it is a SwiftUI `SceneAccessoryContent`.
- **App Resizability was described as an Xcode 27 skill**; it exists only from 27.1, and the export
  command takes `--output-dir`.
- The Duo `simctl` device type was listed as "not published" — it is
  `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`.

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

[1.0.0]: https://github.com/anatoliykant/iphone-duo-plugin/releases/tag/v1.0.0
[0.10.0]: https://github.com/anatoliykant/iphone-duo-plugin/releases/tag/v0.10.0
[0.9.0]: https://github.com/anatoliykant/iphone-duo-plugin/releases/tag/v0.9.0
