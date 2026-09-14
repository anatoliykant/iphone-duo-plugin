# iPhone Duo design rules — D1–D18 with sources

Sources: Apple HIG "Designing for iPhone Duo" (page published 2026-09-09; JSON: `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/designing-for-iphone-duo.json`, sections Best practices · Device poses · Dynamic layouts (Split views, Arrangement views, Reserved regions) · Vertical controls (Anatomy)); tech talks **111466** "Design for iPhone Duo" (Apple Design team), **111462** "Raise the bar with iPhone Duo" (design chapters), **111463** "Strike a pose with adaptive layouts on iPhone Duo" (design chapters), **111461** "Prepare your app for iPhone Duo". Quotes are Apple's wording; timecodes are chapter starts on `https://developer.apple.com/videos/play/tech-talks/<id>/`.

Facts a reviewer needs (all from those sources): outer display 5.4" compact width (like other iPhones, but wider and shorter); inner display 7.6" **regular × regular**; system bars (navigation, toolbar, tab bar, status bar, Dynamic Island) move to a **vertical edge** on the outer display and on the inner display in landscape; inner display in **portrait keeps horizontal bars**; when partially folded the hinge divides the inner display into two usable regions; the outer front camera is always present in a corner, the inner camera is under the display and shows only while active; every app takes part in Split View. Points in this file are **derived** — Apple publishes pixels only: outer 466 × 678; inner **626 × 890 in portrait** (horizontal bars; folded = table pose, hinge horizontal at y ≈ 445) and **890 × 626 in landscape** (vertical bars; folded = book pose, hinge **vertical at x ≈ 445**); Split View half ≈ 313 × 890 portrait or ≈ 445 × 626 landscape. The "fold band" is therefore a vertical strip in landscape frames and a horizontal strip in portrait frames.

Severity legend: B = BLOCKER, M = MUST-FIX, S = SHOULD, N = NOTE.

## Coverage of the design set

| Id | Rule | Fail if | Sev | Source |
|---|---|---|---|---|
| D1 | Both displays are designed: at least one compact (outer) and one regular (inner) frame per screen that ships on Duo | only phone-width frames exist, or inner-display frames are missing for a screen | B | HIG Best practices "Build your app to resize" / "Create a consistent experience across displays"; 111466 3:42 |
| D2 | Frames use realistic Duo geometry, labelled derived, and are classified by `absoluteBoundingBox`, not by name | frames at arbitrary sizes; a "Duo" frame identical to an iPad frame; frames named "Portrait" that are 890 × 626, or "Split View" frames that show the app's own folded two-pane arrangement rather than two apps | N | Apple publishes pixels 1398 × 2034 / 1878 × 2670 only (specs page); points derived |
| D3 | No layout designed per **pose** (book, table, tent) — only per size class | separate "folded"/"table" screens with different content or controls | B | HIG Device poses: design for size classes, not poses; 111466 0:28 "Don't design per pose — focus on compact and regular size classes" |
| D4 | Split View half (~313 pt) considered for screens with dense layouts | a regular-width screen that cannot collapse to a compact half without losing functions | S | 111461 6:06 "test in Split View"; HIG Best practices "Support Split View" |

## Consistency and hierarchy

| Id | Rule | Fail if | Sev | Source |
|---|---|---|---|---|
| D5 | Same functionality and element states on both displays; the inner display shows **additional hierarchy** (Mail: list *or* message closed, both open) | features exist on one display only; inner display just enlarges the outer layout | M | HIG "Create a consistent experience across displays"; 111466 7:34 |
| D6 | Inner display uses width for structure — split views, two columns, sidebars, inspectors — not for stretched rows or longer text lines | forms/text stretched edge to edge on 626 pt; single column where a list + detail fits | S | HIG "Dynamic layouts" / "Split views" (expand on inner, collapse to one pane on outer); 111466 7:34 "show more content, split views to surface more hierarchy, or a two-column layout" |
| D7 | Functionality does not depend on pose or orientation; controls may overflow, content may move, access stays the same | an action only reachable in one pose | M | HIG "Maintain functionality across device poses" |

## Vertical controls (bars)

| Id | Rule | Fail if | Sev | Source |
|---|---|---|---|---|
| D8 | Standard system bars are used and drawn where the system puts them: **vertical** on the outer display (and inner landscape), horizontal on inner portrait; the mockup does not hand-draw a bottom tab bar / top nav bar on outer-display frames | custom bar chrome, bars at the wrong edge for the class, "we'll keep our own bar" | B | HIG Vertical controls: "Follow the system's vertical layout for controls … Core pattern of iPhone Duo. Reinforces unified platform experience"; 111462 0:28, 2:00 |
| D9 | Bar item order on the vertical bar: primary navigation (Back / Close) at the top, then prominent actions (Done), then remaining groups; overflow items are the least important | Done above Back; primary actions designed into overflow | M | HIG Vertical controls "Anatomy" (order 1–4, overflow bottom → top); 111462 4:29 |
| D10 | Every bar item has a **symbol and a title**; symbol-only rendering preferred; badges instead of inline text ("Inbox 7") | text-only buttons in bars (they stay horizontal and eat space); labels as the only affordance | M | HIG Do: "Give every non-text-only toolbar item both a title and a symbol"; "Prefer symbol-only toolbar items; use badges"; 111462 5:56, 9:00 |
| D11 | Related items grouped; no manual fixed spacing between bar items; own "more" actions live in the system overflow (ellipsis reserved for overflow) | custom ellipsis menus, hand-spaced items | M | HIG Do/Don't: "Don't use manual fixed spacing"; "reserve the ellipsis symbol for overflow only"; 111462 11:40 |
| D12 | Frequently used actions (Compose, New) and status-conveying items (badges) are shown as staying visible when the bar compresses (landscape outer, keyboard) | mockup shows them buried, or no compressed state considered for a 6+ item bar | S | HIG Do: "Preserve frequently used actions and status-conveying controls from overflowing"; 111462 13:10 |
| D13 | Opt-out of vertical bars only for single-page immersive screens (Calculator-like) or a sheet with a single Close button | opt-out drawn for ordinary content screens | B | 111462 14:21 "When to opt out" |

## Fold avoidance and reserved regions

| Id | Rule | Fail if | Sev | Source |
|---|---|---|---|---|
| D14 | On inner-display frames no interactive or semantic element sits on the fold band (vertical strip at x ≈ 445 in landscape, horizontal at y ≈ 445 in portrait): buttons, text, faces, QR codes, input fields, drag handles, small icons. Backgrounds and scrolling content may cross. **Severity depends on the folded state:** B when the folded frames are missing or still straddle; S when the folded frames clear the band and only the flat state hugs the line (the crease is physical in every pose) | a primary button, form field or title centred on the fold in the folded frames (B); CTA chevron / links / timeline spine on the centre line in flat frames only (S) | B / S | HIG Duo §Reserved regions: "When the device is partially open, the folding region divides the inner display into multiple usable regions" and "Use the reserved region APIs to keep important elements clear of the center if the system doesn't move them automatically"; 111466 9:28 "keep interactive elements away from the hinge as much as possible"; 111463 1:29 "Designing around the hinge" — content spanning the fold "stops reading as one continuous image" (talk, not the HIG page) |
| D15 | Grids use an **even** number of columns on the inner display so a fold divides them cleanly | 3- or 5-column grids on regular frames | M | HIG Dynamic layouts: "use an even number of columns in grid layouts so they divide cleanly" |
| D16 | Displacement is small and local: alerts/sheets move to the trailing side in book pose, content goes top / controls bottom in table pose; the screen is not redesigned around the fold | drastic rearrangement between flat and folded frames; controls disappearing | S | HIG "Avoid extreme layout changes … Move only what's necessary"; 111463 2:26, 4:00 |
| D17 | Content respects the outer camera (corner, always visible; Dynamic Island grows vertically) and the inner camera when active — nothing important under them; foreground inside the safe area, only backgrounds extend past it | title, avatar or button placed in the camera corner; content designed edge-to-edge on the camera side | B | HIG Reserved regions (three regions: outer camera, inner camera, folding region); 111461 6:06 "keep interactive foreground content inside the safe area; let background art extend past it" |
| D18 | Sheets: on the outer display they carry vertical controls (a single-Close sheet may opt out), on the inner display horizontal bars; when folded they slide aside from the fold | sheets designed with a bottom-only action row on outer frames; sheet content centred on the fold | S | 111466 8:36 "Sheet behavior" |

## What Apple does **not** say (do not invent)

- No Duo-specific typography sizes, tap-target sizes, spacing or margins — apply the general HIG values (`hig-general-checklist.md`).
- No hinge width, angle thresholds or safe-area numbers.
- No "compatibility mode" or "letterboxing" for unadapted apps — they use the space left of the status bar until rebuilt with the iOS 27 / 27.1 SDK.
- Games: "make games playable in every pose" — pick portrait or landscape, fill the screen as the pose changes, prefer aspect-ratio changes over letterboxing (HIG Best practices 5); this is the only game-specific guidance.

## Mapping findings to implementation

All targets below are files of the separate `iphone-duo` skill (its `references/` directory): D8/D10/D11 → `bars-and-toolbars.md`; D14–D16 → `arrangements-and-reserved-regions.md`; D5/D6 → `layout-size-classes-safe-area.md` (adaptive toolbox, `NavigationSplitView`); D1–D3 → that skill's `SKILL.md` §Hard rules. The design review stops at "what" and "why"; the implementation skill owns "how".
