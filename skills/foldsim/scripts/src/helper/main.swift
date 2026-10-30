// foldsim-helper runs inside the simulator (`xcrun simctl spawn <udid> <helper> …`) and prints one
// JSON object on stdout. The foldsim host builds it, runs it and reads that object.
//
//   angle                                         hinge angle in degrees (null without a hinge)
//   hinge <degrees> <seconds> <tolerance>         sweep the hinge, then wait for CoreMotion to agree
//   orient <portrait|pud|landscape-left|landscape-right>   send a device orientation
//   digitizers                                    touchscreens and the display each one belongs to
//   touch <displayUUID> <seconds> <x,y> [<x,y>…]  press, move through the points, lift
//                                                 (normalized 0…1, the panel's native axes)
//   doctor                                        which private interfaces this runtime provides

import Foundation

func reply(_ fields: [String: Any], exitCode: Int32 = 0) -> Never {
    var object = fields
    object["ok"] = exitCode == 0
    let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
    FileHandle.standardOutput.write(data + Data("\n".utf8))
    exit(exitCode)
}

func fail(_ kind: String, _ message: String, _ extra: [String: Any] = [:], exitCode: Int32 = 1) -> Never {
    reply(["error": ["kind": kind, "message": message].merging(extra) { a, _ in a }], exitCode: exitCode)
}

func usage() -> Never {
    fail("usage", "usage: foldsim-helper angle | hinge <degrees> <seconds> <tolerance> | orient <portrait|pud|"
         + "landscape-left|landscape-right> | digitizers | touch <displayUUID> <seconds> <x,y>… | doctor", exitCode: 2)
}

func point(_ text: String) -> (x: Double, y: Double)? {
    let parts = text.split(separator: ",").compactMap { Double($0) }
    guard parts.count == 2 else { return nil }
    return (min(max(parts[0], 0), 1), min(max(parts[1], 0), 1))
}

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    switch (arguments.first ?? "", arguments.count) {
    case ("angle", 1):
        reply(["angle": try Hinge.angle().map { $0 as Any } ?? NSNull()])

    case ("hinge", 4):
        guard let target = Double(arguments[1]).map({ min(max($0, 0), 180) }),
              let seconds = Double(arguments[2]), let tolerance = Double(arguments[3]) else { usage() }
        try Hinge.sweep(to: target, over: max(seconds, 0.05))
        // CoreMotion catches up with the last event shortly after the sweep.
        let deadline = Date(timeIntervalSinceNow: 3)
        var angle = try Hinge.angle()
        while let current = angle, abs(current - target) > tolerance, Date() < deadline {
            usleep(150_000)
            angle = try Hinge.angle()
        }
        reply(["angle": angle.map { $0 as Any } ?? NSNull(),
               "settled": angle.map { abs($0 - target) <= tolerance } ?? false])

    case ("orient", 2):
        guard DeviceHub.orientations.contains(arguments[1]) else { usage() }
        try DeviceHub.orient(arguments[1])
        reply([:])

    case ("digitizers", 1):
        reply(["digitizers": try Touchscreens.all().map {
            ["displayUUID": $0.display, "product": $0.product.map { $0 as Any } ?? NSNull()]
        }])

    case ("touch", let count) where count >= 4:
        guard let seconds = Double(arguments[2]) else { usage() }
        let points = arguments.dropFirst(3).compactMap(point)
        guard points.count == count - 3 else { usage() }
        guard let digitizer = try Touchscreens.all().first(where: {
            $0.display.caseInsensitiveCompare(arguments[1]) == .orderedSame
        }) else {
            fail("failed", "no touchscreen belongs to display \(arguments[1])")
        }
        try VirtualTouchscreen(copying: digitizer).touch(along: points, over: max(seconds, 0))
        reply([:])

    case ("doctor", 1):
        reply(["checks": Doctor.checks()])

    default:
        usage()
    }
} catch let error as Unavailable {
    fail("unavailable", "\(error.name) is missing from this simulator runtime: a private interface changed",
         ["name": error.name])
} catch let error as Failure {
    fail("failed", error.message)
} catch {
    fail("failed", "\(error)")
}
