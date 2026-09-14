# Layout on iPhone Duo — size classes, geometry, safe area, windows

Status tags: **VERBATIM** (Apple Code section) · **PROSE** (Apple chapter text / HIG) · **EXISTING(iOS xx)** (pre-Duo API; versions marked "verified" were read from the iOS 26.5 SDK). Anything else → verify in the iOS 27.1 SDK (`testing-and-sources.md` §Verify symbols).

Order of work (Apple, 111461): size classes → no `UIScreen.main` → standard containers → safe area per edge → fixed widths out → only then reserved regions / arrangements (`arrangements-and-reserved-regions.md`).

## Size classes are the only layout signal

| Pose | Horizontal | Vertical |
|---|---|---|
| Closed, portrait | compact | regular |
| Closed, landscape | compact | compact |
| Open (any pose, any orientation) | **regular** | **regular** |
| Split View on the inner display | compact (each half) | regular |

The inner display is regular × regular **on an iPhone**, and it does not honor `supportedInterfaceOrientations`. Idiom (`.phone`), orientation and device model tell you nothing about the space you have.

```swift
// 111461 2:59 — Read size classes                                   VERBATIM
// SwiftUI
@Environment(\.horizontalSizeClass)
private var horizontalSizeClass

@Environment(\.verticalSizeClass)
private var verticalSizeClass

// UIKit
traitCollection.horizontalSizeClass
traitCollection.verticalSizeClass
```

Rules:
- Branch on `horizontalSizeClass == .regular` to add hierarchy (second column, sidebar) — never to pick a "phone" or "tablet" layout by name.
- **No pose flags.** Do not introduce `isDuo`, `isFolded`, `isBookPose`, `isInnerDisplay`, `isFoldable` or a device-model switch. Each is a hidden `UIScreen.main`.
- Replace width buckets (`if width < 350 … else if width > 400`) with size classes plus intrinsic layout (`ViewThatFits`, `containerRelativeFrame`, Auto Layout priorities). Buckets tuned for 375–430 pt phones misfire at ~313 pt (Split View half) and ~626 pt (inner display, derived).
- Replace `userInterfaceIdiom == .pad` layout branches with `horizontalSizeClass == .regular`. Keep idiom only for non-layout concerns (analytics, feature flags).
- Open ≠ regular-only: every regular layout must fall back to a compact one (a Split View half) without losing state — design the whole range ~313 → 466 → 626 pt (derived), not two endpoints.

## Replace `UIScreen.main`

111461: "ambiguous and will be deprecated in a future release." Two displays, one `main`.

| Old | New | Status |
|---|---|---|
| `UIScreen.main.scale` | `traitCollection.displayScale` (view / view controller / window) | VERBATIM |
| `UIScreen.main` (the screen object) | `window?.windowScene?.screen` | VERBATIM |
| `UIScreen.main.bounds` for layout | `view.bounds`, the superview's bounds, or `windowScene.effectiveGeometry.coordinateSpace.bounds` | EXISTING(iOS 16) for `effectiveGeometry` |
| `UIScreen.main.bounds` for a new window | `UIWindow(windowScene:)` — the window takes the scene's size | EXISTING(iOS 13) |
| `UIScreen.main.traitCollection` | the view's own `traitCollection`; in SwiftUI, the environment | EXISTING |
| `UIScreen.main.bounds.width` in SwiftUI | `GeometryReader` / `onGeometryChange` / `containerRelativeFrame` — the container, not the device | EXISTING(iOS 17 for `containerRelativeFrame`) |

```swift
// 111461 4:16 — Access the screen from the window scene             VERBATIM
// Avoid referencing the main screen on a two-display device.
// Access the screen dynamically from the window scene instead.
let screen = window?.windowScene?.screen
```

```swift
// 111461 9:25 — Replace main screen references                      VERBATIM
func updateThumbnail(from image: UIImage) {
    // Before
    let screenScale = UIScreen.main.scale

    // After
    let screenScale = traitCollection.displayScale
    // ...
}
```

Scale may differ when the app moves between displays (both panels are @3x today — do not assume). Invalidate caches through trait registration — EXISTING(iOS 17), named in WWDC26 278 (PROSE):

```swift
registerForTraitChanges([UITraitDisplayScale.self]) { (self: Self, _: UITraitCollection) in
    self.invalidateRasterizedThumbnails()
}
```

Observe scene geometry changes with `UIWindowSceneDelegate.windowScene(_:didUpdateEffectiveGeometry:)` (EXISTING(iOS 16)); SwiftUI views receive new geometry automatically.

### Static width cache — the most common latent bug

```swift
// Anti-pattern: captured once at launch, never updated on open/close/Split View
enum ScreenWidthBucket {
    static var screenWidth: CGFloat = UIScreen.main.bounds.width
    static var current: ScreenWidthBucket { screenWidth < 350 ? .small : screenWidth > 400 ? .large : .medium }
}
```

Every consumer of such a value is wrong after the first fold. Fix: delete the cache; consumers read their own container width (`view.bounds`, `GeometryReader`) or size class at layout time. Do not "fix" it by re-reading `UIScreen.main` on each access — still the wrong screen under multiple scenes.

### State survives the fold

A layout transition must not become an application-state transition. Opening, closing or dragging a Split View divider re-evaluates size classes repeatedly; anything whose identity is keyed on them is rebuilt from scratch.

```swift
// Anti-pattern: two roots, two sets of state — every fold resets scroll, selection and drafts
if horizontalSizeClass == .regular { WideRoot() } else { CompactRoot() }

// Fix: one hierarchy, state above the layout decision, only the container changes
struct EditorScreen: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var draft = Draft()                       // hoisted — survives the switch
    var body: some View {
        let layout = sizeClass == .regular ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
        layout { EditorPane(draft: $draft); InspectorPane(draft: $draft) }
    }
}
```

UIKit: never rebuild the view-controller tree in `traitCollectionDidChange` / `viewWillTransition`; let `UISplitViewController` collapse and expand, keep models outside view controllers. Must survive a mid-session resize: navigation depth, scroll offset, text-field contents, selection, playback position, unsaved work.

## Windows and scenes

### Scene lifecycle is mandatory (TN3187) — BLOCKER

Built with the iOS 27 SDK, an app without a scene manifest and `UIWindowSceneDelegate` does not launch: `Application failed to launch: UIScene life cycle is required for apps built with this SDK.` (`_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`). This is the standard iOS 13 migration, nothing Duo-specific — EXISTING(iOS 13):

1. `Info.plist` → `UIApplicationSceneManifest` → `UISceneConfigurations` → `UIWindowSceneSessionRoleApplication` → one configuration with `UISceneDelegateClassName` = `$(PRODUCT_MODULE_NAME).SceneDelegate`. Keep `UIApplicationSupportsMultipleScenes` at `false` until multi-window is a product decision.
2. Move window creation from `application(_:didFinishLaunchingWithOptions:)` to `scene(_:willConnectTo:options:)`:

   ```swift
   final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
       var window: UIWindow?

       func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
           guard let windowScene = scene as? UIWindowScene else { return }
           let window = UIWindow(windowScene: windowScene)
           window.rootViewController = RootBuilder.make()
           self.window = window
           window.makeKeyAndVisible()
       }
   }
   ```
3. Move URL / user-activity / shortcut handling to the scene delegate (`scene(_:openURLContexts:)`, `connectionOptions.urlContexts`, `windowScene(_:performActionFor:completionHandler:)`); `applicationDidBecomeActive` → `sceneDidBecomeActive`, etc.
4. Every other `UIWindow` in the app (alerts, hints, feedback overlays, developer menus) must become `UIWindow(windowScene:)`, using the scene of the view that triggers it.

### Detached windows

`UIWindow(frame: UIScreen.main.bounds)` and `UIWindow()` are sized once and belong to no scene: wrong size after open/close; may appear on the wrong display or in the wrong app instance once there are multiple scenes. Template:

```swift
guard let scene = presentingView.window?.windowScene else { return }
let overlay = UIWindow(windowScene: scene)
overlay.windowLevel = .alert
overlay.rootViewController = HintViewController()
overlay.makeKeyAndVisible()
```

### Global window lookup

`UIApplication.shared.windows`, `.keyWindow`, `connectedScenes.first`, `windows.first` pick an arbitrary scene once there are several. Start from the owning view (`view.window?.windowScene`) or pass the scene explicitly. Requesting new scenes → `hinge-scenes-camera.md` §Scenes.

## Safe area and layout margins — per edge

111461 (PROSE): "Safe areas and layout margins are often asymmetric on iPhone Duo, so handle each side independently and test in Split View." Standard bars lay out **outside** the safe area and avoid the status bar and cameras automatically. With a vertical bar on one edge and Split View on the other, `left != right` is the normal case.

```swift
// 111461 6:52 — Align foreground content to the safe area           VERBATIM
// UIKit
foreground.frame = view.bounds.inset(by: view.safeAreaInsets)
```

```swift
// 111461 7:07 — Let background content extend past the safe area   VERBATIM
// SwiftUI
.ignoresSafeArea()

// UIKit
backgroundView.frame = view.bounds
```

```swift
// 111461 7:30 — Handle asymmetric safe area insets                  VERBATIM
// Avoid assuming insets on opposite sides are equal
let width = view.bounds.width - view.safeAreaInsets.left * 2

// Handle each side independently
let width = view.bounds.inset(by: view.safeAreaInsets).width
```

Rules:
- Interactive foreground inside the safe area; artwork/background past it.
- Auto Layout: pin to `safeAreaLayoutGuide` / `layoutMarginsGuide` per edge; never mirror one inset to the other side.
- SwiftUI: rely on default safe-area behavior; `GeometryProxy.safeAreaInsets` when you must compute (HIG, PROSE). `.ignoresSafeArea()` only on backgrounds.
- Outer display: most content needs an offset — the safe area provides it. Immersive non-scrolling interfaces (Calculator) may center on the full display; mixing is fine (full-bleed background, inset scrolling content) — 111466 (PROSE).

## Screen corners — concentricity (EXISTING(iOS 26))

```swift
// 111461 4:30 — Match the screen corners with Concentricity         VERBATIM
// SwiftUI
ConcentricRectangle()
    .fill(Color.green)
    .padding(8.0)
    .ignoresSafeArea()

// UIKit
// UICornerConfiguration
```

Use these instead of hard-coded corner radii for edge-hugging cards — the two displays have different corner geometry.

## Standard containers adapt for free

`NavigationSplitView`, `NavigationStack`, `TabView`, `List`, `ScrollView` / `UISplitViewController`, `UINavigationController`, `UITabBarController` — "columns collapse when closed and tile or overlay when open" (111461, PROSE). Sheets, popovers, context menus, alerts reposition around reserved regions too. Prefer them over custom two-column layouts; custom → `arrangements-and-reserved-regions.md`.

Sidebar on the inner display:

```swift
// 111461 5:44 — Show a sidebar on the inner display                 VERBATIM
// SwiftUI
TabView { … }
    .defaultTabBarPlacement(.sidebar)

// UIKit
tabBarController.sidebar.preferredPlacement = .sidebar
```

Version check (iOS 27.0 SDK, verified): `defaultTabBarPlacement(_: AdaptableTabBarPlacement)` is `@available(anyAppleOS 27.0)` — the talk's spelling is right and it ships in iOS 27.0; on iOS 18–26 use `.defaultAdaptableTabBarPlacement(.sidebar)`. UIKit `tabBarController.sidebar` is iOS 18, `sidebar.preferredPlacement` is `API_AVAILABLE(ios(27.0))`. Companions: `.tabViewStyle(.sidebarAdaptable)` and `@Environment(\.tabBarPlacement)` (iOS 18), `@Environment(\.isTabViewSidebarAvailable)` (iOS 27.0).

### Adaptive toolbox — EXISTING, versions verified in the iOS 27.0 SDK

Tier 1 tools: they work on every Apple platform and window size and need no Duo SDK. Reach for them before any 27.1 API.

| Intent | SwiftUI | UIKit | Since (iOS) |
|---|---|---|---|
| collection → selection → detail | `NavigationSplitView` | `UISplitViewController` | 16 / 8 |
| tabs become a sidebar in regular width | `.tabViewStyle(.sidebarAdaptable)`, read `@Environment(\.tabBarPlacement)`; on Duo `defaultTabBarPlacement(.sidebar)` + `@Environment(\.isTabViewSidebarAvailable)` | `tabBarController.sidebar.preferredPlacement = .sidebar` | 18 / 18 / 27.0 / 27.0 · UIKit 27.0 |
| "which arrangement fits?" | `ViewThatFits(in: .horizontal) { HStack { … }; VStack { … } }` | `UIStackView.axis` switched on `horizontalSizeClass` | 16 |
| same children, different arrangement, identity kept | `AnyLayout(HStackLayout())` / `AnyLayout(VStackLayout())` chosen from the size class (SwiftUICore) | `UIStackView.axis` | 16 |
| repeated cards / media | `GridItem(.adaptive(minimum:maximum:))` — see the column-count note | `UICollectionViewCompositionalLayout` with fractional widths | 14 / 13 |
| size relative to the container, not the device | `containerRelativeFrame(_:count:span:spacing:)`, `onGeometryChange(for:of:action:)` | `view.bounds`, `readableContentGuide` | 17 / 16–18 · 9 |
| readable text width | `.frame(maxWidth: 600–700)` — a design choice, Apple publishes no Duo number | `readableContentGuide` — the system's own width | — / 9 |

Replace → with:
- `isDuo ? WideDashboard() : Dashboard()` → one `Dashboard()` whose layout reads its container.
- `if width > 700 { HStack { A; B } } else { VStack { A; B } }` → `ViewThatFits`, or `AnyLayout` when A/B carry state.
- `let columns = isDuo ? 3 : 1` → adaptive columns (note below).
- `if UIDevice.current.userInterfaceIdiom == .pad` → `horizontalSizeClass == .regular`.

Column count: never hard-code it (breaks at ~313 and ~626 pt). Compact width: let `.adaptive(minimum:maximum:)` decide. Regular width: `.adaptive` cannot promise the **even** count the HIG asks for — compute `n = max(2, Int(width / minItem) / 2 * 2)` in `onGeometryChange` and use `Array(repeating: GridItem(.flexible()), count: n)`; on 27.1 apply the parity rule only where a fold can appear (`reservedRegions(kind: .division, options: .includeInactive)` non-empty).

## Fixed widths and device literals

- `.frame(width: 320)` / `widthAnchor.constraint(equalToConstant: 340)` clip in a ~313 pt Split View half and float in a ~626 pt inner display. Use `maxWidth:` caps, `containerRelativeFrame`, or size-class-driven columns.
- Coefficients "tuned for 393/430 pt" in coordinate-conversion or scaling helpers are hidden device assumptions — express them relative to the actual container.
- Games: pick portrait or landscape, fill the display as the pose changes, keep text and control sizes consistent, **prefer aspect-ratio changes over letterboxing/pillarboxing**, add artwork in padding areas if needed (HIG).

## Per-screen checklist (UIKit + SwiftUI)

1. Works across a continuous range of widths (~313 → 466 → 626 pt, derived), not at two devices?
2. Navigation switched by hand between a "phone" and a "tablet" tree? → `NavigationSplitView` / adaptive `TabView` / `UISplitViewController`.
3. Fixed widths, width literals, `UIScreen.main`, idiom or orientation branches? → §Size classes, §Replace `UIScreen.main`.
4. Does the regular-width layout only stretch? → add hierarchy (sidebar, detail, inspector, more columns); cap readable text.
5. Could important interactive or semantic content sit on the fold? → keep it out of the division region; scrolling content may cross.
6. Two related views rearranged by hand? → `ViewThatFits` / `AnyLayout`; only if they must follow the division region or go side by side when folded → `ArrangementView` (27.1, `arrangements-and-reserved-regions.md`).
7. Custom toolbar or tab bar? → container bars (`bars-and-toolbars.md`).
8. Does state survive a resize mid-session (navigation, scroll, selection, text, playback)? → §State survives the fold.
9. Any hinge-angle or "second display" logic? → hinge only for physical interaction; outer display only via `CameraCaptureAccessory` (`hinge-scenes-camera.md`).

## HIG summary — do / don't (designing-for-iphone-duo)

Five best practices: (1) build to resize — size classes, layout margins, safe area, no fixed widths, support Split View; (2) same functionality and hierarchy on both displays, the inner display shows **additional** levels (Mail: list *or* message closed, both open); (3) functionality never depends on pose; (4) follow the system's vertical control layout — "core pattern of iPhone Duo"; (5) games playable in every pose.

**Do:** standard components · even number of grid columns · controls near the content they affect · handle each safe-area edge · "move only what's necessary for visibility, favor small adjustments over rearrangement, prevent controls from disappearing or shifting dramatically" · use extra width for hierarchy (List + Detail, Editor + Inspector, Player + Queue, tabs → sidebar) — never a 300 pt form stretched to 900 pt; cap readable text width.

**Don't:** custom layout per pose · `UIScreen.main` · orientation for layout · `left == right` insets · content or controls spanning the fold ("a photo spread across a book's spine" — tech talk 111463 1:29; the HIG page says the folding region "divides the inner display into multiple usable regions") · text-only bar buttons · manual fixed spacers in bars · letterbox a game that could change aspect ratio.

**Not published:** any Duo-specific typography, tap-target or spacing numbers. Do not invent them.
