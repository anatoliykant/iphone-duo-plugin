# Layout on iPhone Duo — size classes, geometry, safe area, windows

Status tags: **VERBATIM** (Apple Code section or developer article) · **PROSE** (Apple chapter text / HIG / article) · **EXISTING(iOS xx)** (pre-Duo API) · **SDK(27.1)** (confirmed in the released iOS 27.1 SDK, re-verified 2026-10-28 together with Xcode 27.2 RC). Anything else → verify (`testing-and-sources.md` §Verify symbols).

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
- **No pose flags.** Do not introduce `isDuo`, `isFolded`, `isBookPose`, `isInnerDisplay`, `isFoldable` or a device-model switch. Each is a hidden `UIScreen.main`. The one new gate allowed is hinge presence, and only to keep a change off iPad and other iPhones (§Scope); an existing iPad idiom branch may stay for the same reason.
- Replace width buckets (`if width < 350 … else if width > 400`) with size classes plus intrinsic layout (`ViewThatFits`, `containerRelativeFrame`, Auto Layout priorities). Buckets tuned for 375–430 pt phones misfire at ~313 pt (Split View half) and ~626 pt (inner display, derived).
- Replace `userInterfaceIdiom == .pad` layout branches with size classes or available space — where iPad and the other iPhones come out unchanged. Where they would not (a Pro Max in landscape has a regular width), leave the existing iPad branch and give the Duo its path through the hinge gate (§Scope). Keep idiom only for that and for non-layout concerns (analytics, feature flags).
- **Regular width is not iPad.** Apple's "Three steps" page: "Code that shows an iPad-only layout when `horizontalSizeClass == .regular`, or that assumes iPhone is always compact, will now run that layout on iPhone too." With iPhone Duo and resizable iPhone Mirroring "an iPhone app can have any combination of size classes", and "On the inner display, your app should look like a natural extension of its iPad layout." Read every regular-width branch for iPad-only assumptions (popover anchors, iPad-only features, copy that says "iPad"). Under §Scope the iPad layout reaches the Duo through the hinge gate: the existing iPad branch stays as it was, and a second condition, `deviceHasHinge && horizontalSizeClass == .regular`, lets the Duo's inner display use the same layout — so a Pro Max in landscape keeps its current one.
- **Never override size classes.** Forcing `horizontalSizeClass` through `traitOverrides`, `setOverrideTraitCollection` or `.environment(\.horizontalSizeClass, …)` keeps the fold from reaching that subtree — the DTS summary of the labs: "Yes, it would very likely interfere. Use automatic trait tracking … rather than overriding them." 
- Open ≠ regular-only: every regular layout must fall back to a compact one (a Split View half) without losing state — design the whole range ~313 → 466 → 626 pt (derived), not two endpoints.

## Scope — Duo changes stay on Duo

**Owner's rule (2026-10-20), applies to every change made for iPhone Duo.** It deliberately goes further than Apple, whose forum answer is: "There is no API to detect whether your app is running on iPhone Duo. … An iPhone Duo app is still an iPhone app, and other than avoiding placing interactive UI on reserved regions, the recommendation would be to not introduce behavior that is specific to the device" ([847775](https://developer.apple.com/forums/thread/847775)). The rule is about keeping iPad and the other iPhones unchanged, not about inventing Duo-only features — use the gate only where a lineup-wide change would otherwise reach them. The iPad app and every other iPhone — an iPhone 17 Pro Max, say — keep exactly the layout and behavior they had. Nothing made for Duo reaches them in any form: a split added to a sheet for Duo does not appear on iPad at all, not even as a variant.

Why this needs a gate of its own:

- **Size classes do not mean Duo.** iPad is regular × regular too, and a Pro Max in landscape has a regular width — a `horizontalSizeClass == .regular` branch lands on both.
- **Many Duo APIs act on every device.** `ArrangementView` renders two columns wherever there is room (lab 286 56:21), bar priorities apply to any crowded bar, `navigationBarMinimization` changes other iPhones, and giving a text-only bar item an icon changes how every iPhone draws it (horizontal bars prefer the icon).
- What the system does only on Duo needs no gate: vertical bars and their behaviors (`toolbarVerticalBehavior`, `toolbarVerticalCompressionBehavior`, `axisBehavior` — "it doesn't mean it will go vertical on other phones", lab 287 31:24), fold avoidance, reserved-region displacement.

Gate a Duo-only change on **hinge presence**. It is a device capability, not a pose: true on iPhone Duo whether open or closed, false on iPad and every other iPhone (111464: "A null hinge means the device doesn't have one"), and false below iOS 27.1, where the API does not exist. Latch it once and never let it flip back — UIKit also reports `nil` when a view leaves a hierarchy that provides hinge updates, during dismissal for instance. Inside the gate, layout still comes from size classes, reserved regions and arrangements; the gate only decides *whether* the Duo change exists.

```swift
// SDK(27.1), typechecked 2026-10-20 at deployment targets 27.1 and 17.0
extension EnvironmentValues {
    @Entry var deviceHasHinge = false
}

struct DetectHinge: ViewModifier {
    @Binding var deviceHasHinge: Bool

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, context in
                if context.hinge != nil { deviceHasHinge = true }   // latch: a device keeps its hinge
            }
        } else {
            content
        }
    }
}

struct RootView: View {
    @State private var deviceHasHinge = false

    var body: some View {
        ContentView()
            .environment(\.deviceHasHinge, deviceHasHinge)
            .modifier(DetectHinge(deviceHasHinge: $deviceHasHinge))
    }
}

struct FilterSheet: View {
    @Environment(\.deviceHasHinge) private var deviceHasHinge

    var body: some View {
        if deviceHasHinge {
            DuoFilterSheet()        // the new split — iPhone Duo only
        } else {
            FilterSheetContent()    // iPad, iPhone 17 Pro Max and every other iPhone: untouched
        }
    }
}
```

```swift
// UIKit — latch once for the whole app from the window; screens read it at their first layout.
// The handler runs with the initial state as soon as the window is in a hierarchy with hinge data.
// SDK(27.1), typechecked 2026-10-28 at deployment targets 27.1 and 17.0, Swift 5 and 6 modes
@MainActor enum HingeGate {
    static private(set) var deviceHasHinge = false

    static func install(on window: UIWindow) {
        guard #available(iOS 27.1, *) else { return }            // no hinge API before 27.1: stays false
        window.addInteraction(UIHingeInteraction { _, update in
            if update.hinge != nil { deviceHasHinge = true }      // latch: a device keeps its hinge
        })
    }
}

// SceneDelegate.scene(_:willConnectTo:options:), right after creating the window:
// HingeGate.install(on: window)

final class FilterSheetViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        if HingeGate.deviceHasHinge { installDuoSplit() } else { installExistingLayout() }
    }
}
```

Measured 2026-10-20 on the iPhone Duo simulator (Xcode 27.1 beta 1, closed): both the `UIHingeInteraction` handler (`status = .closed`, angle 0) and `onHingeChange` (`old = nil`, `new = closed`) fire right after the view appears, about 60 ms after `onAppear`. Apple confirms the SwiftUI side: "This modifier will be called with the initial context when the view reaches a hierarchy that has hinge data" ([847765](https://developer.apple.com/forums/thread/847765)). So the gate starts `false` and flips once at launch — branch at the screen that owns the Duo change (the sheet above), not at the app root, and nothing visible is rebuilt. A screen that is already on screen at launch would see the flip; keep Duo-only changes off the launch screen, or re-read the gate once after the first layout. Because the gate does not change while the device folds, the branch never costs state on a fold (§State survives the fold). The iOS 27.1 simulator runtime supports only iPhone Duo, so in Xcode 27.1 iPad and the other iPhones run 27.0, where the `#available` branch keeps the gate `false`. With Xcode 27.2 RC they run iOS 27.2 (24B114), where the API exists; that a device without a hinge reports `nil` there rests on Apple's word (111464: "A null hinge means the device doesn't have one") and was not measured on an iPad simulator for this release.

- Name the gate after the capability (`deviceHasHinge`), never after a pose or a model — `isDuo`, `isFolded` and friends stay forbidden, and the gate never feeds a frame, offset or column count.
- Tier 1 refactors (`UIScreen.main` → `displayScale`, scene lifecycle, safe-area math) touch every device by nature. They are allowed only when iPad and the other iPhones come out pixel- and flow-identical.
- **Prove it**: snapshot tests if the project has them; otherwise screenshots of every touched screen on an iPad and an iPhone 17 Pro Max simulator, before and after, with a fixed status bar (`xcrun simctl status_bar <udid> override --time 9:41`). Any difference outside Duo is a regression to fix, not a side effect to report.

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

Apple's own list ("Three steps to make your app shine on iPhone Duo", Step 2 "Stop sizing from the main screen"):

- "Replace `UIScreen.main.bounds` with `view.bounds` or `window.bounds`. In SwiftUI, use `GeometryReader` or `onGeometryChange`."
- "**Re-read the size whenever it changes.** Reading the size once at launch or in `viewIsAppearing` isn't enough, because a fold can resize your app in the middle of a session. Do size-dependent layout in `layoutSubviews` or `viewDidLayoutSubviews`, and use `viewWillTransition(to:with:)` for work that needs to run when the size changes."
- "Use `traitCollection.displayScale` in UIKit or `@Environment(\.displayScale)` in SwiftUI."
- "Replace `UIWindow(frame: UIScreen.main.bounds)` with `UIWindow(windowScene:)`."
- "**Don't store a `UIScreen`.** When screen information is needed, access it dynamically with `view.window?.windowScene?.screen`." 

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

UIKit: never rebuild the view-controller tree in `traitCollectionDidChange` / `viewWillTransition`; let `UISplitViewController` collapse and expand, keep models outside view controllers. Adopt **automatic trait tracking** and `registerForTraitChanges(_:handler:)` instead — the article: "Use automatic trait tracking to observe `horizontalSizeClass` and `verticalSizeClass` changes to adapt your interface to different sizes. Don't use `userInterfaceIdiom` or `UIInterfaceOrientation` for layout decisions in your UIKit app." (See "Adapting your app when traits change".) Must survive a mid-session resize: navigation depth, scroll offset, text-field contents, selection, playback position, unsaved work.

Apple names this exact pattern as the thing that breaks on Duo — lab 286 19:27: "one thing that I see SwiftUI apps sometimes do is in a complex size class, they will use one container on one side of an if statement, and then they'll use a different container on the other side of an if statement … oftentimes that if statement is guarded by size class. So if you were doing that, you will see state loss. If you haven't raised everything up." It already bites on iPad; folding just makes it happen constantly. Lab 287 38:57 repeats it for a half-filled form in a `List`: "there's nothing in doing that that is intrinsically going to tear your app down or your view down … However, that will change the size class … a big if statement at the root of your app that is switching on. If compact, if regular, that is going to tear down all the state in your app."

The DTS summary of the labs states the model in one line: "Treat display transitions as size-class and trait changes, not a scene disconnect or app termination; your process stays alive." The keyboard and the editing session survive closing the device (no new scene), text input and scroll position are generally preserved, and AVKit keeps playback and resizes the video itself. Only scenes that really disconnect and reconnect — Split View, multiple windows — need `stateRestorationActivity(for:)` and an `NSUserActivity`.

What the fold does **not** do, lab 287 41:25–42:29: views and view controllers stay the same instances, and `onAppear` / `onDisappear` are not expected to fire again — "you should really be treating this as a adaptive layout resize". So geometry read once in `onAppear`, `viewDidLoad` or `viewWillAppear` goes stale on the first fold; read it in the resize hooks (`onGeometryChange`, `viewWillTransition(to:with:)`, trait registration). The scene phase can change, though: in Split View, closing the device backgrounds the app that was not used most recently (43:56). Apple's forum answer adds both ends ([847838](https://developer.apple.com/forums/thread/847838)): "if your app is in full-screen using the entire open flat inner display, the scene is unaffected by the hinge state change", while with two windows of your app "the most recently active scene window would be remain active when the device closes—the secondary window scene would transition to an inactive state, then backgrounded".

Scroll position in UIKit is already handled — lab 287 55:05, on a `UITextView` reflowing mid-article: "it does actually kind of already baked into UITextView and various other ScrollView based components … as your view resizes, we do actually anchor it to the visible position". Lab 288 32:14 explains it for collection views — `UICollectionView` stores the visible cell's index path and shows the same one after the resize, which is how News keeps the open section when the device opens; a SwiftUI `List` or a `UICollectionView` list behaves the same (35:16). Do not add your own re-anchoring on top.

- **Custom text rendering needs a semantic anchor.** News draws its own article text, so it stores a "text anchor" before the transition and scrolls back to that text position afterwards (lab 288 32:35). "Critically, you can't just keep the same Y offset" — the offset changes as the content reflows (33:45).
- **SwiftUI lazy grids**: the DTS summary says the system preserves the position even when a `LazyVGrid`'s column count changes with the fold, so `scrollPosition(id:)` is "typically" not needed; lab 288 35:39 was less sure about lazy layouts and asked for a Feedback Assistant report with a sample project if the position jumps. Check yours in Device Hub.
- Test it the way Apple suggests (33:24): resize the same screen on iPad — "it's the same instance of your app … the same instance of your scene".

**The column that appears on open needs content.** Lab 287 39:39: Mail shows the message that was open last, but for another app "it might be surprising that we just pick the message that was open last". Never auto-select something that has side effects — 40:39, opening onto an unread conversation would send a read receipt. When there is no natural selection, fill the slot with `ContentUnavailableView` (EXISTING(iOS 17)) until the person picks one (41:01).

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
5. Once-per-process work does not belong in scene callbacks. On Duo, as on iPad, "each user-level window is a scene with its own SceneDelegate", so a second window runs `scene(_:willConnectTo:options:)` and the activation callbacks again — security checks, SDK setup and analytics sessions would repeat. Use the app-level notifications for those: "While the UIApplicationDelegate life cycle callbacks are deprecated in preference to the ones on UISceneDelegate, the associated app life cycle notifications are not, and will remain for any sort of overall app life cycle state considerations" ([847966](https://developer.apple.com/forums/thread/847966)).

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

111461 7:12: "Keep in mind that safe areas are often asymmetric. This is especially true on iPhone Duo." And 8:55: "Align your interactive or visible foreground content to the safe area, while background content may extend past the safe area. Make sure to account for, and test, asymmetrical safe areas and layout margins." Standard bars lay out **outside** the safe area and avoid the status bar and cameras automatically. With a vertical bar on one edge and Split View on the other, `left != right` is the normal case.

Who this catches, from lab 285 54:48: "a lot of phone apps that have been locked to portrait have only worried about top and bottom safe areas … the unsafe areas are on the side often now." And 55:27: "the content insets are also asymmetrical" — read the real values, do not take one side and double it. 55:19 on why it is easy to miss: "often you don't know that you made them … you got it working. And you discover that, oh, we made an assumption."

Lab 288 4:09 puts a number on how new this is: "the first time that apps will be given asymmetric left and right safe area insets as well as Layout margins". News found it the hard way (6:38) — it honored only the vertical-edge safe area, and text ran under the vertical bar until the horizontal insets were fixed. The DTS summary lists what to expect per pose: closed — the bar on the trailing edge (leading in right-to-left languages) gives an asymmetric inset on that side; open in portrait — top and bottom insets; open in landscape and in Split View — leading or trailing insets; partially folded — the fold is a division region, not a safe-area inset.

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
- Scrolling content may run under the vertical bar. Asked whether horizontally scrolling content passing under the open display's vertical tab bar is a bug, Apple: "Yes, this is expected. Don't clip your content manually. The right side of your view will have a safe area inset which will automatically become a content inset on the scroll view, allowing all the content in the scroll view to be reachable" ([847821](https://developer.apple.com/forums/thread/847821)).
- Safe areas do not cover the camera or the fold. For a custom bar or a custom bottom sheet the DTS summary is explicit: "Relying only on standard safeAreaInsets is insufficient for handling dynamic folding regions" — query reserved regions and the bar edge (`arrangements-and-reserved-regions.md`, `bars-and-toolbars.md`).

### Default layout margins are zero on iOS 27.1+

iOS 27.2 release notes (UIKit, 186294594): "On iOS 27.1 and later, the default layout margins for a `UIView` are zero. A view controller continues to provide its view with `systemMinimumLayoutMargins`, which vary depending on the presentation context. To inherit these margins in a subview of the view controller's view, set its `preservesSuperviewLayoutMargins` property to `true`."

A custom `UIView` that pinned content to `layoutMarginsGuide` and relied on the old 8 pt default now draws edge to edge. This is an OS change, not a Duo change — it reaches every iPhone on iOS 27.1 and later, so fix it as Tier 1 and screenshot iPad and the other iPhones before and after (§Scope).


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

`NavigationSplitView`, `NavigationStack`, `TabView`, `List`, `ScrollView` / `UISplitViewController`, `UINavigationController`, `UITabBarController` — 111461 5:19: "When iPhone Duo is closed, columns will collapse to single-stack navigation. When open, columns will appear both tiled and as overlays." Sheets, popovers, context menus, alerts reposition around reserved regions too. Prefer them over custom two-column layouts; custom → `arrangements-and-reserved-regions.md`.

### Sidebar

Sidebar on the inner display:

```swift
// 111461 5:44 — Show a sidebar on the inner display                 VERBATIM
// SwiftUI
TabView { … }
    .defaultTabBarPlacement(.sidebar)

// UIKit
tabBarController.sidebar.preferredPlacement = .sidebar
```

Tab bar or sidebar on the open Duo is a hierarchy decision, not an automatic upgrade — lab 287 49:42–54:24, on why the TV app keeps its tab bar on the inner display while it uses a sidebar on iPad. A sidebar pays off when there are many destinations or categories to jump between; a tab bar when there are a few main areas and people spend their time browsing the content inside them (TV: "you're really looking at the shows"). Duo adds consistency: the app constantly switches between two sizes, and "there is something to be said for having like a consistent navigation model where you're playing into the muscle memory" (53:40). A sidebar works best when it represents a view that also exists closed — the top level of Settings.

Lab 288 9:11–17:13 adds Apple's own split: Music, TV and Podcasts keep a **vertical tab bar** on the open Duo although they use split views on iPad; Mail keeps its split view; most system apps that use a tab bar closed keep it open, on the right. The exceptions are deliberate: **Phone** puts a split view *inside* a `TabView` on the inner display ("not the most common pattern, but it's not that it's not allowed"), and **Health** shows a sidebar in open landscape because surfacing its many categories was worth "breaking the continuity". Weather, which never supported landscape, got a new two-column layout for the Duo instead of an arrangement. "Think about that data flow and that navigation … before the visual design" (15:43).

`.sidebarAdaptable` alone does not give a sidebar on iPhone Duo — the DTS summary: "In general, iOS displays a bottom tab bar rather than adapting into a sidebar the way iPadOS does. You can opt into a sidebar on the inner display of iPhone Duo by setting the default tab bar placement to sidebar in SwiftUI, or the preferred placement to sidebar in UIKit." Under §Scope those two calls are Duo-only by construction only if nothing else changes for iPad — check the iPad sidebar before and after.

Nothing needs to *suppress* the sidebar on an iPhone: "you do not need to actively "suppress" the representation by forcing mode = .tabBar or sidebar.preferredPlacement = .tabBar", and "there's no need to set sidebar.preferredLayout = .tile at all, even on iPad, unless your app requires it" ([847961](https://developer.apple.com/forums/thread/847961)) — such leftovers can be deleted.

Inspectors (DTS summary): `.inspector(isPresented:content:)` shows as a trailing column in regular width and as a sheet in compact width or on the outer display. Inside a `NavigationSplitView` the inspector's bars stay horizontal and it gets no vertical bar of its own. `UIModalPresentationStyle.overCurrentContext` applies only in regular width, with `adaptivePresentationStyle(for:traitCollection:)` substituting in compact width — the same on a Duo open flat with one app.

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
| rows that should become columns when wide | `LazyVGrid` / `Grid`, or a `List` beside a detail | `UICollectionView` with a compositional layout — `UITableView` cannot: "This is not a behavior that is supported by UITableView" ([847873](https://developer.apple.com/forums/thread/847873)) | 14–16 / 13 |

Replace → with:
- `isDuo ? WideDashboard() : Dashboard()` → one `Dashboard()` whose layout reads its container. If the wide layout must stay off iPad and other iPhones (§Scope — the default), the condition becomes `deviceHasHinge`, never a model or pose flag.
- `if width > 700 { HStack { A; B } } else { VStack { A; B } }` → `ViewThatFits`, or `AnyLayout` when A/B carry state.
- `let columns = isDuo ? 3 : 1` → adaptive columns (note below).
- `if UIDevice.current.userInterfaceIdiom == .pad` → `horizontalSizeClass == .regular` — only where iPad and the other iPhones look the same afterwards; otherwise §Scope.

Column count: never hard-code it (breaks at ~313 and ~626 pt). Compact width: let `.adaptive(minimum:maximum:)` decide. Regular width: `.adaptive` cannot promise the **even** count the HIG asks for — compute `n = max(2, Int(width / minItem) / 2 * 2)` in `onGeometryChange` and use `Array(repeating: GridItem(.flexible()), count: n)`; on 27.1 apply the parity rule only where a fold can appear (`reservedRegions(kind: .division, options: .includeInactive)` non-empty).

## Fixed widths and device literals

- `.frame(width: 320)` / `widthAnchor.constraint(equalToConstant: 340)` clip in a ~313 pt Split View half and float in a ~626 pt inner display. Use `maxWidth:` caps, `containerRelativeFrame`, or size-class-driven columns.
- Coefficients "tuned for 393/430 pt" in coordinate-conversion or scaling helpers are hidden device assumptions — express them relative to the actual container.
- **Exact device sizes.** Apple's "Three steps" page: "Comparisons such as `bounds.height == 844` or a list of known iPhone sizes won't match iPhone Duo." Heights are as dangerous as widths.
- **Full-bleed media.** Same page: "Hero images and video set to `.scaleAspectFill` or `.aspectRatio(contentMode: .fill)` can lose important content on wider displays. Use the current size classes or aspect ratio to choose between fill and fit, or set a focal point." On a Pro Max the same image may look right today — switch fill to fit only where the crop actually loses content, and keep that switch behind the hinge gate when it would change other iPhones (§Scope).
- Horizontal carousels sized as the device width minus padding grow into huge cards on the open display. Lab 287 27:06: cap each item, for example by aspect ratio, so a wider screen shows more items instead of bigger ones.
- Games: pick portrait or landscape, fill the display as the pose changes, keep text and control sizes consistent, **prefer aspect-ratio changes over letterboxing/pillarboxing**, add artwork in padding areas if needed (HIG).

## Three columns on a two-column display

An iPad app with a three-column `NavigationSplitView` / `UISplitViewController` shows **two columns at a time** on the inner display, with the root column reachable as an overlay from a button in the top left; in portrait you get the detail alone and pull the sidebar in over it (lab 285 35:27–35:45). The same construction already applies to a Pro Max in landscape, so this is not a Duo special case — and the system does the work: lab 285 36:56, "if you do use those UI components … then you get some nice features, like when you go like partially open, like a book, then the split view kind of automatically resizes and takes up 50/50 of the screen."

`TabView` / `UITabBarController` can also show its tabs as a sidebar when open and wide (`defaultTabBarPlacement(.sidebar)` / `sidebar.preferredPlacement`) — a different answer to the same width, see §Sidebar.

## Accessibility on a bigger screen

Two things the labs single out:

- **Dynamic Type at the largest sizes finally has room.** Lab 285 29:15: "you're on a bigger screen. So you're going to maybe have users who really rely on dynamic type … especially like, these UIs at the largest accessibility sizes are going to look really good when they open their phone." Adapting to it — `readableContentGuide` and friends — is part of resizability, not a separate task.
- **Reduce Transparency draws an opaque rectangle behind the vertical bar**, slightly narrower than its safe area so it does not butt against content (lab 285 30:20). Turn it on and look at the screen.

VoiceOver runs on both displays at once — a first — so an app that already labels its content correctly needs nothing new (lab 285 30:02).

## Per-screen checklist (UIKit + SwiftUI)

1. Works across a continuous range of widths (~313 → 466 → 626 pt, derived), not at two devices?
2. Navigation switched by hand between a "phone" and a "tablet" tree? → `NavigationSplitView` / adaptive `TabView` / `UISplitViewController`.
3. Fixed widths, width literals, `UIScreen.main`, idiom or orientation branches? → §Size classes, §Replace `UIScreen.main`.
4. Does the regular-width layout only stretch? → add hierarchy (sidebar, detail, inspector, more columns); cap readable text — behind the hinge gate wherever iPad or another iPhone would change (§Scope).
5. Could important interactive or semantic content sit on the fold? → keep it out of the division region; scrolling content may cross.
6. Two related views rearranged by hand? → `ViewThatFits` / `AnyLayout`; only if they must follow the division region or go side by side when folded → `ArrangementView` (27.1, `arrangements-and-reserved-regions.md`).
7. Custom toolbar or tab bar? → container bars (`bars-and-toolbars.md`).
8. Does state survive a resize mid-session (navigation, scroll, selection, text, playback)? Is geometry read only in `onAppear` / `viewWillAppear` / `viewIsAppearing`, which do not fire on a fold? Custom text rendering re-anchored semantically, not by Y offset? → §State survives the fold.
9. Any hinge-angle or "second display" logic? → hinge only for physical interaction; outer display only via `CameraCaptureAccessory` (`hinge-scenes-camera.md`).
10. Size classes overridden anywhere (`traitOverrides`, `setOverrideTraitCollection`, `.environment(\.horizontalSizeClass, …)`)? → remove; the fold cannot reach that subtree (§Size classes).
11. Hero image or video set to fill? Custom views relying on the old 8 pt default margins? → §Fixed widths, §Default layout margins.

## HIG summary — do / don't (designing-for-iphone-duo)

Five best practices: (1) build to resize — size classes, layout margins, safe area, no fixed widths, support Split View; (2) same functionality and hierarchy on both displays, the inner display shows **additional** levels (Mail: list *or* message closed, both open); (3) functionality never depends on pose; (4) follow the system's vertical control layout — "one of the core patterns of iPhone Duo"; (5) games playable in every pose.

**Do:** standard components · even number of grid columns · controls near the content they affect · handle each safe-area edge · "Move only what's necessary to keep elements visible and easy to tap … favor small adjustments over rearrangement" · use extra width for hierarchy (List + Detail, Editor + Inspector, Player + Queue, tabs → sidebar) — never a 300 pt form stretched to 900 pt; cap readable text width.

**Don't:** custom layout per pose · `UIScreen.main` · orientation for layout · `left == right` insets · content or controls spanning the fold (111463 1:44 shows "this photo spread across the two pages", which when folded "no longer reads as one continuous image"; the HIG page says the folding region "divides the inner display into multiple usable regions") · text-only bar buttons · manual fixed spacers in bars · letterbox a game that could change aspect ratio.

**Not published:** any Duo-specific typography, tap-target or spacing numbers. Do not invent them.
