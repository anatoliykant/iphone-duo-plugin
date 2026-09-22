# Testing iPhone Duo layouts, toolchain status, sources

Research 2026-09-10/11. **SDK-verified 2026-09-21** against the iOS 27.1 SDK in Xcode 27.1 beta 1 (27A9269, released 2026-09-18). Re-check §Freshness on first use after **2026-10-23** (device ships) or as soon as an iOS 27.1 RC lands.

## Toolchain gate — the first thing you run, before anything else

**Detect the capability, never compare version numbers.** Xcode **27.2 beta 1** (27B5019j) shipped on
**2026-09-16**, two days *before* **27.1 beta 1** (27A9269) on **2026-09-18**, and it is not on the
same build train (27B vs 27A). A `>= 27.1` test passes 27.2 and then every Duo symbol fails to
compile. Ask the SDK what it contains instead:

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
  printf 'WARNING — no installed Xcode carries the iPhone Duo APIs.\n  Get the Xcode 27.1 beta: https://developer.apple.com/xcode/resources/\n  Until then do resizability work only and leave 27.1 symbols as // TODO:.\n'
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
- **Do not read the version out of `Contents/Info.plist`** — the 27.1 beta reports
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

- **Xcode 27.1 beta 1** (27A9269) ships the iOS 27.1 SDK and the iPhone Duo simulator. Verified locally 2026-09-21: `xcrun --sdk iphoneos --show-sdk-version` → `27.1`, `xcrun --sdk iphonesimulator --show-sdk-version` → `27.1`.
- **Simulator identifiers** (recorded once they existed — previously "not published"):

  | Thing | Identifier |
  |---|---|
  | Device type | `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo` |
  | Runtime | `com.apple.CoreSimulator.SimRuntime.iOS-27-1` (`27.1 - 24A94401`) |

- **Device Hub** replaces Simulator.app in Xcode 27. 111461 1:25: "Use the control buttons at the bottom of the screen to open, close, rotate, or fold iPhone Duo." Lab 285 adds that it renders the device in 3D as it moves through the poses. **Buttons only — still no documented CLI** (`simctl` has no fold/pose subcommand; `simctl ui` covers appearance / increase_contrast / content_size only).
- **Hinge angle plus rotation in 3D reaches every pose** except both displays lit at once, which needs a camera session and therefore a real device (lab 286 ~44:00).
- **Split View** in the simulator: drag the home indicator sideways to bring in a second app.
- Poses to cover: closed portrait, closed landscape, open flat portrait (the only horizontal-bar pose), open landscape, partially folded book (hinge vertical), table/laptop (hinge horizontal), tent; each with and without Split View; PiP stacking; scene accessory on/off for camera apps. **Also watch the transition between poses**, not just the resting states (lab 286 ~43:30; lab 285 ~42:00 on disorienting transitions).
- **Camera apps now launch in Simulator** (new in 27.1, lab 286 ~44:30): there is no camera, the preview stays empty and the app detects no capture device, but the surrounding UI is testable. Anything that depends on an actual capture session — scene accessories included — needs hardware.
- **Xcode 27.1 beta 1 known issues** (release notes): first Simulator launch can take several minutes; StandBy is unavailable in the Duo runtime; most app extensions cannot be run or debugged in the Duo runtime. Previews gained a **Display** group in the canvas overrides picker for previewing on a device's alternative display.
- **Not documented — do not invent:** Instruments templates for Duo. Third-party (bitrise.io) mentions `devicectl device appResize start/set/observe` and `devicectl device orientation` — unverified, not Apple.
- **App Resizability** — Xcode's modernization agent skill, **present only from 27.1** (`IDEIntelligenceChat.framework/.../app-resizability.idechatprompttemplate` plus five `app-resizability-ref-*-task.md` files; Xcode 27.0 has none of them). Its own description covers `mainScreen`, `interfaceOrientation`, `userInterfaceIdiom`, app → scene lifecycle and safe-area insets, and it treats "get my app ready for iPhone Duo" as a request for every task in its registry. Export it for other tools:

  ```bash
  DEVELOPER_DIR=/Applications/Xcode-27.1.0-Beta.app/Contents/Developer \
    xcrun agent skills export --output-dir <path> [--replace-existing]
  ```

## Proxies when 27.1 is not installed

1. **iPhone Mirroring** — Apple's own first recommendation (Technology Overviews; lab 285 ~21:30, lab 286 ~05:00): resize the mirrored window to a Duo-like aspect ratio. It keeps the **phone idiom**, so the frameworks behave the way they will on Duo. See TN3210 "Optimizing your app for iPhone Mirroring".
2. **iPad with window resizing** — drag the window through a continuum of sizes (lab 286 ~04:30). Exercises the inner-display size class, sidebars, `NavigationSplitView` expansion. Does not exercise vertical bars, reserved regions, hinge.
3. **Compact × regular**: iPhone 18 Pro / 17 Pro on 27.0 — the outer-display class, plus the TN3187 launch check when built with the 27.0 SDK.
4. **Width-parameterized render tests** at 466 pt (outer) and 626 pt (inner) — **derived from @3x, not Apple-stated** — plus 313 pt (Split View half of 626). Pattern: host the view (or a `UIHostingController`) in a `UIWindow(frame: CGRect(x: 0, y: 0, width: w, height: h))`, call `layoutIfNeeded()`, then assert frames or snapshot; parameterize one test over the three widths. Label the numbers `derived` in test names. Also resize the same window mid-test (626 → 313 → 626) and assert that state survived: navigation depth, scroll offset, text-field contents, selection, playback position.
5. **Static analysis**: the grep audit (`audit-checklist.md`) — the biggest wins (`UIScreen.main`, cached widths, missing size classes, custom bars, scene lifecycle) need no simulator.
6. **Split View asymmetry** can be approximated on iPad simulators with Split View / Stage Manager — different insets, same class of bug.

A single screenshot is not verification: check several geometries and poses, a resize mid-session, Split View, and the reserved regions.

## Verify symbols against the SDK

Anything marked PROSE / CAPTION / "verify" in the references — check before writing it:

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.1.0-Beta.app/Contents/Developer   # adjust to the installed name
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path); echo "$SDK"
grep -rhoE "reservedRegions|ReservedRegion|ArrangementView|ArrangementViewStyle|arrangementViewStyle|splitArrangement[A-Za-z]*|overlayArrangement[A-Za-z]*|onHingeChange|DeviceHinge|axisBehavior|toolbarVerticalEdge|toolbarVerticalBehavior|toolbarVerticalCompressionBehavior|ToolbarOverflowMenu|visibilityPriority|sceneAccessory|CameraCaptureAccessory|presentationPlacement|backgroundExtensionEffect|AnyLayout|containerRelativeFrame|onGeometryChange" \
  "$SDK/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/"*.swiftinterface \
  "$SDK/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/"*.swiftinterface | sort | uniq -c
# SwiftUICore holds the layout primitives and, on 27.1, DeviceHinge / ReservedRegion / the arrangement modifiers —
# grepping SwiftUI alone reports them as missing.
grep -rhoE "UIHingeInteraction|UIHinge|UIArrangementViewController|UIArrangement|UISplitArrangement|UIOverlayArrangement|UIViewReservedRegion|reservedRegionsOfKind|verticalBarEdge|UIVerticalBarEdge|UIVerticalBarBehavior|preferredVerticalBarBehavior|verticalBarCompressionBehavior|UIVerticalBarCompressionBehavior|axisBehavior|visibilityPriority|preferredPlacement|UIBackgroundExtensionView|layoutRegionForBarOnEdge|UISceneAccessory" \
  "$SDK/System/Library/Frameworks/UIKit.framework/Headers/"*.h | sort | uniq -c
grep -rhoE "AVCaptureDeviceDirectionCoordinator|AVCaptureDeviceDescriptor|AVCaptureDeviceDirectionMap|BuiltInOuterUltraWideCamera|BuiltInInnerUltraWideCamera|dynamicAspectRatio|activePrimaryConstituent" \
  "$SDK/System/Library/Frameworks/AVKit.framework/Headers/"*.h "$SDK/System/Library/Frameworks/AVFoundation.framework/Headers/"*.h | sort | uniq -c
```

Availability of a found symbol: `grep -B6 '<symbol>' <file>` and read the nearest `API_AVAILABLE(ios(…))` / `@available(iOS …)` line above it.

**Result on the iOS 27.1 SDK (Xcode 27.1 beta 1, 2026-09-21).** Every Duo symbol in these references is present and annotated; the reference tables carry the per-symbol tags. Two spellings to know:

- **UIKit reserved regions are refined for Swift.** The header declares `-reservedRegionsOfKind:` / `-reservedRegionsOfKind:options:` on a `UIView (ReservedRegion)` category with `NS_REFINED_FOR_SWIFT`, so a grep for `reservedRegions` in the headers returns **zero** — Swift still sees `reservedRegions(kind:options:)`. Grep `reservedRegionsOfKind` instead.
- **`UIViewLayoutRegion` is refined too** (`NS_REFINED_FOR_SWIFT`): `+layoutRegionForBarOnEdge:extent:` and `+layoutRegionForBarOnDirectionalEdge:extent:` surface in Swift as `UIView.LayoutRegion.bar(onEdge:extent:)`.

Earlier availability, unchanged: `ToolbarOverflowMenu`, `visibilityPriority` (SwiftUI + `UIBarButtonItem`), `.topBarPinnedTrailing`, `defaultTabBarPlacement`, `isTabViewSidebarAvailable`, the `.sceneAccessory` modifier, `presentationPlacement(_:)` / `UISheetPresentationController.preferredPlacement` — **iOS 27.0**; `tabBarPlacement` / `.sidebarAdaptable` — 18; `additionalOverflowItems` / `pinnedTrailingGroup` — 16; `UIWindowSceneActivationAction` — 15; `AVCaptureDevice.AspectRatio` / `dynamicAspectRatio` / `isCameraSensorOrientationCompensationEnabled`, `backgroundExtensionEffect()` / `UIBackgroundExtensionView`, `UIViewLayoutRegion` itself — 26.

## Xcode MCP as the tool provider

No custom MCP is needed for Duo: build / run / screenshot are covered by XcodeBuildMCP and Apple's own Xcode MCP bridge. Apple documents connecting external agents: Xcode → Settings → Intelligence → Model Context Protocol → "Allow external agents to use Xcode tools", then

```bash
claude mcp add --transport stdio xcode -- xcrun mcpbridge
```

(`https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode` — JS-rendered page; the command comes from a secondary report citing it.) Device Hub pose switching stays manual even with the bridge.

## Freshness — what is still open

Closed since the last pass: Xcode 27.1 beta shipped, the Duo simulator and runtime exist, the developer article was published (at a **different** path — see §Sources), `documentation/updates/{swiftui,uikit,avkit}` gained their "September 2026" sections, Xcode 27.1 Beta Release Notes are up.

Still to watch:

1. **iOS 27.1 RC / GM** — the availability annotations currently read `iOS 27.1 beta` on every Duo API page. When "beta" drops, re-run §Verify symbols and retag.
2. **Xcode 27.1 release** (non-beta) — `https://xcodereleases.com/data.json`.
3. **HIG page** — the change log still reads `September 9, 2026 | New page.`, but Apple edited the page anyway: between 2026-09-16 and 2026-09-21 the fold sentence changed from "the reserved region APIs" to "the `ReservedRegion` API", and a **Developer documentation** block appeared linking the article and both `ReservedRegion` pages. **Hash the JSON, do not trust the log.**
4. **Technology Overviews article** — no change log of its own; hash it.
5. **Apple forum Q&A 2026-09-23** (Photos & Camera, SwiftUI, UIKit) and the iPhone Duo Workshops announced on the landing page — future sources of answers.
6. **Device ships 2026-10-23** — re-check `UIRequiresFullScreen` discrete-resizing behavior and anything in `device-and-platform.md` §Unverified on hardware.

### Machine-checkable signals (no JavaScript needed — usable from a cron / launchd script)

| Signal | Check | Baseline 2026-09-21 |
|---|---|---|
| Duo API pages still beta | `curl -s https://developer.apple.com/tutorials/data/documentation/swiftui/arrangementview.json \| grep -c '"beta":true'` | > 0 → 0 when 27.1 goes RC |
| Developer article edited | `curl -s https://developer.apple.com/tutorials/data/documentation/technologyoverviews/preparing-your-app-for-iphone-duo.json \| shasum -a 256` | hash change |
| HIG page edited | `curl -s https://developer.apple.com/tutorials/data/design/human-interface-guidelines/designing-for-iphone-duo.json \| shasum -a 256` | hash change (it already grew a Developer documentation block) |
| Xcode 27.1 non-beta | `curl -s https://xcodereleases.com/data.json \| grep -c '"number":"27\.1","release":{"release"'` | 0 → > 0 (beta 1 is dated 2026-09-18) |
| Xcode release notes index | `curl -s https://developer.apple.com/tutorials/data/documentation/xcode-release-notes.json \| grep -oE '"title":"Xcode 27[^"]*"'` | "Xcode 27", "Xcode 27.1 Beta", "Xcode 27.2 Beta" |
| Apple releases feed | `curl -s https://developer.apple.com/news/releases/rss/releases.rss \| grep -oE '<title>[^<]*</title>' \| grep -E '27\.1'` | Xcode 27.1 beta, iOS 27.1 beta |
| Apple news feed | `curl -s https://developer.apple.com/news/rss/news.rss \| grep -oE '<title>[^<]*Duo[^<]*</title>'` | "Get ready for iPhone Duo" |
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
L=285
curl -s -A "Mozilla/5.0" "https://developer.apple.com/videos/play/meet-with-apple/$L/" -o /tmp/$L.html
M=$(grep -oE 'https://devstreaming-cdn.apple.com/videos/meet-with-apple/[^"]+cmaf\.m3u8' /tmp/$L.html | head -1)
B="${M%/*}/subtitles/en/"
curl -s "$B/prog_index.m3u8" | grep -v '^#' | while read -r seg; do curl -s "$B$seg"; done
# then keep lines with a "HH:MM:SS.mmm --> " cue, strip tags, drop repeats (the captions roll)
```

These are **auto-generated captions, not an edited transcript**. Use them for intent, guidance and timecodes; never for an API spelling, and never quote a panelist's "I believe" / "I'm not sure" as a fact — those belong in `device-and-platform.md` §Unverified.

## Sources

| URL | Status (2026-09-21) |
|---|---|
| https://developer.apple.com/iphone-duo/ | landing; "Xcode 27.1 beta" now links the betas page — "Coming later this month" is gone. Lists the Q&As, Workshops and Group Labs |
| https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo | **the developer article, 200** — resizing, vertical bars, item organization, arrangements, reserved regions, camera |
| https://developer.apple.com/documentation/UIKit/preparing-your-app-for-iphone-duo | still **404** — the article lives under `technologyoverviews`, not `UIKit` |
| https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo | HTML is JS-only; content at the `tutorials/data/…json` twin. Change log still 2026-09-09 |
| https://developer.apple.com/videos/play/tech-talks/111461/ … /111466/ | chapter list, **full official transcript** and Code sections, all inline in the HTML (see §Read a talk); YouTube ids in `device-and-platform.md` |
| https://developer.apple.com/videos/play/meet-with-apple/285/ · /286/ | iPhone Duo Group Labs, 2026-09-16 and 2026-09-17, ~60 min each; Apple engineers and designers answering questions. Captions only (see §Read a Meet with Apple lab) |
| https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces | full camera article with code: virtual front camera, direction coordinator, descriptors, mirroring, rotation |
| https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo | scene-accessory article with code, SwiftUI **and** UIKit |
| https://developer.apple.com/documentation/updates/swiftui · /uikit · /avkit | "September 2026" sections enumerate every new Duo symbol |
| https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes | Xcode 27.1 Beta Release Notes — Simulator known issues, Previews Display group |
| https://developer.apple.com/videos/play/wwdc2026/278/ | "Modernize your UIKit app" — scene lifecycle requirement, `displayScale`, `effectiveGeometry`, `UIRequiresFullScreen` |
| https://developer.apple.com/documentation/technotes/tn3210-optimizing-your-app-for-iphone-mirroring | iPhone Mirroring as the pre-27.1 proxy |
| https://developer.apple.com/design/resources/ | Figma and Sketch design kits for iPhone Duo (lab 285 ~00:30) |
| https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/ | iPhone Duo category present |
| https://www.apple.com/iphone-duo/specs/ · https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/ | hardware, dates |
| https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode | Xcode MCP bridge (JS-only page) |
| https://code.claude.com/docs/en/skills · https://code.claude.com/docs/en/sub-agents | skill / agent frontmatter reference |
| Related: WWDC26 269 "What's new in SwiftUI", WWDC26 341 "Support the Center Stage front camera in your iOS app", WWDC25 356 "Get to know the new design system"; TN3187 (scene lifecycle), TN3208 (launch screen); "Supporting device rotation in your camera app" | linked from the talks and the article |
| Third-party (unverified, not Apple): blakecrosley.com, pasqualepillitteri.it, bitrise.io, dev.to | point sizes, Touch ID, `devicectl appResize`, pose names |
