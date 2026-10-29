# Reserved regions and arrangements — laying out around the hinge and cameras

Sources: tech talk 111463 "Strike a pose with adaptive layouts on iPhone Duo" (every code block **VERBATIM** from its Code section), HIG "Dynamic layouts", the developer article "Preparing your app for iPhone Duo", and `documentation/updates/{swiftui,uikit}` September 2026. Everything here is **iOS 27.1 SDK**, and every symbol below was checked against it on 2026-09-21 (Xcode 27.1 beta 1) and re-verified on 2026-10-28 against the released Xcode 27.1 and Xcode 27.2 RC — see the status table.

Spelling notes: the talk prose says "the reservedRegion method" singular while both the code and the SDK write `reservedRegions(kind:…)` — follow the code. The talk's "split ArrangementStyle" is, in the SDK, the protocol **`ArrangementViewStyle`** with `SplitArrangementViewStyle` / `OverlayArrangementViewStyle` / `AutomaticArrangementViewStyle` conforming.

## Concepts

**Reserved regions** — 111463 0:36: "New hardware features also play a role in shaping the available space. These include the hinge and the two cameras across the outer and inner displays. We call these reserved regions … And treat these just like any other areas your layout already adapts to." … "such as the window controls on iPadOS." Two kinds:

| Kind | What | Behavior |
|---|---|---|
| `.division` | the fold | **divides** a larger area into smaller ones; **active only when partially folded**. The talk adds that when flat "it's inactive and has a width of zero", but the Xcode 27.2 RC and 27.1 simulators return the inactive region with the same 40 pt band — test `isActive`, never the width |
| `.occlusion` | the FaceTime (front) camera | **occludes** rather than divides |

Regions are **active or inactive**; queries return active ones by default, `options: .includeInactive` returns the rest. Inactive regions still inform high-level decisions — e.g. **prefer an even number of grid columns** so a later fold divides cleanly. The article restates it: "a reserved region that represents the fold is active when iPhone Duo is partially open, but inactive when it is fully open."

A region value carries more than a frame (SDK 27.1, identical in both frameworks):

| Member | Type | Use |
|---|---|---|
| `frame` | `CGRect` | the region itself, in the proxy's / view's coordinate space |
| `margins` | `EdgeInsets` / `UIEdgeInsets` | the clearance the system wants around it — inset by these rather than butting content against `frame` |
| `kind` | `ReservedRegion.Kind` / `UIView.ReservedRegion.Kind` | `.division` or `.occlusion` |
| `isActive` | `Bool` | false for a region returned only because you passed `.includeInactive` |
| `id` | `ReservedRegion.ID` (opaque) | identify the same region across coordinate spaces, or follow it over time |

The SwiftUI query takes a third argument: `reservedRegions(kind:options:layoutDirectionBehavior:)`, defaulting to `.mirrors`, so frames follow the layout direction unless you ask otherwise. UIKit's is `reservedRegions(kind:options:)`.

The HIG names three regions: outer front camera (always present; grows into the Dynamic Island for Live Activities), inner front camera (under-display, present only while active — UI moves aside when it turns on), folding region (divides the inner display when partially open).

**No numeric hinge width, angle thresholds or inset values are published.** Query — never hard-code. For orientation only, measured 2026-10-29 on the Duo simulator (Xcode 27.2 RC; iOS 27.2 and 27.1 runtimes the same): the division region is a **40 pt band centred on the 669 × 951 pt inner window** — x 455–495 in landscape (book), y 455–495 in portrait (table) — active when folded, inactive when flat.

**Touches over the camera region are not reliable.** The DTS summary of the labs: a custom element that overlaps a hardware-reserved region such as the camera without adopting the reserved-region APIs gets "touch events in that area … suppressed or may not register as expected". Safe-area insets alone do not describe these regions either — the same summary says safe areas are "insufficient for handling dynamic folding regions", and size classes "don't encode the hinge's exact location".

The order Apple recommends reaching for tools in (lab 288 7:21–8:26, "a sliding scale"): standard containers (`NavigationSplitView`, `NavigationStack`, `TabView`) → bar and corner regions for custom controls → `ArrangementView` → reserved regions → the hinge API. Each step down gives more control and more work; stop at the first one that does the job.

**Displacement** — 111463 2:39: it "adjusts the frame of the existing elements based on the available space". Scope from one button to a whole container. Move elements independently when they can adapt alone, together when they work as a unit. **Continuously scrolling content (articles, feeds) should not displace.** Avoid excessive movement. Fold-sensitive content that must never straddle the division region: buttons and input controls, faces and focal image content, text that has to read uninterrupted, QR codes, drag handles, small icons — backgrounds, gradients and scrolling content may cross.

Where content moves (HIG / 111463 4:00):
- folded like a **book** (hinge vertical) → alerts and single controls move to the **trailing** side;
- propped on a **table** (hinge horizontal) → **top** region for content viewed at a distance, **bottom** for interactive controls;
- several regions viable → keep it contextual (near related content).

How Apple's own apps pick the side, lab 287 4:56–7:25:

- Controls mostly avoid **to the right** — "we found that, you know, more people are more likely to hold it kind of that way."
- Small elements tied to a source stay on the source's side: context menus and the text edit menu open on the side the cursor or source view is on, so nothing jumps across the device in your hand.
- The hierarchy often decides already: in a primary/detail layout (left-to-right languages) the primary sits left and the detail right, and each only shifts off the fold. The detail is also, usually, what stays on screen when the device closes — no extra work.
- Seated on a surface, interactive controls go toward the **bottom**: a stable surface to press against, shorter reach, a place to rest the wrist (lab 287 19:54 — the device is "sturdier than you would expect" and does not tip when the top half is tapped). Video apps put the video on top and the controls below; a scrolling-heavy app may simply be used in another pose — do not build for every pose.
- Move as little as possible — 21:42: "we try to avoid having controls move significantly when you go between poses"; move only when the new pose gains enough from it.

Whether to move at all depends on the **scroll axis relative to the hinge** (lab 288 44:54–49:09, Grant on the system apps):

| App, pose | Scrolls | Hinge | What Apple did |
|---|---|---|---|
| Messages, book | vertically | vertical — parallel | bubbles shift off the hinge, otherwise one stays under it however far you scroll |
| App Store Today, book | vertically | parallel | the two grid columns shift slightly so none sits on the fold — an exception, see below |
| Preview / Quick Look PDF, book | switched to horizontal, two pages | perpendicular | flat it scrolls vertically; folded like a book it pages sideways, so anything under the hinge scrolls away |
| Safari, Mail, any list, laptop | vertically | horizontal — perpendicular | nothing moves — the person scrolls content off the fold |
| Music, Podcasts, TV carousels, book | horizontally | perpendicular | nothing moves; items scroll straight through the fold |

Scrollable grids are the general case the other way round: "In general, we don't recommend having grids avoid the division regions, as long as their content is scrollable. Note that there are no traits or safe area insets applied by default by the division region" ([847879](https://developer.apple.com/forums/thread/847879), Frameworks Engineer). If a collection-view section must clear the fold, do it "only … in sections that aren't scrolling orthogonal to the fold's axis, by reading the reserved regions from the collection view and manually adjusting your compositional layout. There is no automatic fold avoidance to UICollectionView or compositional layout at this time" (same answer).

Fixed-position controls that do not scroll still move — minimally, "shifting it, the minimal amount to take those controls out of that reserved region rather than about radically reflowing everything" (47:47).

The system already repositions **action sheets, alerts, menus, popovers** around reserved regions, splits `UISplitViewController` / `NavigationSplitView` columns evenly, and — 111466 9:31 — "nudges interactive elements aside whenever iPhone Duo is partially folded" (fold avoidance). `NavigationStack`, `NavigationSplitView`, `TabView`, `List`, `ScrollView` adapt to the fold without custom code (111463 8:33: "leveraging our own components that adapt to the fold"). Custom code is only for what these do not cover — and that includes the *rows* of a list or collection view: asked whether anything besides `ArrangementView` moves list items off the fold, Apple: "Some built-in container classes do this as well, like UISplitViewController. The more "automatic" API that handles responding to reserved regions for you is ArrangementView" ([847842](https://developer.apple.com/forums/thread/847842)). A tab bar accessory is the app's job too — "You should use the reserved region of the division for this behavior" ([847814](https://developer.apple.com/forums/thread/847814)).

**Sheets** move on their own, and the forum answer says where: "All sheets move to the leading edge when folded, and are presented in the center when the inner display is opened flat" ([847797](https://developer.apple.com/forums/thread/847797), DTS). An explicit `presentationPlacement` / `preferredPlacement` "applies the position of the sheet at all times, not specifically when folded" — to change it only when folded, "use the reserved region API to detect an active division region, then set your placement based on its existence".

## Query reserved regions

SwiftUI: on a `GeometryProxy` — from `GeometryReader` or `onGeometryChange`. UIKit: on `UIView`.

```swift
// 111463 6:46 — Query reserved regions in SwiftUI                    VERBATIM
GeometryReader { proxy in
  let regions = proxy.reservedRegions(
    kind: .division)
}
```

```swift
// 111463 7:03 — Query reserved regions in UIKit                      VERBATIM
let regions = view.reservedRegions(
  kind: .division)

// Query the frame to incorporate it into your own layout
let frames = regions.map(\.frame)
```

```swift
// 111463 7:22 — Include inactive regions                             VERBATIM
GeometryReader { proxy in
  let regions = proxy.reservedRegions(
    kind: .division, options: .includeInactive)

  let frames = regions.map(\.frame)
  // ...
}
```

```swift
// 111463 8:07 — Query occlusion regions                              VERBATIM
GeometryReader { proxy in
  let regions = proxy.reservedRegions(
    kind: .occlusion)

  let frames = regions.map(\.frame)
  // ...
}
```

### Flat and fully open — avoid the middle or not

Either is fine; the question is how big the change gets when the device starts to fold (lab 287 44:59–49:18).

- A natural two-column layout keeps two columns flat, so the partial fold is a small step. Flat does not have to be 50/50 — 45:21: system split views often sit "like a 35, like 65 kind of layout" flat and move toward 50/50 when folded.
- Content that works best full-width uses the full width; no avoidance at all is also legitimate.
- **Scroll perpendicular to the hinge.** Book pose → horizontal scrolling (carousels, PDF pages in Quick Look / Preview); laptop pose → vertical scrolling (a web page). Scrolling parallel to the hinge is harder, because "it's very difficult to reach in and actually perform a scroll right in that hinge area" (47:08). Apple's own carousels do not avoid the hinge; they scroll straight through it (46:05).
- The same content can choose differently per orientation: the App Store's landscape article (hero image left, text right) avoids the fold naturally, while in open portrait the panel's example does not — "if we did, then you would only have half a screen to scroll in" (48:57).
- A layout that is already near 50/50 can pre-avoid the fold with `.includeInactive`, so folding the device changes nothing (48:14).

Frames are in the proxy's / view's coordinate space, and already oriented: to tell a book fold from a laptop fold, "You can see if it is taller than wide or wider than tall" — and there is no layout guide for it, "Reserved Regions is the API to use for manual layout" ([847854](https://developer.apple.com/forums/thread/847854)). In UIKit, query where automatic observation tracking runs — trait-change closures and layout or display updates — so the read repeats when the regions change; a `UIHingeInteraction` update is a fine *trigger* to query again ([847876](https://developer.apple.com/forums/thread/847876)), as long as the frames still come from the regions. Typical uses: keep a manually positioned control (custom bar, floating button) out of the fold or camera; choose 2 vs 3 grid columns; widen spacing around the hinge while preserving outer margins. Apple's priority (111463 17:06): "identify the highest priority manually laid-out controls in your views and consider adopting the ReservedRegions API to implement your own displacement where needed" — not everything.

## Arrangements

111463 10:57: "this function of inputs to outputs is called an arrangement". The inputs are "the horizontal and vertical size class of the view, the aspect ratio of the view's width over its height, and whether there are any active division regions", outputs are "whether I should show the view at all, and if I do show the view, what's its frame?". iOS 27.1 exposes the system's arrangements as a container with a **primary** and a **secondary** child.

```swift
// 111463 11:23 — Add an ArrangementView                              VERBATIM
var body: some View {
  NavigationStack {
    ArrangementView {
      PlayerView()
    } secondary: {
      UpNextView()
    }
  }
}
```

```swift
// 111463 11:26 — Add a UIArrangementViewController                   VERBATIM
let arrangementVC = UIArrangementViewController()
let navController = UINavigationController(rootViewController: arrangementVC)

let playerVC = PlayerViewController()
arrangementVC.setViewController(playerVC, for: .primary)

let upNextVC = UpNextViewController()
arrangementVC.setViewController(upNextVC, for: .secondary)
```

Placement rule: the arrangement is the **root of the navigation container**, never the other way round. Apple's `ArrangementView` documentation names the containers to keep apart: "avoid adding an arrangement view inside another container such as a scroll view, navigation split view, grid, or other container view that lays out other views. Also avoid placing some container views inside an arrangement view, such as a navigation split view or tab view." `UIArrangementViewController` has the same rule for scroll views, split view controllers, collection views and tab view controllers. Measured 2026-10-29: inside a `VStack`, an `ArrangementView` still laid out both panes, but on iPad and on the closed Duo the panes kept the window's size classes and `splitArrangementAxis` was `nil`; as the root of the `NavigationStack` they got the pane's values (§Size classes inside the panes).

### Split arrangement

Divides the bounds between primary and secondary. **Horizontal when wider than tall, vertical when taller than wide.** When folded, the split follows the division region. From the `SplitArrangementViewStyle` documentation: the primary view goes leading in landscape and on top in portrait; "By default, a split arrangement view sizes the primary and secondary views equally when a display has one region"; and "When someone is holding a closed iPhone Duo in landscape orientation, the split arrangement only shows the primary view."

```swift
// 111463 12:00 — Specify the split arrangement style                 VERBATIM
var body: some View {
  NavigationStack {
    ArrangementView {
      PlayerView()
    } secondary: {
      UpNextView()
    }
    .arrangementViewStyle(.split)
  }
}
```

Restrict the axis when one direction never makes sense; if it cannot split along that axis it **shows a single view** — which one is up to you: "ArrangementView is an adaptive container that collapses to displaying only one view, prioritizing the view with higher .layoutPriority, or the primary view by default whenever its split axes cannot be satisfied within the current aspect ratio, pose, or compact size class" ([847800](https://developer.apple.com/forums/thread/847800), DTS). Mark the essential child with `.layoutPriority` and read `splitArrangementAxis` to react to the collapse.

A bar that belongs to one half goes on that child: put `.safeAreaBar(edge: .bottom)` on each child inside the arrangement, not around it ([847790](https://developer.apple.com/forums/thread/847790)).

Arrangements **nest** (lab 288 41:12: "You can nest ArrangementViews for some interesting combinations"). The TV app's video player uses several, configured per orientation: on the outer display it looks like any iPhone; folded like a book the video fills the display and the controls move to one side; folded like a laptop the controls go to the bottom and the video to the top (40:00–41:12). A split arrangement already stacks content vertically in portrait and side by side in landscape (39:15), which covers most orientation-specific layouts without reading the orientation.

```swift
// 111463 12:41 — Restrict the split to one axis                      VERBATIM
var body: some View {
  NavigationStack {
    ArrangementView {
      PlayerView()
    } secondary: {
      UpNextView()
    }
    .arrangementViewStyle(
      .split.axes(.horizontal))
  }
}
```

```swift
// 111463 13:07 — Update the arrangement in UIKit                     VERBATIM
let arrangementVC = UIArrangementViewController()

// ...

arrangementVC.updateArrangement(.split.axes(.horizontal))
```

Spelling: `.axes(...)`, plural, and it takes an `Axis.Set`. CAPTION `axis(` is wrong.

**Sizing the two panes** (SDK 27.1, none of it in the talk). By default the system picks the split; four modifiers on a *child* override it:

| Modifier | Effect |
|---|---|
| `splitArrangementLayoutRatio(_: CGFloat?)` | this view's share of the arrangement |
| `splitArrangementLayoutRatio(minHorizontal:idealHorizontal:maxHorizontal:minVertical:idealVertical:maxVertical:)` | the same as a range, per axis |
| `splitArrangementLayoutSize(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:)` | absolute points instead of a ratio |
| `splitArrangementFixedLayoutSize(horizontal:vertical:)` | keep the view's own ideal size on that axis |

Read the resolved axis from a child with `@Environment(\.splitArrangementAxis)` → `Axis?` — on iOS 27.1 from a view nested *inside* the child, because the child itself reads `nil` there (§Size classes inside the panes). In UIKit the same knobs are `UISplitArrangement.Dimension` (`automatic()`, `intrinsic()`, `fractional(_:)`, `absolute(_:)`) and `UISplitArrangement.DimensionRange`.

Prefer a ratio to absolute points: absolute widths are the thing that breaks in a ~334 pt Split View half.

#### Size classes inside the panes

Each pane gets its own size classes: **the split axis goes compact** — side by side gives a compact width, stacked gives a compact height. A 372 pt pane in the book pose therefore lays out like an iPhone, not like the regular × regular window around it. Measured 2026-10-29 on the simulators (Xcode 27.2 RC; Duo runtime 24B91014, iPad on iOS 27.2 24B114), `ArrangementView` as the root of a `NavigationStack` with a large title; the default style and `.split` gave the same values, and a `UIView` inside a pane reads the same traits:

| Pose | Window | Layout | Each pane (W / H) | Pane sizes (pt) |
|---|---|---|---|---|
| Closed, portrait | 466 × 678, C / R | stacked | C / C | 382 × 281 each (84 pt bar trailing) |
| Closed, landscape | 678 × 466, C / C | primary only | C / C | 594 × 350 |
| Partially open, portrait (table) | 669 × 951, R / R | stacked around the fold | R / C | 669 × 322 above, 669 × 422 below |
| Partially open, landscape (book) | 951 × 669, R / R | side by side around the fold | C / R | 456 and 372 wide (84 pt bar) |
| Open, portrait | 669 × 951, R / R | stacked | R / C | 669 × 392 each |
| Open, landscape | 951 × 669, R / R | side by side | C / R | 434 and 433 wide (84 pt bar) |
| iPad Pro 13-inch (M5), portrait | 1032 × 1376, R / R | stacked | R / C | 1032 × 609 each |

Heights depend on the bars above the arrangement; the widths and the classes are the point.

- Need the window's size classes inside a pane? Read them outside the `ArrangementView` and pass them in.
- **iOS 27.1 bug, fixed in 27.2:** the view passed straight to `ArrangementView` reads the **window's** size classes (C / R closed, R / R open) and gets `splitArrangementAxis == nil`; every view nested inside it reads the pane's values. Wrap each child so the view that reads them is not the top one — `ArrangementView { VStack { PaneView() } } secondary: { VStack { Detail() } }`. Measured on the iOS 27.1 runtime (24A94425) with the same probe; first reported by sarunw.com (2026-10-26). → `testing-and-sources.md` §Known iOS 27.1 bugs.
- **Rule 14:** iPad gets the same treatment — its panes turn regular × compact — so an arrangement added for Duo changes the layouts inside it on iPad too. Keep a Duo-only arrangement behind the hinge gate (`layout-size-classes-safe-area.md` §Scope).

### Overlay arrangement

Stacks the two children — primary above secondary — and moves them **side by side when folded**. Read the z-index to switch between collapsed and expanded content. The HIG says so in words ("otherwise the primary view moves atop the secondary view"), the 111463 sample collapses the *primary* while it is stacked, and the API documentation agrees (checked 2026-10-29): `OverlayArrangementViewStyle` is "A style that layers the primary view over the secondary view", and "In a stacked overlay arrangement, the arrangement view places the primary view above the secondary view in the z-axis." One DTS forum answer says the opposite ("positions the secondary view on top of the primary view in portrait", [847816](https://developer.apple.com/forums/thread/847816)); treat it as the outlier, and still let `overlayArrangementZIndex` / `state(for:)?.zIndex` decide at runtime ("Views with a higher z-index are rendered on top of views with a lower z-index").

The HIG names one capability that still has no spelling: "You can limit which axes a split arrangement uses, and **collapse the secondary view in an overlay arrangement when you don't want it to appear**." `.axes(…)` covers the first half. The collapse half was searched for in the **iOS 27.1 SDK on 2026-09-21 and is not there** — no modifier, no style member, nothing on `ArrangementView`. Until Apple ships one, express "no secondary right now" by not putting the view in the arrangement, or by giving the secondary an empty body. Do not invent a name.

Anchor the overlaid view with `overlayArrangementEdge(_:)`, which takes an optional `HorizontalEdge` or `VerticalEdge` (SDK 27.1).

```swift
// 111463 13:26 — Switch to the overlay arrangement                   VERBATIM
var body: some View {
  NavigationStack {
    ArrangementView {
      UpNextView()
    } secondary: {
      PlayerView()
    }
    .arrangementViewStyle(.overlay)
  }
}
```

```swift
// 111463 14:07 — Respond to the overlay Z index                      VERBATIM
enum UpNextMinimization {
  case collapsed; case expanded
}

struct UpNextView: View {
  @Environment(\.overlayArrangementZIndex)
  private var zIndex: Int

  var body: some View {
    UpNextList(minimization: minimization)
  }

  var minimization: UpNextMinimization {
    zIndex > 0 ? .collapsed : .expanded
  }
}
```

```swift
// 111463 14:21 — Read the Z index in UIKit                           VERBATIM
let arrangementVC = UIArrangementViewController()

// ...

let primaryState = arrangementVC.state(for: .primary)
myModel.minimization = (primaryState?.zIndex ?? 0) > 0
  ? .collapsed : .expanded
```

`zIndex > 0` = this view is stacked **on top** of the other (show the compact form); `0` = side by side or alone (show the full form). UIKit's `UIArrangementViewState` also carries `splitAxis` (`UIAxis`) and `isHidden`, so one read covers z-order, axis and visibility.

Which way the pair separates when the device folds, from the article: "When iPhone Duo is partially open, the overlay arrangement places the primary view in the trailing or bottom part of the display relative to the fold, and the secondary view in the leading or top part."

### Choosing

| Existing code | Arrangement |
|---|---|
| `HStack` / `VStack` with two panes, custom two-column `UIView` layout | `.split` |
| `ZStack`, floating panel over content, mini-player over a list | `.overlay` |
| No existing pattern, clear foreground/background (Accessibility Reader) | `.overlay` |
| Game with touch controls over the gameplay | `.overlay`, controls as **primary** — stacked over the game when flat, the bottom half when the device is seated (lab 287 35:04, "very similar to … AVKit video players"); read `overlayArrangementZIndex` to lay the controls out differently while they overlap. Controls that are not bars stay custom — they do not need to become system vertical bars (56:38) |
| Main + detail where neither may be obscured (Podcasts transcript) | `.split` |
| Two panes already on `ViewThatFits` / `AnyLayout` (EXISTING, iOS 16) | keep them; upgrade to `.split` / `.overlay` (27.1) only when the pair must follow the division region or go side by side when folded |
| Master/detail navigation, sidebar + content | **not an arrangement** — `NavigationSplitView` / `UISplitViewController` |
| Full-screen map with a panel that opens beside it | `.split` — the DTS summary calls `ArrangementView` "the intended container" for it |
| Multi-column data table under a book fold | not an arrangement — query `reservedRegions(kind: .division, …)` and move columns off the division (DTS summary) |

Which child is primary has "no single fixed rule" (DTS summary) — pick by content hierarchy. For a custom layout that crosses the fold, VoiceOver order usually follows the view hierarchy, but you "may need to explicitly define accessibility containers or adjust sort priorities" (same source).

## Anti-patterns

- Navigation container (`NavigationStack`, `NavigationSplitView`, `UINavigationController`) **inside** an `ArrangementView` — navigation goes outside.
- `ArrangementView` inside `List` / `ScrollView` — the article widens this: "Avoid placing an arrangement view inside a navigation split view, list, scroll view, or other container that might cause part of your view to become inaccessible."
- Reimplementing split/overlay with `GeometryReader` + division frames when an arrangement or `NavigationSplitView` already does it. Lab 287 9:01: a split arrangement with a custom column ratio (`splitArrangementLayoutRatio`) "can eliminate things that you might have previously been using a GeometryReader for", on Duo and on other iPhones. A `GeometryReader` that reports an unexpected size after rotation is a bug to file with Feedback Assistant, not to work around.
- Hard-coded fold width / offset ("the hinge is ~N pt") — query regions.
- Per-pose layouts (`if isBookPose { … }`) — inputs are size classes + aspect ratio + regions, and the system computes them.
- Using hinge angle to compute frames — `hinge-scenes-camera.md` §Hinge.
- Displacing scrolling content, or moving elements far / rearranging (HIG: "move only what's necessary").

## Migration recipe for a custom two-pane screen

1. Is it master/detail? → `NavigationSplitView` / `UISplitViewController`, done.
2. Otherwise wrap the two panes in `ArrangementView { primary } secondary: { secondary }` / `UIArrangementViewController`, inside the existing `NavigationStack` / `UINavigationController` — behind the hinge-presence gate, with the existing layout kept for iPad and other iPhones (`layout-size-classes-safe-area.md` §Scope).
3. Pick `.split` (was HStack/VStack) or `.overlay` (was ZStack); restrict `.axes` only if one axis is meaningless.
4. For `.overlay`, drive collapsed/expanded from `overlayArrangementZIndex` / `state(for:)?.zIndex` instead of your own "is minimized" flag.
5. Any remaining manually positioned control that must not sit in the fold → `reservedRegions(kind: .division)`; camera avoidance → `.occlusion`.
6. Grids: even column counts; consider `.includeInactive` to pre-decide columns on the flat inner display. Scrolling regions that cross the fold scroll perpendicular to it (§Flat and fully open).
7. Test book, table and flat poses plus Split View in Device Hub (`testing-and-sources.md`).

## What this buys you elsewhere

An arrangement is not Duo-only. Lab 286 56:21, asked what happens on a normal phone: "It does actually work on our other hardware as well. As long as … the conditions that you've kind of set up the ArrangementView are true on the device that it's running on. So … if you still have space for two columns, it will render as two columns. If you don't, it will kind of move towards a single view, which is exactly what happens when you move between inner and outer display." That is the argument for adopting it instead of hand-rolling `if` statements between `HStack` and `ZStack` — and Apple did: lab 286 56:04, "almost every single app has an ArrangementView." It is also why a new arrangement changes the iPad app and a Pro Max in landscape the moment it ships — the DTS summary is explicit that arrangement views "are available on all iOS devices running 27.1 and later" and "work on any iPhone or iPad". Under the owner's scope rule (SKILL.md hard rule 14) an arrangement added for Duo sits behind the hinge-presence gate, and every other device keeps its existing layout (`layout-size-classes-safe-area.md` §Scope).

Where Apple used it: AVKit. Lab 285 17:16 — "TV is using AVKit, which uses it to … move the video to the top and controls to the bottom in when you position the phone like a laptop", so TV and Podcasts get the behavior for free; lab 286 26:17 says the same for Music, whose engineer also reads "the reserved region to know where the division is" for the rest of the layout. A single revenue-driving control sitting in the fold — lab 286 35:48, "a buy now there or like an add to cart or like a start free trial" — is the textbook one-element reserved-region case.

## Symbol status table

| Symbol | Status |
|---|---|
| `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`, `.division`, `.occlusion`, `.includeInactive`, `regions.map(\.frame)` | VERBATIM · SDK(27.1) |
| `ReservedRegion` — `frame`, `margins`, `kind`, `isActive`, `id` (`ReservedRegion.ID`), `ReservedRegion.QueryOptions` | SDK(27.1) — was PROSE |
| `UIView.reservedRegions(kind:options:)` (ObjC `-reservedRegionsOfKind:options:`, `NS_REFINED_FOR_SWIFT`) | VERBATIM · SDK(27.1) |
| `UIView.ReservedRegion` (ObjC `UIViewReservedRegion`) — same members, `margins` as `UIEdgeInsets` | SDK(27.1) — was PROSE |
| `ArrangementView { } secondary: { }`, `init(primary:secondary:)`, `init(_: ArrangementViewStyleConfiguration)` | VERBATIM · SDK(27.1) |
| `arrangementViewStyle(_:)` with `.split` / `.overlay` / `.automatic` | VERBATIM · SDK(27.1) |
| `ArrangementViewStyle` protocol, `makeBody(configuration:)`, `ArrangementViewStyleConfiguration` (`primary`, `secondary`) | SDK(27.1) — was PROSE as "ArrangementStyle" |
| `SplitArrangementViewStyle.axes(_: Axis.Set)`, `OverlayArrangementViewStyle.axes(_:)` | VERBATIM (`.split.axes(.horizontal)`) · SDK(27.1) |
| `splitArrangementLayoutRatio(_:)`, `splitArrangementLayoutRatio(minHorizontal:idealHorizontal:maxHorizontal:minVertical:idealVertical:maxVertical:)`, `splitArrangementLayoutSize(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:)`, `splitArrangementFixedLayoutSize(horizontal:vertical:)` | SDK(27.1) |
| `@Environment(\.splitArrangementAxis)` → `Axis?`, `@Environment(\.overlayArrangementZIndex)` → `Int`, `overlayArrangementEdge(_:)` | VERBATIM (z-index) · SDK(27.1) |
| `UIArrangementViewController` — `setViewController(_:for:animated:)`, `updateArrangement(_:animated:)`, `viewController(for:)`, `placement(for:)`, `state(for:)`, `.primary` / `.secondary` | VERBATIM · SDK(27.1) |
| `UIArrangementViewState` — `zIndex`, `splitAxis` (`UIAxis`), `isHidden`; `UIViewController.arrangementViewController` | SDK(27.1) |
| `UIArrangement` base class; `UISplitArrangement` / `UIOverlayArrangement` with `axes(_:)`; `UISplitArrangement.Dimension` (`automatic()` / `intrinsic()` / `fractional(_:)` / `absolute(_:)`) and `DimensionRange` | PROSE (111463 13:08) · SDK(27.1) |
| collapsing the secondary view of an `.overlay` arrangement | HIG names it; **absent from the 27.1 SDK** (searched 2026-09-21) — do not write it |
| `UIViewReservedRegion` as a *method*, `.axis(` | CAPTION — wrong, never use |
| `.divisions`, `.occlusions` (plural kinds) | wrong — written in two DTS forum answers, but the SDK declares only `.division` and `.occlusion` |
