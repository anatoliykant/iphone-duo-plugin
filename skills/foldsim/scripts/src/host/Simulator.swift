// What foldsim knows about a booted simulator and how it acts on it. Public tools come first —
// simctl and devicectl — and the in-simulator helper only does what they cannot: the Duo's hinge
// and rotation, and touches on any display.

import Foundation

struct FoldsimError: Error {
    enum Kind: String { case failed, usage, device, refused, unsettled }

    let kind: Kind
    let message: String
    var hint: String?

    var exitCode: Int32 {
        switch kind {
        case .failed: 1
        case .usage, .device: 2
        case .refused: 3
        case .unsettled: 4
        }
    }
}

// MARK: - Running Xcode's tools

struct Output {
    let status: Int32
    let stdout: Data
    let stderr: String
}

enum Xcrun {
    static func run(_ arguments: [String], timeout: TimeInterval = 60) throws -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        var stdout = Data(), stderr = Data()
        let reading = DispatchGroup()
        DispatchQueue.global().async(group: reading) { stdout = out.fileHandleForReading.readDataToEndOfFile() }
        DispatchQueue.global().async(group: reading) { stderr = err.fileHandleForReading.readDataToEndOfFile() }
        if reading.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            throw FoldsimError(kind: .failed, message: "xcrun \(arguments.prefix(4).joined(separator: " ")) did not finish in \(Int(timeout)) s")
        }
        process.waitUntilExit()
        return Output(status: process.terminationStatus, stdout: stdout, stderr: String(decoding: stderr, as: UTF8.self))
    }

    static func json(_ arguments: [String]) throws -> [String: Any] {
        let output = try run(arguments)
        guard output.status == 0, let object = try? JSONSerialization.jsonObject(with: output.stdout) as? [String: Any] else {
            throw FoldsimError(kind: .failed, message: "xcrun \(arguments.prefix(4).joined(separator: " ")) failed: \(output.stderr.trimmed)",
                               hint: output.stderr.contains("CoreSimulatorService")
                                   ? "a sandbox blocks the simulator service; run foldsim outside it (in Codex, approve running the command outside the sandbox)"
                                   : nil)
        }
        return object
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Devices

struct Device {
    enum Kind: String { case duo, iphone, ipad }

    let udid: String
    let name: String
    let kind: Kind
    let runtime: String

    static func booted() throws -> [Device] {
        let byRuntime = try Xcrun.json(["simctl", "list", "devices", "booted", "-j"])["devices"] as? [String: [[String: Any]]] ?? [:]
        return byRuntime.flatMap { runtime, devices in
            devices.compactMap { entry -> Device? in
                guard entry["state"] as? String == "Booted", let udid = entry["udid"] as? String else { return nil }
                let type = entry["deviceTypeIdentifier"] as? String ?? ""
                let kind: Kind = type.contains("iPhone-Duo") ? .duo : type.contains("iPad") ? .ipad : .iphone
                return Device(udid: udid, name: entry["name"] as? String ?? udid, kind: kind,
                              runtime: runtime.components(separatedBy: ".").last ?? runtime)
            }
        }.sorted { $0.name < $1.name }
    }

    /// `-d`, then FOLDSIM_DEVICE, then the only booted simulator. Never a guess between several:
    /// other sessions boot their own simulators on the same Mac.
    static func resolve(_ requested: String?) throws -> Device {
        let booted = try booted()
        if let requested = requested ?? ProcessInfo.processInfo.environment["FOLDSIM_DEVICE"], !requested.isEmpty {
            guard let device = booted.first(where: { $0.udid.caseInsensitiveCompare(requested) == .orderedSame }) else {
                throw FoldsimError(kind: .device, message: "no booted simulator has the UDID \(requested)",
                                   hint: "`foldsim devices` lists the booted ones")
            }
            return device
        }
        switch booted.count {
        case 1:
            return booted[0]
        case 0:
            throw FoldsimError(kind: .device, message: "no simulator is booted", hint: "boot one: xcrun simctl boot <udid>")
        default:
            throw FoldsimError(kind: .device, message: "\(booted.count) simulators are booted; pass -d <udid> or set FOLDSIM_DEVICE:\n"
                + booted.map { "  \($0.udid)  \($0.name) (\($0.kind.rawValue))" }.joined(separator: "\n"))
        }
    }
}

// MARK: - Displays

/// Interface orientations, named the way `UIInterfaceOrientation` names them.
enum Orientation: String, CaseIterable {
    case portrait
    case landscapeLeft = "landscape-left"
    case landscapeRight = "landscape-right"
    case portraitUpsideDown = "portrait-upside-down"

    /// devicectl's `currentOrientation` follows the interface. The same on the Duo's cover and inner
    /// displays, iPhone 18 Pro Max and iPad Pro 13-inch (measured with the probe app, Xcode 27.2 RC).
    init?(rotation: String) {
        switch rotation {
        case "rot0": self = .portrait
        case "rot90": self = .landscapeLeft
        case "rot180": self = .portraitUpsideDown
        case "rot270": self = .landscapeRight
        default: return nil
        }
    }

    var isLandscape: Bool { self == .landscapeLeft || self == .landscapeRight }
}

struct Display {
    enum Role: String { case cover, inner, main }

    let role: Role
    let id: Int
    let uuid: String
    let active: Bool
    /// The unrotated panel in pixels, as devicectl reports it whatever the rotation.
    let panelWidth: Double, panelHeight: Double
    let scale: Double
    let rotation: String

    var orientation: Orientation? { Orientation(rotation: rotation) }

    /// The interface size in points: the panel, turned with the interface.
    var points: (width: Double, height: Double) {
        let width = panelWidth / scale, height = panelHeight / scale
        return orientation?.isLandscape == true ? (height, width) : (width, height)
    }

    /// An interface point as normalized coordinates on the unrotated panel, which is what a
    /// digitizer reports.
    func panelPoint(x: Double, y: Double) -> (x: Double, y: Double) {
        let u = x / points.width, v = y / points.height
        switch orientation {
        case .landscapeLeft: return (v, 1 - u)
        case .portraitUpsideDown: return (1 - u, 1 - v)
        case .landscapeRight: return (1 - v, u)
        default: return (u, v)
        }
    }

    var json: [String: Any] {
        ["role": role.rawValue, "active": active, "displayId": id, "orientation": orientation?.rawValue ?? rotation,
         "points": [points.width, points.height], "pixels": [panelWidth, panelHeight], "scale": scale]
    }

    static func all(of device: Device) throws -> [Display] {
        let result = try Xcrun.json(["devicectl", "device", "info", "displays", "--device", device.udid, "--json-output", "-"])
        return parse((result["result"] as? [String: Any])?["displays"] as? [[String: Any]] ?? [], kind: device.kind)
    }

    static func parse(_ displays: [[String: Any]], kind: Device.Kind) -> [Display] {
        let entries = displays.filter { ($0["name"] as? String)?.hasPrefix("LCD") == true }
        // Opened right after it boots, a Duo shows the inner display while devicectl keeps `active` on
        // the cover for good; only the inner display's backlight is on then. Booted or just closed,
        // both backlights can be on, and `active` is right. Xcode 27.2 RC, runtime 24B91014.
        let lit = entries.filter { ($0["backlightState"] as? String)?.hasPrefix("active") == true }
        return entries.compactMap { entry -> Display? in
            guard let id = entry["displayId"] as? Int,
                  let uuid = entry["uniqueId"] as? String, let bounds = entry["bounds"] as? [[Double]],
                  bounds.count == 2, bounds[1].count == 2 else { return nil }
            let primary = entry["primary"] as? Bool ?? true
            let active = lit.count == 1 ? lit[0]["displayId"] as? Int == id : entry["active"] as? Bool ?? true
            return Display(role: kind == .duo ? (primary ? .cover : .inner) : .main, id: id, uuid: uuid,
                           active: active, panelWidth: bounds[1][0], panelHeight: bounds[1][1],
                           scale: entry["pointScale"] as? Double ?? 1, rotation: entry["currentOrientation"] as? String ?? "rot0")
        }.sorted { $0.id < $1.id }
    }
}

// MARK: - The helper inside the simulator

enum Helper {
    static func run(_ device: Device, _ arguments: [String], timeout: TimeInterval = 30) throws -> [String: Any] {
        guard let path = ProcessInfo.processInfo.environment["FOLDSIM_HELPER"] else {
            throw FoldsimError(kind: .failed, message: "FOLDSIM_HELPER is not set", hint: "run foldsim through scripts/foldsim, which builds it")
        }
        let output = try Xcrun.run(["simctl", "spawn", device.udid, path] + arguments, timeout: timeout)
        guard let reply = try? JSONSerialization.jsonObject(with: output.stdout) as? [String: Any] else {
            throw FoldsimError(kind: .failed, message: "the helper inside the simulator gave no answer (exit \(output.status)): \(output.stderr.trimmed)")
        }
        guard reply["ok"] as? Bool != true else { return reply }
        let error = reply["error"] as? [String: Any]
        throw FoldsimError(kind: .failed, message: error?["message"] as? String ?? "the helper failed",
                           hint: error?["kind"] as? String == "unavailable"
                               ? "a private simulator interface changed with this Xcode or runtime; use Device Hub until foldsim is updated"
                               : nil)
    }
}

// MARK: - Acting on a simulator

/// Device orientations, which Device Hub's event (Duo) and devicectl (iPhone, iPad) set.
enum DeviceOrientation: CaseIterable {
    case portrait, landscapeLeft, landscapeRight, portraitUpsideDown

    var helperName: String {
        switch self {
        case .portrait: "portrait"
        case .landscapeLeft: "landscape-left"
        case .landscapeRight: "landscape-right"
        case .portraitUpsideDown: "pud"
        }
    }

    var devicectlName: String {
        switch self {
        case .portrait: "portrait"
        case .landscapeLeft: "landscapeLeft"
        case .landscapeRight: "landscapeRight"
        case .portraitUpsideDown: "portraitUpsideDown"
        }
    }

    /// The device orientation that turns the interface to `target`. Device landscape-left is
    /// interface landscape-right, as in UIKit, and the Duo's inner display sits a quarter turn from
    /// its cover. Measured with the probe app on Xcode 27.2 RC.
    static func turning(_ role: Display.Role, to target: Orientation) -> DeviceOrientation {
        switch (role, target) {
        case (.inner, .portrait): .landscapeLeft
        case (.inner, .landscapeLeft): .portrait
        case (.inner, .landscapeRight): .portraitUpsideDown
        case (.inner, .portraitUpsideDown): .landscapeRight
        case (_, .portrait): .portrait
        case (_, .landscapeLeft): .landscapeRight
        case (_, .landscapeRight): .landscapeLeft
        case (_, .portraitUpsideDown): .portraitUpsideDown
        }
    }
}

struct Simulator {
    let device: Device

    func displays() throws -> [Display] {
        let displays = try Display.all(of: device)
        guard !displays.isEmpty else { throw FoldsimError(kind: .failed, message: "devicectl reports no display for \(device.name)") }
        return displays
    }

    func activeDisplay() throws -> Display {
        guard let display = try displays().first(where: \.active) else {
            throw FoldsimError(kind: .failed, message: "no display is active", hint: "is the simulator still booting?")
        }
        return display
    }

    /// Polls until the active display satisfies `condition`.
    func waitForActiveDisplay(timeout: TimeInterval, _ condition: (Display) -> Bool) throws -> Display? {
        let deadline = Date(timeIntervalSinceNow: timeout)
        repeat {
            if let display = try displays().first(where: { $0.active && condition($0) }) { return display }
            usleep(300_000)
        } while Date() < deadline
        return nil
    }

    func hingeAngle() throws -> Double? {
        guard device.kind == .duo else { return nil }
        return try Helper.run(device, ["angle"])["angle"] as? Double
    }

    func state() throws -> [String: Any] {
        let displays = try displays()
        var state: [String: Any] = ["udid": device.udid, "name": device.name, "kind": device.kind.rawValue,
                                    "runtime": device.runtime, "displays": displays.map(\.json),
                                    "active": displays.first(where: \.active)?.role.rawValue ?? NSNull()]
        if device.kind == .duo {
            state["hingeAngle"] = try hingeAngle().map { ($0 * 10).rounded() / 10 } ?? NSNull()
        }
        return state
    }

    // MARK: Hinge

    /// Moves a Duo's hinge at Device Hub's pace (60° a second unless `seconds` says otherwise, never
    /// an instant jump) and waits for the angle and, at 0° or 180°, for the matching display.
    @discardableResult
    func moveHinge(to degrees: Double, seconds: Double? = nil, tolerance: Double = 6) throws -> Double? {
        guard device.kind == .duo else {
            throw FoldsimError(kind: .usage, message: "\(device.name) has no hinge", hint: "use rotate on an iPhone or iPad")
        }
        let target = min(max(degrees, 0), 180)
        let current = try hingeAngle() ?? 0
        let duration = max(seconds ?? abs(target - current) / 60, 0.4)
        let reply = try Helper.run(device, ["hinge", "\(target)", "\(duration)", "\(tolerance)"], timeout: duration + 20)
        let angle = reply["angle"] as? Double
        guard reply["settled"] as? Bool == true else {
            throw FoldsimError(kind: .unsettled, message: "the hinge reads \(angle.map { "\(Int($0.rounded()))°" } ?? "nothing") after moving to \(Int(target))°")
        }
        let expected: Display.Role? = target <= 5 ? .cover : target >= 175 ? .inner : nil
        if let expected, try waitForActiveDisplay(timeout: 6, { $0.role == expected }) == nil {
            throw FoldsimError(kind: .unsettled, message: "the \(expected.rawValue) display did not become active at \(Int(target))°",
                               hint: "a Duo on the iOS 27.1 runtime can get stuck after an instant open or close; recreate that simulator")
        }
        return angle
    }

    // MARK: Rotation

    private func send(_ orientation: DeviceOrientation) throws {
        if device.kind == .duo {
            _ = try Helper.run(device, ["orient", orientation.helperName])
        } else {
            let output = try Xcrun.run(["devicectl", "device", "orientation", "set", "--device", device.udid, orientation.devicectlName])
            guard output.status == 0 else {
                throw FoldsimError(kind: .failed, message: "devicectl could not set \(orientation.devicectlName): \(output.stderr.trimmed)")
            }
        }
    }

    /// Turns the active display's interface to `target`. When the interface stays put, the app or
    /// the system refused: the device is turned back and the error says so (exit code 3). Where the
    /// display ends up is read back, never assumed.
    @discardableResult
    func rotate(to target: Orientation) throws -> Display {
        let start = try activeDisplay()
        guard start.orientation != target else { return start }
        let preferred = DeviceOrientation.turning(start.role, to: target)
        try send(preferred)
        if let turned = try waitForActiveDisplay(timeout: 2.5, { $0.role == start.role && $0.orientation == target }) {
            return turned
        }
        // It turned, but not where the table says: a runtime changed the mapping, so try the rest.
        if try activeDisplay().rotation != start.rotation {
            for candidate in DeviceOrientation.allCases where candidate != preferred {
                try send(candidate)
                if let turned = try waitForActiveDisplay(timeout: 2, { $0.role == start.role && $0.orientation == target }) {
                    return turned
                }
            }
        }
        if let original = start.orientation { try? send(DeviceOrientation.turning(start.role, to: original)) }
        // Turning the device back can turn the display instead where the hinge has turned it over: a
        // tent shows the cover upside down, so there the table is half a turn off.
        usleep(2_500_000)
        let end = try activeDisplay()
        if end.role == start.role && end.orientation == target { return end }
        guard end.role == start.role && end.orientation == start.orientation else {
            throw FoldsimError(kind: .unsettled,
                               message: "the \(end.role.rawValue) display ended \(end.orientation?.rawValue ?? end.rotation), not \(target.rawValue)")
        }
        throw FoldsimError(kind: .refused,
                           message: "the \(start.role.rawValue) display stayed \(start.orientation?.rawValue ?? start.rotation): \(target.rawValue) was refused",
                           hint: target == .portraitUpsideDown && start.role != .inner && device.kind != .ipad
                               ? "iPhones never show portrait upside down"
                               : "the app's supported orientations do not include \(target.rawValue) here")
    }

    // MARK: Touches and screenshots

    /// Presses at the first point (interface points of the active display), moves through the rest
    /// over `seconds` — or holds that long for a single point — and lifts.
    func touch(_ points: [(x: Double, y: Double)], seconds: Double) throws {
        let display = try activeDisplay()
        let size = display.points
        for point in points where !(0...size.width ~= point.x && 0...size.height ~= point.y) {
            throw FoldsimError(kind: .usage, message: "(\(format(point.x)), \(format(point.y))) is outside the \(display.role.rawValue) display, which is \(format(size.width)) × \(format(size.height)) pt")
        }
        let panel = points.map { display.panelPoint(x: $0.x, y: $0.y) }
        _ = try Helper.run(device, ["touch", display.uuid, "\(seconds)"] + panel.map { String(format: "%.5f,%.5f", $0.x, $0.y) },
                           timeout: seconds + 20)
    }

    func screenshot(_ display: Display, to path: String) throws {
        let output = try Xcrun.run(["simctl", "io", device.udid, "screenshot", "--display=\(display.id)", path])
        guard output.status == 0 else {
            throw FoldsimError(kind: .failed, message: "simctl could not capture the \(display.role.rawValue) display: \(output.stderr.trimmed)")
        }
    }
}

func format(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
}
