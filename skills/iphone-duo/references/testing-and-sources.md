# Testing iPhone Duo layouts, toolchain status, sources

Research 2026-09-10/11. SDK-verified 2026-09-21 against Xcode 27.1 beta 1 (27A9269) and **re-verified 2026-10-28 against the released Xcode 27.1 (27A9275, 2026-10-15) and Xcode 27.2 RC (27B48, 2026-10-19)**. §Freshness lists what is still open.

## Toolchain gate — the first thing you run, before anything else

**Detect the capability, never compare version numbers.** Xcode **27.2 beta 1** (27B5019j) shipped on
**2026-09-16**, two days *before* **27.1 beta 1** (27A9269) on **2026-09-18**, and it is not on the
same build train (27B vs 27A). A `>= 27.1` test passed that 27.2 beta and then every Duo symbol failed to
compile. Xcode 27.2 RC (27B48) does carry the Duo APIs, so today the version compare would happen to work —
the probe stays because it answers the real question on every build train. Ask the SDK what it contains:

```bash
duo_sdk() {   # $1 = .../Xcode.app/Contents/Developer — true when its iOS SDK has the Duo APIs
  local h="$1/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/UIKit.framework/Headers"
  [ -f "$h/UIHingeInteraction.h" ] && [ -f "$h/UIViewReservedRegion.h" ]
}
xc_label() {  # "27.1 (27A9269), iOS SDK 27.1"
  local v b sv p="$1/Contents/version"
  v=$(defaults read "$p" CFBundleShortVersionString 2>/dev/null)
  b=$(defaults read "$p" ProductBuildVersion 2>/dev/null)
  sv=$(defaults read "$1/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/SDKSettings" Version 2>/dev/null)
  echo "${v:-?} (${b:-?}), iOS SDK ${sv:-none}"
}
xcodes() {    # every installed Xcode: the usual folders plus Spotlight, which also finds other volumes
  { ls -d /Applications/Xcode*.app "$HOME/Applications"/Xcode*.app 2>/dev/null
    mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null; } | sort -u
}

ACTIVE="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null)}"
echo "Active toolchain: ${ACTIVE:-none}   (xcodebuild, xcrun and xed all follow this)"
DUO_DIR=""; duo_sdk "$ACTIVE" && DUO_DIR="$ACTIVE"
xcodes | while read -r app; do
  [ -d "$app/Contents/Developer" ] || continue
  duo_sdk "$app/Contents/Developer" && m="Duo APIs: yes" || m="Duo APIs: NO "
  printf '  %-46s %-32s %s\n' "$app" "$(xc_label "$app")" "$m"
done
[ -n "$DUO_DIR" ] || DUO_DIR=$(xcodes | while read -r a; do duo_sdk "$a/Contents/Developer" && { echo "$a/Contents/Developer"; break; }; done)

if duo_sdk "$ACTIVE"; then
  echo "OK — the active toolchain has the iPhone Duo SDK."
elif [ -n "$DUO_DIR" ]; then
  printf 'WARNING — the active toolchain has no iPhone Duo APIs, but an installed Xcode does.\n  Use it per command (no admin rights):\n      export DEVELOPER_DIR=%s\n  Machine-wide instead (needs admin):\n      sudo xcode-select -s %s\n' "$DUO_DIR" "$DUO_DIR"
else
  printf 'WARNING — no installed Xcode carries the iPhone Duo APIs.\n  Get Xcode 27.1 or later: https://developer.apple.com/xcode/resources/\n  Until then do resizability work only and leave 27.1 symbols as // TODO:.\n'
fi

xcrun simctl list devicetypes | grep -i duo        # empty = no Duo simulator installed
```

Report the outcome to the user **as a warning, before any other finding** — silently building against
the wrong SDK is the failure this prevents.

Why these two files: `UIHingeInteraction.h` and `UIViewReservedRegion.h` exist only in an SDK that
carries the Duo APIs; the probe is a `test -f`, so it costs nothing and needs no permissions. A
`grep -qm1 ArrangementView` in
`.../SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/*.swiftinterface` answers the same
question in ~0.04 s if you want a second signal.

### What the gate is careful about

- **Nothing here needs admin rights or a TCC prompt** — it reads app bundles and runs no installer.
  Only `sudo xcode-select -s` would, which is why `DEVELOPER_DIR=` is the recommendation.
- **Never launch a candidate Xcode to interrogate it.** `defaults read …/Contents/version` gets the
  version and build without a first-run dialog or a licence prompt; running `xcodebuild` under an
  unopened Xcode can demand `sudo xcodebuild -license`.
- **Do not read the version out of `Contents/Info.plist`** — the 27.1 beta and the released 27.1 both report
  `DTPlatformVersion = 27.0` there. `Contents/version.plist` is the honest one.
- **`xcode-select -p` is the command-line default** and `xed`, `xcodebuild` and `xcrun` all resolve
  through it (`DEVELOPER_DIR` overrides it per process). Double-clicking a project in Finder is a
  *separate* setting owned by LaunchServices, so "my Xcode opens 26.6" and "my builds use 27.1" can
  both be true at once. The gate reports the one that decides your build.
- `xcode-select -p` can point at `/Library/Developer/CommandLineTools`, which has no `Platforms`
  directory at all — the probe returns false and the warning is still correct.
- Spotlight may be disabled; the glob covers the normal locations, `mdfind` adds other volumes when
  it works. Neither is authoritative alone, so the gate uses both.

| SDK reported | What you may write |
|---|---|
| no Duo probe | resizability work only: scene lifecycle, `UIScreen.main`, size classes, safe area, standard containers, windows |
| 27.0 | same; a 27.0 build also **fails to launch without the UIScene lifecycle** (TN3187) — use it to prove the BLOCKER |
| Duo probe passes | everything: reserved regions, arrangements, vertical-bar API, hinge, scene accessories, dual cameras |

Without the Duo SDK, new symbols go into `// TODO:` comments and the report's **Pending iOS 27.1 SDK**
section — never into code. Do not restructure working screens around assumptions about Duo geometry
(hinge position, exact widths) — prepare boundaries, verify later.

## What Apple provides — Xcode 27.1 + Device Hub

- **Xcode 27.1** (27A9275, released 2026-10-15; beta 1 was 27A9269) ships "SDKs for iOS 27.1, iPadOS 27" and the iPhone Duo simulator. **Xcode 27.2 RC** (27B48) ships the iOS 27.2 SDK with every Duo API. Apple's news post: "Recompile existing apps with Xcode 27.1, which adds development support for iPhone Duo."
- **Simulator identifiers** (checked 2026-10-28):

  | Thing | Identifier |
  |---|---|
  | Device type | `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo` |
  | Runtime, Xcode 27.1 | `com.apple.CoreSimulator.SimRuntime.iOS-27-1` (24A94401 for beta 1; later builds share the identifier) — **runs only the iPhone Duo** |
  | Runtime, Xcode 27.2 RC, Duo | `com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4` (24B91014) |
  | Runtime, Xcode 27.2 RC, every other iPhone and iPad | `com.apple.CoreSimulator.SimRuntime.iOS-27-2` (24B114) — the first runtime where iPad and the other iPhones see the 27.1 APIs, so §Scope's "no hinge" check can run there |

- **Device Hub** replaces Simulator.app in Xcode 27. 111461 1:25: "Use the control buttons at the bottom of the screen to open, close, rotate, or fold iPhone Duo." Lab 285 adds that it renders the device in 3D as it moves through the poses. **Buttons only — still no documented CLI** (`simctl` has no fold/pose subcommand; `simctl ui` covers appearance / increase_contrast / content_size only). Asked in lab 287 32:07 about the missing XCUITest / `simctl` hook for the hinge state, Apple pointed to none and asked for Feedback Assistant reports that name the exact need — snapshot testing, which transitions to cover, and why (33:12). Until then CI covers sizes, not poses: width-parameterized tests and resizing (§Proxies) run anywhere, and the fold is checked by hand in Device Hub.
- **A physical Duo is not required** for most testing (lab 287 10:08): the simulator reaches "all of the different states and poses". Hardware-specific work — camera streaming, for one — is better on a device, and holding one can change where you put controls (11:14).
- **Hinge angle plus rotation in 3D reaches every pose** except both displays lit at once, which needs a camera session and therefore a real device (lab 286 ~44:00).
- **Split View** in the simulator: drag the home indicator sideways to bring in a second app.
- Poses to cover: closed portrait, closed landscape, open flat portrait (the only horizontal-bar pose), open landscape, partially folded book (hinge vertical), table/laptop (hinge horizontal), tent; each with and without Split View; PiP stacking; scene accessory on/off for camera apps. **Also watch the transition between poses**, not just the resting states (lab 286 ~43:30; lab 285 ~42:00 on disorienting transitions).
- **Camera apps now launch in Simulator** (new in 27.1, lab 286 ~44:30): there is no camera, the preview stays empty and the app detects no capture device, but the surrounding UI is testable. Anything that depends on an actual capture session — scene accessories included — needs hardware.
- **Known issues, Xcode 27.1** (release notes): first Simulator launch can take several minutes; StandBy is unavailable in the Duo runtime; most app extensions cannot be run or debugged in the Duo runtime; a `CameraCaptureAccessory` can use both displays without an active capture session (190155353 — fixed in 27.2 RC); iOS 27.1-only APIs fail to compile for Mac Catalyst (185924957, still open in 27.2 RC — wrap them in `#if !targetEnvironment(macCatalyst)`), and a target with an iOS 27.1 minimum has no Catalyst run destination until it gets a Mac Catalyst 27.0 deployment target (187046347). The simulator carried only a limited set of first-party apps before launch (lab 287 12:38); lab 288 30:20 confirmed the Camera app cannot be tried there. Previews gained a **Display** group in the canvas overrides picker for previewing on a device's alternative display.
- **Known issues, Xcode 27.2 RC**: screenshots and recordings of an iPhone Duo can be black for a few minutes after boot (187146039) — wait before capturing App Store shots; **VoiceOver, Accessibility Inspector and other accessibility tools cannot read an iPhone Duo inside Device Hub** (187148389) — audit accessibility on another device or on hardware; modifier keys can stop working after switching displays (189465196, click the visible screen); cloning a 27.2 simulator can fail (188407822, the release notes give a `find … -delete` workaround). Device Hub itself gained slow animations, shake, memory pressure and hardware-keyboard simulation.
- **Apple's test list** (Three steps page, Step 3): "The iOS resizable simulator in Device Hub", "iPhone Mirroring on macOS 27. Resize the window to extreme sizes in both directions", and "The iPhone Duo simulator in Xcode 27.1" — "the best way to test the full native experience". The DTS summary adds that Device Hub supports checking resizing in iPad or iPhone Mirroring contexts, and that reachability, asymmetric safe areas and the weight of the device only show on hardware: "Always validate button targets, vertical bar positioning, and navigation flows on physical iPhone Duo devices." 
- **Not documented — do not invent:** Instruments templates for Duo.
- **`devicectl` resizing — real, and not a fold** (corrected 2026-10-28; earlier editions called it third-party). Xcode 27.0, 27.1 and 27.2 RC all ship `devicectl device appResize` — "Start and adjust resizable app sessions on a device display", with `start` (moves the frontmost apps to a display whose name contains "Resizable" and runs until interrupted), `set --preferred-size <WxH> [--corner-radius]`, `observe`, and `devicectl device info appResize` for the state — plus `devicectl device orientation`, "Query or set simulated device physical orientation (for devices that supported it)". It drives continuous resizing on a connected device, the same exercise as iPhone Mirroring; it does not fold a Duo or change a pose. A DTS forum answer treats stale accessibility snapshots during "live device resizing operations via devicectl" as a bug to file and asks for proper content shapes on interactive elements so automated tests hit-test correctly ([847880](https://developer.apple.com/forums/thread/847880)).
- **App Resizability** — Xcode's modernization agent skill, **present only from 27.1** (`IDEIntelligenceChat.framework/.../app-resizability.idechatprompttemplate` plus five `app-resizability-ref-*-task.md` files; Xcode 27.0 has none of them). Its own description covers `mainScreen`, `interfaceOrientation`, `userInterfaceIdiom`, app → scene lifecycle and safe-area insets, and it treats "get my app ready for iPhone Duo" as a request for every task in its registry. Export it for other tools:

  ```bash
  DEVELOPER_DIR=/Applications/Xcode-27.1.0.app/Contents/Developer \
    xcrun agent skills export --output-dir <path> [--replace-existing]
  ```

## UI tests (XCUITest) on the open Duo — take coordinates from the window

Observed locally 2026-10-13 (Xcode 27.1 beta, iPhone Duo simulator iOS 27.1, open flat at 180°; not re-run on Xcode 27.2 RC).
Open flat, the interface is landscape — `XCUIDevice.shared.orientation` is `.landscapeRight` and the
window is 951×669 pt — while `XCUIApplication.frame` **EXISTING(iOS 9)** stays portrait at 669×951.
Everything derived from the application's frame comes out rotated by 90°:

- `app.coordinate(withNormalizedOffset:)` **EXISTING(iOS 9)** — a "swipe up" from (0.5, 0.6) to
  (0.5, 0.3) becomes a sideways drag and scrolls nothing; a tap "near the top" lands elsewhere.
- `app.swipeUp()` / `app.swipeDown()` **EXISTING(iOS 9)** — do not scroll either.
- `app.frame` used to clip or compare element frames cuts landscape frames at 669 pt.

Element frames and the window's frame (`app.windows.firstMatch`) are in interface coordinates and
correct. Probe test: a drag built from `app.windows.firstMatch.coordinate(withNormalizedOffset:)`,
dy 0.6 → 0.3, scrolled the content at dx 0.25, 0.5 and 0.75; the same drag built from `app` scrolled
nothing at any dx.

- Build screen-level gestures, taps and the screen rectangle from `app.windows.firstMatch`, never from
  `app`. One shared helper (for example an `appWindow` property on the base test class) fixes every
  caller at once; on a portrait iPhone the two frames are equal, so nothing changes there.
- **The fold does not swallow touches.** A drag over the hinge, at the window's center, scrolls the
  same as one over either column. "The swipe landed on the fold" is the tempting first guess for a
  two-column screen and it is wrong here.
- Symptom: "element not found while scrolling" or "tap missed the popup" only on the open Duo, with the
  same tests green on a portrait iPhone.
- AXe 1.8 `swipe` on a second open Duo simulator moved nothing in the same session, in portrait or
  landscape coordinates. Cause not established — do not carry the XCUITest result over to AXe.

## Proxies when 27.1 is not installed

1. **iPhone Mirroring** — Apple's own first recommendation (Technology Overviews; lab 285 ~21:30, lab 286 ~05:00): resize the mirrored window to a Duo-like aspect ratio. It keeps the **phone idiom**, so the frameworks behave the way they will on Duo. See TN3210 "Optimizing your app for iPhone Mirroring".
2. **iPad with window resizing** — drag the window through a continuum of sizes (lab 286 ~04:30). An iPhone-only app counts too: "iPhone apps running in iPhone Mirroring and on iPad will be expected to resize as well", and there is no opt-out ([847872](https://developer.apple.com/forums/thread/847872)). Exercises the inner-display size class, sidebars, `NavigationSplitView` expansion. Does not exercise vertical bars, reserved regions, hinge.
3. **Compact × regular**: iPhone 18 Pro / 17 Pro on 27.0 — the outer-display class, plus the TN3187 launch check when built with the 27.0 SDK.
4. **Width-parameterized render tests** at 466 pt (outer) and 626 pt (inner) — **derived from @3x, not Apple-stated** — plus 313 pt (Split View half of 626). Pattern: host the view (or a `UIHostingController`) in a `UIWindow(frame: CGRect(x: 0, y: 0, width: w, height: h))`, call `layoutIfNeeded()`, then assert frames or snapshot; parameterize one test over the three widths. Label the numbers `derived` in test names. Also resize the same window mid-test (626 → 313 → 626) and assert that state survived: navigation depth, scroll offset, text-field contents, selection, playback position.
5. **Static analysis**: the grep audit (`audit-checklist.md`) — the biggest wins (`UIScreen.main`, cached widths, missing size classes, custom bars, scene lifecycle) need no simulator.
6. **Split View asymmetry** can be approximated on iPad simulators with Split View / Stage Manager — different insets, same class of bug.

A single screenshot is not verification: check several geometries and poses, a resize mid-session, Split View, and the reserved regions.

## Verify symbols against the SDK

Anything marked PROSE / CAPTION / "verify" in the references — check before writing it:

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.1.0.app/Contents/Developer   # adjust to the installed name
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path); echo "$SDK"
grep -rhoE "reservedRegions|ReservedRegion|ArrangementView|ArrangementViewStyle|arrangementViewStyle|splitArrangement[A-Za-z]*|overlayArrangement[A-Za-z]*|onHingeChange|DeviceHinge|axisBehavior|toolbarVerticalEdge|toolbarVerticalBehavior|toolbarVerticalCompressionBehavior|ToolbarOverflowMenu|visibilityPriority|toolbarMinimization[A-Za-z]*|sceneAccessory|CameraCaptureAccessory|presentationPlacement|backgroundExtensionEffect|AnyLayout|containerRelativeFrame|onGeometryChange" \
  "$SDK/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/"*.swiftinterface \
  "$SDK/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/"*.swiftinterface | sort | uniq -c
# SwiftUICore holds the layout primitives and, on 27.1, DeviceHinge / ReservedRegion / the arrangement modifiers —
# grepping SwiftUI alone reports them as missing.
grep -rhoE "UIHingeInteraction|UIHinge|UIArrangementViewController|UIArrangement|UISplitArrangement|UIOverlayArrangement|UIViewReservedRegion|reservedRegionsOfKind|verticalBarEdge|UIVerticalBarEdge|UIVerticalBarBehavior|preferredVerticalBarBehavior|verticalBarCompressionBehavior|UIVerticalBarCompressionBehavior|axisBehavior|visibilityPriority|preferredPlacement|navigationBarMinimization|UIBarMinimization|UIBackgroundExtensionView|layoutRegionForBarOnEdge|UISceneAccessory" \
  "$SDK/System/Library/Frameworks/UIKit.framework/Headers/"*.h | sort | uniq -c
grep -rhoE "AVCaptureDeviceDirectionCoordinator|AVCaptureDeviceDescriptor|AVCaptureDeviceDirectionMap|BuiltInOuterUltraWideCamera|BuiltInInnerUltraWideCamera|dynamicAspectRatio|activePrimaryConstituent" \
  "$SDK/System/Library/Frameworks/AVKit.framework/Headers/"*.h "$SDK/System/Library/Frameworks/AVFoundation.framework/Headers/"*.h | sort | uniq -c
```

Availability of a found symbol: `grep -B6 '<symbol>' <file>` and read the nearest `API_AVAILABLE(ios(…))` / `@available(iOS …)` line above it.

**Result on the iOS 27.1 SDK (Xcode 27.1 beta 1, 2026-09-21; repeated 2026-10-28 on Xcode 27.1 27A9275 and Xcode 27.2 RC 27B48).** Every Duo symbol in these references is present and annotated; the reference tables carry the per-symbol tags. The UIKit headers of the released 27.1 SDK are byte-identical to beta 1, and the Duo declarations in the SwiftUI, SwiftUICore, UIKit, AVKit, AVFoundation, WidgetKit and ActivityKit interfaces did not change. 27.2 RC adds `UIView.LayoutRegion.bar(onEdge:)` without `extent:` and `UINavigationItem.titleAlignment` (not Duo-specific), and drops the private `_boundaryLayoutRegions`. Two spellings to know:

- **UIKit reserved regions are refined for Swift.** The header declares `-reservedRegionsOfKind:` / `-reservedRegionsOfKind:options:` on a `UIView (ReservedRegion)` category with `NS_REFINED_FOR_SWIFT`, so a grep for `reservedRegions` in the headers returns **zero** — Swift still sees `reservedRegions(kind:options:)`. Grep `reservedRegionsOfKind` instead.
- **`UIViewLayoutRegion` is refined too** (`NS_REFINED_FOR_SWIFT`): `+layoutRegionForBarOnEdge:extent:` and `+layoutRegionForBarOnDirectionalEdge:extent:` surface in Swift as `UIView.LayoutRegion.bar(onEdge:extent:)`.

Earlier availability, unchanged: `ToolbarOverflowMenu`, `visibilityPriority` (SwiftUI + `UIBarButtonItem`), `.topBarPinnedTrailing`, `defaultTabBarPlacement`, `isTabViewSidebarAvailable`, the `.sceneAccessory` modifier, `presentationPlacement(_:)` / `UISheetPresentationController.preferredPlacement` — **iOS 27.0**; `tabBarPlacement` / `.sidebarAdaptable` — 18; `additionalOverflowItems` / `pinnedTrailingGroup` — 16; `UIWindowSceneActivationAction` — 15; `AVCaptureDevice.AspectRatio` / `dynamicAspectRatio` / `isCameraSensorOrientationCompensationEnabled`, `backgroundExtensionEffect()` / `UIBackgroundExtensionView`, `UIViewLayoutRegion` itself — 26.

## Xcode MCP as the tool provider

No custom MCP is needed for Duo: build / run / screenshot are covered by XcodeBuildMCP and Apple's own Xcode MCP bridge. Apple documents connecting external agents: Xcode → Settings → Intelligence → Model Context Protocol → "Allow external agents to use Xcode tools", then

```bash
# Claude Code
claude mcp add --transport stdio xcode -- xcrun mcpbridge
# Codex
codex mcp add xcode -- xcrun mcpbridge
```

Both commands are documented by Apple in
[Giving external agents access to Xcode](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode).
Verify with `claude mcp list` or `codex mcp list`, and open the app project in Xcode before using
its tools. Device Hub pose switching stays manual even with the bridge.

## Freshness — what is still open

Closed 2026-10-28: Xcode 27.1 released (27A9275) and 27.2 RC out (27B48); the Duo shipped on 2026-10-23; the Duo API documentation pages no longer carry `"beta":true` and every symbol was re-verified (§Verify symbols); the HIG text is unchanged since 2026-09-21 and the article since 2026-10-04 (sentence diff against Wayback Machine copies); group labs 285–288, the DTS summary thread and the three 2026-09-23 forum Q&As are read; Apple's "Three steps" page and the 2026-10-05 news post are folded into `device-and-platform.md`.

Still to watch:

1. **New group labs and workshops** — the landing page lists labs as "Day N"; the October newsletter announced more labs. New `meet-with-apple/<id>` pages appear one number up (288 was the last on 2026-10-28).
2. **Xcode 27.2 release** — re-run §Verify symbols on it; 27.2 RC already adds `UIView.LayoutRegion.bar(onEdge:)`.
3. **HIG page** — the change log still reads `September 9, 2026 | New page.`, but Apple edited the page anyway between 2026-09-16 and 2026-09-21 (the fold sentence changed from "the reserved region APIs" to "the `ReservedRegion` API", and a **Developer documentation** block appeared). **Hash the JSON, do not trust the log.**
4. **Technology Overviews article** — no change log of its own; hash it.
5. **App Store, April 2027** — Duo screenshots required for apps on the iOS 27.1 SDK, iOS 27 SDK minimum for uploads (`device-and-platform.md` §App Store). Watch the upcoming-requirements page for the exact date.
6. **Open questions** — settle them in Device Hub where it can show them, on hardware otherwise: the PiP pin orientation (lab 287 and the DTS summary disagree), `UIRequiresFullScreen` discrete steps and its behavior in Split View, and the rest of `device-and-platform.md` §Unverified.

### Machine-checkable signals (no JavaScript needed — usable from a cron / launchd script)

| Signal | Check | Baseline 2026-10-28 |
|---|---|---|
| Duo API pages beta flag | `curl -s https://developer.apple.com/tutorials/data/documentation/swiftui/arrangementview.json \| grep -c '"beta":true'` | 0 (was > 0 until 27.1 shipped) |
| Developer article edited | `curl -s https://developer.apple.com/tutorials/data/documentation/technologyoverviews/preparing-your-app-for-iphone-duo.json \| shasum -a 256` | `2da25364c293d2fd…` |
| HIG page edited | `curl -s https://developer.apple.com/tutorials/data/design/human-interface-guidelines/designing-for-iphone-duo.json \| shasum -a 256` | `1153299e056e4b60…` |
| Xcode 27.2 released | `curl -s https://xcodereleases.com/data.json \| grep -c '"number":"27\.2","release":{"release"'` | 0 → > 0 (27.2 RC is 27B48) |
| Xcode release notes index | `curl -s https://developer.apple.com/tutorials/data/documentation/xcode-release-notes.json \| grep -oE '"title":"Xcode 27[^"]*"'` | "Xcode 27", "Xcode 27.1 Release Notes", "Xcode 27.2 RC Release Notes" |
| Apple releases feed | `curl -s https://developer.apple.com/news/releases/rss/releases.rss \| grep -oE '<title>[^<]*</title>' \| grep -E '27\.[12]'` | Xcode 27.1 (27A9275), Xcode 27.2 RC (27B48), iOS 27.2 (24B91020 Duo / 24B119) |
| Apple news feed | `curl -s https://developer.apple.com/news/rss/news.rss \| grep -oE '<title>[^<]*Duo[^<]*</title>'` | "Get ready for iPhone Duo", "Build for iPhone Duo with new resources", "Prepare and submit your apps for iPhone Duo" — titles may use a non-breaking space in "iPhone Duo" |
| New group lab | `curl -s -o /dev/null -w '%{http_code}' https://developer.apple.com/videos/play/meet-with-apple/289/` | 302 (288 is the last one) |
| Duo simulator installed locally | `xcrun simctl list devicetypes \| grep -ci duo` | 1 |

The `documentation/…` HTML pages are a JavaScript app; their `tutorials/data/…json` twins return real 404/200 and real content — check those.

## Read a talk

The tech-talk pages are plain HTML — transcript and sample code are in the markup, no JavaScript needed. Use this instead of YouTube captions; it is the source every VERBATIM block and talk quote in these references was checked against (2026-09-16, re-checked 2026-09-21).

```bash
T=111463
curl -s -A "Mozilla/5.0" "https://developer.apple.com/videos/play/tech-talks/$T/" -o /tmp/$T.html
# transcript, one sentence per line with its start time in seconds
grep -o '<span data-start="[0-9.]*">[^<]*' /tmp/$T.html | sed 's/<span data-start="//;s/">/\t/'
# sample code: title + timecode
grep -oE 'data-start-time="[0-9]+"[^>]*>[^<]+' /tmp/$T.html
```

Prose names an API loosely — 111463 says "the reservedRegion method" while the Code section writes `reservedRegions(kind:)`. **The Code section wins**; the transcript is for intent and timecodes.

### Read a Meet with Apple lab

Group-lab pages carry **no** transcript section. The captions live in the HLS stream:

```bash
L=287
curl -s -A "Mozilla/5.0" "https://developer.apple.com/videos/play/meet-with-apple/$L/" -o /tmp/$L.html
M=$(grep -oE 'https://devstreaming-cdn.apple.com/videos/meet-with-apple/[^"]+cmaf\.m3u8' /tmp/$L.html | head -1)
B="${M%/*}/subtitles/en/"   # ends in "/" — "$B/prog_index.m3u8" makes "//": a 302 with an S3 AccessDenied body, no captions
mkdir -p /tmp/$L.seg
# ~600 segments for an hour: fetch them in parallel (seconds, not minutes), numbered to keep the order
curl -s "${B}prog_index.m3u8" | grep -v '^#' | nl -w4 -nrz \
  | B="$B" D=/tmp/$L.seg xargs -P 16 -L1 sh -c 'curl -s "$B$1" -o "$D/$0.vtt"'
cat /tmp/$L.seg/*.vtt > /tmp/$L.vtt
# then keep lines with a "HH:MM:SS.mmm --> " cue, strip tags, drop repeats (the captions roll)
```

Lab 288 is the fourth; the landing page links it from the "All Group Lab videos" search rather than as "Day 4".

These are **auto-generated captions, not an edited transcript**. Use them for intent, guidance and timecodes; never for an API spelling, and never quote a panelist's "I believe" / "I'm not sure" as a fact — those belong in `device-and-platform.md` §Unverified.

### Read the forum Q&As

`developer.apple.com/forums/…` answers `curl` with a "verify you are human" page (and the `apple.co` short links redirect there), so read the threads in a real browser session and save `main.innerText`. The three 2026-09-23 activities list their threads 20 per page (`?page=N&sortBy=activity&sortOrder=DESC`). Only posts marked **Apple** (DTS Engineer, Frameworks Engineer, Media Engineer, …) count as Apple statements; many threads have no Apple reply at all.

## Sources

| URL | Status (2026-10-28) |
|---|---|
| https://developer.apple.com/iphone-duo/ | landing (2026-10-28): videos, Group Labs Day 1–3, "Group Lab highlights" (the DTS thread), the three forum Q&As, Xcode 27.1, HIG, the article, the "Three steps" page and App Store asset links |
| https://developer.apple.com/iphone-duo/prepare/ | **"Three steps to make your app shine on iPhone Duo"** — SDK tiers with pictures, the App Resizability skill, the patterns to fix (main screen, orientation, idiom, regular ≠ iPad, device sizes, full-bleed media), test tools, App Store badge |
| https://developer.apple.com/forums/thread/847644 | **"A Summary of the iPhone Duo Group Lab"** — DTS, 17 posts of edited Q&A; cited as "DTS summary" |
| https://developer.apple.com/forums/activities/1659080 · /1664080 · /1670080 | the 2026-09-23 forum Q&As: Photos & Camera, SwiftUI, UIKit (134 threads, 78 with Apple answers) |
| https://developer.apple.com/news/?id=kkphp5qo | "Prepare and submit your apps for iPhone Duo" (2026-10-05) — badge, April 2027 screenshot requirement |
| https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo | **the developer article, 200** — resizing, vertical bars, item organization, arrangements, reserved regions, camera |
| https://developer.apple.com/documentation/UIKit/preparing-your-app-for-iphone-duo | still **404** — the article lives under `technologyoverviews`, not `UIKit` |
| https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo | HTML is JS-only; content at the `tutorials/data/…json` twin. Change log still 2026-09-09 |
| https://developer.apple.com/videos/play/tech-talks/111461/ … /111466/ | chapter list, **full official transcript** and Code sections, all inline in the HTML (see §Read a talk); YouTube ids in `device-and-platform.md` |
| https://developer.apple.com/videos/play/meet-with-apple/285/ · /286/ · /287/ · /288/ | iPhone Duo Group Labs, 2026-09-16, 2026-09-17, 2026-10-13 and 2026-10-15, ~60 min each; Apple engineers and designers answering questions. Captions only (see §Read a Meet with Apple lab) |
| https://antongubarenko.substack.com/p/iphone-duo-group-lab-101326-q-and | third-party recap of lab 287 (Q&A per question, YouTube timecodes ~2 min later than the captions). Checked against the captions on 2026-10-20 — use it to find a question, cite the lab |
| https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces | full camera article with code: virtual front camera, direction coordinator, descriptors, mirroring, rotation |
| https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo | scene-accessory article with code, SwiftUI **and** UIKit |
| https://developer.apple.com/documentation/updates/swiftui · /uikit · /avkit | "September 2026" sections enumerate every new Duo symbol |
| https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes · /xcode-27_2-release-notes | Xcode 27.1 and 27.2 RC release notes — Simulator and Device Hub known issues, Mac Catalyst issue, Previews Display group |
| https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27_2-release-notes | iOS 27.2 — default `UIView` layout margins are zero on iOS 27.1 and later |
| https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key | TN3192 — `UIRequiresFullScreen` deprecated, discrete resizing, `UIRequiresFullScreenIgnoredStartingWithVersion`, launch screen required |
| https://developer.apple.com/app-store/submitting/ | April 2027: iOS 27 SDK minimum, target iOS 15+ |
| https://developer.apple.com/videos/play/wwdc2026/278/ | "Modernize your UIKit app" — scene lifecycle requirement, `displayScale`, `effectiveGeometry`, `UIRequiresFullScreen` |
| https://developer.apple.com/documentation/technotes/tn3210-optimizing-your-app-for-iphone-mirroring | iPhone Mirroring as the pre-27.1 proxy |
| https://developer.apple.com/design/resources/ | Figma and Sketch design kits for iPhone Duo (lab 285 ~00:30) |
| https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications · /app-preview-specifications | iPhone Duo sizes, the badge, the April 2027 requirement (the old `reference/screenshot-specifications/` path redirects here) |
| https://www.apple.com/iphone-duo/specs/ · https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/ | hardware, dates |
| https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode | Xcode MCP bridge (JS-only page) |
| https://code.claude.com/docs/en/skills · https://code.claude.com/docs/en/sub-agents | skill / agent frontmatter reference |
| Related: WWDC26 269 "What's new in SwiftUI", WWDC26 341 "Support the Center Stage front camera in your iOS app", WWDC25 356 "Get to know the new design system"; TN3187 (scene lifecycle), TN3208 (launch screen); "Supporting device rotation in your camera app" | linked from the talks and the article |
| Third-party (unverified, not Apple): blakecrosley.com, pasqualepillitteri.it, bitrise.io, dev.to | point sizes, pose names (Touch ID is now on Apple's specs page; `devicectl appResize` turned out to be a real Apple command) |
