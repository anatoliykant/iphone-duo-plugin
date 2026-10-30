// foldsim's probe app: logs what an app sees, so foldsim's commands can be checked against it.
// Every line on stderr is `PROBE <json>`: the window size and interface orientation, the hinge
// status and angle, the moment the hinge gate latches, and every touch in window points.
// PROBE_MASK (pass it as SIMCTL_CHILD_PROBE_MASK) picks the supported orientations:
//   all (default) · gated — portrait until the hinge gate latches, as the iphone-duo skill
//   recommends for landscape on the outer display · portrait

import SwiftUI
import UIKit

let orientationMask = ProcessInfo.processInfo.environment["PROBE_MASK"] ?? "all"

func log(_ fields: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else { return }
    FileHandle.standardError.write(Data("PROBE ".utf8) + data + Data("\n".utf8))
}

func name(_ orientation: UIInterfaceOrientation) -> String {
    switch orientation {
    case .portrait: "portrait"
    case .portraitUpsideDown: "portrait-upside-down"
    case .landscapeLeft: "landscape-left"
    case .landscapeRight: "landscape-right"
    default: "unknown"
    }
}

@MainActor enum HingeGate {
    static private(set) var deviceHasHinge = false

    static func install(on window: UIWindow) {
        window.addInteraction(UIHingeInteraction { [weak window] _, update in
            guard let hinge = update.hinge else { return }
            log(["event": "hinge", "status": hinge.status.rawValue, "degrees": (hinge.angle * 1800 / .pi).rounded() / 10])
            guard !deviceHasHinge else { return }
            deviceHasHinge = true
            log(["event": "gate"])
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        })
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        switch orientationMask {
        case "portrait": .portrait
        case "gated": HingeGate.deviceHasHinge ? .allButUpsideDown : .portrait
        default: .all
        }
    }
}

@main
struct ProbeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { WindowGroup { TouchSurface().ignoresSafeArea() } }
}

struct TouchSurface: UIViewRepresentable {
    func makeUIView(context: Context) -> TouchView { TouchView() }
    func updateUIView(_ view: TouchView, context: Context) {}
}

final class TouchView: UIView {
    private var reported = ""
    private var timer: Timer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        timer?.invalidate()
        guard let window else { return }
        backgroundColor = .systemTeal
        log(["event": "launch", "mask": orientationMask,
             "model": ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"])
        HingeGate.install(on: window)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.report() }
        }
    }

    private func report() {
        guard let window, let scene = window.windowScene else { return }
        let size = window.bounds.size
        let orientation = name(scene.effectiveGeometry.interfaceOrientation)
        let state = "\(size) \(orientation) \(HingeGate.deviceHasHinge)"
        guard state != reported else { return }
        reported = state
        log(["event": "window", "width": size.width, "height": size.height, "orientation": orientation,
             "gate": HingeGate.deviceHasHinge])
    }

    private func logTouches(_ touches: Set<UITouch>, _ phase: String) {
        for touch in touches {
            let point = touch.location(in: window)
            log(["event": "touch", "phase": phase, "x": (point.x * 10).rounded() / 10, "y": (point.y * 10).rounded() / 10,
                 "t": (touch.timestamp * 1000).rounded() / 1000])
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { logTouches(touches, "began") }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { logTouches(touches, "moved") }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { logTouches(touches, "ended") }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { logTouches(touches, "cancelled") }
}
