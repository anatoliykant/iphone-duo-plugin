# Reserved regions and arrangements — laying out around the hinge and cameras

Source: tech talk 111463 "Strike a pose with adaptive layouts on iPhone Duo" (every code block **VERBATIM** from its Code section) + HIG "Dynamic layouts". Everything here is **iOS 27.1 SDK**. Types named only in prose — `ReservedRegion` (SwiftUI) and `UIViewReservedRegion` (111461 8:20 / 8:27), `UISplitArrangement` and `ArrangementStyle` (111463 13:08 / 12:40) — are PROSE: spoken in Apple's official transcript, never written in a Code section, so verify the exact names in the SDK. Note the prose says "the reservedRegion method" singular while the code writes `reservedRegions(kind:)` — follow the code.

## Concepts

**Reserved regions** — 111463 0:36: "New hardware features also play a role in shaping the available space. These include the hinge and the two cameras across the outer and inner displays. We call these reserved regions … And treat these just like any other areas your layout already adapts to." … "such as the window controls on iPadOS." Two kinds:

| Kind | What | Behavior |
|---|---|---|
| `.division` | the fold | **divides** a larger area into smaller ones; **active only when partially folded, zero width when flat** |
| `.occlusion` | the FaceTime (front) camera | **occludes** rather than divides |

Regions are **active or inactive**; queries return active ones by default, `options: .includeInactive` returns the rest. Inactive regions still inform high-level decisions — e.g. **prefer an even number of grid columns** so a later fold divides cleanly.

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

Spelling: `.axes(...)`, plural. CAPTION `axis(` is wrong.

### Overlay arrangement

Stacks the two children — primary above secondary — and moves them **side by side when folded**. Read the z-index to switch between collapsed and expanded content.

The HIG adds one capability with no published spelling: "You can limit which axes a split arrangement uses, and **collapse the secondary view in an overlay arrangement when you don't want it to appear**." `.axes(…)` covers the first half (VERBATIM above); the collapse modifier appears in no Code section of 111463 — **PROSE**. Grep the SDK (`testing-and-sources.md` §Verify symbols) before writing it; until it is found, leave the secondary content out of the arrangement rather than inventing a modifier name.

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

`zIndex > 0` = this view is stacked **on top** of the other (show the compact form); `0` = side by side or alone (show the full form).

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
- `ArrangementView` inside `List` / `ScrollView`.
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

## Symbol status table

| Symbol | Status |
|---|---|
| `GeometryProxy.reservedRegions(kind:)`, `(kind:options:)`, `.division`, `.occlusion`, `.includeInactive`, `regions.map(\.frame)` | VERBATIM, 27.1 |
| `UIView.reservedRegions(kind:)` | VERBATIM, 27.1 |
| `ReservedRegion`, `UIViewReservedRegion` | PROSE ("New in iOS 27.1") |
| `ArrangementView { } secondary: { }` | VERBATIM, 27.1 |
| `.arrangementViewStyle(.split)`, `.split.axes(.horizontal)`, `.overlay` | VERBATIM, 27.1 |
| `@Environment(\.overlayArrangementZIndex)` → `Int` | VERBATIM, 27.1 |
| `UIArrangementViewController`, `setViewController(_:for:)`, `.primary` / `.secondary`, `updateArrangement(_:)`, `state(for:)?.zIndex` | VERBATIM, 27.1 |
| `ArrangementStyle`, `.axes` as "the axes method on the split ArrangementStyle" | PROSE (111463 12:40, official transcript) |
| `UISplitArrangement` | PROSE (111463 13:08, official transcript) |
| collapsing the secondary view of an `.overlay` arrangement | PROSE (HIG names the capability, no spelling published — verify in the SDK) |
| `UIViewReservedRegion` as a *method*, `.axis(` | CAPTION — wrong, never use |
