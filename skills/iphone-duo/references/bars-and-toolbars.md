# Vertical bars on iPhone Duo — navigation bars, toolbars, tab bars

Sources: tech talk 111462 "Raise the bar with iPhone Duo" (every code block below is **VERBATIM** from its Code section), HIG "Vertical controls", the developer article "Preparing your app for iPhone Duo", `documentation/updates/{swiftui,uikit}` September 2026, and the two group labs. Vertical bars themselves need the **iOS 27.1 SDK** (axis, edge, compression and opt-out APIs are 27.1); the overflow menu, visibility priority, pinned-trailing placement and sheet placement already ship in **iOS 27.0**. Every symbol below was checked against the iOS 27.1 SDK on 2026-09-21 (Xcode 27.1 beta 1).

## Why bars move to the side

The outer display is wider and shorter than a standard iPhone; moving navigation, toolbar and tab-bar controls to the side preserves vertical space and improves reach. Position stays consistent on the inner display in landscape; **the inner display in portrait returns to horizontal bars** (the only pose with horizontal bars). Dynamic Island and status bar move to the same side and share the vertical space with Live Activities.

Split View: each app puts controls along its **outer** edge (left app → left side). The bar follows the hardware/camera and therefore **does not flip in right-to-left languages**. The outer front camera sits in the corner **vertically aligned with the side controls** (HIG Anatomy) — the top of the vertical bar is camera territory, which is why the system, not your code, decides what goes there.

## Opt in

Two conditions: (1) rebuild with the iOS 27.1 SDK; (2) bars must come from **navigation containers**.

```swift
// 111462 2:24 — Use system container toolbars                        VERBATIM
// SwiftUI
var body: some View {
    NavigationStack {
        ContentView()
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    ...
                }
            }
    }
}
```

```swift
// 111462 2:39 — Prefer navigation controllers over custom bars       VERBATIM
// UIKit — content from a custom UIToolbar won't be considered.
// Prefer UINavigationController and UITabBarController,
// which manage their own bars.
let toolbar = UIToolbar()
toolbar.items = [...]
```

SwiftUI: `.toolbar { }` only participates when paired with `NavigationStack` / `NavigationSplitView`. UIKit: `UINavigationController`, `UITabBarController`, `UISplitViewController`. Content of a **standalone `UIToolbar` / `UINavigationBar` / `UITabBar` is not considered** — a hand-built xib-based navbar over a hidden system bar (`setNavigationBarHidden(true)`) stays horizontal, eats the shorter outer display and gets no reserved-region avoidance. Migration = restore the system bar and express the custom bar as `navigationItem` content / `.toolbar` items.

## The shared vertical region

Navigation, toolbar and tab-bar controls coexist in one vertical stack, as if the horizontal bars were rotated 90°.

- **Split views**: the article is precise — "the system shows bars horizontally for the sidebar or content view, and vertically for the detail view". Only the detail column gets the vertical bar.
- **Inspectors**: "The system presents bars in inspectors horizontally." (Earlier editions of this file said inspectors get no bar — wrong.)
- **Sheets**: on the **outer display** the system "presents bars vertically for sheets by default"; opt out with `toolbarVerticalBehavior(_:)` / `preferredVerticalBarBehavior`. On the **inner display** it depends on where the sheet sits: "the system presents the toolbar horizontally for centered or leading placements, and vertically for trailing placements." Choose the placement with `presentationPlacement(_:)` (SwiftUI) or `UISheetPresentationController.preferredPlacement` (UIKit) — `.automatic` / `.leading` / `.center` / `.trailing`, **iOS 27.0**. When folded, sheets slide sideways to avoid the fold (111466). A sheet with a single close button may opt out (§Opt out) — then the sheet does not extend up to the camera.
- A sheet that is mostly *controls* rather than content (writing tools, Notes) often reads better without a vertical bar — lab 286 46:47, where a designer calls one "Distracting almost, and limiting the space of the controls that you actually will be interfacing with". Whatever you pick, the controls stay with the sheet across rotation.
- Accessory bars shown with the keyboard stay horizontal.
- Mechanics: vertical bars have **fixed width, flexible item height** → suited to symbol-only items. Items too wide to fit vertically (text buttons, segmented controls) **stay in the horizontal navigation bar**.
- Vertical bars have **no scroll-edge effect** by default, but do get a background when **Reduce Transparency** is on. **Flexible spacers are zero-size vertically; fixed spacers respect their minimum.**

## Order of items (HIG)

1. Primary navigation — Back / Close — at the **top**.
2. Prominent actions — Done — pinned trailing.
3. Remaining toolbar items in their original groupings.
4. The system inserts the vertical space between top and bottom groups.

```swift
// 111462 5:00 — Place a back or close button                         VERBATIM
// SwiftUI
.toolbar {
    ToolbarItem(placement: .cancellationAction) {
        ...
    }
}

// UIKit
navigationItem.leftItemsSupplementBackButton = false
navigationItem.leadingItemGroups
    = [UIBarButtonItemGroup(...)]
```

`leftItemsSupplementBackButton` — EXISTING(iOS 5); the chapter prose misspells it `leftItemSupplementsBackButton`, the code is right. `leadingItemGroups` — EXISTING(iOS 16).

```swift
// 111462 5:24 — Pin prominent actions to the trailing edge           VERBATIM
// SwiftUI
.toolbar {
    ToolbarItem(placement: .topBarPinnedTrailing) {
        ...
    }
}

// UIKit
navigationItem.pinnedTrailingGroup
    = UIBarButtonItemGroup(...)
```

`pinnedTrailingGroup` — EXISTING(iOS 16, verified). `.topBarPinnedTrailing` — `@available(iOS 27.0)` in the 27.0 SDK: VERBATIM and already shipping in iOS 27.0.

## Not everything belongs on the bar

HIG Vertical controls, "Locate controls near the content they affect": "When controls belong to a content area other than the one along the trailing edge, keep them with that area rather than moving them to the side. Proximity makes the relationship between controls and content clear." Mail's list controls stay above the leading pane; moving them to the vertical bar would read as acting on the open message.

So on a two-column screen only the **detail** column's actions become `toolbar` / `navigationItem` content (matching "only the detail column participates" above). Actions that belong to the sidebar or list go into that column's own navigation bar (`NavigationSplitView` gives each column its own `.toolbar`; UIKit: the column's own `UINavigationController`), not into the shared vertical stack.

## Prepare toolbar content

The system decides per item whether it suits a vertical or horizontal axis. The article states the whole rule — **give every item both an icon and a title**, because iPhone Duo may present it vertically, horizontally or in the overflow menu:

- "The system uses an icon for an item it presents vertically."
- "The system uses an icon or a title for an item it presents horizontally, preferring an icon."
- "The system uses an icon and title for an item in an overflow menu."
- "If your item has a title and doesn't have an icon, the system doesn't present it vertically."
- "If your item uses a custom view rather than a title or icon, the system doesn't present it vertically."

`Label("Inbox", systemImage: "tray")`, `UIBarButtonItem(title:image:…)`. Group related items with `ToolbarItemGroup` / `UIBarButtonItemGroup` for adaptive spacing; no manual fixed spacers.

**Tab bars are the exception that bites.** A tab item with a title and no icon *does* go vertical — and then shows nothing useful, because a vertical tab bar draws the icon and reveals labels only while a finger scrubs across it (lab 286 07:05: "if you're only using text labels and you haven't set an icon that will still be able to go vertical … by default the tab bar shows the icon representation, and when someone interacts with it, that's when you'll start seeing the labels"; 08:27 notes the scrub-to-reveal behavior is "a different experience than on any of our other phones so far"). Ship icons for every tab.

### Axis behavior (iOS 27.1)

Keep related items on the same axis. A custom view that toggles between symbol and text (Select ↔ Done) → `.horizontalOnly`. Custom/complex views stay horizontal by default; opt them into vertical with `.verticalPreferred` once they have a vertical representation.

```swift
// 111462 8:08 — Set a preferred axis for a custom view               VERBATIM
// SwiftUI
var body: some View {
    ContentView()
        .toolbar {
            ToolbarItem {
                ProfileView()
            }
            .axisBehavior(.verticalPreferred)
        }
}

// UIKit
let item = UIBarButtonItem(customView: ProfileView())
item.axisBehavior = .verticalPreferred
```

```swift
// 111462 8:36 — Keep an item on the horizontal axis                  VERBATIM
// SwiftUI
var body: some View {
    ContentView()
        .toolbar {
            ToolbarItem {
                SelectOrDoneButton()
            }
            .axisBehavior(.horizontalOnly)
        }
}

// UIKit
item.axisBehavior = .horizontalOnly
```

```swift
// 111462 8:52 — Allow a custom view to go vertical                   VERBATIM
// SwiftUI
var body: some View {
    ContentView()
        .toolbar {
            ToolbarItem {
                CompassView()
            }
            .axisBehavior(.verticalPreferred)
        }
}

// UIKit
let item = UIBarButtonItem(customView: CompassView())
item.axisBehavior = .verticalPreferred
```

### Prefer symbol-only items — badges (EXISTING(iOS 26), verified: `UIBarButtonItem.badge: UIBarButtonItemBadge`)

Ask whether the text merely reinforces the symbol. "Inbox 7" → symbol + badge. A cart button showing a dollar amount stays horizontal (the number *is* the content).

```swift
// 111462 9:27 — Use a badge instead of inline text                   VERBATIM
// SwiftUI
var body: some View {
    ContentView()
        .toolbar {
            ToolbarItem(...) {
                InboxButton()
                    .badge(7)
            }
        }
}

// UIKit
let item = UIBarButtonItem(...)
item.badge = .count(7)
```

### Adapt custom views

A custom view must fit the fixed bar width or provide a vertically adapted layout; some metrics need adjusting. Detect the axis and edge:

```swift
// 111462 10:36 — Read the vertical bar edge                          VERBATIM
// SwiftUI
struct ContentView: View {
    @Environment(\.toolbarVerticalEdge) var edge

    var body: some View {
        switch edge {
            ...
        }
    }
}

// UIKit
switch traitCollection.verticalBarEdge {
    ...
}
```

`edge` is `nil` when the bar is horizontal. The CAPTION-only spelling `UITraitToolbarVerticalEdge` is **wrong** — do not use. In UIKit, register for changes with `UITraitCollection.systemTraitsAffectingVerticalBarEdge` rather than guessing which traits matter.

A view controller can also hand the decision to a child (`childForPreferredVerticalBarBehavior`) and tell the system its preference changed (`setNeedsUpdateOfVerticalBarConfiguration()`).

**If you truly must keep a custom bar**, ask the system where it would have drawn its own instead of measuring: `UIView.LayoutRegion.bar(onEdge:extent:)` (ObjC `+layoutRegionForBarOnEdge:extent:` / `…OnDirectionalEdge:…`, iOS 27.1). Lab 286 09:11: "One API we have that is new in 27.1 is the ability to grab out the region that the system bar would draw in … so you can request, hey, I want a bar that is, you know, like the trailing bar, and then you can know where you should put it. So at the very least, you're not just like guessing." Apple uses it themselves — 09:36, "music uses it for now playing and so does podcast".

For a full-screen view that wants to dodge only the camera and status-bar corner rather than the whole safe area, use a layout region with corner adaptation (the `…(cornerAdaptation:)` factories on `UIViewLayoutRegion`, iOS 26) — lab 286 41:46: "They really just want to know if there's a camera there or if they need to respect the status bar. You can look at the corner adaptation … and then you can draw everywhere else. So this is something, for example, if you're a full screen game app that you might consider looking at." Note the outer display's corners do not all share one radius (41:58).

**Background art under a vertical bar**: extend it with `backgroundExtensionEffect()` (SwiftUI) or `UIBackgroundExtensionView` (UIKit), iOS 26 — the article names both for hero and background images.

## Overflow

Overflow happens more on the outer display in landscape and when the keyboard appears. **Toolbar items compress first by default** (navigation-focused apps); task-oriented apps may prefer compressing the tab bar instead.

Two reasons this matters more than it used to. Lab 286 51:03: "The height of the bar, vertical bar on the edge can change so much … Rotating the outer display, showing a video PiP above the display, internally moving to split view multitasking. There's just so many ways that the height of that can change and you have to adapt to it." And 51:21: "we've also never had like bars sitting together … now everything's pretty much on top of each other … even on a regular height, will just now start compressing because we're not used to having them coexist like that."

So an app that has never exercised compression or an overflow menu will meet both here — and this part is testable today, without a Duo. Lab 286 51:52: "if your app maybe hasn't had to handle compression or overflow menus before, I would consider as part of the work to get ready for iPhone Duo that you can do right now. How does it behave when items move into the overflow? Because making sure that they have representations, that you have set priorities so that the system can preserve the things that are most important for the longest amount of time."

```swift
// 111462 12:23 — Configure toolbar compression behavior              VERBATIM
// SwiftUI
var body: some View {
    TabView {
        Tab("Recents", systemImage: "clock") {
            ContentView()
                .toolbarVerticalCompressionBehavior(.prefersToolbarItems)
        }
    }
}

// UIKit
navigationItem.verticalBarCompressionBehavior = .prefersBarItems
```

Move your own "more" menu into the **system overflow menu**; reserve the ellipsis symbol for overflow only.

```swift
// 111462 12:43 — Consolidate actions into the overflow menu          VERBATIM
// SwiftUI
var body: some View {
    ContentView()
        .toolbar {
            ToolbarOverflowMenu {
                Button("Scan") { ... }
                Button("Connect") { ... }
            }
        }
}

// UIKit
navigationItem.additionalOverflowItems = UIDeferredMenuElement({ provider in
    provider(self.persistentOverflowItems())
})
```

`additionalOverflowItems` — EXISTING(iOS 16, verified). `ToolbarOverflowMenu` — `@available(iOS 27.0)`, verified in the 27.0 SDK (an iOS 27 feature, not 27.1); the CAPTION spelling `toolbarOverflowMenu` is wrong.

### Visibility priority (iOS 27.0, verified)

Default overflow order is **bottom → top**. Assign `.high` / `.low` / custom values — groups first, then items within a group. Compose / New Note should overflow **last**; badged status controls should stay visible for glanceability.

```swift
// 111462 13:21 — Set item visibility priority                        VERBATIM
// SwiftUI
var body: some View {
    ContentView()
        .toolbar {
            ToolbarItem {
                Button(...) { ... }
            }
            .visibilityPriority(.high)
        }
}

// UIKit
let item = UIBarButtonItem(...)
item.visibilityPriority = .high
```

Types: `ToolbarItemVisibilityPriority` (SwiftUI, `@available(iOS 27.0)`) and `UIBarButtonItemVisibilityPriority` (UIKit, `API_AVAILABLE(ios(27.0))` on `UIBarButtonItem.visibilityPriority`) — both verified in the 27.0 SDK.

## Opt out — and when

Single-page, bottom-heavy immersive apps (Calculator) and sheets with only a close button. Not "because our custom bar looks better" — HIG: "In general, don't override the default bar placement" — it is "one of the core patterns of iPhone Duo".

```swift
// 111462 14:47 — Disable the vertical bar                            VERBATIM
// SwiftUI
var body: some View {
    NavigationStack {
        ContentView()
            .toolbarVerticalBehavior(.disabled)
    }
}

// UIKit
class MyViewController: UIViewController {
    override var preferredVerticalBarBehavior: UIVerticalBarBehavior {
        .disabled
    }
}
```

## Per-screen checklist

1. Bar comes from a container (`NavigationStack` / `UINavigationController` …), not a custom view over a hidden system bar.
2. Back/Close is `.cancellationAction` / leading group; Done is `.topBarPinnedTrailing` / `pinnedTrailingGroup`.
3. Every item has title **and** image; text-only items justified or converted (badge).
4. Custom views: `axisBehavior` set; vertical representation exists; reads `toolbarVerticalEdge` / `verticalBarEdge` if metrics differ.
5. Related items grouped; no fixed spacers.
6. Own overflow moved into `ToolbarOverflowMenu` / `additionalOverflowItems`; priorities set for Compose-like and badged items.
7. Compression preference chosen (toolbar items vs tab bar).
8. Opt-out only for Calculator-like screens or one-button sheets; for a sheet, pick `presentationPlacement` / `preferredPlacement` deliberately — it decides the axis on the inner display.
9. Controls that act on another column stay with that column, not on the shared vertical bar (§Not everything belongs on the bar).

## Symbol status table

| Symbol | Status |
|---|---|
| `ToolbarItem(placement: .cancellationAction)`, `.bottomBar` | EXISTING(iOS 14) |
| `presentationPlacement(_:)` with `PresentationPlacement` `.automatic` / `.leading` / `.center` / `.trailing`; `UISheetPresentationController.preferredPlacement` (`UISheetPresentationController.Placement`) | EXISTING(iOS 27.0) · SDK(27.1 β1) |
| `backgroundExtensionEffect()`, `UIBackgroundExtensionView` | EXISTING(iOS 26) · SDK(27.1 β1) |
| `UIView.LayoutRegion.bar(onEdge:extent:)` (ObjC `+layoutRegionForBarOnEdge:extent:`, `+…OnDirectionalEdge:extent:`, `NS_REFINED_FOR_SWIFT`) | SDK(27.1 β1) |
| `UITraitCollection.systemTraitsAffectingVerticalBarEdge`; `childForPreferredVerticalBarBehavior`, `setNeedsUpdateOfVerticalBarConfiguration()` | SDK(27.1 β1) |
| `UIVerticalBarEdge` `.unspecified` / `.leading` / `.trailing`; `UIVerticalBarBehavior` `.automatic` / `.disabled`; `ToolbarItemAxisBehavior` and `ToolbarVerticalBehavior` with the same cases | SDK(27.1 β1) |
| `UIVerticalBarCompressionBehavior` `.automatic` / `.prefersBarItems` / `.prefersTabBar` (automatic prefers the tab bar on iOS); `ToolbarVerticalCompressionBehavior` `.automatic` / `.prefersToolbarItems` / `.prefersTabBar` | SDK(27.1 β1) |
| `ToolbarItem(placement: .topBarPinnedTrailing)` | VERBATIM · EXISTING(iOS 27.0) · SDK(27.1 β1) |
| `.axisBehavior(.verticalPreferred / .horizontalOnly)`, `UIBarButtonItem.axisBehavior` | VERBATIM · SDK(27.1 β1) |
| `.badge(7)` on a toolbar item, `item.badge = .count(7)` (`UIBarButtonItemBadge`) | EXISTING(iOS 26, verified in 26.5 SDK) |
| `@Environment(\.toolbarVerticalEdge)`, `traitCollection.verticalBarEdge` | VERBATIM · SDK(27.1 β1) |
| `.toolbarVerticalCompressionBehavior(.prefersToolbarItems)`, `navigationItem.verticalBarCompressionBehavior = .prefersBarItems` | VERBATIM · SDK(27.1 β1) |
| `ToolbarOverflowMenu { }` | VERBATIM · EXISTING(iOS 27.0) · SDK(27.1 β1) |
| `navigationItem.additionalOverflowItems` (`UIDeferredMenuElement`) | EXISTING(iOS 16, verified) |
| `.visibilityPriority(.high)`, `item.visibilityPriority = .high` | VERBATIM, EXISTING(iOS 27.0, verified — SwiftUI `@available(iOS 27.0)`, UIKit `API_AVAILABLE(ios(27.0))`) |
| `ToolbarItemVisibilityPriority`, `UIBarButtonItemVisibilityPriority` | EXISTING(iOS 27.0, verified) |
| `.toolbarVerticalBehavior(.disabled)`, `preferredVerticalBarBehavior: UIVerticalBarBehavior` | VERBATIM · SDK(27.1 β1) |
| `leftItemsSupplementBackButton`, `leadingItemGroups`, `pinnedTrailingGroup`, `UIBarButtonItemGroup` | EXISTING(iOS 5 / 16 / 16 / 9) |
| `UITraitToolbarVerticalEdge`, `toolbarCompressionBehavior`, `toolbarOverflowMenu` | CAPTION — wrong, never use |
