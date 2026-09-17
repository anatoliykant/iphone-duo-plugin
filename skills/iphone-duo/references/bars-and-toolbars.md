# Vertical bars on iPhone Duo — navigation bars, toolbars, tab bars

Source: tech talk 111462 "Raise the bar with iPhone Duo" (every code block below is **VERBATIM** from its Code section) + HIG "Vertical controls". Vertical bars themselves need the **iOS 27.1 SDK** (axis, edge, compression and opt-out APIs are 27.1); the overflow menu, visibility priority and pinned-trailing placement already ship in **iOS 27.0** — versions marked "verified" were read from the iOS 27.0 SDK (`@available` / `API_AVAILABLE`).

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

- Split views: only the **detail** column participates. **Inspectors do not get their own bar.**
- Sheets: **outer display → vertical controls**; **inner display → horizontal bars**; when folded, sheets slide sideways to avoid the fold (111466). A sheet with a single close button may opt out (§Opt out) — then the sheet does not extend up to the camera.
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

The system decides per item whether it suits a vertical or horizontal axis: **items with an image go vertical; text-only items stay horizontal**. Give every item a **title and an image** (`Label("Inbox", systemImage: "tray")`, `UIBarButtonItem(title:image:…)`) — the title is used in the overflow menu and expanded forms. Group related items with `ToolbarItemGroup` / `UIBarButtonItemGroup` for adaptive spacing; no manual fixed spacers.

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

`edge` is `nil` when the bar is horizontal. The CAPTION-only spelling `UITraitToolbarVerticalEdge` is **wrong** — do not use.

## Overflow

Overflow happens more on the outer display in landscape and when the keyboard appears. **Toolbar items compress first by default** (navigation-focused apps); task-oriented apps may prefer compressing the tab bar instead.

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
8. Opt-out only for Calculator-like screens or one-button sheets.
9. Controls that act on another column stay with that column, not on the shared vertical bar (§Not everything belongs on the bar).

## Symbol status table

| Symbol | Status |
|---|---|
| `ToolbarItem(placement: .cancellationAction)`, `.bottomBar` | EXISTING(iOS 14) |
| `ToolbarItem(placement: .topBarPinnedTrailing)` | VERBATIM, EXISTING(iOS 27.0, verified) |
| `.axisBehavior(.verticalPreferred / .horizontalOnly)`, `UIBarButtonItem.axisBehavior` | VERBATIM, 27.1 |
| `.badge(7)` on a toolbar item, `item.badge = .count(7)` (`UIBarButtonItemBadge`) | EXISTING(iOS 26, verified in 26.5 SDK) |
| `@Environment(\.toolbarVerticalEdge)`, `traitCollection.verticalBarEdge` | VERBATIM, 27.1 |
| `.toolbarVerticalCompressionBehavior(.prefersToolbarItems)`, `navigationItem.verticalBarCompressionBehavior = .prefersBarItems` | VERBATIM, 27.1 |
| `ToolbarOverflowMenu { }` | VERBATIM, EXISTING(iOS 27.0, verified) |
| `navigationItem.additionalOverflowItems` (`UIDeferredMenuElement`) | EXISTING(iOS 16, verified) |
| `.visibilityPriority(.high)`, `item.visibilityPriority = .high` | VERBATIM, EXISTING(iOS 27.0, verified — SwiftUI `@available(iOS 27.0)`, UIKit `API_AVAILABLE(ios(27.0))`) |
| `ToolbarItemVisibilityPriority`, `UIBarButtonItemVisibilityPriority` | EXISTING(iOS 27.0, verified) |
| `.toolbarVerticalBehavior(.disabled)`, `preferredVerticalBarBehavior: UIVerticalBarBehavior` | VERBATIM, 27.1 |
| `leftItemsSupplementBackButton`, `leadingItemGroups`, `pinnedTrailingGroup`, `UIBarButtonItemGroup` | EXISTING(iOS 5 / 16 / 16 / 9) |
| `UITraitToolbarVerticalEdge`, `toolbarCompressionBehavior`, `toolbarOverflowMenu` | CAPTION — wrong, never use |
