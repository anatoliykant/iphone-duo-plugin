# Hinge, multiple scenes, scene accessories, cameras

Sources: tech talks 111464 "Leverage multiple displays and scenes on iPhone Duo" and 111465 "Build a great camera experience for iPhone Duo", plus the two developer articles — "[Choosing a camera by the direction it faces](https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces)" (AVKit) and "[Registering a camera capture accessory on iPhone Duo](https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo)" (AVFoundation), which arrived after the talks and carry the full code. Blocks marked **VERBATIM** are copied from a talk Code section or an article. Everything new here is **iOS 27.1 SDK**, checked against it on 2026-09-21.

## §Hinge

SwiftUI `onHingeChange(isEnabled:_:)`, UIKit `UIHingeInteraction`. Both report a high-level **status** — closed, partially open, fully open — plus **continuous angle** updates. All three statuses are confirmed in the SDK, so the earlier "verify `.closed` / `.fullyOpen`" caveat is gone.

| | SwiftUI | UIKit |
|---|---|---|
| Entry point | `onHingeChange(isEnabled: Bool = true) { old, new in }` — both parameters are `DeviceHingeContext` | `UIHingeInteraction(updateHandler:)` added to a view; `.isEnabled` |
| Payload | `DeviceHingeContext.hinge: DeviceHinge?` | `UIHingeInteraction.Update.hinge: UIHinge?` — `nil` once the interaction leaves a hierarchy that provides hinge updates |
| Value | `DeviceHinge.status`, `.angle: Angle` | `UIHinge.status`, `.angle: CGFloat` |
| Statuses | `.closed`, `.partiallyOpen`, `.fullyOpen` | `.unknown`, `.closed`, `.partiallyOpen`, `.fullyOpen` |

`DeviceHinge` and `DeviceHingeContext` live in **SwiftUICore** — a grep of SwiftUI alone reports them missing.

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

#### The UIKit path (from the article, VERBATIM)

```swift
class CameraViewController: UIViewController {

    private let script = ScriptModel()
    private var registration: UISceneAccessoryRegistration?

    override func viewDidLoad() {
        super.viewDidLoad()

        let configuration = UISceneConfiguration()
        configuration.delegateClass = ScriptSceneDelegate.self

        let accessory = UISceneAccessory.cameraCapture(sceneConfiguration: configuration,
                                                       userInfo: script)
        registration = registerSceneAccessory(accessory)
    }
}
```

Rules the article states outright:

- **Keep a strong reference to the `UISceneAccessoryRegistration`.** Its `isAvailable` is set by the system only; its `isEnabled` is yours. Call `unregisterSceneAccessory(_:)` when you stop offering the content — do not just hide it.
- Availability supports observation, so reading `registration?.isAvailable` inside `updateProperties()` keeps controls current without a notification.
- The system assigns the session role; compare against **`windowCameraCaptureAccessory`** to recognize the scene. Accessory scenes have **no project-level configuration** — a scene-manifest entry for one has no effect.
- Pass shared state as `userInfo` and read it back from `connectionOptions.sceneAccessoryUserInfo` (iOS 27.0) when the scene connects. The accessory identifies the object; it is not storage — keep your own strong reference.
- Content is **on by default**; turning it off dismisses it. Persist anything that must survive in the model, not the view.

**When it disappears** (article + lab 286 37:40): capture stops, the app leaves the foreground, someone folds the device closed — **or the app enters Split View** (lab 286 38:11: "if you're in split view, when the iPhone Duo is open, then you also can't use scene accessories then"). Navigating to a view that registers its own content makes the previous registration unavailable, and going back restores it: the system presents the top-most registration of a kind. Different kinds never compete.

Only `CameraCaptureAccessory` / `cameraCapture(sceneConfiguration:)` is documented — do not invent other accessory types, and do not plan generic outer-display companions (presenter notes, dashboards) until Apple documents one. Lab 286 14:09 confirms there is no non-camera path today — showing content on both displays "is generally the camera accessory, which is really only for camera apps" — and lab 285 43:34 that "apps that have active camera sessions can use the inner and outer screens simultaneously". Kid Cam and Duo FaceTime are Apple's own examples. The glowing alarm clock on the inner display is **AlarmKit**, not an accessory (lab 286 14:21).

It is a **full UIScene**, not a widget: lab 286 33:05, "It's not like widgets where you have to be careful about what you what content you can put in them. You get a full UI scene and you can toss whatever you want in there." The accessory view runs on the **outer** display → compact width, its own safe area and vertical-bar behavior; it needs its own camera direction coordinator if it shows a preview (§Camera). Simulator has no camera, so this one is device-only.

## §Camera (111465)

### Hardware facts

First iPhone with **two front cameras**; both **square sensors with an ultrawide field of view**. Inner = first under-display camera on iPhone (1080p up to 60 fps). Outer = 12 MP Center Stage, corner, up to 4K / 120 fps. Rear: 48 MP Fusion Main + 48 MP Fusion Ultra Wide.

### Virtual front camera (zero-code path)

`AVCaptureDevice.DiscoverySession` with `position: .front` and a wide/ultrawide device type returns the **virtual front camera** on Duo: it switches to the inner camera when open and the outer when closed — automatically. It exposes only the **intersection** of capabilities: **1080p, 60 fps, no depth**. Enough for FaceTime-style and social apps; nothing to change.

The article makes two points the talk skips: the virtual front camera **is a virtual device**, so `isVirtualDevice` is `true` and "code that already handles the dual camera handles this one too"; and you can ask which physical camera is streaming through `activePrimaryConstituent` — `nil` until the session runs.

```swift
// Article "Choosing a camera by the direction it faces"           VERBATIM
final class DeviceLookup {

    // On iPhone Duo, these device types return the virtual front camera.
    private let frontCameraDiscoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera],
        mediaType: .video,
        position: .front
    )

    // The front camera to capture from, which is the virtual front camera on a device that has one.
    var frontCamera: AVCaptureDevice? {
        frontCameraDiscoverySession.devices.first
    }

    // The physical camera a virtual front camera streams from; this is `nil` until the session runs.
    func streamingCamera(for camera: AVCaptureDevice) -> AVCaptureDevice? {
        camera.isVirtualDevice ? camera.activePrimaryConstituent : camera
    }
}
```

"Capture from the two physical cameras when capture is your app's main job."

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

Rules, now all stated in the article:

- **List every built-in camera you capture from, including the rear ones** — a rear camera can be the forward-facing one, which is how someone takes a selfie with it. External, Continuity and Desk View cameras have no effect. **Leave the virtual front camera out** and list `.builtInOuterUltraWideCamera` and `.builtInInnerUltraWideCamera` in its place; the system already moves the virtual one for you.
- **One coordinator per view / display.** "An app that shows a preview on both displays creates a coordinator for each one. The same rear camera then comes back as forward facing from one coordinator and backward facing from the other." A scene accessory on the outer display gets its own.
- **Hold a strong reference** for as long as its view stays onscreen.
- **Create it and handle its updates on the main actor** — "It reports the direction cameras face in relation to a view, which is main-actor state."
- The handler fires **once soon after creation** with the directions in effect, then on every change; `deviceDirections` returns an **empty map** until that first call. So there is no separate "read the starting configuration" step.
- **Don't call AVFoundation from the change handler.** It hands you `AVCaptureDeviceDescriptor` values — `Sendable`, carrying `deviceType`, `mediaTypes`, `position`, `uniqueID`, `localizedName` — which you pass to the actor that owns the session.
- Compare your active camera against `forwardFacingDeviceDescriptors` rather than assuming it still faces the right way; pick a replacement from that array when it drops out.
- The CAPTION spelling `AVCaptureDeviceCoordinator` is wrong.

```swift
// Article "Choosing a camera by the direction it faces"           VERBATIM
actor CaptureService {

    private let captureSession = AVCaptureSession()
    private var activeVideoInput: AVCaptureDeviceInput?

    func selectCamera(with descriptor: AVCaptureDeviceDescriptor) throws {
        guard let device = AVCaptureDevice(uniqueID: descriptor.uniqueID) else {
            // The set of cameras changed again while dispatching.
            return
        }

        let newInput = try AVCaptureDeviceInput(device: device)

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if let activeVideoInput {
            captureSession.removeInput(activeVideoInput)
        }

        guard captureSession.canAddInput(newInput) else {
            // Restore the previous input if the new one doesn't fit the configuration.
            if let activeVideoInput { captureSession.addInput(activeVideoInput) }
            return
        }

        captureSession.addInput(newInput)
        activeVideoInput = newInput
    }
}
```

"A descriptor identifies a camera, and it doesn't reserve one" — handle the `nil` rather than force-unwrapping. And reconfigure **one video input** rather than running a multicamera session: "Reconfiguring one input costs less, and it covers what most apps need."

### Mirroring — decide it from direction, not position

"A capture connection mirrors the preview of any camera whose `position` is `AVCaptureDevice.Position.front`, which describes where the camera sits rather than where it points." So when a rear camera faces forward, mirror it yourself; when a front camera faces backward, present it unmirrored.

```swift
// Article "Choosing a camera by the direction it faces"           VERBATIM
private func applyVideoMirroring(from directionMap: AVCaptureDeviceDirectionMap) {
    // Assigning `isVideoMirrored` raises an exception when the connection doesn't support mirroring.
    guard let connection = previewConnection, connection.isVideoMirroringSupported else { return }

    let uniqueID = activeDevice.uniqueID
    let isFacingForward = directionMap.forwardFacingDeviceDescriptors
        .contains { $0.uniqueID == uniqueID }
    let isFacingBackward = directionMap.backwardFacingDeviceDescriptors
        .contains { $0.uniqueID == uniqueID }
    let isFrontCamera = activeDevice.position == .front

    // Take over mirroring only when a camera's position and its direction disagree.
    let needsOverride = (isFacingForward && !isFrontCamera) || (isFacingBackward && isFrontCamera)
    guard needsOverride else { return }

    // Assigning `isVideoMirrored` raises an exception while automatic adjustment stays on.
    connection.automaticallyAdjustsVideoMirroring = false
    connection.isVideoMirrored = isFacingForward
}
```

Call it on every map **and again after connecting a new device** — "removing and adding an input creates a preview connection that doesn't carry your override". Mask the preview while the swap happens: "frames from the outgoing camera reach the screen while the new camera starts."

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

Adopt `AVCaptureDevice.RotationCoordinator` (EXISTING(iOS 17)); on Duo "the angle also changes as your app moves between the two displays", and a coordinator reports angles **for the device you created it with** — so **create a new one each time you switch cameras** (article). **After adopting it, disable camera sensor orientation compensation** — it is enabled on all iPhone Duo front cameras and costs performance. `isCameraSensorOrientationCompensationEnabled` — EXISTING(iOS 26, verified on `AVCapturePhotoOutput`).

```swift
// 111465 8:34 — Disable sensor orientation compensation             VERBATIM
// Disable for improved performance
class AVCapturePhotoOutput: AVCaptureOutput {
    // ...

    var isCameraSensorOrientationCompensationEnabled: Bool { get set }
}
```

### Camera checklist

1. Virtual front camera enough? (no depth, ≤ 1080p60) → keep discovery by `.front`, done. It is a virtual device: `isVirtualDevice == true`, `activePrimaryConstituent` tells you which physical camera streams.
2. Else: enumerate `.builtInOuterUltraWideCamera` / `.builtInInnerUltraWideCamera` **plus every rear type you use**; add an **AVKit** direction coordinator per preview view, on the main actor, held strongly; reconfigure via descriptors on your camera actor (`AVCaptureDevice(uniqueID:)` may return `nil`).
3. Mirror from the direction map, not from `position`; re-apply after every input swap; mask the preview during the swap.
4. `videoGravity` + `dynamicAspectRatio` for the square sensors.
5. Rotation coordinator + `isCameraSensorOrientationCompensationEnabled = false`.
6. Optional: `CameraCaptureAccessory` for the outer display (own view, own coordinator).
7. Test: open/close mid-session, Split View, both poses with the accessory enabled and disabled.

## Symbol status table

| Symbol | Status |
|---|---|
| `.onHingeChange { previous, context in }`, `context.hinge`, `hinge.status == .partiallyOpen`, `hinge.angle: Angle` | VERBATIM · SDK(27.1 β1) |
| `DeviceHinge` / `DeviceHingeContext` (SwiftUICore); `.closed`, `.partiallyOpen`, `.fullyOpen` (`UIHingeStatus` adds `.unknown`) | SDK(27.1 β1) — was PROSE |
| `UIHingeInteraction(updateHandler:)`, `.isEnabled`, `UIHingeInteraction.Update.hinge`, `UIHinge` (`status`, `angle`) | SDK(27.1 β1) — was PROSE |
| `.sceneAccessory(content:)` (`SceneAccessoryContent`), `.onAvailabilityChange(perform:)` | VERBATIM · EXISTING(iOS 27.0) · SDK(27.1 β1) |
| `CameraCaptureAccessory { }`, `CameraCaptureAccessory(isEnabled:content:)` — **SwiftUI** (`SceneAccessoryContent`), not AVFoundation | VERBATIM · SDK(27.1 β1) |
| `UISceneAccessory.cameraCapture(sceneConfiguration:)` / `(sceneConfiguration:userInfo:)`, `registerSceneAccessory(_:)` → `UISceneAccessoryRegistration` (`isAvailable`, `isEnabled`), `unregisterSceneAccessory(_:)`, `windowCameraCaptureAccessory` role, `connectionOptions.sceneAccessoryUserInfo` | VERBATIM (article) · SDK(27.1 β1) |
| `UIWindowScene.ActivationAction` | EXISTING(iOS 15, verified); talk prose "UIWindowSceneActivation" |
| `UISceneSessionActivationRequest`, `activateSceneSession(for:errorHandler:)` | EXISTING(iOS 17) |
| `.builtInOuterUltraWideCamera`, `.builtInInnerUltraWideCamera` | VERBATIM · SDK(27.1 β1, `API_AVAILABLE(ios(27.1))`) |
| `AVCaptureDeviceDirectionCoordinator(view:deviceTypes:changeHandler:)`, `.deviceDirections` — **AVKit** | VERBATIM · SDK(27.1 β1, `API_AVAILABLE(ios(27.1), macCatalyst(27.1))`) |
| `AVCaptureDeviceDirectionMap` with `forwardFacingDeviceDescriptors` / `backwardFacingDeviceDescriptors` | VERBATIM (article) · SDK(27.1 β1) |
| `AVCaptureDeviceDescriptor` — `deviceType`, `mediaTypes`, `position`, `uniqueID`, `localizedName`; `Sendable` | VERBATIM (article) · SDK(27.1 β1) — was PROSE |
| `AVCaptureDevice.isVirtualDevice`, `.activePrimaryConstituent` | EXISTING |
| `AVCaptureDevice.dynamicAspectRatio`, `setDynamicAspectRatio(_:completionHandler:)`, `supportedDynamicAspectRatios`, `AVCaptureDevice.AspectRatio` | EXISTING(iOS 26, verified) |
| `AVCaptureVideoPreviewLayer.videoGravity`, `AVCaptureDevice.RotationCoordinator` | EXISTING(iOS 17) — one per capture device, recreate on every camera switch |
| `AVCapturePhotoOutput.isCameraSensorOrientationCompensationEnabled` | EXISTING(iOS 26, verified) |
| `AVCaptureDeviceCoordinator` | CAPTION — wrong, never use |
