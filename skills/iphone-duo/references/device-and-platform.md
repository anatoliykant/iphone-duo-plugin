# iPhone Duo — device and platform facts

Research date: 2026-09-10; SDK-verified 2026-09-21 against Xcode 27.1 beta 1 and **re-verified 2026-10-28 against the released Xcode 27.1 (27A9275) and Xcode 27.2 RC (27B48)**. Announced 2026-09-09, shipped 2026-10-23. Everything here is newer than the model's training data — trust this file over memory.

Status legend used across all references: **VERBATIM** = copied from the Code section of an Apple tech talk page · **PROSE** = named only in Apple chapter text, the HIG or the developer article · **CAPTION** = reconstructed from YouTube captions only (never use) · **EXISTING(iOS xx)** = pre-Duo API · **SDK(27.1)** = found in the released iOS 27.1 SDK with an availability annotation (unchanged from beta 1, also present in 27.2 RC). A symbol carries where it came from *and*, once confirmed, the SDK tag; anything without an SDK or EXISTING tag is still unconfirmed (`testing-and-sources.md` §Verify symbols).

## Displays

| | Outer (closed) | Inner (open) |
|---|---|---|
| Diagonal | 5.4" (5.36" measured) | 7.6" (7.58" measured) |
| Pixels (Apple) | 1398 × 2034 @ 460 ppi | 1878 × 2670 @ 430 ppi |
| Points (app window, **measured** on the Duo simulator, Xcode 27.2 RC) | 466 × 678 pt | 669 × 951 pt |
| Rendered pixels @3x | 1398 × 2034 | 2007 × 2853 — the App Store screenshot size, not the panel |
| Aspect ratio (derived) | ~1.45 | ~1.42 |
| Size classes (measured on the simulator) | portrait: compact W × regular H; landscape: compact × compact | **regular × regular** — first iPhone ever |
| Honors `supportedInterfaceOrientations` | yes (as other iPhones) | **no** |
| Bars (iOS 27.1 SDK) | vertical, on the hardware side; in Split View along each app's outer edge; **no RTL flip** | landscape: vertical; **portrait: horizontal** (the only pose with horizontal bars) |
| Front camera | 12 MP ultrawide, corner, always visible; Dynamic Island grows **vertically** | under-display ultrawide (first on iPhone), visible only while a camera session uses it — including another app's, such as a FaceTime call, over your app |

Both panels: OLED Super Retina XDR, ProMotion up to 120 Hz, 1000 nits typical / 1600 HDR / 3000 outdoor. Inner panel adds nano-texture.

The outer display is wider and shorter than a standard iPhone — that is why bars move to the side (preserves vertical space). "Outer landscape = compact × compact" is not stated by Apple; the Duo simulator reports it (Xcode 27.2 RC, iOS 27.1 and 27.2 runtimes, 2026-10-29).

### Landscape on the outer display — for the Duo only

The outer display honors `UISupportedInterfaceOrientations`, and the Duo reports `.phone`. So adding landscape to the iPhone list for the Duo turns landscape on for every iPhone — DMV shipped that by accident and reverted it (EE-5225). Under rule 14:
- keep landscape in the iPhone list;
- return the mask at run time — portrait until the hinge gate latches, landscape after;
- tell UIKit when the gate flips.

```swift
// Only when the app opts the Duo's outer display into landscape — the rest of the gate is
// layout-size-classes-safe-area.md §Scope. Typechecked 2026-10-30, Swift 5 and 6, targets 27.1 and 17.0.
@MainActor enum HingeGate {
    static private(set) var deviceHasHinge = false
    static func install(on window: UIWindow) {
        guard #available(iOS 27.1, *) else { return }
        window.addInteraction(UIHingeInteraction { [weak window] _, update in
            guard update.hinge != nil, !deviceHasHinge else { return }
            deviceHasHinge = true
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        })
    }
}

final class AppDelegate: UIResponder, UIApplicationDelegate {   // SwiftUI: @UIApplicationDelegateAdaptor
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        HingeGate.deviceHasHinge ? .allButUpsideDown : .portrait
    }
}
```

Measured 2026-10-30 (Xcode 27.2 RC):
- **Duo:** the mask switched during launch, and the cover display rotated to landscape.
- **iPhone 18 Pro Max:** the app stayed in portrait while the device turned. With the gate bypassed, the same build rotated.
- **Inner display:** ignores the key either way.

## Poses (HIG terminology)

Apple says **pose** for the physical configuration and **hinge status** for the fold state. There is no "posture" API.

| Pose | Description | What your layout sees |
|---|---|---|
| Closed | outer display | compact width |
| Partially folded like a book | inner display, hinge vertical | regular × regular + active **division** region |
| Placed on a surface (laptop / table) | inner display, hinge horizontal | regular × regular + active division region; top = content viewed from afar, bottom = controls |
| Standing on its edges (tent) | inner display when it stands open like a book; the outer display when it stands folded | regular × regular inside; outside, compact width — and the outer display honors your orientations (for the Duo only: §Landscape on the outer display), so Apple's forum answer suggests landscape support there: "iPhone Duo is a great opportunity to support landscape orientation, as people may want to set the phone down like a tent" ([847851](https://developer.apple.com/forums/thread/847851)) |
| Fully open (flat) | inner display | regular × regular; division region **inactive** — the talk says it then has zero width, but the simulator still reports the 40 pt band; test `isActive`, not the width |

**Do not design a layout per pose.** Design for compact and regular size classes; let reserved regions and arrangements handle the fold. Hinge status/angle is for effects only (`hinge-scenes-camera.md`).

## SDK tiers (Apple wording)

| Built against | Closed (outer display) | Open (inner display) |
|---|---|---|
| iOS 26 SDK or earlier | "your app's content to the left of the status bar and camera" | "your app will appear in the center of the display, with empty space surrounding the window" |
| iOS 27 SDK | — | "resize to fill most of the inner display on iPhone Duo, but still avoid the status bar on the right edge"; 111461 0:58: "Your app will extend to the left of the status bar area on the inner display." |
| iOS 27.1 SDK or later | full display, vertical bars | "Apps will extend to use the full display, with toolbars and tab bars appearing vertically below the status bar" |

Quotes without a timecode come from Apple's page [Three steps to make your app shine on iPhone Duo](https://developer.apple.com/iphone-duo/prepare/), which also says: "Before shipping an app build with the iOS 27.1 SDK, make sure your app's content adapts to the bars becoming vertical." 

Vertical bars (axis / edge / compression / opt-out APIs), reserved regions, arrangements, hinge, `CameraCaptureAccessory`, dual-camera device types — **iOS 27.1 SDK**, all annotated `iOS 27.1` in the shipping SDK. Xcode 27.1 ships "SDKs for iOS 27.1, iPadOS 27" (release notes), and its iOS 27.1 simulator runtime runs only the iPhone Duo; iPad and the other iPhones meet these APIs from iOS 27.2 on (simulator runtime 24B114 in Xcode 27.2 RC; customer build 24B119, released 2026-10-26). Already in **iOS 27.0** (verified): `ToolbarOverflowMenu`, `visibilityPriority`, `.topBarPinnedTrailing`, `defaultTabBarPlacement`, `isTabViewSidebarAvailable`, the `.sceneAccessory` modifier, `presentationPlacement(_:)` / `UISheetPresentationController.preferredPlacement`. Nothing in iOS 27.0 gives vertical bars (a common third-party error).

What an unrebuilt app actually looks like — lab 285 23:27, an Apple engineer walking the same progression: "if you're linking against Xcode 26 on the Inner display, you will be you'll be Letterboxed. Your app will appear in iPhone regular on other iPhone aspect ratio with black bars on the sides. Once you build with Xcode 27 … You support Resizability. You'll use almost the full interior screen, but there'll still be a black bar on the side underneath the status bar. And when it's available later this month, you build with Xcode 27.1. Then you'll go to full screen." On the closed device, 37:45: "on the cover display you will see basically the ratio of an iPhone mini", with "a letter box on the … side … where the vertical bar would be"; opening it puts "that same ratio … in the middle of the screen" in both orientations. It does react to the fold, though — Apple's forum answer ([847887](https://developer.apple.com/forums/thread/847887), DTS): "if the device is only partially open, the app shifts to one side of the display, while at the same size", and in Split View "the same size and aspect ration remain true, regardless if your app is on either side of the display". The Xcode 27.1 Duo simulator runs an old build in this mode, so a team can look at it before rebuilding ([847860](https://developer.apple.com/forums/thread/847860)). None of the Duo-specific APIs is required to ship: "not every app needs to use Arrangement Views or the reserved regions API" (847887). The HIG and the article never use the words *letterbox* or *compatibility mode* — Apple's engineers do, in the labs, and so does Apple's DTS summary of the labs on the forums ("apps that have not yet been updated or linked against newer SDKs will run in a compatibility mode on the displays"). Quote those, not the HIG, for this.

UIScene lifecycle is **required** when building with the iOS 27 SDK (TN3187, WWDC26 278) — apps without it fail to launch: `Application failed to launch: UIScene life cycle is required for apps built with this SDK.` Staying on the iOS 26 SDK is a dead end: Apple's [submitting page](https://developer.apple.com/app-store/submitting/) says that starting April 2027 "iOS and iPadOS apps must be built with the iOS & iPadOS 27 SDK or later, and target iOS 15 or later", and with the iOS 27 SDK a launch screen is required for App Store submission (TN3192, TN3208).

## Multitasking and windowing

- **All apps participate in Split View** — two apps side by side, 50/50, dragged in by the home indicator. Safe areas become asymmetric on both edges. Test here.
- New layout that **stacks video (PiP) and an app**: PiP pins to the top, the app resizes vertically. Handle like any other resize — size classes + scene geometry. Lab 287 59:12: Picture in Picture otherwise works as on other iPhones; the pin is a new control shown **open in portrait**, and the app below is not occluded by the video. Apple's DTS summary of the labs puts the pin "while fully open in landscape" instead — the two Apple sources disagree, so check the orientation in Device Hub before you rely on it. The same summary adds that when partially folded "the video automatically extends to fill half of the screen", that PiP "moves to the outer display only when the device is closed", and that audio-only content cannot be pinned.
- **First iPhone with multiple scenes.** Apps that support multiple windows on iPad get it here. **New windows cannot be created on the outer display** — inner only. Handle scene-request errors; `UIWindowScene.ActivationAction` hides itself when windows are unavailable.
- **Scene accessories** show content on two displays at once (camera teleprompter). Availability is system-controlled (`hinge-scenes-camera.md`).
- On open/close the scene **resizes**; size classes, safe areas and reserved regions change. The app reflows — it is not relaunched. Lab 286 3:21: "It'll continue moving on the outer display … it's just like the app has gotten smaller." Lab 287 42:09: the views and view controllers stay the same instances, and `onAppear` / `onDisappear` are not expected to fire again — "They're not different copies of your app on the other screen and the inner screen."
- **Closing while two apps share the inner display** (lab 286 3:55): "The system will try to promote whichever one you are interacting with to the outer display. And the other one will be backgrounded." Reopening soon after brings both back; after longer, the promoted app takes the whole inner display. Apple does not publish the timing — do not depend on either outcome.
- **Two scenes of one app share app state** — lab 285 57:43, on `@AppStorage`: "Yes, the same app", with the usual SwiftUI / UIKit update mechanisms. Audio is not per-scene: there are no "two volume sliders" (lab 286 34:22); the DTS summary adds that "the active audio and video playback is associated with the most recent app which began the playback session".
- **No API sets a scene's size** (DTS summary): `UIWindowScene` lets you observe geometry, and on Duo the size comes from the pose and Split View. Users cannot drag-resize a window either — "Not with free-form drag-to-resize." Nor its position: "there is no support to position your app's scene on either the left or right side of the screen when the device is open" ([847859](https://developer.apple.com/forums/thread/847859)).
- **Multitasking cannot be refused**: "All apps participate in iPhone Duo's multitasking, in that you cannot prevent multitasking with any sort of API in your app" ([847966](https://developer.apple.com/forums/thread/847966), Frameworks Engineer). Supporting multiple *scenes* stays optional.
- **A full-screen modal covers only your scene**: `.fullScreen` / `.fullScreenCover` fill the display only while the app has it to itself — "If your app is placed side-by-side in Split View with other apps, the modal will only fill your app's active window scene and will not cover the entire physical display" ([847874](https://developer.apple.com/forums/thread/847874)). A privacy or lock screen cannot hide the neighbor.
- **Both halves of an L-shaped, partially folded inner display take touches at the same time** (DTS summary).
- **External display**: behaves as on any other iPhone; **no iPad-style Stage Manager** (lab 286 36:28–37:00).
- System components reposition automatically around reserved regions: action sheets, alerts, menus, popovers, sheets (which slide sideways to avoid the fold), split-view columns.

## StandBy, widgets, Live Activities

Lab 287 13:49: every widget size StandBy supports on other iPhones works on Duo, plus an "extra large" format that "basically fills like half, half of the duo screen when it's open" — "a great new widget format to support, not just for the duo, but for other devices too". Lab 288 19:03 names it "an extra large in portrait", and Apple's DTS summary lists the families iPhone Duo supports: `systemSmall`, `systemMedium`, `systemLarge`, **`systemExtraLargePortrait`** (`WidgetFamily`, iOS 27.0), plus `accessoryCircular`, `accessoryRectangular`, `accessoryInline`. In the book configuration StandBy shows time, date and calendar on one side and a Live Activity on the other (lab 287 14:33) — whatever the app's Live Activity shows on the Lock Screen carries over.

- No dedicated "am I in StandBy" signal was named in lab 288 (17:55, the panel was unsure and pointed at widget `EnvironmentValues`).
- On the outer display a Live Activity grows out of the **bottom** of the vertically laid-out Dynamic Island, so it is narrower than on other iPhones (lab 288 18:18). Implement every presentation — `compactLeading`, `compactTrailing`, `minimal`, expanded and Lock Screen (DTS summary).
- **`isDynamicIslandLimitedInWidth`** **SDK(27.0)** (`EnvironmentValues`, declared in WidgetKit). Apple: "In some devices and context, the system adapts the flexible width of compact and minimal Live Activities and renders them smaller; for example, on iPhone in landscape orientation or on iPhone Duo. Use the `isDynamicIslandLimitedInWidth` environment value to adapt views you provide to compact and minimal Live Activity presentations."
  - DMV hit this on the Duo: a "10/94" counter in the compact presentation was cut off (EE-5233, Xcode 27.2 RC).
  - Their fix reads the value, drops fixed `frame(width:)`, and allows two lines plus a `minimumScaleFactor`. The text wrapped before it scaled.
  - Two lines are not always enough: a three-digit "106/150" was still cut at 15 and 11 pt bold and fit at 13 and 10 pt, with the logo at `scaleEffect(0.8)` (PR #1634). Try the longest value the activity can show.
  - Screenshots: `simctl io … screenshot` leaves the Dynamic Island out; capture Device Hub's window instead, `screencapture -x -o -l <windowID>` (DMV, not re-checked — the Duo runtime has no app with a Live Activity of its own to try it on).
  - The value is also true on other iPhones in landscape, so anything keyed to it changes there as well (rule 14). Keep the change to what makes the content fit.
- An alarm-clock face on the folded device is AlarmKit plus a good countdown Live Activity, not a scene accessory (DTS summary).
- Testing: StandBy is unavailable in the iPhone Duo simulator runtime (Xcode 27.1 release notes, 187708663).

## `UIRequiresFullScreen` — a product decision, not an auto-fix

Apple, WWDC26 278 "Modernize your UIKit app", chapter "Full-screen mode for games" at 6:00: "Due to this, UIRequiresFullscreen is honored on iPhone in resizable environments starting in iOS 27. Its behavior has also been updated and no longer opts your app fully out of resizing. Instead, it enables discrete resizing that honors your supported interface orientations." So the app **still resizes when the device opens or closes** — in discrete steps.

| Key value | Effect on Duo |
|---|---|
| `true` | discrete resizing — the scene jumps between sizes instead of following them (closed / open, and in multitasking); orientation lock honored on the outer display; the closed↔open resize must still be handled. Earlier editions said "no Split View"; no Apple source says that, and Apple's forum answer says no API prevents multitasking — check a full-screen app in Split View in Device Hub |
| absent / `false` | continuous resizing — Split View and PiP stacking resize the scene smoothly; must handle any width |

Apple never says to add the key "for Duo" — it is a games escape hatch. Removing it is a product decision (the closed↔open and multitasking resizes become continuous), but Apple's direction is clear: [TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key) calls the key deprecated since iPadOS 26 and says it "will be ignored in a future release", and the DTS summary of the labs says "As soon as possible, you should remove UIRequiresFullScreen and adopt size-class-driven resizing." To keep full-screen behavior only on older systems, add `UIRequiresFullScreenIgnoredStartingWithVersion` (Info.plist, iOS 26.2) with the first version that should ignore it. With a discrete resize, TN3192: "the scene doesn't change size while people drag the window. When they finish, the `coordinateSpace.bounds` of the scene's `effectiveGeometry` changes, and the scene moves to a `UIScreen` of exactly the same size." For expensive redraws during a continuous resize, `UIWindowSceneGeometry.isInteractivelyResizing` / SwiftUI `onInteractiveResizeChange(_:)` (iOS 26) tell you when the drag ends. Lab 285 28:09 confirms the split: "on the outer display, we will honor supported orientations, but on the inner display, we won't … the size class will be regular, regular on the … inside." There is no opt-out of resizing itself — 47:28, asked for a way to keep classic iPhone behavior on Xcode 27: "There is not. Once you link on iOS 27, you get iPhone Resizability." Verify the exact discrete-resizing steps in Device Hub. Real key spelling has a capital `S`; Apple prose writes "UIRequiresFullscreen".

## `UIScreen.main`

111461: "ambiguous and will be deprecated in a future release." Two displays, one `main`. Replacements in `layout-size-classes-safe-area.md`.

## App Store

**Corrected 2026-10-28** — this section used to say there was no badge and no requirement. Apple's news post [Prepare and submit your apps for iPhone Duo](https://developer.apple.com/news/?id=kkphp5qo) (2026-10-05) and the [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) say otherwise:

- **Badge**: "When you submit iPhone Duo screenshots in App Store Connect, your App Store product page will display a badge to let people know your app is optimized for iPhone Duo."
- **Requirement**: the specifications page — "Starting in April 2027, screenshots will be required for any app using the iOS 27.1 SDK or later." The news post words it more broadly: "Starting April 2027, any apps or games submitted will need to include screenshots for iPhone Duo."
- **Screenshot sizes**, iPhone Duo category: outer 1398 × 2034 and 2034 × 1398; inner **2007 × 2853** and 2853 × 2007 — the app's 669 × 951 pt window at @3x, which is also how the Duo simulator renders the inner display (`nativeBounds` 2007 × 2853, `nativeScale` 3). The 1878 × 2670 panel spec has fewer pixels; how hardware maps one onto the other is not documented.
- **App previews**: device resolutions 2034 × 1398 and 2853 × 2007; accepted resolutions 886 × 1920 (portrait) and 1920 × 886 (landscape), the same as the large iPhones ([app preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications)).
- **Tools**: a new preview tool in App Store Connect shows screenshots, product page headers and other metadata as they appear on iPhone Duo; a featuring nomination can state that the app is optimized for iPhone Duo, "including support for all device poses" (Three steps page).
- **Also from April 2027**: uploads must be built with the iOS 27 SDK and target iOS 15 or later (submitting page) — the date the scene-lifecycle requirement reaches every app.

Duo screenshots are capture work, not app work: they come from the Duo simulator in both displays and orientations — not from a resized 6.9" shot.

## Timeline

| Date | Event |
|---|---|
| 2026-09-09 | Announcement; HIG page + tech talks 111461–111466 published |
| 2026-09-16, 2026-09-17 | iPhone Duo Group Labs (Meet with Apple 285 and 286), ~60 min each |
| 2026-09-18 | **Xcode 27.1 beta 1** (27A9269) — iOS 27.1 SDK, iPhone Duo simulator and runtime, App Resizability skill |
| 2026-09-21 | Technology Overviews article "Preparing your app for iPhone Duo" and the `updates/{swiftui,uikit,avkit}` September 2026 sections available |
| 2026-09-23 | Apple forum Q&As: Photos & Camera, SwiftUI, UIKit (8–10 a.m. and 5–7 p.m. PT); a DTS engineer later posted a summary of the group labs on the forums |
| 2026-09 onward | iPhone Duo Workshops around the world (landing page) |
| 2026-10-05 | news "Prepare and submit your apps for iPhone Duo": App Store badge, April 2027 screenshot requirement, the "Three steps" page |
| 2026-10-13 | iPhone Duo Group Lab (Meet with Apple 287), ~62 min |
| 2026-10-15 | iPhone Duo Group Lab (Meet with Apple 288), ~62 min; **Xcode 27.1** released (27A9275) |
| 2026-10-16 | pre-orders |
| 2026-10-19 | Xcode 27.2 RC (27B48) — iOS 27.2 SDK, still carries every Duo API |
| 2026-10-23 | ships on **iOS 27.1** (newsroom; the specs page says iOS 27) |
| 2026-10-26 | iOS 27.2 released — build 24B91020 for iPhone Duo, 24B119 for the other iPhones |
| April 2027 | App Store: iOS 27 SDK minimum for uploads; Duo screenshots required for apps on the iOS 27.1 SDK |

## Other hardware (context only)

A20 Pro, hinge of 100+ components, magnet closure, dual batteries, Grade 5 titanium, IP68, eSIM-only. Open 6.48 × 4.64 × 0.21 in, closed 3.31 × 4.64 × 0.44 in, 254 g. $1,999 (256 GB). Rear: 48 MP Fusion Main + 48 MP Fusion Ultra Wide.

## Unverified — flag when relevant

| Claim | Source | Status |
|---|---|---|
| 466 × 678 / 669 × 951 pt | app window measured on the Duo simulator (Xcode 27.2 RC, iOS 27.1 and 27.2 runtimes, 2026-10-29); @3x of the App Store screenshot sizes | **measured** — no Apple page states point sizes. Plugin versions before 1.3.2 gave 626 × 890 (the panel's pixels ÷ 3, after blakecrosley.com and pasqualepillitteri.it) — wrong |
| Touch ID instead of Face ID | third parties | **confirmed** 2026-10-28 by the specs page: "Touch ID — Fingerprint sensor built into the side button" |
| Apple Pencil | lab 288 35:59, a question saying it "isn't supported at launch" (not answered) | the specs page says "Supports Apple Pencil (USB-C)", footnoted "Hover is not supported when using Apple Pencil (USB-C) with iPhone Duo" — follow the specs page; no Pencil hover on Duo |
| Ships on iOS 27.1 vs iOS 27 | newsroom vs specs page | 27.1 is the SDK target in every talk |
| `UIApplicationSupportsMultipleScenes` needed for multi-window on Duo | inference from iPad | not named on any Duo page |
| Companion display needs a "system entitlement" | lab 285 4:12, panelist unsure ("I believe there is an API") | the shipping article registers a `UISceneAccessory` with **no entitlement mentioned** — follow the article |
| Extra-large (6 × 4) widgets are inner-display only | lab 286 54:23, "I have not tried" | superseded: the family is `systemExtraLargePortrait` (DTS summary, lab 288 19:03); where it may appear on the outer display is still not stated (§StandBy) |
| WebKit and hinge position | lab 287 34:17, "My understanding is that … WebKit supports that" | **answered** by the DTS summary: "the Viewport Segments and Device Posture APIs. Both are opt-in experimental features in iOS 27.1, and can be enabled for testing in Settings > Apps > Safari > Advanced > Feature Flags." Not on by default — web content must work without them, and there is no way to detect "an iPhone Duo" from the web |
| Setting `XCUIDevice.shared.orientation` does not rotate the Duo simulator | a developer's question in lab 287 32:07; Apple did not contradict it | unverified locally — reading the orientation works (`testing-and-sources.md` §UI tests) |
| `devicectl device appResize` / fold CLI | bitrise.io | **corrected 2026-10-28**: `devicectl device appResize` (`start` / `set` / `observe`) and `devicectl device orientation` are real Apple commands, present since Xcode 27.0 — resizable app sessions on a device display and simulated orientation, not a fold. There is still no fold or pose command (`testing-and-sources.md`) |
| Inner screenshot 2007 × 2853 vs panel 1878 × 2670 | App Store Connect, specs page | **explained 2026-10-29**: 2007 × 2853 is the 669 × 951 pt interface at @3x, as the simulator renders it; whether hardware scales it down to the panel is unverified |
| HIG typography / tap-target numbers for Duo | — | **none Duo-specific** — the general values apply; Apple's answer on camera controls in the forum Q&A uses the standard "accessible hit region of at least 44x44 points" ([847715](https://developer.apple.com/forums/thread/847715)) |
| `UIRequiresFullScreen` exact discrete steps | WWDC26 278 prose | verify in Device Hub |
| Which display faces down in a seated pose is detectable | lab 285 10:10, panel unsure | the DTS summary answers "Does my app need to know which face is up? No." For sensors, `CMMotionManager.deviceMotionBody` corrects motion for the display your UI is on (`hinge-scenes-camera.md` §Motion and heading) |
| A system pose value | — | none — the DTS summary: "There's no single system-provided pose value"; infer it from hinge status, angle, orientation and size class, and only for effects |

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

The group labs are **Meet with Apple 285** (2026-09-16), **286** (2026-09-17), **287** (2026-10-13) and **288** (2026-10-15), not tech talks: no transcript section, captions only, and they are Q&A — cite them for intent and for what Apple engineers say out loud, never for an API spelling. Timecodes here are from the captions on the Apple Developer page. Third-party recaps quote the YouTube upload, which runs about two minutes later (Anton Gubarenko's Q&A for 287 puts the first question at 4:28; the captions have it at 2:39).

Apple's own written digest is the forum thread **[A Summary of the iPhone Duo Group Lab](https://developer.apple.com/forums/thread/847644)** (DTS, 17 posts, linked from the landing page as "Group Lab highlights"): edited answers, written up from the labs. Cite it as "DTS summary". It is not always more precise than the panel — where the two disagree (PiP pin orientation) the references say so.
