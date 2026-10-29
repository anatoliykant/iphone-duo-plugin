# Changelog

All notable changes to this plugin are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Each release bumps both `plugin.json` (Codex / Agent Plugins) and
`.claude-plugin/plugin.json` (Claude Code), plus the version literals in both skills, and uses a
matching git tag. See README.md for the update commands for each host.

## [1.3.2] — 2026-10-29

Xcode 27.2 RC becomes the required toolchain, and three sarunw.com articles (2026-10-16, 10-22 and
10-26) are folded in after re-measuring everything they claim. The measurements were taken on the iPhone
Duo simulator with Xcode 27.2 RC: the iOS 27.2 Duo runtime (24B91014) and the iOS 27.1 runtime (24A94425).
They also exposed a wrong inner-display size that the plugin had carried since 0.9.0.

### Changed

- **Toolchain: Xcode 27.2 RC or later**, with the iOS 27.2 simulator runtimes (owner's decision). The
  gate still probes the SDK for the Duo headers first, then requires version 27.2+; Xcode 27.1 is
  reported as unsupported, with a link to install 27.2 RC. The gate now finds Xcodes with `find`
  instead of a glob, which zsh aborted on no match.
- **iOS 27.1 stays a supported runtime** — the Duo shipped with it. New §Known iOS 27.1 bugs lists
  workarounds that also run on 27.2. It also explains how to keep Duo-only code off 27.1: raise the
  hinge gate to `#available(iOS 27.2, *)`.

### Fixed

- **The inner display is 669 × 951 pt, not 626 × 890.** The old figure was the panel's 1878 × 2670
  pixels divided by 3. The simulator lays apps out on 669 × 951 pt and renders 2007 × 2853 px
  (`nativeScale` 3), which is exactly the App Store screenshot size. The new figures run through the skills,
  the design-review rules, the Figma intake table, the designers' guide and the audit:
  - the fold band is 40 pt wide and centred at 475 pt, not 445;
  - the Split View half is now ≈ 334 pt (derived);
  - the audit now flags render tests still at 313 or 626 pt.
- **The flat fold.** Talk 111463 says the inactive division region has zero width. The simulators
  still report the 40 pt band, so the references now say to test `isActive`, never the width.
- **Overlay z-order.** The `ArrangementView` documentation sides with the HIG: "the arrangement view
  places the primary view above the secondary view in the z-axis". DTS forum answer 847816 is the
  outlier.

### Added

- **`contentMargins(for: .container)`** (`ContentMarginGuide`, iOS 27.1) — SwiftUI's counterpart of
  `layoutMarginsGuide`. Included: Apple's documentation, code typechecked at deployment targets 27.1 and
  17.0, and a measured table of SwiftUI and UIKit margins per pose. Beside a vertical bar the margin is 0.
  Rule 14 caveat: on iPad the guide gives 20 pt, so a swap from `.padding(16)` goes behind the hinge gate.
- **Size classes inside `ArrangementView` panes**, measured per pose on Duo and iPad. The split axis
  goes compact. The iOS 27.1 bug is confirmed: the view passed straight to the arrangement reads the
  window's size classes, and `splitArrangementAxis` is `nil` there; wrapping each child in a container
  works around it.
- **Placement matters.** Inside a `VStack`, the panes kept the window's size classes on iPad and the
  closed Duo; as the root of a `NavigationStack` they got their own.
- **From the `ArrangementView` documentation:**
  - a closed Duo in landscape shows only the primary view;
  - equal pane sizes by default;
  - the containers to keep apart (scroll view, navigation split view, grid; no navigation split view or
    tab view inside).

## [1.3.1] — 2026-10-29

Closes the one check 1.3.0 left open: the hinge gate measured on the Xcode 27.2 RC simulators.

### Fixed

- **Default layout margins** — 1.3.0 said the zero default `UIView` margins from the iOS 27.2 release
  notes reach every iPhone on iOS 27.1 and later. Measured with Xcode 27.2 RC: zero only on iPhone Duo
  (24B91014); iPad Pro 13-inch and iPhone 18 Pro Max on iOS 27.2 (24B114) still get 8 pt. The section
  now says so and shows the explicit-margin fix, which leaves iPad and the other iPhones unchanged.
- **Hinge gate on iPad** — no longer rests on Apple's word alone: on iPad Pro 13-inch and iPhone 18 Pro
  Max with iOS 27.2 neither `onHingeChange` nor `UIHingeInteraction` fired in 40 seconds, so
  `deviceHasHinge` stays `false`; on the Duo runtime both fire at launch.

## [1.3.0] — 2026-10-29

The first release after iPhone Duo shipped (2026-10-23). It folds in everything Apple published
since 1.2.1: group labs 287 (2026-10-13) and 288 (2026-10-15), Apple's DTS summary of the labs on the
forums, the three 2026-09-23 forum Q&As (134 threads, 78 with Apple answers), the "Three steps to make
your app shine on iPhone Duo" page, the 2026-10-05 App Store news, TN3192, and the Xcode 27.1 / 27.2 RC
and iOS 27.2 release notes. Every Duo symbol was re-verified against the released Xcode 27.1 (27A9275)
and Xcode 27.2 RC (27B48). Lab timecodes are the captions' on the Apple Developer page; YouTube-based
recaps run about two minutes later.

### Added

- **Hard rule 14 — Duo changes stay on Duo** (owner's rule). The iPad app and every other iPhone keep
  exactly the layout and behavior they had; a split made for a sheet on Duo does not reach iPad in any
  form. Size classes cannot scope a change to Duo, and `ArrangementView`, bar priorities, minimization
  and bar-item icons act on every device, so Duo-only changes sit behind a latched hinge-presence gate
  (`deviceHasHinge`, SwiftUI and UIKit code typechecked at deployment targets 27.1 and 17.0). Measured
  on the Duo simulator: `UIHingeInteraction` and `onHingeChange` both deliver the initial state about
  60 ms after the view appears. Tier 1 refactors must leave iPad and other iPhones pixel- and
  flow-identical, proven with before/after snapshots on both. Hard rule 3 and the "write for the whole
  lineup" advice changed to match.
- **App Store** (`device-and-platform`): submitting Duo screenshots puts an "optimized for iPhone Duo"
  badge on the product page; from April 2027 Duo screenshots are required for apps on the iOS 27.1 SDK
  and every upload needs the iOS 27 SDK; app preview sizes; the App Store Connect preview tool.
- **Bars that scroll away** (`bars-and-toolbars`): `toolbarMinimizationBehavior(_:for:)`,
  `toolbarMinimizationRestoration(_:for:)`, `toolbarMinimizationSafeAreaAdjustment(_:for:)`,
  `navigationItem.navigationBarMinimization` — all iOS 27.0, typechecked. Navigation bars scroll away on
  Duo by default (lab 288); `.never` keeps them, `.onScrollUp` suits bottom-anchored content.
- **Motion and heading per display** (`hinge-scenes-camera`): `CMMotionManager.deviceMotionBody` and
  `CLLocationManager.headingBody` take a view (iOS 27.0), so attitude and heading follow the display the
  UI is on; `headingOrientation` is deprecated in iOS 27.0.
- **Scroll axis against the hinge** (`arrangements-and-reserved-regions`): Apple's own apps in a table
  — what shifts off the fold (Messages, App Store Today) and what scrolls through it (carousels, lists
  in the laptop pose, Preview's two-page mode). Arrangements nest; touches over the camera region are
  suppressed; the order to reach for tools in, from standard containers down to the hinge.
- **Layout** (`layout-size-classes-safe-area`): Apple's "Three steps" list — re-read size in
  `layoutSubviews` / `viewDidLayoutSubviews` (not `viewIsAppearing`), regular width is not iPad, no
  device-size comparisons, full-bleed media that loses content; never override size classes; default
  `UIView` layout margins are zero on iOS 27.1+; scroll position kept by index path, and a semantic
  anchor for custom text; tab bar or sidebar with Apple's examples (Music, TV, Mail, Phone, Health);
  inspectors; what a fold does not do (`onAppear` does not fire again).
- **RTL, search and side menus** (`bars-and-toolbars`): in right-to-left languages the list column sits
  between the vertical bar and the detail; search stays at the bottom on the inner display;
  `safeAreaBar(edge:)` with `toolbarVerticalEdge` for custom vertical bars; `UIView.LayoutRegion.bar(onEdge:)`
  without `extent:` (iOS 27.2); the launch screen cannot follow a vertical-bar opt-out.
- **Audit categories 24–26**: size-class overrides (HIGH), full-bleed media set to fill (LOW / manual),
  motion and heading frames (LOW). Category 6 is MEDIUM now and catches `statusBarOrientation`;
  category 12 checks for a launch screen (required for App Store submission with the iOS 27 SDK) and
  `UIRequiresFullScreenIgnoredStartingWithVersion`; category 16 catches `bounds.height == 844`-style
  comparisons. The checklist has 26 categories.
- **Design rules D30–D32**: the navigation model stays recognisable between closed and open; scrolling
  across the fold is fine and reads best perpendicular to it, while row-anchored elements such as chat
  bubbles shift off it; search stays at the bottom on the inner display. The set is D1–D32.
- StandBy and widgets (`systemExtraLargePortrait`, Live Activities on the vertical Dynamic Island), PiP
  on the folded device, `UIRequiresFullScreen` deprecation (TN3192), Mac Catalyst build issue for
  iOS 27.1 APIs, Xcode 27.1 / 27.2 RC simulator and Device Hub known issues, the 27.2 runtime
  identifiers, reading the forums in a browser.
- **From the forum Q&As** (each with the thread link): the inner camera's real capabilities (native
  1080p at 30/60 fps, metadata output, long sessions, extra per-frame cleanup), what a virtual front
  camera switch looks like to frame processing, multicam limits, ARKit with `CameraCaptureAccessory`,
  camera availability from the direction coordinator; `ArrangementView` collapsing to the higher
  `.layoutPriority` child; no automatic fold avoidance for collection views and Apple's default of not
  moving scrollable grids; sheets moving to the leading edge when folded; a scene delegate per window;
  scroll content passing under the vertical bar; custom-bar accessibility (long-press labels, Large
  Content Viewer); hinge angle range not guaranteed; hinge-dependent games and App Review.

### Changed

- **SDK tags**: `SDK(27.1 β1)` is now `SDK(27.1)` — the released SDK matches beta 1 for every Duo
  declaration, and the documentation pages dropped "beta".
- **SDK tiers** follow Apple's "Three steps" page: an iOS 26 SDK app sits centered with empty space on
  the open display and left of the status bar on the closed one.
- **Unverified list**: Touch ID confirmed (specs page); Apple Pencil (USB-C) is supported without hover;
  WebKit's Viewport Segments and Device Posture APIs exist as opt-in experimental features in iOS 27.1;
  the extra-large widget is `systemExtraLargePortrait`; there is no system pose value.
- **Testing**: asked about an XCUITest or `simctl` hook for the hinge state, Apple named none and asked
  for Feedback naming the use case; a physical Duo is not needed for most testing.
- **Rule 1 and rule 14 reconciled**: an existing `idiom == .pad` branch that keeps the iPad layout may
  stay; converting it to a size class is allowed only when iPad and the other iPhones come out
  unchanged (a Pro Max in landscape has a regular width). Audit category 5, migration step 4 and the
  report's Opportunities now say which suggestions need the hinge gate. The UIKit gate sample latches
  once per app from the window instead of per screen.
- **D13** also allows immersive games and a regular-width-only opt-out where compact and regular
  interfaces genuinely differ (Safari's tabs); **D16** sends sheets to the leading edge when folded.
- **Freshness** rewritten for the shipped device: new baselines (page hashes, release-notes titles,
  the next lab page) and what is still open.

### Fixed

- `device-and-platform` said Duo screenshots had no badge and no requirement — both now exist.
- The SDK tier table described the closed-display behavior under "inner display".
- `UIRequiresFullScreen` was described as "no Split View"; no Apple source says that, and Apple's forum
  answer says no API prevents multitasking. It now reads "discrete resizing" only.
- `devicectl device appResize` / `orientation` were listed as third-party and unverified; they ship in
  Xcode 27.0–27.2 RC (resizable app sessions and simulated orientation on a device, not a fold).
- An unrebuilt app was said to show "no reaction to any pose"; partially open, it shifts to one side.
- D16 said sheets move to the trailing side in the book pose; Apple says they move to the leading edge.
- The Figma intake pointed fold-avoidance candidates at D9 (bar order) instead of D14.
- The lab-captions recipe built `…/subtitles/en//prog_index.m3u8`; the CDN answers that with a 302
  and an S3 AccessDenied body, so no captions came back. It now joins the path correctly and fetches
  the ~600 segments in parallel.

## [1.2.1] — 2026-10-13

### Added

- `iphone-duo` testing reference: XCUITest on the open iPhone Duo simulator. `XCUIApplication.frame`
  stays portrait (669×951) while the interface is landscape (951×669), so `app.coordinate(…)`,
  `app.swipeUp()` / `app.swipeDown()` and `app.frame` rotate gestures by 90°. Build screen-level
  gestures from `app.windows.firstMatch`. Measured with a probe test on Xcode 27.1 beta; the fold does
  not swallow touches. `SKILL.md` points to the section from its testing summary.

## [1.2.0] — 2026-09-30

### Added

- Native Codex packaging: portable root `plugin.json` and a repo marketplace at
  `.agents/plugins/marketplace.json`, sharing the existing skills with Claude Code.
- A shared read-only audit workflow bundled inside the `iphone-duo` skill. Codex and skills-only
  installs can run the full audit without registering a Claude agent or starting a new session.
- Codex installation, invocation, Figma MCP and Xcode MCP instructions; the designer guide now
  covers both hosts.
- A dependency-free package validator used by CI: both manifests, marketplaces, skill version
  answers, bundled references and release tags must agree.

### Changed

- The Claude audit agent is a thin adapter to the shared workflow. The 23-category checklist,
  severity rules, scope handling and report format remain in their existing shared references.
- Skills recognize standalone help/version requests in both hosts. Flags embedded in a URL or
  a longer task do not short-circuit the request. Version replies need no manifest lookup.
- Audit-only requests return findings without applying fixes. Unavailable subagents fall back
  to the same workflow in the current session.
- Figma intake discovers actual tool names and schemas before using provider-specific examples.

## [1.1.0] — 2026-09-22

### Added

- **`-h` / `--help` and `-v` / `--version` on both skills.** `--help` prints a short card — what the
  skill is for, what to hand it, what comes back, what it needs — and stops, without reading a repo
  or calling Figma. `--version` reads the number out of `.claude-plugin/plugin.json` next to the
  skill body, because that is the only number a skill can read at runtime — the host strips the YAML
  frontmatter before showing a skill, and `npx skills add` copies `skills/` without
  `.claude-plugin/plugin.json`.
- **A CI guard for that literal** (`.github/workflows/version-consistency.yml`): it fails when a
  skill's `skill-version` marker or its `-v` answer line disagrees with `.claude-plugin/plugin.json`,
  and on a tag push it also checks the tag and the CHANGELOG entry. The version now lives in three
  files on purpose, and drifting is a build failure rather than a wrong answer to `-v`.

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

[1.2.0]: https://github.com/anatoliykant/iphone-duo-plugin/releases/tag/v1.2.0
[1.1.0]: https://github.com/anatoliykant/iphone-duo-plugin/releases/tag/v1.1.0
[1.0.0]: https://github.com/anatoliykant/iphone-duo-plugin/releases/tag/v1.0.0
[0.10.0]: https://github.com/anatoliykant/iphone-duo-plugin/releases/tag/v0.10.0
[0.9.0]: https://github.com/anatoliykant/iphone-duo-plugin/releases/tag/v0.9.0
