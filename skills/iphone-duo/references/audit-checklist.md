# iPhone Duo readiness audit — grep checklist and report template

Read by the shared `audit-workflow.md`, used in Claude Code and Codex (the only place the grep set
lives — do not duplicate it elsewhere). Also usable by hand.

## Ground rules

- **`grep`, not `rg`** — assume `rg` is absent. On macOS this is **BSD grep**: use `-E` with plain `|` for alternation. `\|` inside `-E` matches nothing and silently returns 0 hits. `\b`, `\s`, `\w` work.
- Declare the helpers **in every Bash call** (shell functions do not survive between calls). `G` scans Swift, `GM` scans Objective-C — run the `GM` lines only when the repo has `.m`/`.h` files:

  ```bash
  G()  { grep -rnE "$1" --include='*.swift' --exclude='R.generated.swift' --exclude-dir=Pods --exclude-dir=.build . ; }
  GM() { grep -rnE "$1" --include='*.m' --include='*.h' --exclude-dir=Pods --exclude-dir=.build . ; }
  ```

  `R.generated.swift` is R.swift output; add your own generated files and vendored third-party directories to `--exclude` / `--exclude-dir`, or report hits inside them with a "vendored" tag (the fix is an upstream update, not an edit). Interface Builder files (`*.xib`, `*.storyboard`) are grepped directly where a category says so.

- Run from the repo root. Exit code 1 = no matches (fine); exit 2 = bad regex or path — fix before reporting.
- Tests, UI tests and previews are counted on a **separate line**, never as severity: append `| grep -vE 'Tests/|UITests/|Preview'` for production counts. `#Preview` bodies inside production files are not caught by the file-name filter — read the context.
- Write raw output to a scratch file once and count from the file; never re-run a category to "double check".
- Collapse identical patterns into one finding with N sites (e.g. `6× UIWindow(frame: UIScreen.main.bounds)`).
- Exact counts. Never "about", "several", "many".

## Toolchain gate (run first, report verbatim)

```bash
xcodebuild -version | head -1; xcode-select -p; xcrun --sdk iphoneos --show-sdk-version
ls /Applications | grep -i xcode
```

**Run the toolchain gate first** (`testing-and-sources.md` §Toolchain gate) and report its result as a warning at the top. Required: **Xcode 27.2 RC or later** with the iOS 27.2 simulator runtimes; Xcode 27.1 is unsupported — say so and ask for 27.2 RC. The gate probes the SDK for `UIHingeInteraction.h` / `UIViewReservedRegion.h` before it checks the version — Xcode 27.2 beta 1 shipped two days before 27.1 beta 1 with no Duo APIs (27.2 RC has them), so a numeric test alone is not reliable. No Duo SDK → every new-API recommendation (reserved regions, `ArrangementView`, hinge, vertical-bar API, dual cameras, scene accessories) goes into the report's **Pending iOS 27.1 SDK** section, not into fixes; the safe part (resizability, `UIScreen.main`, orientation/idiom, safe area, standard containers, scene lifecycle) is actionable on any SDK. Duo SDK present → drop the Pending section. Present but not active → name the Xcode and hand over `DEVELOPER_DIR=…`.

## Severity

| Level | Meaning |
|---|---|
| BLOCKER | App will not launch or cannot resize at all when built with the iOS 27 SDK |
| HIGH | Layout is wrong on the inner display or in Split View for most screens (stale geometry, no size-class adaptation, custom bars) |
| MEDIUM | Wrong on some screens, or a product decision the team must make (`UIRequiresFullScreen`, idiom checks) |
| LOW | Cosmetic or localized, or needs manual confirmation |
| INFO | Facts that shape the fix plan, no defect by themselves |

## Categories

**Regex behavior** notes below record how each grep behaved on a real, large UIKit + SwiftUI codebase: false-positive rates, cases the pattern misses, and where zero hits is itself the answer. They calibrate the regex — they are not expected counts for your repo.

### 1 · UIScene lifecycle — BLOCKER (TN3187)

```bash
grep -rl UIApplicationSceneManifest --include='*.plist' .
G '@UIApplicationMain|^@main'
G 'UIWindowSceneDelegate|UISceneDelegate'
```

No scene manifest **and** no scene delegate on an app target = the app fails to launch when built with the iOS 27 SDK (`UIScene life cycle is required for apps built with this SDK`). `@main` also matches widget/extension bundles — judge app targets only. Fix → `layout-size-classes-safe-area.md` §Scene lifecycle. Regex behavior: read the three greps together — `@main` matching while both the plist grep and the delegate grep return 0 is exactly the BLOCKER, not a failed search.

### 2 · `UIScreen.main` — HIGH

```bash
G 'UIScreen\.main'
for s in bounds scale traitCollection; do echo "$s $(G "UIScreen\.main\.$s" | wc -l)"; done
GM '\[UIScreen mainScreen\]'
```

Ambiguous on a two-display device, "will be deprecated". `.bounds` → scene/view geometry; `.scale` → `traitCollection.displayScale`; `.traitCollection` → the view's own traits. Objective-C `[UIScreen mainScreen]` is the same finding. Fix → `layout-size-classes-safe-area.md` §Replace UIScreen.main. Regex behavior: near-zero false positives, every hit is a real call. Vendored and third-party sources match too — check the path before filing.

### 3 · Cached screen width — HIGH

```bash
G '^ {0,4}(private |fileprivate |public )?(static )?(let|var) [^=]*=\s*UIScreen\.main'
```

A `static`/stored property captured at launch never updates when the device opens, closes or enters Split View. Indentation ≤ 4 filters out method-local lets. Fix → `layout-size-classes-safe-area.md` §Static width cache. Regex behavior: low volume and precise; the indentation bound is what keeps method-local lets out.

### 4 · Width breakpoints — HIGH

```bash
G '(\.width|screenWidth|Width)\s*(<|>|<=|>=|==)\s*[0-9]{3}'
```

Buckets like `< 350` / `> 400` were designed for phone widths; the inner display (669 pt) and Split View (~334 pt) fall outside them. Follow up: grep the bucket type's call sites (e.g. `G 'YourWidthBucket\.current'`) to size the blast radius; also check `IBInspectable` per-bucket constraint extensions. Fix → `layout-size-classes-safe-area.md` §Size classes. Regex behavior: few declarations, many call sites — the blast radius comes from the follow-up grep, not from this one.

### 5 · User-interface idiom — MEDIUM

```bash
G 'userInterfaceIdiom|isIPad\b|== \.pad|case \.pad'
GM 'userInterfaceIdiom|UI_USER_INTERFACE_IDIOM'
```

111461 2:34 — the best app layouts "avoid making assumptions about display sizes or device capabilities based on user interface idioms". The inner display is regular × regular **on a `.phone` idiom**. Each hit that drives layout (not analytics) → size classes where iPad and the other iPhones come out unchanged; otherwise the existing iPad branch stays and the Duo path goes behind the hinge gate (owner's rule 14). Fix → `layout-size-classes-safe-area.md` §Size classes. Regex behavior: hits mix layout branches with analytics, feature flags and asset naming — only the layout-driving ones are findings.

### 6 · Orientation for layout — MEDIUM

```bash
G 'UIDevice\.current\.orientation|\.isLandscape|\.isPortrait|interfaceOrientation|statusBarOrientation|supportedInterfaceOrientations|UIDeviceOrientation'
```

The inner display ignores `supportedInterfaceOrientations`; orientation is a preference. Apple's "Three steps" page names `UIDevice.current.orientation`, `statusBarOrientation` and `interfaceOrientation` "including `windowScene.effectiveGeometry.interfaceOrientation`" and says to "remove any layout logic that depends on them" — compare the width and height of the space you have instead. Layout branches on orientation → MEDIUM; `supportedInterfaceOrientations` declarations alone → INFO. Regex behavior: 0 hits is a normal result.

### 7 · Symmetric safe-area math — LOW / manual

```bash
G 'safeAreaInsets\.(left|right|leading|trailing)\s*\*\s*2'
G 'safeAreaInsets|layoutMargins'      # then read every hit
```

`left == right` is false on Duo (vertical bar on one edge, Split View on the other). Report the second grep's hits under **Manual review**. Fix → `layout-size-classes-safe-area.md` §Safe area. Regex behavior: the `* 2` pattern rarely fires; the broad second grep is the one that returns material for manual review.

### 8a · Standalone bars — HIGH (appearance proxies: INFO)

```bash
G '\b(UIToolbar|UINavigationBar|UITabBar)\(|class \w+ *: *(UIToolbar|UINavigationBar|UITabBar)\b'
GM '\[(UIToolbar|UINavigationBar|UITabBar) alloc\]'
grep -rnE '<(navigationBar|tabBar|toolbar)\b' --include='*.xib' --include='*.storyboard' --exclude-dir=Pods . | grep -v 'key="'
G '(UIToolbar|UINavigationBar|UITabBar)\.appearance'       # INFO — styling of system bars, not a standalone bar
```

Content of a standalone `UIToolbar`/`UINavigationBar`/`UITabBar` — created in code, subclassed, or dragged into a plain view in Interface Builder — "isn't considered" for vertical bars. In IB a bar with `key="navigationBar"` / `key="tabBar"` / `key="toolbar"` belongs to its `UINavigationController` / `UITabBarController` (system bar, fine); one without `key=` sits in a view = standalone. `.appearance()` proxies style the **system** bars and are fine — report them as INFO and check that `scrollEdgeAppearance` / background assumptions still hold for vertical bars (no scroll-edge effect by default; background only with Reduce Transparency). Fix → `bars-and-toolbars.md` §Opt in. Regex behavior: the `key=` filter does the real work — controller-owned bars dominate the raw IB hits and are all fine; appearance-proxy lines are INFO, never a standalone bar.

### 8b · Custom bar views — HIGH

```bash
G '(class|struct)\s+\w*(NavigationBar|Navbar|NavBar|TabBar|Toolbar)\w*\s*:' | grep -vE 'Coordinator|Model|Mock|Controller:|ToolbarContent'
G '\w*(NavBar|NavigationBar)\w*Controller\b' | grep -E 'class '     # controllers the filter above drops
```

Hand-built navigation/tab bars stay horizontal on Duo, eat the shorter outer display and get no reserved-region avoidance. `ToolbarContent` conformers are system toolbar content (fine). Fix → `bars-and-toolbars.md` §Opt in. Regex behavior: ~50 % of raw hits are coordinators, models and mocks the name filter misses — read each one. Blast radius via IB: `grep -rnoE 'customClass="[^"]*(NavigationBar|NavBar|Navbar|TabBar|Toolbar)[^"]*"' --include='*.xib' --include='*.storyboard' .`

### 8c · Hidden system navigation bar — HIGH (symptom of 8b)

```bash
G 'setNavigationBarHidden\(true|isNavigationBarHidden = true|navigationBarHidden\(true'
```

Count confirms how many screens run on a custom bar. Report the number next to 8b, not as a separate finding.

### 9 · Detached `UIWindow` — HIGH

```bash
G 'UIWindow\(' | grep -vE 'Tests/|UITests/'
GM '\[\[UIWindow alloc\] init'
```

`UIWindow(frame: UIScreen.main.bounds)` and `UIWindow()` (ObjC: `[[UIWindow alloc] initWithFrame:…]`) are not attached to a scene: wrong size after open/close, wrong display in multi-scene. `UIWindow(windowScene:)` is correct — list it as the in-repo template. Fix → `layout-size-classes-safe-area.md` §Windows. Regex behavior: hits split between the two broken forms and the correct `windowScene:` one — classify each; the correct one is the in-repo template to point fixes at.

### 10 · Size-class adaptation present? — HIGH when 0

```bash
G 'horizontalSizeClass|verticalSizeClass'
```

0 hits in a codebase with layout code = finding **"no size-class adaptation"**: nothing changes when the inner display becomes regular × regular. Fix → `layout-size-classes-safe-area.md` §Size classes. Regex behavior: 0 hits is the finding here, not an empty search.

### 11 · Change hooks — INFO

```bash
for p in viewWillTransition traitCollectionDidChange registerForTraitChanges onGeometryChange GeometryReader containerRelativeFrame effectiveGeometry; do echo "$p $(G "$p" | wc -l)"; done
```

Shows whether the app has *any* place to react to a resize. `registerForTraitChanges` used only for appearance/dark mode does not count as geometry handling — read the hits. Neither do `onAppear` / `viewDidLoad` / `viewWillAppear`: opening or closing the device keeps the same views and view controllers and does not call them again (lab 287 41:25), so geometry read only there is stale after the first fold. Regex behavior: `GeometryReader` usually dominates the counts while the real resize hooks stay at 0 — a high total is not coverage.

### 12 · Info.plist and project settings — MEDIUM

```bash
for f in */Info.plist; do echo "== $f"; /usr/libexec/PlistBuddy -c 'Print :UIRequiresFullScreen' -c 'Print :UIRequiresFullScreenIgnoredStartingWithVersion' -c 'Print :UISupportedInterfaceOrientations' -c 'Print :UIApplicationSupportsMultipleScenes' -c 'Print :UILaunchScreen' -c 'Print :UILaunchStoryboardName' "$f" 2>&1 | tr '\n' ' '; echo; done
grep -oE 'TARGETED_DEVICE_FAMILY = [^;]+;|IPHONEOS_DEPLOYMENT_TARGET = [^;]+;|INFOPLIST_KEY_UILaunch[A-Za-z_]+ = [^;]+;|INFOPLIST_KEY_UIRequiresFullScreen = [^;]+;' *.xcodeproj/project.pbxproj | sort | uniq -c
```

- `UIRequiresFullScreen = true` → **MEDIUM "product decision"**: discrete resizing (closed/open), outer-display orientation lock honored; it does not keep the app out of multitasking. Do not recommend deleting it silently — present both options (`device-and-platform.md` §UIRequiresFullScreen), and say that Apple calls the key deprecated and "will be ignored in a future release" (TN3192). `UIRequiresFullScreenIgnoredStartingWithVersion` set → INFO, the team has already planned its removal.
- **No launch screen** — neither `UILaunchScreen` nor `UILaunchStoryboardName` in the plist, nor an `INFOPLIST_KEY_UILaunch…` build setting → **HIGH**: "Starting in iOS 27 and iPadOS 27, a launch screen is required for App Store submission" (TN3192, TN3208).
- Portrait-only `UISupportedInterfaceOrientations` → INFO: ignored on the inner display anyway.
- `UIApplicationSupportsMultipleScenes` absent → INFO (multi-window is opt-in; the Duo link is inferred, not Apple-stated).
- `TARGETED_DEVICE_FAMILY = 1` (iPhone-only) → INFO: the app has never seen regular × regular.
- Extension/widget plists have none of these keys — skip them. **No `Info.plist` found → stop and say so.**

Regex behavior: a multi-target project prints one line per target — expect repeats, and judge each app target separately.

### 13 · Bar items without title + image — LOW / manual

```bash
G 'UIBarButtonItem\('
G 'ToolbarItem\('
```

Read the bodies. Flag `ToolbarItem { Button("Text") }` / `Text(...)` without `Label`/`systemImage`, and `UIBarButtonItem(title:)` without an image: text-only items stay in the horizontal bar and consume space; the title is still needed for overflow menus. Fix → `bars-and-toolbars.md` §Prepare toolbar content. Regex behavior: both greps return every bar item — only the bodies without an image are findings.

### 14 · Camera — N/A when 0

```bash
G 'AVCaptureDevice|AVCaptureSession|AVCaptureVideoPreviewLayer|RotationCoordinator'
```

0 → write "Camera: not applicable (no capture code)" and skip the section. `import AVFoundation` alone is usually audio. Otherwise → `hinge-scenes-camera.md` §Camera. Regex behavior: 0 hits is a normal result.

### 15 · Fixed SwiftUI frames ≥ 300 pt — LOW

```bash
G '\.frame\((width|maxWidth|minWidth):\s*[3-9][0-9]{2}' | grep -vE 'Tests/|Preview'
```

A fixed `width: 320` inside a ~334 pt Split View pane clips. `maxWidth:` is usually fine (cap, not floor) — report separately. Check for `#Preview` context in production files. Fix → `layout-size-classes-safe-area.md` §Fixed widths. Regex behavior: `#Preview` bodies inside production files survive the path filter and are a large share of the hits — check the enclosing context.

### 16 · Device-size literals — LOW / manual

```bash
G '\b(375|390|393|402|430)\b' | grep -vE 'Tests/|Preview|UITests'
G '(bounds|frame|size|nativeBounds)\.(height|width)\s*(==|!=)\s*[0-9]{3,4}|\b(667|736|812|844|852|874|896|926|932|956)\b' | grep -vE 'Tests/|Preview|UITests'
```

The second line is Apple's own example — "Comparisons such as `bounds.height == 844` or a list of known iPhone sizes won't match iPhone Duo" (Three steps page). An equality against a device height is a finding on sight; bare height numbers need reading.

As a regex this is ~100 % false positives (ids, data, comments). Its value is finding **width-interpolation formulas** tuned to specific devices (coefficients "for 393/430" in comments). Report under Manual review with a one-line note. Regex behavior: ~100 % false positives; the one shape worth finding is a helper with device-tuned coefficients.

### 17 · Global window lookup — HIGH

```bash
G 'UIApplication\.shared\.windows|\.keyWindow|connectedScenes\.first|windows\.first' | grep -vE 'Tests/|UITests/'
G 'connectedScenes' | grep -vE 'Tests/|UITests/'      # then read each chain — `.compactMap {…}.first` usually spans several lines
```

With multiple scenes `first` is an arbitrary scene; presenting from it can land on the other display or another app instance. UI actions must start from the owning view's `window?.windowScene`. The first grep only sees single-line chains; the second lists every `connectedScenes` start — read the following lines for `.first` / `.first(where:)`. Skip commented-out lines. Fix → `layout-size-classes-safe-area.md` §Windows. Regex behavior: the single-line regex misses multi-line `.first(where:)` chains — use the second grep's `connectedScenes` starts and read the lines that follow. Commented-out code matches too.

### 18 · Scene requests without error handling — MEDIUM

```bash
G 'requestSceneSessionActivation|activateSceneSession|UIWindowScene\.ActivationAction|openWindow'
```

New windows cannot be created on the outer display. Every request needs an error path; prefer `UIWindowScene.ActivationAction`, which hides itself when unavailable. 0 hits → N/A. Fix → `hinge-scenes-camera.md` §Scenes. Regex behavior: 0 hits is a normal result.

### 19 · Hinge angle used for layout — HIGH / manual

```bash
G 'onHingeChange|UIHingeInteraction'
```

Read the bodies: angle → `frame`/`offset`/`padding`/`width` = anti-pattern. Hinge data is for effects; layout uses arrangements and reserved regions. 0 hits → N/A. Fix → `hinge-scenes-camera.md` §Hinge. Regex behavior: 0 hits until an app adopts the iOS 27.1 hinge API.

### 20 · Pose flags — HIGH

```bash
G '\bis(IPhone)?(Duo|Folded|Unfolded|Foldable|InnerDisplay|OuterDisplay|BookPose|TablePose|TentPose)\b|\bdeviceIsUnfolded\b'
```

Any production hit is a hidden `UIScreen.main`: a boolean that freezes one pose into the layout. Replace with size classes / container geometry (hard rule 3). Fix → `layout-size-classes-safe-area.md` §Size classes. Regex behavior: 0 hits in an app that has not started Duo work; any hit is a defect.

### 21 · Hard-coded grid columns and sidebar widths — LOW / manual

```bash
G 'Array\(repeating:\s*GridItem|GridItem\(\.fixed\(|GridItem\(.*GridItem\(|\b(numberOfColumns|columnCount|itemsPerRow)\s*(=|:)\s*[0-9]+'
G 'GridItem\(\.(flexible|fixed)' | grep -vE 'Tests/|Preview' | cut -d: -f1 | sort | uniq -c | sort -rn    # ≥ 2 in one file = a literal column count spread over lines
G 'navigationSplitViewColumnWidth\(\s*[0-9]|preferred(Primary|Supplementary)ColumnWidth(Fraction)?\s*=|\b(sidebarWidth|menuWidth|drawerWidth|panelWidth)\s*(=|:)\s*[0-9]'
G 'GridItem\(\.adaptive' | wc -l      # INFO: adaptive grids already in use
```

A literal column count gives the same 2 columns at ~334 pt (cramped) and 669 pt (sparse); a fixed sidebar width ignores Split View. `navigationSplitViewColumnWidth(min:ideal:max:)` is fine. Read the hits for the regular-width count and its parity (HIG: even). Fix → `layout-size-classes-safe-area.md` §Adaptive toolbox (column-count note), `arrangements-and-reserved-regions.md` §Migration recipe step 6. Regex behavior: the single-line regex misses column lists spread over several lines — the per-file count (≥ 2 `GridItem` in one file) is what catches them.

### 22 · Duplicated compact / expanded hierarchies — MEDIUM / manual

```bash
G '\b[A-Z]\w*(Compact|Regular|Expanded|Wide|Narrow|Phone|Pad|Tablet)(View|ViewController|Screen|Layout|Content)\b' | grep -oE '\b[A-Z]\w*(Compact|Regular|Expanded|Wide|Narrow|Phone|Pad|Tablet)(View|ViewController|Screen|Layout|Content)\b' | sort | uniq -c | sort -rn
```

Then read every `horizontalSizeClass == .regular` / idiom branch from categories 5 and 10: two different root views or view controllers, each owning its own state, = the fold resets navigation, scroll, selection and drafts. ActivityKit "compact" presentations and thin wrappers around shared content are not findings. Fix → `layout-size-classes-safe-area.md` §State survives the fold. Regex behavior: ~50 % false positives — ActivityKit compact presentations match the name pattern without being a duplicated hierarchy.

### 23 · Coverage signals — INFO

```bash
echo "readableContentGuide $(G 'readableContentGuide' | wc -l)  numeric caps $(G 'frame\((maxWidth|width):\s*[0-9]' | grep -vE 'Tests/|Preview' | wc -l)  infinity $(G 'maxWidth:\s*\.infinity' | grep -vE 'Tests/|Preview' | wc -l)"
grep -rnoE 'ViewImageConfig\.\w+|width:\s*[0-9]{3}' --include='*.swift' --exclude-dir=Pods . | grep -E 'Tests/|Snapshot' | grep -oE '(\.\w+|[0-9]{3})$' | sort | uniq -c | sort -rn
G '\b(334|466|669)\b' | grep -E 'Tests/' | wc -l      # 0 = the Duo widths are in no render test yet
G '\b(313|626)\b' | grep -E 'Tests/' | wc -l          # > 0 = tests at the pre-1.3.2 derived widths: move them to 334 / 669
```

Facts for the fix plan, not defects: no `readableContentGuide` and no numeric width caps in an app with long copy → "no readable-width caps anywhere"; render/snapshot tests at ≤ 2 distinct widths → "layouts rendered at ≤ 2 widths"; 0 hits for 334/466/669 → "Duo widths untested". Whether wide text actually stretches is **manual review only** (onboarding, settings, legal, articles). Regex behavior: `readableContentGuide` at 0 next to a high `maxWidth: .infinity` count is the signal to report; in every codebase audited so far the Duo widths (334/466/669, or 313/626 from older guidance) appeared in no test.

### 24 · Size-class overrides — HIGH

```bash
G 'traitOverrides\.(horizontalSizeClass|verticalSizeClass)|setOverrideTraitCollection|overrideTraitCollection|environment\(\\\.(horizontal|vertical)SizeClass'
GM 'setOverrideTraitCollection'
```

A forced size class keeps the fold from reaching that subtree — the DTS summary of the labs, on whether an override blocks the system's updates as the device folds: "Yes, it would very likely interfere." A screen-level override → HIGH; an override inside a preview or a test → not a finding. Fix → remove it and read the real trait (`layout-size-classes-safe-area.md` §Size classes). Regex behavior: 0 hits is the normal result; the SwiftUI `.environment(\.horizontalSizeClass, …)` form is the common one.

### 25 · Full-bleed media set to fill — LOW / manual

```bash
G '\.scaleAspectFill|contentMode:\s*\.fill|\.scaledToFill\(\)|resizeAspectFill' | grep -vE 'Tests/|Preview'
```

Apple's "Three steps" page: "Hero images and video set to `.scaleAspectFill` or `.aspectRatio(contentMode: .fill)` can lose important content on wider displays." Only hero images, banners and video that fill a screen-wide container are candidates — thumbnails and avatars are not. Report under Manual review with file names. Fix → `layout-size-classes-safe-area.md` §Fixed widths (fit vs fill, focal point), behind the hinge gate when the change would alter other iPhones. Regex behavior: high hit counts, mostly small images — read the container.

### 26 · Motion and heading relative to the display — LOW

```bash
G 'headingOrientation|startDeviceMotionUpdates|deviceMotion\b|CMMotionManager|CLHeading'
```

`CLLocationManager.headingOrientation` is deprecated in iOS 27.0 in favor of `headingBody`; device motion should set `deviceMotionBody` to the view so attitude follows the display the UI is on. `headingOrientation` hit → LOW; other hits → INFO (compass, level, AR, games). Fix → `hinge-scenes-camera.md` §Motion and heading. 0 hits → N/A. Regex behavior: 0 hits in most apps.

### Bonus · `UIDevice.current.*` inventory — INFO

```bash
G 'UIDevice\.current\.' | grep -oE 'UIDevice\.current\.\w+' | sort | uniq -c
```

`userInterfaceIdiom` → category 5; `orientation` → category 6; `systemVersion` / `identifierForVendor` → ignore.

## Report template

```markdown
# iPhone Duo readiness audit — <app> (<git rev>, <date>)

## Summary
<verdict in 2–3 sentences: launches? resizes? adapts?> · Toolchain: <xcodebuild -version / SDK> · Swift files scanned: N (production N, tests N)

## Blockers
- **<category>** — N sites — `file:line` (up to 5) — why it breaks on Duo — Fix → `references/<file>.md` §<section>

## High
…same shape…

## Medium
… (`UIRequiresFullScreen` goes here as "product decision" with both options)

## Low
…

## Info (facts that shape the plan, no defect: categories 8a appearance proxies, 11 change hooks, 12 project settings, 23 coverage signals, 26 sensor use, `UIDevice.current` inventory)
…

## Opportunities (tiered — finish Tier 1 before proposing Tier 2/3)
- Tier 1 universal: `ViewThatFits` / `AnyLayout` for hand-rearranged pairs; adaptive, even grid columns; readable-width caps; regular-width screens that only stretch → expose hierarchy (manual — list files); a sidebar on the inner display via `defaultTabBarPlacement(.sidebar)` / `sidebar.preferredPlacement` (iOS 27.0). Each one that would change iPad or another iPhone goes behind the hinge gate (owner's rule 14), which needs the iOS 27.1 SDK
- Tier 2 Duo-aware (iOS 27.1): `HStack`/`VStack` two-pane candidates → `ArrangementView` behind the hinge gate, since it also splits on iPad and a Pro Max (list files); reserved regions for custom-positioned controls
- Tier 3 Duo-exclusive (product decision): scene accessories if the app has a camera; hinge-driven effects

## Pending iOS 27.1 SDK
- items that cannot be written on the current SDK (reserved regions, arrangements, bar axis API, hinge, dual cameras) — one line each, with the file that will need them

## Manual review (no severity)
- category 7 safe-area hits · category 13 bar items · category 15 `#Preview` context · category 16 size formulas · category 21 column parity · category 22 branch reading · category 25 fill-mode hero media · regular-width branches written for iPad only · regular-width screens that only stretch

## Not applicable
- camera (0 capture code) · scene requests (0) · hinge (0) …

## Next steps (Apple's order)
1. … (see below, keep only the applicable steps)
```

## Apple's migration order (13 steps, 111461 + WWDC26 278)

1. Rebuild with the iOS 27.1 SDK (27.0 only extends left of the status bar; 27.1 reaches the edge and gives vertical bars).
2. Remove `UIScreen.main` — `.scale` → `traitCollection.displayScale`; screen → `window?.windowScene?.screen`; bounds → scene/view bounds; register for `UITraitDisplayScale` changes and invalidate caches.
3. Orientation checks → size classes.
4. Idiom checks → size classes, where iPad and the other iPhones come out unchanged; otherwise keep the iPad branch and gate the Duo path (owner's rule 14).
5. Adopt the UIScene lifecycle (TN3187) — required to launch.
6. Safe area / layout margins per edge; test in Split View.
7. Remove fixed widths and width breakpoints.
8. Audit bars: container-provided bars, order (back/close top, prominent next), `axisBehavior`, fewer text-only items, badges, visibility priorities, overflow into the system menu.
9. Audit centered layouts: two-column / displacement; standard containers first, `ArrangementView` for custom split/overlay, reserved regions for the highest-priority manually laid-out controls.
10. Split View + multiple scenes: handle scene-request errors; new windows are inner-display only.
11. Camera: virtual front camera vs direction coordinator; rotation coordinator then disable sensor orientation compensation; preview gravity/aspect.
12. `UIRequiresFullScreen`: don't add it "for Duo"; keep only as a games escape hatch — product decision. Apple calls the key deprecated (TN3192).
13. Run Xcode's **App Resizability** agent skill (the ex-modernization skill, present from 27.1 — use it from Xcode 27.2 RC or later; with Xcode 27.1 it "supports SwiftUI and iPhone Duo" per the DTS summary; export it for other tools with `xcrun agent skills export --output-dir <path>`). Apple's "Three steps" page: "The skill finds most issues, but not all of them." 

Shorter mnemonic (external review, consistent with Apple): Resizability → Size classes → Standard containers → Safe areas → Reserved regions → Arrangements → Hinge (effects only).
