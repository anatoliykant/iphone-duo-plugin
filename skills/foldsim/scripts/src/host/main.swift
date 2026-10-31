// foldsim — drive iOS simulators for layout checks: fold and rotate an iPhone Duo, rotate an
// iPhone or iPad, touch any display, and capture what each display shows. scripts/foldsim builds
// this host and the in-simulator helper, then runs this with FOLDSIM_HELPER and FOLDSIM_VERSION set.

import Foundation

let usage = """
    usage: foldsim [-d <udid>] [--json] <command>

      devices                       booted simulators and their kind (duo, iphone, ipad)
      state                         each display: active, orientation, size; the hinge angle on a Duo
      hinge <degrees|closed|half|open> [--duration <s>] [--tolerance <degrees>]
      pose <closed-portrait|closed-landscape|tent|book|open-landscape|open-portrait|table>
      rotate <portrait|landscape-left|landscape-right|portrait-upside-down>
      tap <x> <y>                   interface points of the active display
      press <x> <y> [--duration <s>]
      swipe <x1> <y1> <x2> <y2> [--duration <s>]
      screenshot -o <file.png> [--display active|cover|inner|both]
      tour [--out <directory>]      every pose of a Duo, or orientation of an iPhone or iPad
      doctor                        the toolchain and the private interfaces of the booted runtime
      build | selftest | --version

    -d picks a booted simulator by UDID (or set FOLDSIM_DEVICE); without it foldsim needs exactly one.
    Exit codes: 0 ok · 1 tool or runtime failure · 2 usage or device · 3 refused by the app or system ·
    4 did not settle.
    """

var deviceOption: String?
var json = false
var options: [String: String] = [:]
var words: [String] = []

func emit(_ object: [String: Any], _ text: @autoclosure () -> String) {
    if json {
        var object = object
        object["ok"] = true
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        print(String(decoding: data, as: UTF8.self))
    } else {
        print(text())
    }
}

func fail(_ error: FoldsimError) -> Never {
    if json {
        var detail: [String: Any] = ["kind": error.kind.rawValue, "message": error.message]
        detail["hint"] = error.hint
        let data = (try? JSONSerialization.data(withJSONObject: ["ok": false, "error": detail], options: [.sortedKeys])) ?? Data()
        print(String(decoding: data, as: UTF8.self))
    } else {
        FileHandle.standardError.write(Data("foldsim: \(error.message)\n\(error.hint.map { "  \($0)\n" } ?? "")".utf8))
    }
    exit(error.exitCode)
}

func usageError(_ message: String) -> FoldsimError {
    FoldsimError(kind: .usage, message: message, hint: "run foldsim --help")
}

func number(_ text: String?, _ what: String) throws -> Double {
    guard let text, let value = Double(text), value >= 0 else { throw usageError("\(what) must be a number ≥ 0") }
    return value
}

func describe(_ state: [String: Any]) -> String {
    var lines = ["\(state["name"] ?? "") \(state["udid"] ?? "") · \(state["kind"] ?? "") · \(state["runtime"] ?? "")"
        + ((state["hingeAngle"] as? Double).map { " · hinge \(format($0))°" } ?? "")]
    for display in state["displays"] as? [[String: Any]] ?? [] {
        let size = (display["points"] as? [Double])?.map(format).joined(separator: " × ") ?? "?"
        let marker = display["active"] as? Bool == true ? "▸" : " "
        lines.append("\(marker) \("\(display["role"] ?? "")".padding(toLength: 6, withPad: " ", startingAt: 0)) "
            + "\("\(display["orientation"] ?? "")".padding(toLength: 21, withPad: " ", startingAt: 0)) \(size) pt")
    }
    return lines.joined(separator: "\n")
}

func run() throws {
    var arguments = Array(CommandLine.arguments.dropFirst())[...]
    while let argument = arguments.popFirst() {
        switch argument {
        case "-d", "--device": deviceOption = arguments.popFirst()
        case "--json": json = true
        case "-h", "--help", "help": print(usage); exit(0)
        case "--version": print("foldsim \(ProcessInfo.processInfo.environment["FOLDSIM_VERSION"] ?? "?")"); exit(0)
        case "-o", "--out", "--duration", "--tolerance", "--display":
            guard let value = arguments.popFirst() else { throw usageError("\(argument) needs a value") }
            options[argument == "-o" ? "--out" : argument] = value
        default:
            guard !argument.hasPrefix("-") else { throw usageError("unknown option \(argument)") }
            words.append(argument)
        }
    }
    guard let command = words.first else { print(usage); exit(2) }
    let rest = Array(words.dropFirst())

    switch command {
    case "selftest":
        let failures = SelfTest.failures()
        guard failures.isEmpty else { throw FoldsimError(kind: .failed, message: "selftest failed:\n" + failures.joined(separator: "\n")) }
        emit(["selftest": "passed"], "selftest passed")
        return
    case "build":
        let helper = ProcessInfo.processInfo.environment["FOLDSIM_HELPER"] ?? "?"
        emit(["host": CommandLine.arguments[0], "helper": helper], "built:\n  \(CommandLine.arguments[0])\n  \(helper)")
        return
    case "devices":
        let devices = try Device.booted()
        emit(["devices": devices.map { ["udid": $0.udid, "name": $0.name, "kind": $0.kind.rawValue, "runtime": $0.runtime] }],
             devices.isEmpty ? "no simulator is booted" : devices.map { "\($0.udid)  \($0.name) (\($0.kind.rawValue), \($0.runtime))" }.joined(separator: "\n"))
        return
    default:
        break
    }

    let device = try Device.resolve(deviceOption)
    if deviceOption == nil, ProcessInfo.processInfo.environment["FOLDSIM_DEVICE"] == nil {
        FileHandle.standardError.write(Data("foldsim: using \(device.name) \(device.udid)\n".utf8))
    }
    let simulator = Simulator(device: device)

    switch (command, rest.count) {
    case ("state", 0):
        let state = try simulator.state()
        emit(state, describe(state))

    case ("hinge", 1):
        let named = ["closed": 0.0, "close": 0, "half": 90, "open": 180]
        let degrees = try named[rest[0]] ?? number(rest[0], "the angle")
        let seconds = try options["--duration"].map { try number($0, "--duration") }
        let tolerance = try options["--tolerance"].map { try number($0, "--tolerance") } ?? 6
        try simulator.moveHinge(to: degrees, seconds: seconds, tolerance: tolerance)
        let state = try simulator.state()
        emit(state, describe(state))

    case ("pose", 1):
        guard let pose = Pose(rawValue: rest[0]) else {
            throw usageError("unknown pose \(rest[0]); poses: \(Pose.allCases.map(\.rawValue).joined(separator: ", "))")
        }
        try simulator.enter(pose)
        let state = try simulator.state()
        emit(state, describe(state))

    case ("rotate", 1):
        guard let orientation = Orientation(rawValue: rest[0]) else {
            throw usageError("unknown orientation \(rest[0]); use \(Orientation.allCases.map(\.rawValue).joined(separator: ", "))")
        }
        try simulator.rotate(to: orientation)
        let state = try simulator.state()
        emit(state, describe(state))

    case ("tap", 2), ("press", 2):
        let point = (x: try number(rest[0], "x"), y: try number(rest[1], "y"))
        let seconds = command == "tap" ? 0.08 : try options["--duration"].map { try number($0, "--duration") } ?? 1
        try simulator.touch([point], seconds: seconds)
        emit(["x": point.x, "y": point.y], "\(command) (\(format(point.x)), \(format(point.y)))")

    case ("swipe", 4):
        let values = try rest.map { try number($0, "a coordinate") }
        let seconds = try options["--duration"].map { try number($0, "--duration") } ?? 0.3
        try simulator.touch([(values[0], values[1]), (values[2], values[3])], seconds: seconds)
        emit(["from": [values[0], values[1]], "to": [values[2], values[3]]],
             "swipe (\(format(values[0])), \(format(values[1]))) → (\(format(values[2])), \(format(values[3])))")

    case ("screenshot", 0):
        guard let path = options["--out"] else { throw usageError("screenshot needs -o <file.png>") }
        let displays = try simulator.displays()
        let which = options["--display"] ?? "active"
        var targets: [(Display, String)]
        switch which {
        case "active":
            guard let display = displays.first(where: \.active) else { throw FoldsimError(kind: .failed, message: "no display is active") }
            targets = [(display, path)]
        case "cover", "inner":
            guard let display = displays.first(where: { $0.role.rawValue == which }) else {
                throw usageError("\(device.name) has no \(which) display")
            }
            targets = [(display, path)]
        case "both":
            let stem = (path as NSString).deletingPathExtension, ext = (path as NSString).pathExtension.isEmpty ? "png" : (path as NSString).pathExtension
            targets = displays.map { ($0, "\(stem)-\($0.role.rawValue).\(ext)") }
        default:
            throw usageError("--display takes active, cover, inner or both")
        }
        for (display, file) in targets { try simulator.screenshot(display, to: file) }
        // The state goes with the files: two poses can look the same in a picture.
        let state = try simulator.state()
        emit(["files": targets.map(\.1), "state": state], (targets.map(\.1) + [describe(state)]).joined(separator: "\n"))

    case ("tour", 0):
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
        let directory = URL(fileURLWithPath: options["--out"] ?? "foldsim-tour-\(device.kind.rawValue)-\(stamp)")
        let records = try simulator.tour(into: directory)
        let problems = records.filter { $0["result"] as? String != "ok" }
        emit(["directory": directory.path, "steps": records],
             "tour of \(device.name): \(records.count) steps, \(problems.count) refused or unsettled\n\(directory.path)/tour.md")
        if problems.contains(where: { $0["result"] as? String == "unsettled" }) { exit(4) }

    case ("doctor", 0):
        let checks = try Helper.run(device, ["doctor"])["checks"] as? [[String: Any]] ?? []
        let missing = checks.filter { $0["ok"] as? Bool != true }.map { "\($0["name"] ?? "")\($0["missing"].map { ": \($0) is missing" } ?? "")" }
        guard missing.isEmpty else {
            throw FoldsimError(kind: .failed, message: "\(device.runtime) lacks private interfaces foldsim needs:\n  " + missing.joined(separator: "\n  "),
                               hint: "use Device Hub until foldsim is updated for this runtime")
        }
        let xcode = ProcessInfo.processInfo.environment["FOLDSIM_XCODE"] ?? "?"
        emit(["checks": checks, "device": device.udid, "runtime": device.runtime, "xcode": xcode],
             "Xcode \(xcode)\n\(device.name) \(device.runtime): all \(checks.count) private interfaces are present")

    default:
        throw usageError("unknown command or wrong arguments: \(words.joined(separator: " "))")
    }
}

do {
    try run()
} catch let error as FoldsimError {
    fail(error)
} catch {
    fail(FoldsimError(kind: .failed, message: "\(error)"))
}
