---
name: iphone-duo
description: Adapt, audit, or build iOS apps (Swift, UIKit + SwiftUI) for iPhone Duo — Apple's foldable iPhone (Sept 2026, iOS 27.1 SDK, Xcode 27.1). Covers outer/inner display size classes, vertical toolbars and tab bars, reserved regions (hinge, cameras), ArrangementView / UIArrangementViewController, hinge angle (onHingeChange), multiple scenes and scene accessories, dual front cameras, Split View multitasking, Device Hub poses, adaptive layout for continuously changing window sizes (ViewThatFits, AnyLayout, NavigationSplitView, adaptive grids, state continuity), and a grep-based readiness audit. Use whenever the user mentions iPhone Duo, foldable/folding iPhone, fold, hinge, dual display, inner or outer display, vertical bars, reserved regions, arrangement views, resizable or adaptive iPhone layouts, or asks whether an app is ready for iPhone Duo — even without the words "iPhone Duo". Critical because iPhone Duo APIs are newer than the model's training data.
---

# iPhone Duo (iOS 27.1) — adapt Swift apps to the foldable iPhone

## Why this skill exists

iPhone Duo was announced 2026-09-09 and ships 2026-10-23 on iOS 27.1 — after the model's training data. Without `references/` you will hallucinate API names (`reservedRegions`, `ArrangementView`, `onHingeChange`, `axisBehavior`, `AVCaptureDeviceDirectionCoordinator` are real; many plausible neighbors are not). **Trust the references over memory.** Every new symbol carries a status: **VERBATIM** (copied from an Apple Code section), **PROSE** (named only in Apple text), **CAPTION** (YouTube captions only — never use), **EXISTING(iOS xx)** (pre-Duo API). Research date 2026-09-10; the Xcode 27.1 beta had not shipped, so no symbol has an official availability annotation yet — anything not VERBATIM/EXISTING is "verify in SDK".

## Quick facts

- Two displays. Outer 5.4": compact width (regular height portrait, compact × compact landscape) — behaves like other iPhones. Inner 7.6": **regular × regular** — first time on an iPhone — and it **does not honor `supportedInterfaceOrientations`**.
- Points ≈ 466 × 678 (outer) and 626 × 890 (inner) — **derived from pixels @3x, not Apple-stated**.
- SDK tiers: unrebuilt apps run using only the area left of the status bar; **iOS 27 SDK** extends left of the status bar; **iOS 27.1 SDK** reaches the screen edge and gets **vertical bars**. Duo layout APIs (bar axis/edge, reserved regions, arrangements, hinge) are 27.1; `ToolbarOverflowMenu`, `visibilityPriority`, `.topBarPinnedTrailing`, `defaultTabBarPlacement`, `.sceneAccessory` already ship in 27.0.
- **UIScene lifecycle is required** with the iOS 27 SDK — apps without it do not launch (TN3187).
- **All apps participate in Split View** (50/50) and video + app stacking. First iPhone with multiple scenes; **new windows can only be created on the inner display**.
- `UIScreen.main` is "ambiguous and will be deprecated".
- Bars are vertical on the outer display and in inner-landscape; horizontal only in inner-portrait. The bar stays on the hardware side — no RTL flip.
- Hinge and cameras are **reserved regions** (`.division` = fold, active only when folded; `.occlusion` = front camera). No numbers are published — query, never hard-code.

## Hard rules

The goal in one sentence: make the app excellent at every size first, then use Duo's unique hardware only where it adds value — there is no "Duo version" of an app (rule 3 is the negative form).

1. **Size classes** decide layout — never idiom, orientation, device model, or screen-width buckets.
2. **No `UIScreen.main`.** Scale → `traitCollection.displayScale`; screen → `window?.windowScene?.screen`; bounds → view / scene geometry.
3. **No pose flags** — never introduce `isDuo`, `isFolded`, `isBookPose`, `isInnerDisplay`. Do not design a layout per pose.
4. **Safe area per edge.** `left != right` is normal; use `bounds.inset(by: safeAreaInsets)`, never `width - left * 2`. Interactive foreground inside the safe area; background past it.
5. **Standard containers** (`NavigationStack` / `NavigationSplitView` / `TabView`, `UINavigationController` / `UITabBarController` / `UISplitViewController`) give vertical bars, fold avoidance and region avoidance for free. Standalone `UIToolbar` / `UINavigationBar` / `UITabBar` and hand-built bar views **do not participate** in vertical bars.
6. **Every toolbar item has a title and an image.** Text-only items stay horizontal and eat space; badges replace inline text.
7. **Interactive controls stay away from the fold** (scrolling content excepted); content never spans the fold.
8. **Hinge data is for effects, not layout.** Layout comes from size classes, `reservedRegions`, and `ArrangementView` / `UIArrangementViewController`.
9. Navigation containers go **outside** `ArrangementView`; `ArrangementView` never goes inside `List` / `ScrollView`.
10. **Every window is `UIWindow(windowScene:)`**; present from the owning view's scene, not `UIApplication.shared.windows.first`. Handle scene-request errors (the outer display refuses new windows).
11. **`UIRequiresFullScreen` is a product decision**, not an auto-fix: `true` = discrete resizing, no Split View; absent = continuous resizing + Split View. Never add it "for Duo"; never delete it silently.
12. **Toolchain gate before any new API**: `xcodebuild -version`, `xcrun --sdk iphoneos --show-sdk-version`. SDK < 27.1 → do only the resizability work, leave `// TODO:` for 27.1 symbols, list them under "Pending iOS 27.1 SDK".
13. **A layout transition is not a state transition.** One view hierarchy; state hoisted above the size-class branch; navigation depth, scroll, selection, editor contents and playback survive fold / Split View resizes (`references/layout-size-classes-safe-area.md` §State survives the fold).

## Decision tree

| Request looks like… | Do |
|---|---|
| "Is this app ready for iPhone Duo / the foldable?", "audit", "what breaks on Duo" | Delegate: `Agent(subagent_type: "iphone-duo:iphone-duo-audit", prompt: "Repo root: <absolute repo path>. Checklist: <this skill's base directory>/references/audit-checklist.md. Scratch dir: <path>. Write the report to <path>. <scope hints>")` — the base directory is printed at the top when this skill loads. Read-only, returns a severity-ranked report. Then fix in Apple's order (§Migration order) using the reference each finding points to. |
| Fix layout, `UIScreen.main`, orientation/idiom checks, cached widths, safe area, windows, scene lifecycle | `references/layout-size-classes-safe-area.md` |
| Toolbar / navigation bar / tab bar / sidebar on Duo, overflow, badges, custom bar views | `references/bars-and-toolbars.md` |
| Fold, two columns, split/overlay, "the camera covers my button", grid columns | `references/arrangements-and-reserved-regions.md` |
| Hinge angle, "second screen", two windows, Split View behavior, teleprompter / accessory display | `references/hinge-scenes-camera.md` §Hinge / §Scenes |
| Camera app: front cameras, preview mirrored/rotated wrong, which camera faces the user | `references/hinge-scenes-camera.md` §Camera |
| How to test, simulator, Device Hub, Xcode 27.1, "does the SDK have X" | `references/testing-and-sources.md` |
| Display facts, size classes per pose, timeline, App Store screenshots, what is unverified | `references/device-and-platform.md` |
| New screen from scratch | Build size-class-first with standard containers (layout reference), then the bars reference for its toolbar. |

Do not run the grep audit inline in the main context — that is what the agent is for. The agent reads the checklist itself; passing the path only saves it a search. Installed as the `iphone-duo` plugin, the agent type is scoped — `iphone-duo:iphone-duo-audit` — and `${CLAUDE_PLUGIN_ROOT}` resolves inside both files. Copied by hand into `~/.claude/agents/` instead, it is plain `iphone-duo-audit`. If `Agent` reports the type is not found, the agent file was added after the session started — new agents appear with a delay of a few minutes (skills appear immediately): retry on the next turn, restart the session, or as a one-off pass the agent file's body verbatim as the prompt of a `general-purpose` agent. Hosts without subagents (Cursor, Codex): run `references/audit-checklist.md` by hand in a fresh session.

## Migration order (Apple, 13 steps — full text in `references/audit-checklist.md`)

1. Rebuild with the iOS 27.1 SDK. 2. Remove `UIScreen.main`. 3. Orientation → size classes. 4. Idiom → size classes. 5. UIScene lifecycle. 6. Safe area / margins per edge, test in Split View. 7. Remove fixed widths and breakpoints. 8. Audit bars (container bars, order, `axisBehavior`, badges, priorities, overflow). 9. Audit centered layouts (containers → `ArrangementView` → `reservedRegions`). 10. Split View + multiple scenes (scene-request errors). 11. Camera (virtual front camera vs direction coordinator; rotation coordinator + disable compensation). 12. `UIRequiresFullScreen` decision. 13. Run Xcode 27.1's App Resizability skill.

Mnemonic: Resizability → Size classes → Standard containers → Safe areas → Reserved regions → Arrangements → Hinge (effects only).

Classify every change by tier and finish Tier 1 before proposing Tier 2/3: **Tier 1 universal** (steps 2–7, any SDK — size classes, `UIScreen.main`, scene lifecycle, safe area, standard containers, the adaptive toolbox) · **Tier 2 Duo-aware** (steps 8–9, iOS 27.1 — bar axis/priority, reserved regions, arrangements) · **Tier 3 Duo-exclusive** (steps 10–11 plus hinge effects and scene accessories — product decisions).

## Writing code against new APIs

- Copy names **exactly** as they appear in the references, with their status. For PROSE / "verify" symbols run the SDK grep in `references/testing-and-sources.md` §Verify symbols first; if the SDK is < 27.1, do not write the symbol — leave `// TODO:` and report it under "Pending iOS 27.1 SDK".
- Never use CAPTION-only spellings: `UITraitToolbarVerticalEdge`, `toolbarCompressionBehavior`, `toolbarOverflowMenu`, `AVCaptureDeviceCoordinator`, `.axis(` (correct: `.axes(`), `UIWindowSceneActivation` (correct: `UIWindowScene.ActivationAction`).
- Gate with `if #available(iOS 27.1, *)` when the deployment target is lower. Pieces that already exist need lower gates: `ToolbarOverflowMenu`, `visibilityPriority`, `.topBarPinnedTrailing`, `defaultTabBarPlacement`, `isTabViewSidebarAvailable`, `.sceneAccessory` (iOS 27.0); `additionalOverflowItems`, `pinnedTrailingGroup` (iOS 16); `UIWindowScene.ActivationAction` (iOS 15); `isCameraSensorOrientationCompensationEnabled`, `dynamicAspectRatio`, badges, concentricity (iOS 26).
- SwiftUI `defaultTabBarPlacement(.sidebar)` is iOS 27.0 (verified); on iOS 18–26 use `defaultAdaptableTabBarPlacement(.sidebar)`.
- Fixes follow the host project's own conventions (its `CLAUDE.md` / style rules) and introduce no new `UIScreen.main`, force unwraps or `fatalError`. Remember that SPM packages do not see the app target's compile-time flags — `#available` works everywhere, `#if` flags may not.

## Verifying

Before Xcode 27.1: run the toolchain gate; build for an iPad simulator on iOS 27.0 (regular × regular) and an iPhone on 27.0 (compact — plus the TN3187 launch check with the 27.0 SDK); width-parameterized render tests at 466 / 626 / 313 pt (derived); confirm no code reads `UIScreen.main`. With Xcode 27.1: Device Hub poses (closed portrait/landscape, open flat, book, table, tent), Split View via home-indicator drag, PiP stacking, scene accessory on/off. One screenshot is not verification — cover several geometries and a mid-session fold. Details: `references/testing-and-sources.md`.

## Freshness

On first use after **2026-09-20**, check: developer.apple.com/iphone-duo/ (Xcode 27.1 beta out?), `documentation/UIKit/preparing-your-app-for-iphone-duo` (was 404), `documentation/updates/{swiftui,uikit}`, Xcode 27.1 release notes; then run the SDK symbol grep and update status tags in `references/`. Record the Duo `simctl` device-type id once it exists.

## References

| File | Read when |
|---|---|
| `references/device-and-platform.md` | Display/size-class facts, SDK tiers, Split View, `UIRequiresFullScreen`, timeline, App Store, **unverified** list, tech-talk map |
| `references/audit-checklist.md` | Running or interpreting the readiness audit: 23 grep categories, severities, tiered report template, Apple's 13 steps |
| `references/layout-size-classes-safe-area.md` | Size classes, replacing `UIScreen.main`, static width caches, state continuity, scene lifecycle, windows, safe area, concentricity, sidebar + adaptive toolbox (`ViewThatFits`, `AnyLayout`, adaptive grids), per-screen checklist, fixed widths, HIG do/don't |
| `references/bars-and-toolbars.md` | Vertical bars: opt-in, order, axis behavior, badges, edge detection, compression, overflow, priority, opt-out — all 111462 code |
| `references/arrangements-and-reserved-regions.md` | Reserved regions, displacement, `ArrangementView` / `UIArrangementViewController`, split vs overlay, anti-patterns — all 111463 code |
| `references/hinge-scenes-camera.md` | `onHingeChange`, multiple scenes, scene accessories, virtual front camera, direction coordinator, rotation — 111464 / 111465 code |
| `references/testing-and-sources.md` | Toolchain gate, Device Hub, local proxies, SDK symbol verification, Xcode MCP, freshness, source URLs |
