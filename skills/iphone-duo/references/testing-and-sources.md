# Testing iPhone Duo layouts, toolchain status, sources

Research date 2026-09-10 / 2026-09-11. Re-check §Freshness on first use after 2026-09-20.

## Toolchain gate — run before promising any new API

```bash
xcodebuild -version | head -1; xcode-select -p; xcrun --sdk iphoneos --show-sdk-version
ls /Applications | grep -i xcode
xcrun simctl list devicetypes | grep -i duo        # empty = no Duo simulator installed
```

| SDK reported | What you may write |
|---|---|
| < 27.0 | resizability work only: scene lifecycle, `UIScreen.main`, size classes, safe area, standard containers, windows |
| 27.0 | same; a 27.0 build also **fails to launch without the UIScene lifecycle** (TN3187) — use it to prove the BLOCKER |
| ≥ 27.1 | everything: reserved regions, arrangements, vertical-bar API, hinge, scene accessories, dual cameras |

Below 27.1, new symbols go into `// TODO:` comments and the report's **Pending iOS 27.1 SDK** section — never into code. Do not restructure working screens around assumptions about Duo geometry (hinge position, exact widths) — prepare boundaries, verify later. Pick a toolchain per call with `DEVELOPER_DIR=/Applications/Xcode-27.x.app/Contents/Developer`.

## What Apple provides — Xcode 27.1 + Device Hub

- **Xcode 27.1** contains the iPhone Duo SDK and simulator. Status on developer.apple.com/iphone-duo/ (2026-09-10): "Xcode 27.1 beta — Coming later this month."
- **Device Hub** replaces Simulator.app in Xcode 27. 111461 1:25: "Use the control buttons at the bottom of the screen to open, close, rotate, or fold iPhone Duo." — **buttons only; no documented CLI** (`simctl` has no fold/pose subcommand; `simctl ui` covers appearance / increase_contrast / content_size only).
- **Split View** in the simulator: drag the home indicator sideways to bring in a second app.
- Poses to cover: closed portrait, closed landscape, open flat portrait (the only horizontal-bar pose), open landscape, partially folded book (hinge vertical), table/laptop (hinge horizontal), tent; each with and without Split View; PiP stacking; scene accessory on/off for camera apps.
- **Not documented — do not invent:** the Duo `simctl` device-type identifier, a `#Preview` trait for Duo, Instruments templates for Duo. Third-party (bitrise.io) mentions `devicectl device appResize start/set/observe` and `devicectl device orientation` — unverified, not Apple.
- **App Resizability** — Xcode 27.1's renamed modernization agent skill (SwiftUI + iPhone Duo): converts `UIScreen.main` to traits, orientation checks to size classes, app → scene lifecycle, updates `UIRequiresFullScreen`. Export for other tools: `xcrun agent skills export` (Xcode 27, PROSE).

## Toolchain status at research time (2026-09-11, SDK re-check 2026-09-14)

| Item | State |
|---|---|
| Latest public Xcode | 26.6 — `xcrun --sdk iphoneos --show-sdk-version` → 26.5 |
| Xcode 27.0 Release Candidate | iOS 27.0 SDK (already carries the iOS 27.0-tier APIs listed in §Verify symbols); iOS 27.0 simulator runtime (24A5370g) |
| Duo device type | **none** in any released Xcode (`xcrun simctl list devicetypes \| grep -i duo` is empty) |
| `simctl` fold / pose command | none (`simctl ui` covers appearance / increase_contrast / content_size only) |
| `rg` | may be absent — use `grep -E` (BSD on macOS; `\|` is not alternation) |

## Proxies until Xcode 27.1 arrives

1. **Regular × regular on iOS 27.0**: any iPad simulator on the 27.0 runtime. Exercises the inner-display size class, sidebars, `NavigationSplitView` expansion. Does not exercise vertical bars, reserved regions, hinge.
2. **Compact × regular**: iPhone 18 Pro / 17 Pro on 27.0 — the outer-display class, plus the TN3187 launch check when built with the 27.0 SDK.
3. **Width-parameterized render tests** at 466 pt (outer) and 626 pt (inner) — **derived from @3x, not Apple-stated** — plus 313 pt (Split View half of 626). Pattern: host the view (or a `UIHostingController`) in a `UIWindow(frame: CGRect(x: 0, y: 0, width: w, height: h))`, call `layoutIfNeeded()`, then assert frames or snapshot; parameterize one test over the three widths. Label the numbers `derived` in test names. Also resize the same window mid-test (626 → 313 → 626) and assert that state survived: navigation depth, scroll offset, text-field contents, selection, playback position.
4. **Static analysis**: the grep audit (`audit-checklist.md`) — the biggest wins (`UIScreen.main`, cached widths, missing size classes, custom bars, scene lifecycle) need no simulator.
5. **Split View asymmetry** can be approximated on iPad simulators with Split View / Stage Manager — different insets, same class of bug.

A single screenshot is not verification: check several geometries and poses, a resize mid-session, Split View, and (with 27.1) reserved regions.

## Verify symbols against the SDK (once 27.1 is installed)

Anything marked PROSE / CAPTION / "verify" in the references — check before writing it:

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.1*.app/Contents/Developer   # adjust to the installed name
SDK=$(xcrun --sdk iphoneos --show-sdk-path); echo "$SDK"
grep -rhoE "reservedRegions|ArrangementView|arrangementViewStyle|onHingeChange|axisBehavior|toolbarVerticalEdge|toolbarVerticalBehavior|toolbarVerticalCompressionBehavior|ToolbarOverflowMenu|visibilityPriority|overlayArrangementZIndex|sceneAccessory|CameraCaptureAccessory|defaultTabBarPlacement|topBarPinnedTrailing|isTabViewSidebarAvailable|AnyLayout|containerRelativeFrame|onGeometryChange" \
  "$SDK/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/"*.swiftinterface \
  "$SDK/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/"*.swiftinterface | sort | uniq -c
# SwiftUICore holds the layout primitives (AnyLayout, HStackLayout, containerRelativeFrame, onGeometryChange) — grepping SwiftUI alone reports them as missing.
grep -rhoE "UIHingeInteraction|UIArrangementViewController|UISplitArrangement|UIViewReservedRegion|reservedRegions|verticalBarEdge|UIVerticalBarBehavior|preferredVerticalBarBehavior|verticalBarCompressionBehavior|axisBehavior|visibilityPriority" \
  "$SDK/System/Library/Frameworks/UIKit.framework/Headers/"*.h | sort | uniq -c
grep -rhoE "AVCaptureDeviceDirectionCoordinator|AVCaptureDeviceDescriptor|builtInOuterUltraWideCamera|builtInInnerUltraWideCamera|dynamicAspectRatio" \
  "$SDK/System/Library/Frameworks/AVKit.framework/Headers/"*.h "$SDK/System/Library/Frameworks/AVFoundation.framework/Headers/"*.h | sort | uniq -c
```

Availability of a found symbol: `grep -B6 '<symbol>' <file>` and read the nearest `API_AVAILABLE(ios(…))` / `@available(iOS …)` line above it. Result on the **iOS 27.0 SDK** (Xcode 27.0 RC, 2026-09-14): present with `iOS 27.0` — `ToolbarOverflowMenu`, `visibilityPriority` (SwiftUI + `UIBarButtonItem`), `.topBarPinnedTrailing`, `defaultTabBarPlacement`, `isTabViewSidebarAvailable`, `.sceneAccessory` modifier; present earlier — `tabBarPlacement` / `.sidebarAdaptable` (18), `additionalOverflowItems` / `pinnedTrailingGroup` (16), `UIWindowSceneActivationAction` (15), `AVCaptureDevice.AspectRatio` / `dynamicAspectRatio` / `isCameraSensorOrientationCompensationEnabled` (26); **absent (still 27.1)** — `axisBehavior`, `toolbarVerticalEdge` / `verticalBarEdge`, `toolbarVerticalBehavior`, `toolbarVerticalCompressionBehavior`, `UIVerticalBarBehavior`, `reservedRegions`, `ArrangementView`, `UIArrangementViewController`, `overlayArrangementZIndex`, `onHingeChange`, `UIHingeInteraction`, `CameraCaptureAccessory`, `AVCaptureDeviceDescriptor`, `builtInOuter/InnerUltraWideCamera` (AVKit ships an empty `AVCaptureDeviceDirectionCoordinator.h` stub). No Duo `simctl` device type in 27.0 RC.

## Xcode MCP as the tool provider

No custom MCP is needed for Duo: build / run / screenshot are covered by XcodeBuildMCP and Apple's own Xcode MCP bridge. Apple documents connecting external agents: Xcode → Settings → Intelligence → Model Context Protocol → "Allow external agents to use Xcode tools", then

```bash
claude mcp add --transport stdio xcode -- xcrun mcpbridge
```

(`https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode` — JS-rendered page; the command comes from a secondary report citing it.) Device Hub pose switching stays manual even with the bridge.

## Freshness — check on first use after 2026-09-20

1. `https://developer.apple.com/iphone-duo/` — has the Xcode 27.1 beta shipped?
2. `https://developer.apple.com/documentation/UIKit/preparing-your-app-for-iphone-duo` — was 404 "Coming later this month".
3. `https://developer.apple.com/documentation/updates/swiftui` and `https://developer.apple.com/documentation/updates/uikit` — not yet updated for 27.1; the first place official availability annotations will appear.
4. Xcode 27.1 release notes — not published as of 2026-09-10.
5. Run §Verify symbols on the 27.1 SDK; update status tags (PROSE / CAPTION → VERBATIM, or remove) across the references and the `Unverified` table in `device-and-platform.md`.
6. `xcrun simctl list devicetypes | grep -i duo` — record the device-type identifier once it exists.

### Machine-checkable signals (no JavaScript needed — usable from a cron / launchd script)

| Signal | Check | Baseline 2026-09-12 |
|---|---|---|
| Xcode 27.1 beta status on the landing page | `curl -s https://developer.apple.com/iphone-duo/ \| grep -c 'Coming later this month'` | 3 → drops when the beta ships |
| UIKit article published | `curl -s -o /dev/null -w '%{http_code}' https://developer.apple.com/tutorials/data/documentation/UIKit/preparing-your-app-for-iphone-duo.json` | 404 → 200 |
| Availability annotations | `curl -s https://developer.apple.com/tutorials/data/documentation/updates/uikit.json \| grep -c '27\.1'` (same for `swiftui`, `avfoundation`; `avkit.json` is 404 today) | 0 → > 0 |
| Xcode 27.1 listed by xcodereleases.com | `curl -s https://xcodereleases.com/data.json \| grep -c '"number":"27\.1'` | 0 → > 0 |
| Apple releases feed | `curl -s https://developer.apple.com/news/releases/rss/releases.rss \| grep -oE '<title>[^<]*</title>' \| grep -E '27\.1'` | none |
| Apple news feed | `curl -s https://developer.apple.com/news/rss/news.rss \| grep -oE '<title>[^<]*Duo[^<]*</title>'` | only "Get ready for iPhone Duo" |
| HIG page edited | `curl -s https://developer.apple.com/tutorials/data/design/human-interface-guidelines/designing-for-iphone-duo.json \| shasum -a 256` | hash change |
| Xcode release notes index | `curl -s https://developer.apple.com/tutorials/data/documentation/xcode-release-notes.json \| grep -oE '"title":"Xcode 27[^"]*"'` | "Xcode 27", "Xcode 27 RC Release Notes" |
| Duo simulator installed locally | `xcrun simctl list devicetypes \| grep -ci duo` | 0 → > 0 |

The `documentation/…` HTML pages are a JavaScript app; their `tutorials/data/…json` twins return real 404/200 and real content — check those.

## Read a talk

The talk pages are plain HTML — transcript and sample code are in the markup, no JavaScript needed. Use this instead of YouTube captions; it is the source every VERBATIM block and talk quote in these references was checked against (2026-09-16).

```bash
T=111463
curl -s -A "Mozilla/5.0" "https://developer.apple.com/videos/play/tech-talks/$T/" -o /tmp/$T.html
# transcript, one sentence per line with its start time in seconds
grep -o '<span data-start="[0-9.]*">[^<]*' /tmp/$T.html | sed 's/<span data-start="//;s/">/\t/'
# sample code: title + timecode
grep -oE 'data-start-time="[0-9]+"[^>]*>[^<]+' /tmp/$T.html
```

Prose names an API loosely — 111463 says "the reservedRegion method" while the Code section writes `reservedRegions(kind:)`. **The Code section wins**; the transcript is for intent and timecodes.

## Sources

| URL | Status (2026-09-10/11) |
|---|---|
| https://developer.apple.com/iphone-duo/ | landing; "Xcode 27.1 beta — Coming later this month" |
| https://developer.apple.com/news/?id=vn8abkxx | 2026-09-09 news post, no version details |
| https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo | HTML is JS-only; content at https://developer.apple.com/tutorials/data/design/human-interface-guidelines/designing-for-iphone-duo.json |
| https://developer.apple.com/videos/play/tech-talks/111461/ … /111466/ | chapter list, **full official transcript** and Code sections, all inline in the HTML (see §Read a talk); YouTube ids in `device-and-platform.md` |
| https://developer.apple.com/videos/play/wwdc2026/278/ | "Modernize your UIKit app" — scene lifecycle requirement, `displayScale`, `effectiveGeometry`, `UIRequiresFullScreen` |
| https://developer.apple.com/documentation/UIKit/preparing-your-app-for-iphone-duo | **404** |
| Xcode 27.1 release notes; `documentation/updates/{swiftui,uikit}` | not published / not updated |
| https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/ | iPhone Duo category present |
| https://developer.apple.com/news/upcoming-requirements/ | no Duo / iOS 27 requirement |
| https://www.apple.com/iphone-duo/specs/ · https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/ | hardware, dates |
| https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode | Xcode MCP bridge (JS-only page) |
| https://code.claude.com/docs/en/skills · https://code.claude.com/docs/en/sub-agents | skill / agent frontmatter reference |
| Related: WWDC26 269 "What's new in SwiftUI", WWDC26 341 "Support the Center Stage front camera in your iOS app", WWDC25 356 "Get to know the new design system"; TN3187 (scene lifecycle), TN3208 (launch screen); "Choosing a camera by the direction it faces", "Supporting device rotation in your camera app" | linked from the talks |
| Third-party (unverified, not Apple): blakecrosley.com, pasqualepillitteri.it, bitrise.io, dev.to | point sizes, Touch ID, `devicectl appResize`, pose names |
