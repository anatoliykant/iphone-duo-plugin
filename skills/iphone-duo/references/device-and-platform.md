# iPhone Duo — device and platform facts

Research date: 2026-09-10. Announced 2026-09-09, ships 2026-10-23. Everything here is newer than the model's training data — trust this file over memory.

Status legend used across all references: **VERBATIM** = copied from the Code section of an Apple tech talk page · **PROSE** = named only in Apple chapter text / HIG · **CAPTION** = reconstructed from YouTube captions only (never use) · **EXISTING(iOS xx)** = pre-Duo API. Anything not VERBATIM/EXISTING → verify in the iOS 27.1 SDK before writing it (`testing-and-sources.md` §Verify symbols).

## Displays

| | Outer (closed) | Inner (open) |
|---|---|---|
| Diagonal | 5.4" (5.36" measured) | 7.6" (7.58" measured) |
| Pixels (Apple) | 1398 × 2034 @ 460 ppi | 1878 × 2670 @ 430 ppi |
| Points @3x (**derived, not Apple-stated**) | 466 × 678 pt | 626 × 890 pt |
| Aspect ratio (derived) | ~1.45 | ~1.42 |
| Size classes | portrait: compact W × regular H; landscape: compact × compact | **regular × regular** — first iPhone ever |
| Honors `supportedInterfaceOrientations` | yes (as other iPhones) | **no** |
| Bars (iOS 27.1 SDK) | vertical, on the hardware side; in Split View along each app's outer edge; **no RTL flip** | landscape: vertical; **portrait: horizontal** (the only pose with horizontal bars) |
| Front camera | 12 MP ultrawide, corner, always visible; Dynamic Island grows **vertically** | under-display ultrawide (first on iPhone), visible only while active |

Both panels: OLED Super Retina XDR, ProMotion up to 120 Hz, 1000 nits typical / 1600 HDR / 3000 outdoor. Inner panel adds nano-texture.

The outer display is wider and shorter than a standard iPhone — that is why bars move to the side (preserves vertical space). "Outer landscape = compact × compact" is a third-party detail, not Apple-confirmed.

## Poses (HIG terminology)

Apple says **pose** for the physical configuration and **hinge status** for the fold state. There is no "posture" API.

| Pose | Description | What your layout sees |
|---|---|---|
| Closed | outer display | compact width |
| Partially folded like a book | inner display, hinge vertical | regular × regular + active **division** region |
| Placed on a surface (laptop / table) | inner display, hinge horizontal | regular × regular + active division region; top = content viewed from afar, bottom = controls |
| Standing on its edges (tent) | inner display | regular × regular |
| Fully open (flat) | inner display | regular × regular; division region **inactive**, zero width |

**Do not design a layout per pose.** Design for compact and regular size classes; let reserved regions and arrangements handle the fold. Hinge status/angle is for effects only (`hinge-scenes-camera.md`).

## SDK tiers (111461, Apple wording)

| Built against | Behavior on the inner display |
|---|---|
| Pre-iOS 27 SDK | runs without recompiling; uses only the space to the left of the status bar and camera |
| iOS 27 SDK | "extends your app left of the status bar on the inner display" |
| iOS 27.1 SDK | "reaches the screen edge and lays standard navigation and toolbar buttons out vertically" |

Vertical bars (axis / edge / compression / opt-out APIs), reserved regions, arrangements, hinge, `CameraCaptureAccessory`, dual-camera device types — **iOS 27.1 SDK**. Already in **iOS 27.0** (verified in the 27.0 SDK): `ToolbarOverflowMenu`, `visibilityPriority`, `.topBarPinnedTrailing`, `defaultTabBarPlacement`, `isTabViewSidebarAvailable`, the `.sceneAccessory` modifier. Nothing in iOS 27.0 gives vertical bars (a common third-party error). Apple never uses "compatibility mode" or "letterboxing" for apps on Duo.

UIScene lifecycle is **required** when building with the iOS 27 SDK (TN3187, WWDC26 278) — apps without it fail to launch: `Application failed to launch: UIScene life cycle is required for apps built with this SDK.`

## Multitasking and windowing

- **All apps participate in Split View** — two apps side by side, 50/50, dragged in by the home indicator. Safe areas become asymmetric on both edges. Test here.
- New layout that **stacks video (PiP) and an app**: PiP pins to the top, the app resizes vertically. Handle like any other resize — size classes + scene geometry.
- **First iPhone with multiple scenes.** Apps that support multiple windows on iPad get it here. **New windows cannot be created on the outer display** — inner only. Handle scene-request errors; `UIWindowScene.ActivationAction` hides itself when windows are unavailable.
- **Scene accessories** show content on two displays at once (camera teleprompter). Availability is system-controlled (`hinge-scenes-camera.md`).
- On open/close the scene **resizes**; size classes, safe areas and reserved regions change. The app reflows — it is not relaunched.
- System components reposition automatically around reserved regions: action sheets, alerts, menus, popovers, sheets (which slide sideways to avoid the fold), split-view columns.

## `UIRequiresFullScreen` — a product decision, not an auto-fix

Apple (WWDC26 278 chapter title): "UIRequiresFullscreen honored on iPhone; enables discrete resizing." 111461 captions add that the app **still resizes when the device opens/closes**.

| Key value | Effect on Duo |
|---|---|
| `true` | two discrete sizes (closed / open); **no Split View**; orientation lock honored on the outer display; the closed↔open resize must still be handled |
| absent / `false` | continuous resizing + Split View + PiP stacking; must handle any width |

Apple never says to add the key "for Duo" — it is a games escape hatch. Removing it is a product decision (Split View support becomes mandatory). Verify the exact discrete-resizing behavior in Device Hub once Xcode 27.1 ships. Real key spelling has a capital `S`; Apple prose writes "UIRequiresFullscreen".

## `UIScreen.main`

111461: "ambiguous and will be deprecated in a future release." Two displays, one `main`. Replacements in `layout-size-classes-safe-area.md`.

## App Store Connect screenshots

Category **"iPhone Duo"** is listed first. Accepted pixel sizes:

- Outer: 1398 × 2034 and 2034 × 1398
- Inner: **2007 × 2853** and 2853 × 2007 — does **not** match the 1878 × 2670 panel spec; Apple does not explain

Reading of the 6.9" row: Duo screenshots are optional and scaled 6.9" shots are substituted — verify in App Store Connect. No "Optimized for iPhone Duo" badge, no new requirement or deadline (upcoming-requirements lists only the Xcode 26 minimum in force since 2026-04-28).

## Timeline

| Date | Event |
|---|---|
| 2026-09-09 | Announcement; HIG page + tech talks 111461–111466 published |
| late Sept 2026 | Xcode 27.1 beta with iPhone Duo simulator ("Coming later this month" as of 2026-09-10) |
| 2026-09-16/17, 2026-09-23 | Apple group labs / Q&As (Photos & Camera, SwiftUI, UIKit) |
| 2026-10-16 | pre-orders |
| 2026-10-23 | ships on **iOS 27.1** (newsroom; the specs page says iOS 27) |

## Other hardware (context only)

A20 Pro, hinge of 100+ components, magnet closure, dual batteries, Grade 5 titanium, IP68, eSIM-only. Open 6.48 × 4.64 × 0.21 in, closed 3.31 × 4.64 × 0.44 in, 254 g. $1,999 (256 GB). Rear: 48 MP Fusion Main + 48 MP Fusion Ultra Wide.

## Unverified — flag when relevant

| Claim | Source | Status |
|---|---|---|
| 466 × 678 / 626 × 890 pt | arithmetic @3x; blakecrosley.com, pasqualepillitteri.it | derived — no Apple page states point sizes |
| Touch ID instead of Face ID | third parties | not on any Apple page |
| Ships on iOS 27.1 vs iOS 27 | newsroom vs specs page | 27.1 is the SDK target in every talk |
| `UIApplicationSupportsMultipleScenes` needed for multi-window on Duo | inference from iPad | not named on any Duo page |
| `simctl` device-type name for Duo | — | not published; `xcrun simctl list devicetypes \| grep -i duo` is empty on Xcode 27.0 RC |
| `devicectl device appResize` / fold CLI | bitrise.io | third-party; no fold/pose subcommand anywhere |
| Inner screenshot 2007 × 2853 | App Store Connect | unexplained mismatch with 1878 × 2670 |
| HIG typography / tap-target numbers for Duo | — | **none published** — do not invent |
| `UIRequiresFullScreen` exact behavior | captions vs chapter title | verify in Device Hub |

## Tech talk ↔ YouTube map

| ID | Title | YouTube id |
|---|---|---|
| 111461 | Prepare your app for iPhone Duo | `qsd-VwqmZvI` |
| 111462 | Raise the bar with iPhone Duo | `2y6xvya0b8M` |
| 111463 | Strike a pose with adaptive layouts on iPhone Duo | `d1xi9GAfSRI` |
| 111464 | Leverage multiple displays and scenes on iPhone Duo | `Biqw19XiqQY` |
| 111465 | Build a great camera experience for iPhone Duo | `8mNyxpsx7fY` |
| 111466 | Design for iPhone Duo (no code) | `do3UqxfYc3I` |

Playlist "Get ready for iPhone Duo": `PLEAYCWiT4WO4`. Pages at `https://developer.apple.com/videos/play/tech-talks/<id>/` carry chapter text + Code sections — not word-for-word transcripts.
