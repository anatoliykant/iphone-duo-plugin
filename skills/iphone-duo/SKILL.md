---
name: iphone-duo
description: Adapt, audit, or build iOS apps (Swift, UIKit + SwiftUI) for iPhone Duo — Apple's foldable iPhone (Sept 2026, iOS 27.1 SDK, Xcode 27.1). Covers outer/inner display size classes, vertical toolbars and tab bars, reserved regions (hinge, cameras), ArrangementView / UIArrangementViewController, hinge angle (onHingeChange), multiple scenes and scene accessories, dual front cameras, Split View multitasking, Device Hub poses, adaptive layout for continuously changing window sizes (ViewThatFits, AnyLayout, NavigationSplitView, adaptive grids, state continuity), and a grep-based readiness audit. Use whenever the user mentions iPhone Duo, foldable/folding iPhone, fold, hinge, dual display, inner or outer display, vertical bars, reserved regions, arrangement views, resizable or adaptive iPhone layouts, or asks whether an app is ready for iPhone Duo — even without the words "iPhone Duo". Critical because iPhone Duo APIs are newer than the model's training data.
---

# iPhone Duo (iOS 27.1) — adapt Swift apps to the foldable iPhone

## Flags — answer and stop

Interpret flags only when the user's skill request consists solely of `-h`, `--help`, `-v`,
or `--version`. Claude Code may append that request as `ARGUMENTS: …`; Codex supplies it in the
user message after the skill mention (for example, `$iphone-duo:iphone-duo` in a plugin install
or `$iphone-duo` in a skills-only install). Do not treat flags inside a URL,
file name, quoted code, or a longer task as skill flags. For a flag-only request, print only the
corresponding block and stop — no repo reads, toolchain gate, network calls or delegation.

**`-v` / `--version`** — answer in one line, from the literal below:

> `iphone-duo 1.3.1` · references SDK-verified 2026-10-28 against iOS 27.1 (Xcode 27.1, 27A9275) and iOS 27.2 RC · labs 285–288 · design rules D1–D32

<!-- skill-version: 1.3.1 — kept equal to both plugin manifests by .github/workflows/version-consistency.yml -->

The literal lives in the skill body so it also works in skills-only installs without either
plugin manifest. CI keeps it equal to root `plugin.json` (Codex / Agent Plugins) and
`.claude-plugin/plugin.json` (Claude Code). Answer version requests from this literal without
searching for manifests in the user's project.

**`-h` / `--help`** — print this, verbatim:

> **iphone-duo** — adapt, audit or build iOS apps for iPhone Duo, Apple's foldable (iOS 27.1, shipped 2026-10-23).
>
> **Ask for**
> - *"is this app ready for iPhone Duo"* → read-only grep audit in Claude Code or Codex, severity-ranked, `file:line` per finding
> - *"fix X for Duo"* → the reference that owns X, then the change, in Apple's 13-step order
> - *"build this screen"* → size-class-first with standard containers
>
> **Knows** outer/inner size classes · vertical bars, overflow and compression · reserved regions (fold, cameras) · `ArrangementView` · hinge · multiple scenes and camera accessories · dual front cameras · Split View · Device Hub poses.
>
> **Refuses to guess.** Every symbol carries where it came from and whether it was found in the iOS 27.1 SDK. The first thing it runs is a toolchain gate that probes the SDK for Duo headers — **not** a version compare, because Xcode 27.2 beta 1 predated 27.1 beta 1 and had none of them.
>
> **Leaves iPad and other iPhones as they were.** Duo-only changes sit behind a hinge-presence gate, and Tier 1 refactors must come out pixel-identical on an iPad and an iPhone 17 Pro Max.
>
> **Needs** Xcode 27.1+ for the Duo APIs; everything else (resizability, size classes, safe areas, scene lifecycle) works on any toolchain.
>
> **Reference files** — `device-and-platform` facts · `audit-checklist` the grep set · `layout-size-classes-safe-area` layout · `bars-and-toolbars` bars · `arrangements-and-reserved-regions` the fold · `hinge-scenes-camera` hardware · `testing-and-sources` toolchain, Device Hub, freshness.
>
> Mockups rather than code → `$iphone-duo:hig-design-review` in a Codex plugin install (`$hig-design-review` for skills-only) or `/iphone-duo:hig-design-review` in Claude Code. `-v` for the version.

## Why this skill exists

iPhone Duo was announced 2026-09-09 and shipped 2026-10-23 on iOS 27.1 — after the model's training data. Without `references/` you will hallucinate API names (`reservedRegions`, `ArrangementView`, `onHingeChange`, `axisBehavior`, `AVCaptureDeviceDirectionCoordinator` are real; many plausible neighbors are not). **Trust the references over memory.** Every new symbol carries a status: **VERBATIM** (copied from an Apple Code section or developer article), **PROSE** (named in Apple's text but never written as code), **CAPTION** (YouTube auto-captions only — never use; Apple's own transcripts disagree with all of them), **EXISTING(iOS xx)** (pre-Duo API), **SDK(27.1)** (found in the released iOS 27.1 SDK with an availability annotation).

Research date 2026-09-10; first SDK check 2026-09-21 against Xcode 27.1 beta 1; **re-verified 2026-10-28 against the released Xcode 27.1 (27A9275) and Xcode 27.2 RC (27B48)**. Every Duo declaration is identical to beta 1 — no renames — and the documentation pages no longer carry "beta". 27.2 adds two overloads of `UIView.LayoutRegion.bar(onEdge:)` (`UIRectEdge` and `NSDirectionalRectEdge`) that drop the `extent:` argument. One capability the HIG names is still missing from the SDK (collapsing an overlay arrangement's secondary view); the references say so where it matters.

## Quick facts

- Two displays. Outer 5.4": compact width (regular height portrait, compact × compact landscape) — behaves like other iPhones. Inner 7.6": **regular × regular** — first time on an iPhone — and it **does not honor `supportedInterfaceOrientations`**.
- Points ≈ 466 × 678 (outer) and 626 × 890 (inner) — **derived from pixels @3x, not Apple-stated**.
- SDK tiers (Apple, "Three steps to make your app shine on iPhone Duo"): **iOS 26 SDK or earlier** — open, the app sits in the center with empty space around it; closed, it stays left of the status bar and camera. **iOS 27 SDK** — fills most of the inner display but still avoids the status bar on the right edge. **iOS 27.1 SDK** — full display and **vertical bars**. Duo layout APIs (bar axis/edge, reserved regions, arrangements, hinge) are 27.1; `ToolbarOverflowMenu`, `visibilityPriority`, `.topBarPinnedTrailing`, `defaultTabBarPlacement`, `.sceneAccessory` already ship in 27.0.
- **UIScene lifecycle is required** with the iOS 27 SDK — apps without it do not launch (TN3187) — and **from April 2027 uploads must be built with the iOS 27 SDK** (App Store submitting page), so the old SDK stops being an escape hatch.
- **App Store**: Duo screenshots (1398 × 2034 outer, 2007 × 2853 inner, both orientations) earn an "optimized for iPhone Duo" badge on the product page, and become **required from April 2027** for apps built with the iOS 27.1 SDK or later.
- A plain `UIView`'s default `layoutMargins` are **zero** "on iOS 27.1 and later" (iOS 27.2 release notes) — measured on the Xcode 27.2 RC simulators only on iPhone Duo; iPad and iPhone 18 Pro Max on iOS 27.2 still get 8 pt; view-controller views keep `systemMinimumLayoutMargins`, subviews inherit them only with `preservesSuperviewLayoutMargins = true`.
- **All apps participate in Split View** (50/50) and video + app stacking. First iPhone with multiple scenes; **new windows can only be created on the inner display**.
- `UIScreen.main` is "ambiguous and will be deprecated".
- Bars are vertical on the outer display and in inner-landscape; horizontal only in inner-portrait. The bar stays on the hardware side — no RTL flip.
- Hinge and cameras are **reserved regions** (`.division` = fold, active only when folded; `.occlusion` = front camera). No numbers are published — query, never hard-code.

## Hard rules

The goal in one sentence: make the app excellent at every size first, then use Duo's unique hardware only where it adds value — there is no per-pose "Duo version" of an app (rule 3 is the negative form). Whatever changes for Duo leaves iPad and every other iPhone exactly as they were (rule 14).

1. **Size classes** decide new layout — never idiom, orientation, device model, or screen-width buckets. An *existing* `idiom == .pad` branch that keeps the iPad layout as it is may stay (rule 14): convert it only when iPad and the other iPhones come out unchanged, otherwise give the Duo its path through the hinge gate.
2. **No `UIScreen.main`.** Scale → `traitCollection.displayScale`; screen → `window?.windowScene?.screen`; bounds → view / scene geometry.
3. **No pose flags** — never introduce `isDuo`, `isFolded`, `isBookPose`, `isInnerDisplay`. Do not design a layout per pose. The only gate allowed is hinge presence for rule 14, and it never feeds geometry.
4. **Safe area per edge.** `left != right` is normal; use `bounds.inset(by: safeAreaInsets)`, never `width - left * 2`. Interactive foreground inside the safe area; background past it.
5. **Standard containers** (`NavigationStack` / `NavigationSplitView` / `TabView`, `UINavigationController` / `UITabBarController` / `UISplitViewController`) give vertical bars, fold avoidance and region avoidance for free. Standalone `UIToolbar` / `UINavigationBar` / `UITabBar` and hand-built bar views **do not participate** in vertical bars.
6. **Every toolbar item has a title and an image.** Text-only items stay horizontal and eat space; badges replace inline text.
7. **Interactive controls stay away from the fold** (scrolling content excepted); content never spans the fold.
8. **Hinge data is for effects, not layout.** Layout comes from size classes, `reservedRegions`, and `ArrangementView` / `UIArrangementViewController`.
9. Navigation containers go **outside** `ArrangementView`; `ArrangementView` never goes inside `List` / `ScrollView`.
10. **Every window is `UIWindow(windowScene:)`**; present from the owning view's scene, not `UIApplication.shared.windows.first`. Handle scene-request errors (the outer display refuses new windows).
11. **`UIRequiresFullScreen` is a product decision**, not an auto-fix: `true` = discrete resizing; absent = continuous resizing. Neither keeps the app out of multitasking — "you cannot prevent multitasking with any sort of API in your app" (Apple, forum Q&A). Never add it "for Duo"; never delete it silently. Present Apple's direction with it: the key is deprecated and "will be ignored in a future release" (TN3192), Apple's forum answer says to remove it "as soon as possible", and `UIRequiresFullScreenIgnoredStartingWithVersion` (iOS 26.2) keeps it only for older OS versions.
12. **Toolchain gate first, and by capability — never by version number.** Before any other step, run the gate in `references/testing-and-sources.md` §Toolchain gate: it probes each installed Xcode's iOS SDK for `UIHingeInteraction.h` and `UIViewReservedRegion.h`. **Xcode 27.2 beta 1 shipped two days before 27.1 beta 1 with no Duo APIs** (27.2 RC has them), so `>= 27.1` is the wrong test. Report the result as a **warning before anything else**, including when the Duo SDK is installed but not the active toolchain — then work through `DEVELOPER_DIR=…` (no admin) rather than `sudo xcode-select`. No Duo SDK anywhere → resizability work only, `// TODO:` for 27.1 symbols, listed under "Pending iOS 27.1 SDK".
13. **A layout transition is not a state transition.** One view hierarchy; state hoisted above the size-class branch; navigation depth, scroll, selection, editor contents and playback survive fold / Split View resizes (`references/layout-size-classes-safe-area.md` §State survives the fold).
14. **Duo changes stay on Duo** (owner's rule). The iPad app and every other iPhone (e.g. iPhone 17 Pro Max) keep exactly the layout and behavior they had — a split made for a sheet on Duo does not appear on iPad in any form. Size classes do not scope a change to Duo (iPad is regular × regular, a Pro Max in landscape has a regular width), and `ArrangementView`, bar priorities, bar minimization and bar-item icons act on every device. Gate Duo-only changes on latched hinge presence (`deviceHasHinge`); keep Tier 1 refactors pixel- and flow-identical on iPad and other iPhones, and prove it with before/after snapshots on both (`references/layout-size-classes-safe-area.md` §Scope). Apple's general advice is the opposite — no device-specific behavior; this plugin follows the owner's rule and says so in §Scope.

## Decision tree

| Request looks like… | Do |
|---|---|
| "Is this app ready for iPhone Duo / the foldable?", "audit", "what breaks on Duo" | Read `references/audit-workflow.md` and follow §Audit dispatch below. Read-only: return the severity-ranked report; apply fixes only when the user also requested implementation. |
| Fix layout, `UIScreen.main`, orientation/idiom checks, cached widths, safe area, windows, scene lifecycle | `references/layout-size-classes-safe-area.md` |
| Toolbar / navigation bar / tab bar / sidebar on Duo, overflow, badges, custom bar views, a bar that scrolls away | `references/bars-and-toolbars.md` |
| Fold, two columns, split/overlay, "the camera covers my button", grid columns | `references/arrangements-and-reserved-regions.md` |
| Hinge angle, "second screen", two windows, Split View behavior, teleprompter / accessory display | `references/hinge-scenes-camera.md` §Hinge / §Scenes |
| Camera app: front cameras, preview mirrored/rotated wrong, which camera faces the user | `references/hinge-scenes-camera.md` §Camera |
| How to test, simulator, Device Hub, Xcode 27.1, "does the SDK have X" | `references/testing-and-sources.md` |
| Display facts, size classes per pose, timeline, what is unverified | `references/device-and-platform.md` |
| App Store: Duo screenshots, the "optimized for iPhone Duo" badge, the April 2027 requirements | `references/device-and-platform.md` §App Store |
| Compass, level, AR: motion or heading relative to the display the UI is on | `references/hinge-scenes-camera.md` §Motion and heading |
| New screen from scratch | Build size-class-first with standard containers (layout reference), then the bars reference for its toolbar. |

## Audit dispatch — Claude Code, Codex and skills-only hosts

Resolve `references/audit-workflow.md` and `references/audit-checklist.md` relative to this
installed `SKILL.md`, not the user's working directory. Both files ship with this skill,
including when installed alone through the Agent Skills CLI.

- **Claude Code with the audit agent available:** delegate using
  `Agent(subagent_type: "iphone-duo:iphone-duo-audit", prompt: "Repo root: <absolute repo path>. Workflow: <absolute skill directory>/references/audit-workflow.md. <scope and output path, if requested>")`.
  A manually installed user agent may instead be named `iphone-duo-audit`.
- **Codex:** read and execute `references/audit-workflow.md` using the available file and shell
  tools. The Claude `Agent(...)` API and `agents/iphone-duo-audit.md` registration are not required.
  If the user requests delegation and the session exposes subagents, pass one the absolute
  workflow and repo paths, scope, and the read-only constraint, then collect its report. Do not
  assume that a Claude agent name is a registered Codex role.
- **Skills-only hosts or an unavailable Claude agent:** execute the same workflow in the current
  session. Missing subagent support is not a reason to ask the user to restart or run it by hand.

Keep raw grep output in scratch files and return the compact report. Do not change source files,
create commits, run builds, or apply findings during a read-only audit. Fix requests follow
Apple's migration order below after the audit.

## Migration order (Apple, 13 steps — full text in `references/audit-checklist.md`)

1. Rebuild with the iOS 27.1 SDK. 2. Remove `UIScreen.main`. 3. Orientation → size classes. 4. Idiom → size classes (where iPad and the other iPhones stay unchanged — rule 14). 5. UIScene lifecycle. 6. Safe area / margins per edge, test in Split View. 7. Remove fixed widths and breakpoints. 8. Audit bars (container bars, order, `axisBehavior`, badges, priorities, overflow). 9. Audit centered layouts (containers → `ArrangementView` → `reservedRegions`). 10. Split View + multiple scenes (scene-request errors). 11. Camera (virtual front camera vs direction coordinator; rotation coordinator + disable compensation). 12. `UIRequiresFullScreen` decision. 13. Run Xcode 27.1's **App Resizability** skill (`xcrun agent skills export` to use it outside Xcode).

Mnemonic: Resizability → Size classes → Standard containers → Safe areas → Reserved regions → Arrangements → Hinge (effects only).

Classify every change by tier and finish Tier 1 before proposing Tier 2/3: **Tier 1 universal** (steps 2–7, any SDK — size classes, `UIScreen.main`, scene lifecycle, safe area, standard containers, the adaptive toolbox) · **Tier 2 Duo-aware** (steps 8–9, iOS 27.1 — bar axis/priority, reserved regions, arrangements) · **Tier 3 Duo-exclusive** (steps 10–11 plus hinge effects and scene accessories — product decisions). Every tier obeys rule 14: Tier 1 only while iPad and other iPhones stay pixel-identical, Tier 2 behind the hinge-presence gate wherever the API also acts on other devices.

## Writing code against new APIs

- Copy names **exactly** as they appear in the references, with their status. Symbols tagged **SDK(27.1)** are confirmed; for anything still PROSE-only, run the grep in `references/testing-and-sources.md` §Verify symbols first. If the installed SDK is < 27.1, do not write a 27.1 symbol at all — leave `// TODO:` and report it under "Pending iOS 27.1 SDK".
- Never use CAPTION-only spellings: `UITraitToolbarVerticalEdge`, `toolbarCompressionBehavior`, `toolbarOverflowMenu`, `AVCaptureDeviceCoordinator`, `.axis(` (correct: `.axes(`), `UIWindowSceneActivation` (correct: `UIWindowScene.ActivationAction`). Apple's own forum answers misspell too: `.divisions` / `.occlusions` appear in two DTS posts, while the SDK declares only `.division` and `.occlusion`.
- Gate with `if #available(iOS 27.1, *)` when the deployment target is lower. Pieces that already exist need lower gates: `ToolbarOverflowMenu`, `visibilityPriority`, `.topBarPinnedTrailing`, `defaultTabBarPlacement`, `isTabViewSidebarAvailable`, `.sceneAccessory`, `presentationPlacement(_:)` / `UISheetPresentationController.preferredPlacement`, `toolbarMinimizationBehavior(_:for:)` / `navigationItem.navigationBarMinimization`, `CMMotionManager.deviceMotionBody`, `CLLocationManager.headingBody` (iOS 27.0); `UIView.LayoutRegion.bar(onEdge:)` without `extent:` (iOS 27.2); `UIRequiresFullScreenIgnoredStartingWithVersion` (iOS 26.2); `safeAreaBar(edge:)`, `onInteractiveResizeChange(_:)`, `UIWindowSceneGeometry.isInteractivelyResizing` (iOS 26); `additionalOverflowItems`, `pinnedTrailingGroup` (iOS 16); `UIWindowScene.ActivationAction` (iOS 15); `isCameraSensorOrientationCompensationEnabled`, `dynamicAspectRatio`, badges, concentricity, `backgroundExtensionEffect()` / `UIBackgroundExtensionView` (iOS 26).
- The Duo APIs are not Duo-only. An `ArrangementView` renders two columns wherever there is room and one where there is not (lab 286 56:21), and visibility priorities and the overflow menu apply to any crowded bar (vertical-bar compression and axis settings are Duo-only). That is exactly how a Duo change leaks onto iPad and other iPhones — under hard rule 14, put Duo-only adoption behind the hinge-presence gate. There is no Duo idiom to use instead: it reports `.phone` (lab 286 52:58: "It is a phone … it responds to a phone idiom").
- SwiftUI `defaultTabBarPlacement(.sidebar)` is iOS 27.0 (verified); on iOS 18–26 use `defaultAdaptableTabBarPlacement(.sidebar)`.
- **Mac Catalyst**: iOS 27.1-only APIs do not compile for Catalyst in Xcode 27.1 or 27.2 RC (known issue 185924957) — wrap Duo code in `#if !targetEnvironment(macCatalyst)`, and give a target with an iOS 27.1 minimum a Mac Catalyst 27.0 deployment target, or Catalyst has no run destination (187046347).
- Fixes follow the host project's own conventions (its `AGENTS.md`, `CLAUDE.md` and style rules) and introduce no new `UIScreen.main`, force unwraps or `fatalError`. Remember that SPM packages do not see the app target's compile-time flags — `#available` works everywhere, `#if` flags may not.

## Verifying

With Xcode 27.1 or later (27.2 RC included): Device Hub poses — closed portrait/landscape, open flat, book, table, tent — plus **the transitions between them**, Split View via home-indicator drag, PiP stacking, and reserved regions. Camera apps launch in the simulator but find no capture device, so scene accessories need hardware — and the Xcode 27.1 Duo simulator shows a `CameraCaptureAccessory` even without a capture session (fixed in 27.2 RC), so do not trust its availability there. In Xcode 27.2 RC, VoiceOver and Accessibility Inspector cannot read a Duo inside Device Hub. Apple's own checklist also names the **resizable iOS simulator in Device Hub** and iPhone Mirroring on macOS 27 resized to extremes in both directions. Without 27.1: iPhone Mirroring resized to a Duo-like ratio (keeps the phone idiom — Apple's own first recommendation), an iPad with window resizing, width-parameterized render tests at 466 / 626 / 313 pt (derived), and the TN3187 launch check with the 27.0 SDK. One screenshot is not verification — cover several geometries and a mid-session fold. No XCUITest or `simctl` hook changes the hinge state (Apple named none in lab 287), so poses stay manual in Device Hub; a physical Duo is not needed for most testing (lab 287), though Apple's DTS summary still says to "Always validate button targets, vertical bar positioning, and navigation flows on physical iPhone Duo devices" — reachability and weight only show in the hand, and camera streaming needs hardware. XCUITest on the open Duo: `XCUIApplication.frame` stays portrait while the interface is landscape, so build gestures and screen coordinates from `app.windows.firstMatch`, not from `app`. Details: `references/testing-and-sources.md`.

## Freshness

Closed 2026-10-28: Xcode 27.1 released (27A9275, 2026-10-15) and the Duo shipped (2026-10-23); every Duo symbol re-verified against the release SDK and 27.2 RC, "beta" gone from the documentation pages; group labs 285–288, the DTS summary of them and the three 2026-09-23 forum Q&As read; HIG text unchanged since 2026-09-21 and the developer article since 2026-10-04 (diffed against Wayback copies); Apple's "Three steps" page and the 2026-10-05 App Store news folded in.

Still open: new group labs and workshops; the Xcode 27.2 release; HIG or article edits (hash the JSON — the change log stays silent); the April 2027 App Store requirements as the date approaches. Details and machine-checkable signals: `references/testing-and-sources.md` §Freshness.

## References

| File | Read when |
|---|---|
| `references/device-and-platform.md` | Display/size-class facts, SDK tiers, Split View, `UIRequiresFullScreen`, StandBy and widgets, timeline, App Store, **unverified** list, tech-talk and lab map |
| `references/audit-workflow.md` | Shared read-only audit procedure for Claude Code, Codex and skills-only installs |
| `references/audit-checklist.md` | Running or interpreting the readiness audit: 26 grep categories, severities, tiered report template, Apple's 13 steps |
| `references/layout-size-classes-safe-area.md` | Size classes, replacing `UIScreen.main`, static width caches, state continuity, scene lifecycle, windows, safe area, concentricity, sidebar + adaptive toolbox (`ViewThatFits`, `AnyLayout`, adaptive grids), per-screen checklist, fixed widths, HIG do/don't |
| `references/bars-and-toolbars.md` | Vertical bars: opt-in, order, which column owns a control, axis behavior, badges, edge detection, compression, overflow, priority, opt-out — all 111462 code |
| `references/arrangements-and-reserved-regions.md` | Reserved regions, displacement, `ArrangementView` / `UIArrangementViewController`, split vs overlay, anti-patterns — all 111463 code |
| `references/hinge-scenes-camera.md` | `onHingeChange`, multiple scenes, scene accessories, virtual front camera, direction coordinator, rotation, motion and heading per display — 111464 / 111465 code |
| `references/testing-and-sources.md` | Toolchain gate, Device Hub, local proxies, SDK symbol verification, Xcode MCP, freshness, source URLs |
