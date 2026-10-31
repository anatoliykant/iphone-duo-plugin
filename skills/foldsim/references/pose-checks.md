# What to check in each pose

`foldsim tour` puts the simulator through the poses and saves a screenshot of every display plus
the state; this file says what to look for. Open the screenshots — "settled" only means the hinge
and the rotation ended where asked, not that the layout is right. Record per pose what was checked,
what was seen and which file shows it.

The layout rules behind these checks live in the iphone-duo skill of this plugin (layout, bars,
the fold). This list is about seeing them in the simulator.

## 1. Both displays, every pose

| Pose (`foldsim pose …`) | Active display | Size, pt | Look for |
|---|---|---|---|
| `closed-portrait` | cover | 466 × 678 | the compact layout the app had on any iPhone |
| `closed-landscape` | cover | 678 × 466 | landscape only if the app allows it on the Duo (§3) |
| `tent` | cover, landscape-right | 678 × 466 | the same as closed landscape: the app sees a closed Duo, in the other landscape |
| `book` | inner, landscape, hinge 110° | 951 × 669 | nothing interactive on the vertical fold band (x ≈ 455–495), columns split at the fold, scrolling across it horizontal; a sheet shrinks to one pane, 459 pt with 12 pt in the band — the last column of a grid or calendar in it |
| `open-landscape` | inner | 951 × 669 | the regular layout, vertical bars at the side |
| `open-portrait` | inner | 669 × 951 | the only pose with horizontal bars |
| `table` | inner, portrait, hinge 110° | 669 × 951 | content in the top half, controls in the bottom half, nothing on the horizontal fold band (y ≈ 455–495) |

- **Continuity.** The tour ends where it began; compare its first and last screenshots. Scroll
  position, selection, text being typed and an open sheet should survive the trip.
- **Transitions, not only poses.** Run `foldsim hinge open` and `hinge closed` with the app on a
  screen that has state, and watch for a flash of the wrong layout or a lost scroll position. With a
  sheet up, fold to `book` and back: a grid in it that keeps its first width runs past the folded sheet
  or leaves a gap in the flat one.
- **Record the fold where a layout depends on it.** Flat and book differ only in the fold region's
  `isActive`, and a SwiftUI layout keyed to it jumps unless the app animates it, while UIKit layouts and
  sheets animate (iphone-duo skill, "A fold reaches SwiftUI without an animation"). Record the inner
  display — its `displayId` is in `foldsim --json state`, 3 on the simulator — around the move:

  ```bash
  xcrun simctl io <udid> recordVideo --display=3 --force fold.mov &   # stop it with kill -INT
  foldsim -d <udid> pose book
  ```

  The file gains a frame only when the picture changes; pull one out with
  `ffmpeg -ss <seconds> -i fold.mov -frames:v 1 frame.png`. Measured 2026-10-31: the recording showed a
  sheet sliding into the trailing pane.
- **An inactive display is black** in its screenshot; that is expected.

## 2. The hinge gate — Duo-only behaviour only on the Duo

An app that adds something only for the Duo (landscape on the cover, a split for the fold) gates it
on hinge presence: a flag latched from `UIHingeInteraction` (the iphone-duo skill, rule 14). Check
both directions:

1. Log the latch in the app, for example `Logger(subsystem: "<bundle id>", category: "duo").debug("hinge gate latched")`.
2. Read it on each simulator: `xcrun simctl spawn <udid> log stream --level debug --predicate 'subsystem == "<bundle id>"'`, or launch the app with `xcrun simctl launch --console-pty <udid> <bundle id>` when the app prints instead.
3. Expected: the line appears on the Duo right after launch, closed or open; it never appears on an
   iPhone 18 Pro Max or an iPad.
4. Run `foldsim tour` on all three and compare: Duo-only UI shows up only in the Duo's screenshots.

## 3. The orientation mask

Landscape added to the iPhone `UISupportedInterfaceOrientations` for the Duo's cover reaches every
iPhone. The app keeps other iPhones in portrait by returning `.portrait` from
`application(_:supportedInterfaceOrientationsFor:)` until the hinge gate latches. foldsim's exit
codes make that a scripted check:

| Simulator, app state | Command | Expected exit |
|---|---|---|
| Duo, closed | `foldsim -d <duo> pose closed-portrait && foldsim -d <duo> rotate landscape-left` | 0 |
| iPhone 18 Pro Max | `foldsim -d <iphone> rotate landscape-left` | 3, and `state` still says portrait |
| iPad | `foldsim -d <ipad> rotate landscape-left` | 0 even for a gated app — the iPad ignores the run-time mask (below); compare with the build before the Duo change, since rule 14 keeps the iPad as it was |

Exit 3 means the interface stayed put: that is the answer, not a tool failure. An iPhone and the
Duo's cover never show portrait upside down, so `rotate portrait-upside-down` gives 3 there for any
app. The iPad simulator (iPad Pro 13-inch (M5), iOS 27.2) turned a probe that returned `.portrait` from
`application(_:supportedInterfaceOrientationsFor:)` and has no `UIRequiresFullScreen` — the gated mask
holds iPhones in portrait, not iPads (measured 2026-10-30).

## 4. Render tests (snapshot tests)

On the Duo simulator, a window sized exactly like a Duo display — 466 × 678 or 669 × 951, either
orientation — is resized to the scene, at creation and on every fold or rotation. Tests that create
such a window measure the scene instead of the size they asked for.

- Create the window with `UIWindow(windowScene:)` at the scene's size and lay the view out in a child
  container of the size under test; assert the container's bounds before taking the snapshot.
- Put the simulator into a known pose before `xcodebuild test` (`foldsim -d <udid> pose closed-portrait`),
  so the scene size is the one the test expects.
- Run the suite on the Duo and on an iPhone 18 Pro Max: the iPhone keeps every window size, so a
  test that passes there and fails on the Duo is hitting the resize.
- A change to a shared component — a sheet, a bar, a cell used on many screens — needs every suite that
  renders it, in every pose, not only the new tests. In DMV a merge broke an older geometry test of a
  shared popup only on the open Duo.
- Suites that need the open Duo (two columns, the fold) fail on a closed one — eight failures in DMV's
  unit tests, green when open. Run them on their own after `foldsim pose open-landscape`, one run per pose.
- Open is two poses with one window: flat (`open-landscape`) and `book` differ only in the fold
  region's `isActive`. A test written for one fails in the other — pin the pose before the run, or
  branch the test on `isActive`.

The measured details are in the iphone-duo skill: `iphone-duo/references/testing-and-sources.md`
§Proxies, item 4.

## 5. Known simulator behaviour

- One continuous move switches displays between about 75° and 90°, opening or folding; a hinge that
  stops on the way keeps the display it had (folded in steps, the inner display held to 20°).
  `foldsim pose` takes care of it; with `foldsim hinge`, check `state` before judging a screenshot.
- iOS 27.2 runtime: angles between closed and open land within a few degrees of the request (90°
  reads 91.7°); 0° and 180° are exact.
- iOS 27.1 runtime: an instant jump between closed and open can leave the Duo unable to switch
  displays until it is recreated. foldsim never jumps; Device Hub's buttons can.
- Screenshots and recordings of a Duo can be black for a few minutes after boot (Xcode 27.2 RC known
  issue 187146039).
- A Duo shut down open came back closed (hinge 0°) in each of five reboots: run `foldsim state` after
  booting instead of assuming the pose. Opened right after the boot, it showed the inner display
  while devicectl kept marking the cover active; foldsim 1.4.0 took that for a failed open (exit 4),
  1.4.1 reads the displays' backlight instead.
- VoiceOver and Accessibility Inspector cannot read a Duo inside Device Hub (Xcode 27.2 RC); check
  accessibility on an iPhone or iPad simulator, or on hardware.
