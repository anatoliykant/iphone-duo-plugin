# Reserved regions and arrangements — laying out around the hinge and cameras

Sources: tech talk 111463 "Strike a pose with adaptive layouts on iPhone Duo" (every code block **VERBATIM** from its Code section), HIG "Dynamic layouts", the developer article "Preparing your app for iPhone Duo", and `documentation/updates/{swiftui,uikit}` September 2026. Everything here is **iOS 27.1 SDK**, and every symbol below was checked against it on 2026-09-21 (Xcode 27.1 beta 1) — see the status table.

Spelling notes: the talk prose says "the reservedRegion method" singular while both the code and the SDK write `reservedRegions(kind:…)` — follow the code. The talk's "split ArrangementStyle" is, in the SDK, the protocol **`ArrangementViewStyle`** with `SplitArrangementViewStyle` / `OverlayArrangementViewStyle` / `AutomaticArrangementViewStyle` conforming.

## Concepts

**Reserved regions** — 111463 0:36: "New hardware features also play a role in shaping the available space. These include the hinge and the two cameras across the outer and inner displays. We call these reserved regions … And treat these just like any other areas your layout already adapts to." … "such as the window controls on iPadOS." Two kinds:

| Kind | What | Behavior |
|---|---|---|
| `.division` | the fold | **divides** a larger area into smaller ones; **active only when partially folded, zero width when flat** |
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

**No numeric hinge width, angle thresholds or inset values are published.** Query — never hard-code.

**Displacement** — 111463 2:39: it "adjusts the frame of the existing elements based on the available space". Scope from one button to a whole container. Move elements independently when they can adapt alone, together when they work as a unit. **Continuously scrolling content (articles, feeds) should not displace.** Avoid excessive movement. Fold-sensitive content that must never straddle the division region: buttons and input controls, faces and focal image content, text that has to read uninterrupted, QR codes, drag handles, small icons — backgrounds, gradients and scrolling content may cross.

Where content moves (HIG / 111463 4:00):
- folded like a **book** (hinge vertical) → alerts and single controls move to the **trailing** side;
- propped on a **table** (hinge horizontal) → **top** region for content viewed at a distance, **bottom** for interactive controls;
- several regions viable → keep it contextual (near related content).

The system already repositions **action sheets, alerts, menus, popovers** around reserved regions, splits `UISplitViewController` / `NavigationSplitView` columns evenly, and — 111466 9:31 — "nudges interactive elements aside whenever iPhone Duo is partially folded" (fold avoidance). `NavigationStack`, `NavigationSplitView`, `TabView`, `List`, `ScrollView` adapt to the fold without custom code (111463 8:33: "leveraging our own components that adapt to the fold"). Custom code is only for what these do not cover.

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

Frames are in the proxy's / view's coordinate space. Typical uses: keep a manually positioned control (custom bar, floating button) out of the fold or camera; choose 2 vs 3 grid columns; widen spacing around the hinge while preserving outer margins. Apple's priority (111463 17:06): "identify the highest priority manually laid-out controls in your views and consider adopting the ReservedRegions API to implement your own displacement where needed" — not everything.

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

Placement rule: the arrangement is the **root of the navigation container**, never the other way round.

### Split arrangement

Divides the bounds between primary and secondary. **Horizontal when wider than tall, vertical when taller than wide.** When folded, the split follows the division region.

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

Restrict the axis when one direction never makes sense; if it cannot split along that axis it **shows a single view**.

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

Read the resolved axis from a child with `@Environment(\.splitArrangementAxis)` → `Axis?`. In UIKit the same knobs are `UISplitArrangement.Dimension` (`automatic()`, `intrinsic()`, `fractional(_:)`, `absolute(_:)`) and `UISplitArrangement.DimensionRange`.

Prefer a ratio to absolute points: absolute widths are the thing that breaks in a ~313 pt Split View half.

### Overlay arrangement

Stacks the two children — primary above secondary — and moves them **side by side when folded**. Read the z-index to switch between collapsed and expanded content.

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
| Main + detail where neither may be obscured (Podcasts transcript) | `.split` |
| Two panes already on `ViewThatFits` / `AnyLayout` (EXISTING, iOS 16) | keep them; upgrade to `.split` / `.overlay` (27.1) only when the pair must follow the division region or go side by side when folded |
| Master/detail navigation, sidebar + content | **not an arrangement** — `NavigationSplitView` / `UISplitViewController` |

## Anti-patterns

- Navigation container (`NavigationStack`, `NavigationSplitView`, `UINavigationController`) **inside** an `ArrangementView` — navigation goes outside.
- `ArrangementView` inside `List` / `ScrollView` — the article widens this: "Avoid placing an arrangement view inside a navigation split view, list, scroll view, or other container that might cause part of your view to become inaccessible."
- Reimplementing split/overlay with `GeometryReader` + division frames when an arrangement or `NavigationSplitView` already does it.
- Hard-coded fold width / offset ("the hinge is ~N pt") — query regions.
- Per-pose layouts (`if isBookPose { … }`) — inputs are size classes + aspect ratio + regions, and the system computes them.
- Using hinge angle to compute frames — `hinge-scenes-camera.md` §Hinge.
- Displacing scrolling content, or moving elements far / rearranging (HIG: "move only what's necessary").

## Migration recipe for a custom two-pane screen

1. Is it master/detail? → `NavigationSplitView` / `UISplitViewController`, done.
2. Otherwise wrap the two panes in `ArrangementView { primary } secondary: { secondary }` / `UIArrangementViewController`, inside the existing `NavigationStack` / `UINavigationController`.
3. Pick `.split` (was HStack/VStack) or `.overlay` (was ZStack); restrict `.axes` only if one axis is meaningless.
4. For `.overlay`, drive collapsed/expanded from `overlayArrangementZIndex` / `state(for:)?.zIndex` instead of your own "is minimized" flag.
5. Any remaining manually positioned control that must not sit in the fold → `reservedRegions(kind: .division)`; camera avoidance → `.occlusion`.
6. Grids: even column counts; consider `.includeInactive` to pre-decide columns on the flat inner display.
7. Test book, table and flat poses plus Split View in Device Hub (`testing-and-sources.md`).

## What this buys you elsewhere

An arrangement is not Duo-only. Lab 286 56:21, asked what happens on a normal phone: "It does actually work on our other hardware as well. As long as … the conditions that you've kind of set up the ArrangementView are true on the device that it's running on. So … if you still have space for two columns, it will render as two columns. If you don't, it will kind of move towards a single view, which is exactly what happens when you move between inner and outer display." That is the argument for adopting it instead of hand-rolling `if` statements between `HStack` and `ZStack` — and Apple did: lab 286 56:04, "almost every single app has an ArrangementView."

Where Apple used it: AVKit. Lab 285 17:16 — "TV is using AVKit, which uses it to … move the video to the top and controls to the bottom in when you position the phone like a laptop", so TV and Podcasts get the behavior for free; lab 286 26:17 says the same for Music, whose engineer also reads "the reserved region to know where the division is" for the rest of the layout. A single revenue-driving control sitting in the fold — lab 286 35:48, "a buy now there or like an add to cart or like a start free trial" — is the textbook one-element reserved-region case.

## Symbol status table

| Symbol | Status |
|---|---|
| `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`, `.division`, `.occlusion`, `.includeInactive`, `regions.map(\.frame)` | VERBATIM · SDK(27.1 β1) |
| `ReservedRegion` — `frame`, `margins`, `kind`, `isActive`, `id` (`ReservedRegion.ID`), `ReservedRegion.QueryOptions` | SDK(27.1 β1) — was PROSE |
| `UIView.reservedRegions(kind:options:)` (ObjC `-reservedRegionsOfKind:options:`, `NS_REFINED_FOR_SWIFT`) | VERBATIM · SDK(27.1 β1) |
| `UIView.ReservedRegion` (ObjC `UIViewReservedRegion`) — same members, `margins` as `UIEdgeInsets` | SDK(27.1 β1) — was PROSE |
| `ArrangementView { } secondary: { }`, `init(primary:secondary:)`, `init(_: ArrangementViewStyleConfiguration)` | VERBATIM · SDK(27.1 β1) |
| `arrangementViewStyle(_:)` with `.split` / `.overlay` / `.automatic` | VERBATIM · SDK(27.1 β1) |
| `ArrangementViewStyle` protocol, `makeBody(configuration:)`, `ArrangementViewStyleConfiguration` (`primary`, `secondary`) | SDK(27.1 β1) — was PROSE as "ArrangementStyle" |
| `SplitArrangementViewStyle.axes(_: Axis.Set)`, `OverlayArrangementViewStyle.axes(_:)` | VERBATIM (`.split.axes(.horizontal)`) · SDK(27.1 β1) |
| `splitArrangementLayoutRatio(_:)`, `splitArrangementLayoutRatio(minHorizontal:idealHorizontal:maxHorizontal:minVertical:idealVertical:maxVertical:)`, `splitArrangementLayoutSize(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:)`, `splitArrangementFixedLayoutSize(horizontal:vertical:)` | SDK(27.1 β1) |
| `@Environment(\.splitArrangementAxis)` → `Axis?`, `@Environment(\.overlayArrangementZIndex)` → `Int`, `overlayArrangementEdge(_:)` | VERBATIM (z-index) · SDK(27.1 β1) |
| `UIArrangementViewController` — `setViewController(_:for:animated:)`, `updateArrangement(_:animated:)`, `viewController(for:)`, `placement(for:)`, `state(for:)`, `.primary` / `.secondary` | VERBATIM · SDK(27.1 β1) |
| `UIArrangementViewState` — `zIndex`, `splitAxis` (`UIAxis`), `isHidden`; `UIViewController.arrangementViewController` | SDK(27.1 β1) |
| `UIArrangement` base class; `UISplitArrangement` / `UIOverlayArrangement` with `axes(_:)`; `UISplitArrangement.Dimension` (`automatic()` / `intrinsic()` / `fractional(_:)` / `absolute(_:)`) and `DimensionRange` | PROSE (111463 13:08) · SDK(27.1 β1) |
| collapsing the secondary view of an `.overlay` arrangement | HIG names it; **absent from the 27.1 SDK** (searched 2026-09-21) — do not write it |
| `UIViewReservedRegion` as a *method*, `.axis(` | CAPTION — wrong, never use |
