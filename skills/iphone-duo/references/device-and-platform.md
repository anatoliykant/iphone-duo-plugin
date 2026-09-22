# iPhone Duo — device and platform facts

Research date: 2026-09-10; **SDK-verified 2026-09-21** against the iOS 27.1 SDK (Xcode 27.1 beta 1). Announced 2026-09-09, ships 2026-10-23. Everything here is newer than the model's training data — trust this file over memory.

Status legend used across all references: **VERBATIM** = copied from the Code section of an Apple tech talk page · **PROSE** = named only in Apple chapter text, the HIG or the developer article · **CAPTION** = reconstructed from YouTube captions only (never use) · **EXISTING(iOS xx)** = pre-Duo API · **SDK(27.1 β1)** = found in the iOS 27.1 SDK with an availability annotation. A symbol carries where it came from *and*, once confirmed, the SDK tag; anything without an SDK or EXISTING tag is still unconfirmed (`testing-and-sources.md` §Verify symbols).

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
| iOS 27 SDK | 111461 0:58: "Your app will extend to the left of the status bar area on the inner display." |
| iOS 27.1 SDK | 111461 1:05: "your app extends to the edge of the screen. Standard navigation and toolbar buttons now lay out vertically under the status bar." |

Vertical bars (axis / edge / compression / opt-out APIs), reserved regions, arrangements, hinge, `CameraCaptureAccessory`, dual-camera device types — **iOS 27.1 SDK**, all annotated `iOS 27.1` in the shipping SDK. Already in **iOS 27.0** (verified): `ToolbarOverflowMenu`, `visibilityPriority`, `.topBarPinnedTrailing`, `defaultTabBarPlacement`, `isTabViewSidebarAvailable`, the `.sceneAccessory` modifier, `presentationPlacement(_:)` / `UISheetPresentationController.preferredPlacement`. Nothing in iOS 27.0 gives vertical bars (a common third-party error).

What an unrebuilt app actually looks like — lab 285 23:27, an Apple engineer walking the same progression: "if you're linking against Xcode 26 on the Inner display, you will be you'll be Letterboxed. Your app will appear in iPhone regular on other iPhone aspect ratio with black bars on the sides. Once you build with Xcode 27 … You support Resizability. You'll use almost the full interior screen, but there'll still be a black bar on the side underneath the status bar. And when it's available later this month, you build with Xcode 27.1. Then you'll go to full screen." On the closed device, 37:45: "on the cover display you will see basically the ratio of an iPhone mini", with "a letter box on the … side … where the vertical bar would be"; opening it puts "that same ratio … in the middle of the screen" in both orientations, with no reaction to any pose. The HIG and the article never use the words *letterbox* or *compatibility mode* — Apple's engineers do, in the labs. Quote them, not the HIG, for this.

UIScene lifecycle is **required** when building with the iOS 27 SDK (TN3187, WWDC26 278) — apps without it fail to launch: `Application failed to launch: UIScene life cycle is required for apps built with this SDK.`

## Multitasking and windowing

- **All apps participate in Split View** — two apps side by side, 50/50, dragged in by the home indicator. Safe areas become asymmetric on both edges. Test here.
- New layout that **stacks video (PiP) and an app**: PiP pins to the top, the app resizes vertically. Handle like any other resize — size classes + scene geometry.
- **First iPhone with multiple scenes.** Apps that support multiple windows on iPad get it here. **New windows cannot be created on the outer display** — inner only. Handle scene-request errors; `UIWindowScene.ActivationAction` hides itself when windows are unavailable.
- **Scene accessories** show content on two displays at once (camera teleprompter). Availability is system-controlled (`hinge-scenes-camera.md`).
- On open/close the scene **resizes**; size classes, safe areas and reserved regions change. The app reflows — it is not relaunched. Lab 286 3:21: "It'll continue moving on the outer display … it's just like the app has gotten smaller."
- **Closing while two apps share the inner display** (lab 286 3:55): "The system will try to promote whichever one you are interacting with to the outer display. And the other one will be backgrounded." Reopening soon after brings both back; after longer, the promoted app takes the whole inner display. Apple does not publish the timing — do not depend on either outcome.
- **Two scenes of one app share app state** — lab 285 57:43, on `@AppStorage`: "Yes, the same app", with the usual SwiftUI / UIKit update mechanisms. Audio is not per-scene: there are no "two volume sliders" (lab 286 34:22).
- **External display**: behaves as on any other iPhone; **no iPad-style Stage Manager** (lab 286 36:28–37:00).
- System components reposition automatically around reserved regions: action sheets, alerts, menus, popovers, sheets (which slide sideways to avoid the fold), split-view columns.

## `UIRequiresFullScreen` — a product decision, not an auto-fix

Apple, WWDC26 278 "Modernize your UIKit app", chapter "Full-screen mode for games" at 6:00: "Due to this, UIRequiresFullscreen is honored on iPhone in resizable environments starting in iOS 27. Its behavior has also been updated and no longer opts your app fully out of resizing. Instead, it enables discrete resizing that honors your supported interface orientations." So the app **still resizes when the device opens or closes** — in discrete steps.

| Key value | Effect on Duo |
|---|---|
| `true` | two discrete sizes (closed / open); **no Split View**; orientation lock honored on the outer display; the closed↔open resize must still be handled |
| absent / `false` | continuous resizing + Split View + PiP stacking; must handle any width |

Apple never says to add the key "for Duo" — it is a games escape hatch. Removing it is a product decision (Split View support becomes mandatory). Lab 285 28:09 confirms the split: "on the outer display, we will honor supported orientations, but on the inner display, we won't … the size class will be regular, regular on the … inside." There is no opt-out of resizing itself — 47:28, asked for a way to keep classic iPhone behavior on Xcode 27: "There is not. Once you link on iOS 27, you get iPhone Resizability." Verify the exact discrete-resizing steps in Device Hub. Real key spelling has a capital `S`; Apple prose writes "UIRequiresFullscreen".

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
| 2026-09-16, 2026-09-17 | iPhone Duo Group Labs (Meet with Apple 285 and 286), ~60 min each |
| 2026-09-18 | **Xcode 27.1 beta 1** (27A9269) — iOS 27.1 SDK, iPhone Duo simulator and runtime, App Resizability skill |
| 2026-09-21 | Technology Overviews article "Preparing your app for iPhone Duo" and the `updates/{swiftui,uikit,avkit}` September 2026 sections available |
| 2026-09-23 | Apple forum Q&As: Photos & Camera, SwiftUI, UIKit (8–10 a.m. and 5–7 p.m. PT) |
| announced, dates TBA | iPhone Duo Workshops around the world (landing page) |
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
| Companion display needs a "system entitlement" | lab 285 4:12, panelist unsure ("I believe there is an API") | the shipping article registers a `UISceneAccessory` with **no entitlement mentioned** — follow the article |
| Extra-large (6 × 4) widgets are inner-display only | lab 286 54:23, "I have not tried" | plausible, unconfirmed |
| `devicectl device appResize` / fold CLI | bitrise.io | third-party; no fold/pose subcommand anywhere |
| Inner screenshot 2007 × 2853 | App Store Connect | unexplained mismatch with 1878 × 2670 |
| HIG typography / tap-target numbers for Duo | — | **none published** — do not invent |
| `UIRequiresFullScreen` exact discrete steps | WWDC26 278 prose | verify in Device Hub |
| Which display faces down in a seated pose is detectable | lab 285 10:10, panel unsure | no API named anywhere |

## Tech talk ↔ YouTube map

| ID | Title | YouTube id |
|---|---|---|
| 111461 | Prepare your app for iPhone Duo | `qsd-VwqmZvI` |
| 111462 | Raise the bar with iPhone Duo | `2y6xvya0b8M` |
| 111463 | Strike a pose with adaptive layouts on iPhone Duo | `d1xi9GAfSRI` |
| 111464 | Leverage multiple displays and scenes on iPhone Duo | `Biqw19XiqQY` |
| 111465 | Build a great camera experience for iPhone Duo | `8mNyxpsx7fY` |
| 111466 | Design for iPhone Duo (no code) | `do3UqxfYc3I` |

Playlist "Get ready for iPhone Duo": `PLEAYCWiT4WO4`. Pages at `https://developer.apple.com/videos/play/tech-talks/<id>/` carry the chapter list, the **full official transcript** and the Code sections inline in the HTML (`testing-and-sources.md` §Read a talk).

The two group labs are **Meet with Apple 285** (2026-09-16) and **286** (2026-09-17), not tech talks: no transcript section, captions only, and they are Q&A — cite them for intent and for what Apple engineers say out loud, never for an API spelling.
