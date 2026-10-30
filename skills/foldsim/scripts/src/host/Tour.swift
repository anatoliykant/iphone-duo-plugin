// Poses, the tour through them, and the self-test of the geometry they rely on.

import Foundation

/// The Duo poses the iphone-duo skill asks to check.
enum Pose: String, CaseIterable {
    case closedPortrait = "closed-portrait"
    case closedLandscape = "closed-landscape"
    case tent
    case book
    case openLandscape = "open-landscape"
    case openPortrait = "open-portrait"
    case table

    /// Which display a pose shows on.
    var role: Display.Role {
        switch self {
        case .closedPortrait, .closedLandscape, .tent: .cover
        default: .inner
        }
    }
}

extension Simulator {
    /// Puts a Duo into `pose` the way a hand would. Which display is active depends on how the hinge
    /// got there (Duo runtime 24B91014): one continuous move switches displays between about 75° and
    /// 90° either way, and a hinge that stops on the way keeps the display it had. So the book and
    /// table poses open fully and fold to 110° in one move, and the tent pose opens a closed Duo to 75°.
    func enter(_ pose: Pose) throws {
        guard device.kind == .duo else {
            throw FoldsimError(kind: .usage, message: "poses are for an iPhone Duo; use rotate on \(device.name)")
        }
        switch pose {
        case .closedPortrait:
            try moveHinge(to: 0)
            try rotate(to: .portrait)
        case .closedLandscape:
            try moveHinge(to: 0)
            try rotate(to: .landscapeLeft)
        case .tent:
            try moveHinge(to: 0)
            try rotate(to: .landscapeLeft)
            usleep(2_000_000)   // reopened right after closing, a Duo can switch to the inner display
            // Opening into a tent turns the cover's interface over (landscape-left becomes
            // landscape-right); the pose keeps what the simulator shows.
            try moveHinge(to: 75, seconds: 2)
        case .openLandscape:
            try moveHinge(to: 180)
            try rotate(to: .landscapeLeft)
        case .openPortrait:
            try moveHinge(to: 180)
            try rotate(to: .portrait)
        case .book:
            try moveHinge(to: 180)
            try rotate(to: .landscapeLeft)
            try moveHinge(to: 110)
        case .table:
            try moveHinge(to: 180)
            try rotate(to: .portrait)
            try moveHinge(to: 110)
        }
        // Right after the hinge moves, devicectl can briefly report the other display as active.
        guard try waitForActiveDisplay(timeout: 5, { $0.role == pose.role }) != nil else {
            throw FoldsimError(kind: .unsettled, message: "\(pose.rawValue) should show on the \(pose.role.rawValue) display, but it does not")
        }
    }

    /// Walks every pose of a Duo, or every orientation of an iPhone or iPad, and records each step:
    /// the state, and a screenshot of every display (an inactive Duo display is black). A refused
    /// orientation is part of the result, not a failure. Ends where it started, for comparison.
    func tour(into directory: URL) throws -> [[String: Any]] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let steps: [(name: String, enter: () throws -> Void)]
        switch device.kind {
        case .duo:
            steps = [Pose.closedPortrait, .closedLandscape, .tent, .book, .openLandscape, .openPortrait, .table, .closedPortrait]
                .map { pose in (pose.rawValue, { try enter(pose) }) }
        case .iphone, .ipad:
            let orientations: [Orientation] = device.kind == .ipad
                ? [.portrait, .landscapeLeft, .portraitUpsideDown, .landscapeRight, .portrait]
                : [.portrait, .landscapeLeft, .landscapeRight, .portrait]
            steps = orientations.map { orientation in (orientation.rawValue, { try rotate(to: orientation) }) }
        }
        var records: [[String: Any]] = []
        for (index, step) in steps.enumerated() {
            var record: [String: Any] = ["step": index + 1, "pose": step.name, "result": "ok"]
            do {
                try step.enter()
            } catch let error as FoldsimError where error.kind == .refused || error.kind == .unsettled {
                record["result"] = error.kind.rawValue
                record["note"] = error.message
            }
            usleep(1_000_000)   // let the app finish its layout before the screenshots
            var shots: [String] = []
            for display in try displays() {
                let file = String(format: "%02d-%@-%@.png", index + 1, step.name, display.role.rawValue)
                try screenshot(display, to: directory.appendingPathComponent(file).path)
                shots.append(file)
            }
            record["screenshots"] = shots
            record["state"] = try state()
            records.append(record)
        }
        let report: [String: Any] = ["device": ["udid": device.udid, "name": device.name, "kind": device.kind.rawValue,
                                                "runtime": device.runtime], "steps": records]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("tour.json"))
        try markdown(records).write(to: directory.appendingPathComponent("tour.md"), atomically: true, encoding: .utf8)
        return records
    }

    private func markdown(_ records: [[String: Any]]) -> String {
        var lines = ["# foldsim tour — \(device.name) (\(device.runtime))", "",
                     "| # | Pose | Result | Active display | Orientation | Size, pt | Hinge | Screenshots |",
                     "|---|---|---|---|---|---|---|---|"]
        for record in records {
            let state = record["state"] as? [String: Any] ?? [:]
            let active = (state["displays"] as? [[String: Any]] ?? []).first { $0["active"] as? Bool == true } ?? [:]
            let size = (active["points"] as? [Double])?.map(format).joined(separator: " × ") ?? "—"
            let hinge = (state["hingeAngle"] as? Double).map { "\(format($0))°" } ?? "—"
            let shots = (record["screenshots"] as? [String] ?? []).map { "[\($0)](\($0))" }.joined(separator: " ")
            lines.append("| \(record["step"] ?? "") | \(record["pose"] ?? "") | \(record["result"] ?? "") | \(active["role"] ?? "—") | "
                + "\(active["orientation"] ?? "—") | \(size) | \(hinge) | \(shots) |")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// Checks the geometry without a simulator. The samples are real: the probe app reported these
/// window points for a touch at panel (0.1, 0.2), Xcode 27.2 RC.
enum SelfTest {
    static func failures() -> [String] {
        var failures: [String] = []
        func display(_ role: Display.Role, _ width: Double, _ height: Double, _ scale: Double, _ rotation: String) -> Display {
            Display(role: role, id: 1, uuid: "", active: true, panelWidth: width, panelHeight: height, scale: scale, rotation: rotation)
        }
        let samples: [(Display, Double, Double)] = [
            (display(.cover, 1398, 2034, 3, "rot0"), 46.7, 135.7),
            (display(.inner, 2007, 2853, 3, "rot0"), 67, 190.3),
            (display(.inner, 2007, 2853, 3, "rot90"), 760.7, 67),
            (display(.inner, 2007, 2853, 3, "rot180"), 602, 760.7),
            (display(.inner, 2007, 2853, 3, "rot270"), 190.3, 602),
            (display(.main, 1320, 2868, 3, "rot90"), 764.7, 44),
            (display(.main, 1320, 2868, 3, "rot270"), 191.3, 396),
            (display(.main, 2064, 2752, 2, "rot90"), 1101, 103),
            (display(.main, 2064, 2752, 2, "rot180"), 929, 1101),
            (display(.main, 2064, 2752, 2, "rot270"), 275, 929),
        ]
        for (display, x, y) in samples {
            let panel = display.panelPoint(x: x, y: y)
            if abs(panel.x - 0.1) > 0.002 || abs(panel.y - 0.2) > 0.002 {
                failures.append("\(display.role.rawValue) \(display.rotation): (\(x), \(y)) maps to (\(panel.x), \(panel.y)), not (0.1, 0.2)")
            }
        }
        let inner = display(.inner, 2007, 2853, 3, "rot90").points
        if inner != (951, 669) { failures.append("the open Duo in landscape should be 951 × 669 pt, not \(inner)") }
        for orientation in Orientation.allCases {
            let rotation = ["portrait": "rot0", "landscape-left": "rot90", "portrait-upside-down": "rot180", "landscape-right": "rot270"][orientation.rawValue]!
            if Orientation(rotation: rotation) != orientation { failures.append("\(rotation) should read as \(orientation.rawValue)") }
        }
        // Device orientations measured to turn each display's interface (probe app, Xcode 27.2 RC).
        let turns: [(Display.Role, Orientation, DeviceOrientation)] = [
            (.cover, .landscapeRight, .landscapeLeft), (.cover, .landscapeLeft, .landscapeRight),
            (.inner, .portrait, .landscapeLeft), (.inner, .landscapeLeft, .portrait),
            (.inner, .portraitUpsideDown, .landscapeRight), (.inner, .landscapeRight, .portraitUpsideDown),
            (.main, .portraitUpsideDown, .portraitUpsideDown), (.main, .landscapeRight, .landscapeLeft),
        ]
        for (role, target, expected) in turns where DeviceOrientation.turning(role, to: target) != expected {
            failures.append("\(role.rawValue) \(target.rawValue) should come from device \(expected.devicectlName)")
        }
        return failures
    }
}
