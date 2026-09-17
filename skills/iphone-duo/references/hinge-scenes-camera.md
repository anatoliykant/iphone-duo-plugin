# Hinge, multiple scenes, scene accessories, cameras

Sources: tech talks 111464 "Leverage multiple displays and scenes on iPhone Duo" and 111465 "Build a great camera experience for iPhone Duo". Code blocks marked **VERBATIM** are from the talks' Code sections. Everything new here is **iOS 27.1 SDK**; EXISTING(iOS xx) items marked "verified" were read from the iOS 26.5 SDK.

## §Hinge

SwiftUI `onHingeChange`, UIKit `UIHingeInteraction` (PROSE). Both report a high-level **status** — closed, partially open, fully open — plus **continuous angle** updates. Only `.partiallyOpen` appears in code; `.closed` / `.fullyOpen` are prose spellings — verify.

**Hinge data is for interactions and effects, not layout.** Layout uses arrangements and reserved regions (`arrangements-and-reserved-regions.md`). Apple's demo: a guitar pitch bend driven by the fold angle.

```swift
// 111464 1:33 — Hold pitch bend as state                            VERBATIM
struct InstrumentView: View {
    /// Normalized bend, 0 is no bend, 1 is deepest bend
    @State private var pitchBend: Double = 0

    var body: some View {
        GuitarView(pitchBend: pitchBend)
    }
}
```

```swift
// 111464 1:44 — Add the onHingeChange modifier                      VERBATIM
struct InstrumentView: View {
    /// Normalized bend, 0 is no bend, 1 is deepest bend
    @State private var pitchBend: Double = 0

    var body: some View {
        GuitarView(pitchBend: pitchBend)
            .onHingeChange { _, context in

            }
    }
}
```

```swift
// 111464 1:57 — Check for a hinge and the partially open state      VERBATIM
var body: some View {
    GuitarView(pitchBend: pitchBend)
        .onHingeChange { _, context in
            // A null hinge means the device doesn't have one
            if let hinge = context.hinge, hinge.status == .partiallyOpen {

            }
        }
}
```

```swift
// 111464 2:10 — Reset the pitch bend                                VERBATIM
var body: some View {
    GuitarView(pitchBend: pitchBend)
        .onHingeChange { _, context in
            if let hinge = context.hinge, hinge.status == .partiallyOpen {

            }
            else {
                pitchBend = 0
            }
        }
}
```

```swift
// 111464 2:17 — Calculate the pitch bend from the hinge angle       VERBATIM
struct InstrumentView: View {
    /// Normalized bend, 0 is no bend, 1 is deepest bend
    @State private var pitchBend: Double = 0

    var body: some View {
        GuitarView(pitchBend: pitchBend)
            .onHingeChange { _, context in
                if let hinge = context.hinge, hinge.status == .partiallyOpen {
                    pitchBend = calculatePitchBend(angle: hinge.angle)
                }
                else {
                    pitchBend = 0
                }
            }
    }

    private func calculatePitchBend(angle: Angle) -> Double { ... }
}
```

Contract: the closure receives `(previous, context)`; `context.hinge` is `nil` on devices without a hinge (every other iPhone) — always handle it; filter for `.partiallyOpen`; **always add the `else` that resets the effect**. `hinge.angle` is a SwiftUI `Angle`.

### Anti-pattern — hinge angle as a layout input

```swift
// WRONG: conceptually broken, not just fragile
.onHingeChange { _, context in
    let angle = context.hinge?.angle.degrees ?? 180
    let x = angle / 180 * screenWidth
    button.offset(x: x)
}
```

The angle says nothing about where the usable regions are, and the system already moves interactive elements away from the fold. Anything that ends in `frame`, `offset`, `padding`, `width`, `columns` must come from size classes, `reservedRegions`, or an arrangement. Legitimate uses: audio/visual parameters, 3D/AR camera tilt, a game mechanic, haptics, a "laid on the table" mode that changes *content*, not geometry.

## §Scenes and displays

- **Split View**: all apps participate; two apps side by side. **Video + app stacking**: PiP pinned to the top, the app resizes vertically. Both are ordinary resizes — size classes + scene geometry, no special-casing.
- **Multiple scenes**: iPhone Duo is the **first iPhone that supports multiple instances of your app's UI**. Apps that support it on iPad get it here (`UIApplicationSupportsMultipleScenes = true` — inferred from iPad, not stated on a Duo page).
- **No API addresses a display.** `innerDisplay` / `outerDisplay` are not identifiers; your scene lives wherever the system puts it. The outer display is reachable only through `CameraCaptureAccessory` (below) or system-placed scenes — never plan a second "canvas".
- **New windows cannot be created on the outer display** — inner display only. Every scene request needs an error path.

```swift
// EXISTING(iOS 17) — request a scene with an error handler
let request = UISceneSessionActivationRequest(role: .windowApplication)
UIApplication.shared.activateSceneSession(for: request) { error in
    // On the outer display this fails — keep the content in the current scene
    presentInline()
}
```

Older spelling `requestSceneSessionActivation(_:userActivity:options:errorHandler:)` — EXISTING(iOS 13), deprecated in 17; same `errorHandler` idea.

Preferred in menus and context menus: `UIWindowScene.ActivationAction` (EXISTING(iOS 15, verified as `UIWindowSceneActivationAction`)) — 111464 4:11: it **"automatically hides when new windows aren't available"**. Apple's transcript spells it `UIWindowSceneActivationAction` (the Objective-C name of `UIWindowScene.ActivationAction`); the truncated "UIWindowSceneActivation" was a YouTube-caption artifact. Verify whether 27.1 adds anything beyond the auto-hide. SwiftUI `openWindow` on iOS is scene-request-backed as well; expect it to fail on the outer display.

Multi-scene hygiene (all EXISTING): state per scene, not per app singleton; present from `view.window?.windowScene`; no `UIApplication.shared.windows.first`; `UIWindow(windowScene:)` for every window (`layout-size-classes-safe-area.md` §Windows).

### Scene accessories (`.sceneAccessory` modifier iOS 27.0, verified; `CameraCaptureAccessory` 27.1)

Pair supplementary content with your main UI **across both displays at once**. The system controls availability dynamically; accessories are enabled by default but can be toggled; respond through observation tracking.

`CameraCaptureAccessory`: outer-display UI (teleprompter, preview for the person being filmed) while the main camera UI stays on the inner display. **Available only when the app is full screen on the inner display with an active camera session; register it on the same view as your camera UI.**

```swift
// 111464 5:43 — Register a camera capture accessory                 VERBATIM
struct CameraRootView: View {
    @State private var model = TeleprompterModel()

    var body: some View {
        CameraView(model: model)
            .sceneAccessory {
                CameraCaptureAccessory {
                    TeleprompterView(model: model)
                }
            }
    }
}
```

```swift
// 111464 6:14 — Add a toolbar toggle                                VERBATIM
struct CameraRootView: View {
    @State private var model = TeleprompterModel()

    var body: some View {
        CameraView(model: model)
            .sceneAccessory {
                CameraCaptureAccessory(isEnabled: $model.isEnabled) {
                    TeleprompterView(model: model)
                }
            }
            .toolbar {
                TeleprompterToggle(isEnabled: $model.isEnabled)
            }
    }
}
```

```swift
// 111464 6:25 — Observe accessory availability                      VERBATIM
struct CameraRootView: View {
    @State private var model = TeleprompterModel()

    var body: some View {
        CameraView(model: model)
            .sceneAccessory {
                CameraCaptureAccessory(isEnabled: $model.isEnabled) {
                    TeleprompterView(model: model)
                }
                .onAvailabilityChange { newValue in
                    model.isAvailable = newValue
                }
            }
            .toolbar {
                TeleprompterToggle(isEnabled: $model.isEnabled)
                    .disabled(!model.isAvailable)
            }
    }
}
```

Only `CameraCaptureAccessory` is documented — do not invent other accessory types, and do not plan generic outer-display companions (presenter notes, dashboards) until Apple documents one. The accessory view runs on the **outer** display → compact width, its own safe area and vertical-bar behavior; it needs its own camera direction coordinator if it shows a preview (§Camera).

## §Camera (111465)

### Hardware facts

First iPhone with **two front cameras**; both **square sensors with an ultrawide field of view**. Inner = first under-display camera on iPhone (1080p up to 60 fps). Outer = 12 MP Center Stage, corner, up to 4K / 120 fps. Rear: 48 MP Fusion Main + 48 MP Fusion Ultra Wide.

### Virtual front camera (zero-code path)

`AVCaptureDeviceDiscoverySession` with `position: .front` and a wide/ultrawide device type returns the **virtual front camera** on Duo: it switches to the inner camera when open and the outer when closed — automatically. It exposes only the **intersection** of capabilities: **1080p, 60 fps, no depth**. Enough for FaceTime-style and social apps; nothing to change.

### Individual cameras (full capability)

```swift
// Device types (names VERBATIM from 111465)
.builtInOuterUltraWideCamera   // outer front, up to 4K/120
.builtInInnerUltraWideCamera   // inner under-display front, 1080p/60
.builtInDualWideCamera         // rear (EXISTING)
```

Using them means **you** switch cameras when the device opens or closes.

```swift
// 111465 3:00 — Understand AVCaptureDevicePosition                  VERBATIM
enum AVCaptureDevicePosition: Int {
    case unspecified
    case back
    case front
}

extension AVCaptureDevice {
    // ...
    var position: AVCaptureDevicePosition { get }
}
```

Both front cameras report `.front`, but 111465 3:14: "things get more interesting on iPhone Duo, where displays can face opposite directions. This would mean a front camera is not always looking at you." Position is no longer enough — use **direction relative to your view**.

### Direction coordinator — lives in **AVKit**

`AVCaptureDeviceDirectionCoordinator(view:deviceTypes:changeHandler:)` reports which of the given device types are **forward-facing** (looking at the person who looks at `view`) or **backward-facing**. When the view is on the outer display the outer front camera is forward-facing and rear cameras backward-facing; opening the device moves the view to the inner display, the handler fires, and the inner front camera becomes forward-facing.

```swift
// 111465 4:06 — Initialize a direction coordinator                  VERBATIM
directionCoordinator = AVCaptureDeviceDirectionCoordinator(
    view: view,
    deviceTypes: [
        .builtInOuterUltraWideCamera,
        .builtInInnerUltraWideCamera,
        .builtInDualWideCamera,
    ],
    changeHandler: { [weak self] map in
        self?.updateCameraSession(map)
    }
)
```

Rules:
- **One coordinator per view / display.** A scene accessory on the outer display gets its own.
- The coordinator is view-bound → **main-actor isolated**. The change handler must not touch `AVCaptureSession` directly; it hands you **`AVCaptureDeviceDescriptor`** values (PROSE) — main-actor-safe and `Sendable` — which you pass to your camera actor to reconfigure the session.
- On a direction change: reconfigure inputs, and **mirror the preview when a rear camera is forward-facing** (PROSE).
- The CAPTION spelling `AVCaptureDeviceCoordinator` is wrong.

### Preview polish

The rear camera's full field of view on the inner display leaves extra space: offset the preview or let it fill. Control fit with `videoGravity` (EXISTING).

```swift
// 111465 7:30 — Configure the video preview layer                   VERBATIM
class AVCaptureVideoPreviewLayer {
    // ...

    var videoGravity: AVLayerVideoGravity { get set }
}
```

For the square ultrawide front sensors, select a landscape `dynamicAspectRatio` that fills the display. Resolved in the iOS 27.0 SDK — all `API_AVAILABLE(ios(26.0))`: `AVCaptureDevice.AspectRatio` (`AVCaptureAspectRatio`: 1:1, 16:9, 9:16, 4:3, 3:4); the property is read-only, the setter is `setDynamicAspectRatio(_:completionHandler:)` under `lockForConfiguration()`, and valid values come from `activeFormat.supportedDynamicAspectRatios`.

```swift
// 111465 7:51 — Select a dynamic aspect ratio                       VERBATIM
class AVCaptureDevice {
    // ...

    var dynamicAspectRatio: AVCaptureDevice.AspectRatio? { get }
}
```

### Rotation

Adopt `AVCaptureDeviceRotationCoordinator` (EXISTING(iOS 17)); on Duo it updates when the app moves between displays. **After adopting it, disable camera sensor orientation compensation** — it is enabled on all iPhone Duo front cameras and costs performance. `isCameraSensorOrientationCompensationEnabled` — EXISTING(iOS 26, verified on `AVCapturePhotoOutput`).

```swift
// 111465 8:34 — Disable sensor orientation compensation             VERBATIM
// Disable for improved performance
class AVCapturePhotoOutput: AVCaptureOutput {
    // ...

    var isCameraSensorOrientationCompensationEnabled: Bool { get set }
}
```

### Camera checklist

1. Virtual front camera enough? (no depth, ≤ 1080p60) → keep discovery by `.front`, done.
2. Else: enumerate `.builtInOuterUltraWideCamera` / `.builtInInnerUltraWideCamera`; add an **AVKit** direction coordinator per preview view; reconfigure via descriptors on your camera actor.
3. Mirror the preview when a rear camera faces forward.
4. `videoGravity` + `dynamicAspectRatio` for the square sensors.
5. Rotation coordinator + `isCameraSensorOrientationCompensationEnabled = false`.
6. Optional: `CameraCaptureAccessory` for the outer display (own view, own coordinator).
7. Test: open/close mid-session, Split View, both poses with the accessory enabled and disabled.

## Symbol status table

| Symbol | Status |
|---|---|
| `.onHingeChange { previous, context in }`, `context.hinge`, `hinge.status == .partiallyOpen`, `hinge.angle: Angle` | VERBATIM, 27.1 |
| `.closed`, `.fullyOpen` hinge statuses | PROSE |
| `UIHingeInteraction` | PROSE |
| `.sceneAccessory { }` (`SceneAccessoryContent`), `.onAvailabilityChange { }` | VERBATIM, EXISTING(iOS 27.0, verified — `@available(iOS 27.0)`) |
| `CameraCaptureAccessory { }`, `CameraCaptureAccessory(isEnabled:)` | VERBATIM, 27.1 (0 hits in the 27.0 SDK) |
| `UIWindowScene.ActivationAction` | EXISTING(iOS 15, verified); talk prose "UIWindowSceneActivation" |
| `UISceneSessionActivationRequest`, `activateSceneSession(for:errorHandler:)` | EXISTING(iOS 17) |
| `.builtInOuterUltraWideCamera`, `.builtInInnerUltraWideCamera` | VERBATIM, 27.1 |
| `AVCaptureDeviceDirectionCoordinator(view:deviceTypes:changeHandler:)` — **AVKit** | VERBATIM, 27.1 (the 27.0 SDK ships only an empty `AVCaptureDeviceDirectionCoordinator.h` stub in AVKit — no declaration yet) |
| `AVCaptureDeviceDescriptor` | PROSE, 27.1 (0 hits in the 27.0 SDK) |
| `AVCaptureDevice.dynamicAspectRatio`, `setDynamicAspectRatio(_:completionHandler:)`, `supportedDynamicAspectRatios`, `AVCaptureDevice.AspectRatio` | EXISTING(iOS 26, verified) |
| `AVCaptureVideoPreviewLayer.videoGravity`, `AVCaptureDeviceRotationCoordinator` | EXISTING |
| `AVCapturePhotoOutput.isCameraSensorOrientationCompensationEnabled` | EXISTING(iOS 26, verified) |
| `AVCaptureDeviceCoordinator` | CAPTION — wrong, never use |
