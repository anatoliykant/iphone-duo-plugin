// The only file that touches private simulator interfaces. Every function, class and selector is
// looked up at run time, so a runtime that drops one fails only the command that needs it, and the
// error names what is missing.
//
// Prototypes and constants: WebKit's open-source SPI declarations (Source/WebCore/PAL/pal/spi/ios/
// IOKitSPIIOS.h, spi/mac/IOKitSPIMac.h) and touch synthesizer (Tools/WebKitTestRunner/ios/
// HIDEventGenerator.mm), the macOS SDK's public IOKit/hidsystem headers, and IOHIDFamily's
// HID/PrivateHeaders/HIDVirtualEventService.h. The device-state event Device Hub sends was first
// documented by github.com/artemnovichkov/hinge; reading the angle from CMAngleManager and touching
// the inner display through a virtual touchscreen by github.com/skarol/duoctl. No code is taken
// from either project.

import Foundation
import Darwin

/// A private interface this simulator runtime does not provide.
struct Unavailable: Error {
    let name: String
}

struct Failure: Error {
    let message: String
}

private enum Framework {
    static let iokit = "/System/Library/Frameworks/IOKit.framework/IOKit"
    static let coreMotion = "/System/Library/Frameworks/CoreMotion.framework/CoreMotion"
    static let hid = "/System/Library/PrivateFrameworks/HID.framework/HID"
}

private func load(_ path: String) throws -> UnsafeMutableRawPointer {
    guard let handle = dlopen(path, RTLD_NOW) else { throw Unavailable(name: path) }
    return handle
}

/// A C function, typed as `T` (a `@convention(c)` function type).
private func function<T>(_ name: String, in path: String = Framework.iokit, as _: T.Type) throws -> T {
    guard let address = dlsym(try load(path), name) else { throw Unavailable(name: name) }
    return unsafeBitCast(address, to: T.self)
}

private func objcClass(_ name: String, in path: String) throws -> NSObject.Type {
    _ = try load(path)
    guard let found = NSClassFromString(name) as? NSObject.Type else { throw Unavailable(name: name) }
    return found
}

/// The implementation of `selector` for `receiver` — an instance, or a class for class methods —
/// typed as `T`: a `@convention(c)` function that takes the receiver and the selector first.
private func objcMethod<T>(_ receiver: AnyObject, _ selector: String, as _: T.Type) throws -> (Selector, T) {
    let sel = NSSelectorFromString(selector)
    guard let cls = object_getClass(receiver), class_respondsToSelector(cls, sel),
          let imp = class_getMethodImplementation(cls, sel) else {
        throw Unavailable(name: "\(object_getClass(receiver).map(NSStringFromClass) ?? "?") \(selector)")
    }
    return (sel, unsafeBitCast(imp, to: T.self))
}

// MARK: - IOKit HID event system

private enum HID {
    // IOHIDEventSystemClientType
    static let monitorClient: Int32 = 1
    static let simpleClient: Int32 = 4
    // IOHIDDigitizerEventMask
    static let range: UInt32 = 1 << 0, touch: UInt32 = 1 << 1, position: UInt32 = 1 << 2
    static let identity: UInt32 = 1 << 5, attribute: UInt32 = 1 << 6
    static let handTransducer: UInt32 = 3
    /// kIOHIDEventFieldDigitizerIsDisplayIntegrated: digitizer events start at type 11 << 16.
    static let displayIntegrated: UInt32 = (11 << 16) + 25
    static let digitizerUsagePage = 0x0D

    typealias CreateClient = @convention(c) (CFAllocator?, Int32, CFDictionary?) -> Unmanaged<CFTypeRef>?
    typealias Dispatch = @convention(c) (CFTypeRef, CFTypeRef) -> Void
    typealias CopyServices = @convention(c) (CFTypeRef) -> Unmanaged<CFArray>?
    typealias CopyProperty = @convention(c) (CFTypeRef, CFString) -> Unmanaged<CFTypeRef>?
    typealias Serialize = @convention(c) (CFTypeRef, CFOptionFlags) -> Unmanaged<CFData>?
    typealias CreateVendorDefined = @convention(c)
        (CFAllocator?, UInt64, UInt32, UInt32, UInt32, UnsafePointer<UInt8>?, CFIndex, UInt32) -> Unmanaged<CFTypeRef>?
    typealias CreateDigitizer = @convention(c) (CFAllocator?, UInt64, UInt32, UInt32, UInt32, UInt32, UInt32,
        Double, Double, Double, Double, Double, Int32, Int32, UInt32) -> Unmanaged<CFTypeRef>?
    typealias CreateFinger = @convention(c) (CFAllocator?, UInt64, UInt32, UInt32, UInt32,
        Double, Double, Double, Double, Double, Int32, Int32, UInt32) -> Unmanaged<CFTypeRef>?
    typealias SetInteger = @convention(c) (CFTypeRef, UInt32, CFIndex) -> Void
    typealias Append = @convention(c) (CFTypeRef, CFTypeRef, UInt32) -> Void

    static let symbols = [
        "IOHIDEventSystemClientCreateWithType", "IOHIDEventSystemClientDispatchEvent",
        "IOHIDEventSystemClientCopyServices", "IOHIDServiceClientCopyProperty", "IOCFSerialize",
        "IOHIDEventCreateVendorDefinedEvent", "IOHIDEventCreateDigitizerEvent",
        "IOHIDEventCreateDigitizerFingerEvent", "IOHIDEventSetIntegerValue", "IOHIDEventAppendEvent",
    ]

    static func client(_ type: Int32) throws -> CFTypeRef {
        let create = try function("IOHIDEventSystemClientCreateWithType", as: CreateClient.self)
        guard let client = create(nil, type, nil)?.takeRetainedValue() else {
            throw Failure(message: "the HID event system refused a client")
        }
        return client
    }
}

// MARK: - Device state: hinge and device orientation

/// Device Hub's own controls. It sends a vendor-defined HID event (usage page 0xFF61, usage 0x5B)
/// whose payload is a binary-serialized dictionary; locationd turns it into a hinge angle or a
/// device orientation. The provider name differs between CoreSimulator versions, and every event
/// carries an absolute value, so each one goes out under both names.
final class DeviceHub {
    private static let providers = ["com.apple.Virtualization.VirtualMachines", "com.apple.Virtualization"]
    private let client: CFTypeRef
    private let dispatch: HID.Dispatch
    private let serialize: HID.Serialize
    private let createEvent: HID.CreateVendorDefined

    init() throws {
        client = try HID.client(HID.simpleClient)
        dispatch = try function("IOHIDEventSystemClientDispatchEvent", as: HID.Dispatch.self)
        serialize = try function("IOCFSerialize", as: HID.Serialize.self)
        createEvent = try function("IOHIDEventCreateVendorDefinedEvent", as: HID.CreateVendorDefined.self)
    }

    func send(source: String, type: String, value: Any) throws {
        for provider in Self.providers {
            let payload: NSDictionary = ["provider": provider, "source": source, "type": type, "value": value]
            guard let data = serialize(payload, 1 /* kIOCFSerializeToBinary */)?.takeRetainedValue() as Data? else {
                throw Failure(message: "IOCFSerialize could not encode the device-state payload")
            }
            let event = data.withUnsafeBytes { bytes in
                createEvent(nil, mach_absolute_time(), 0xFF61, 0x5B, 0,
                            bytes.bindMemory(to: UInt8.self).baseAddress, data.count, 0)
            }
            guard let event = event?.takeRetainedValue() else {
                throw Failure(message: "could not create the device-state event")
            }
            dispatch(client, event)
        }
    }

    /// The event system delivers asynchronously; exiting at once can drop the last event.
    func drain() {
        usleep(100_000)
    }

    static let orientations: Set = ["portrait", "pud", "landscape-left", "landscape-right"]

    static func orient(_ deviceOrientation: String) throws {
        let hub = try DeviceHub()
        try hub.send(source: "orientation-picker-control", type: "enum", value: deviceOrientation)
        hub.drain()
    }
}

enum Hinge {
    /// Degrees as CoreMotion reports them — the source UIKit's UIHinge reads — or nil on a
    /// simulator without a hinge.
    static func angle(timeout: TimeInterval = 2) throws -> Double? {
        let manager = try objcClass("CMAngleManager", in: Framework.coreMotion)
        let (isAvailable, callIsAvailable) = try objcMethod(
            manager, "isAvailable", as: (@convention(c) (AnyObject, Selector) -> ObjCBool).self)
        guard callIsAvailable(manager, isAvailable).boolValue else { return nil }

        // CoreMotion keeps the handler, so it has to be an escaping block.
        typealias Handler = @convention(block) (AnyObject?) -> Void
        let instance = manager.init()
        let (start, callStart) = try objcMethod(instance, "startAngleUpdatesToQueue:handler:",
            as: (@convention(c) (AnyObject, Selector, OperationQueue, @escaping Handler) -> Void).self)
        let (stop, callStop) = try objcMethod(instance, "stopAngleUpdates",
            as: (@convention(c) (AnyObject, Selector) -> Void).self)

        let reading = FirstReading()
        let handler: Handler = { reading.take($0) }
        callStart(instance, start, OperationQueue(), handler)
        defer { callStop(instance, stop) }
        let deadline = Date(timeIntervalSinceNow: timeout)
        while reading.degrees == nil, Date() < deadline {
            // CoreMotion may need the main run loop; without sources it returns at once, so pause.
            if !RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02)) { usleep(20_000) }
        }
        guard let degrees = reading.degrees else {
            throw Failure(message: "CoreMotion reported no hinge angle within \(timeout) s")
        }
        return degrees
    }

    /// Sweeps from the current angle to `target`, the way Device Hub's slider moves. The iOS 27.1
    /// runtime stops switching screens after an instant jump between closed and open.
    static func sweep(to target: Double, over seconds: Double) throws {
        guard let start = try angle() else { throw Failure(message: "this simulator has no hinge") }
        let hub = try DeviceHub()
        let steps = max(2, Int((seconds * 60).rounded()))
        for step in 1...steps {
            let progress = Double(step) / Double(steps)
            let eased = (1 - cos(Double.pi * progress)) / 2
            try hub.send(source: "hinge-slider-control", type: "range", value: start + (target - start) * eased)
            usleep(1_000_000 / 60)
        }
        hub.drain()
    }
}

/// The first angle CoreMotion delivers, handed over from its queue.
private final class FirstReading: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Double?

    var degrees: Double? {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func take(_ angle: AnyObject?) {
        guard let angle = angle as? NSObject, angle.responds(to: NSSelectorFromString("angleDegrees")),
              let number = angle.value(forKey: "angleDegrees") as? NSNumber else { return }
        lock.lock(); defer { lock.unlock() }
        if value == nil { value = number.doubleValue }
    }
}

// MARK: - Touchscreens

struct Digitizer {
    /// The display's UUID, as `devicectl device info displays` reports it in `uniqueId`.
    let display: String
    let product: String?
    let properties: [String: Any]
}

enum Touchscreens {
    /// What the virtual copy answers with: enough for the event system to route its touches to the
    /// same display as the built-in touchscreen.
    private static let identityKeys = [
        "PrimaryUsagePage", "PrimaryUsage", "DeviceUsagePairs", "displayUUID", "Built-In", "Transport",
        "DeviceTypeHint",
    ]

    static func all() throws -> [Digitizer] {
        let client = try HID.client(HID.monitorClient)
        let copyServices = try function("IOHIDEventSystemClientCopyServices", as: HID.CopyServices.self)
        let copyProperty = try function("IOHIDServiceClientCopyProperty", as: HID.CopyProperty.self)
        let found: [Digitizer] = withExtendedLifetime(client) {
            let services = (copyServices(client)?.takeRetainedValue() as? [AnyObject]) ?? []
            return services.compactMap { service in
                func property(_ key: String) -> Any? { copyProperty(service, key as CFString)?.takeRetainedValue() }
                guard (property("PrimaryUsagePage") as? NSNumber)?.intValue == HID.digitizerUsagePage,
                      let display = property("displayUUID") as? String else { return nil }
                var properties: [String: Any] = [:]
                for key in identityKeys { properties[key] = property(key) }
                return Digitizer(display: display, product: property("Product") as? String, properties: properties)
            }
        }
        // A display can have more than one digitizer service; the simulator's own one has a Product.
        var byDisplay: [String: Digitizer] = [:]
        for digitizer in found where byDisplay[digitizer.display]?.product == nil {
            byDisplay[digitizer.display] = digitizer
        }
        return byDisplay.values.sorted { $0.display < $1.display }
    }
}

/// A virtual HID service that presents itself as the touchscreen of one display. Simulator HID
/// tools only ever reach the main (cover) touchscreen; this reaches any display, the inner one too.
final class VirtualTouchscreen: NSObject {
    enum Phase { case down, move, up }

    private typealias Dispatch = @convention(c) (AnyObject, Selector, AnyObject) -> ObjCBool
    private typealias Call = @convention(c) (AnyObject, Selector) -> Void

    private let properties: [String: Any]
    private let enumerated = DispatchSemaphore(value: 0)
    private let service: NSObject
    private let dispatchEvent: (Selector, Dispatch)
    private let cancelService: (Selector, Call)
    private let createHand: HID.CreateDigitizer
    private let createFinger: HID.CreateFinger
    private let setInteger: HID.SetInteger
    private let append: HID.Append

    init(copying digitizer: Digitizer) throws {
        properties = digitizer.properties
        service = try objcClass("HIDVirtualEventService", in: Framework.hid).init()
        dispatchEvent = try objcMethod(service, "dispatchEvent:", as: Dispatch.self)
        cancelService = try objcMethod(service, "cancel", as: Call.self)
        createHand = try function("IOHIDEventCreateDigitizerEvent", as: HID.CreateDigitizer.self)
        createFinger = try function("IOHIDEventCreateDigitizerFingerEvent", as: HID.CreateFinger.self)
        setInteger = try function("IOHIDEventSetIntegerValue", as: HID.SetInteger.self)
        append = try function("IOHIDEventAppendEvent", as: HID.Append.self)
        super.init()

        // The service holds its delegate weakly; `self` stays alive for the whole command.
        let (setDelegate, callSetDelegate) = try objcMethod(service, "setDelegate:",
            as: (@convention(c) (AnyObject, Selector, AnyObject?) -> Void).self)
        let (setQueue, callSetQueue) = try objcMethod(service, "setDispatchQueue:",
            as: (@convention(c) (AnyObject, Selector, AnyObject) -> Void).self)
        let (activate, callActivate) = try objcMethod(service, "activate", as: Call.self)
        callSetDelegate(service, setDelegate, self)
        callSetQueue(service, setQueue, DispatchQueue(label: "foldsim.touchscreen"))
        callActivate(service, activate)
        guard enumerated.wait(timeout: .now() + 3) == .success else {
            throw Failure(message: "the event system never opened the virtual touchscreen")
        }
    }

    /// Presses at the first point, moves through the rest over `seconds` (or holds that long when
    /// there is one point), and lifts. Points are normalized (0…1) in the panel's native axes.
    func touch(along points: [(x: Double, y: Double)], over seconds: Double) throws {
        guard let first = points.first, let last = points.last else { return }
        try send(.down, first)
        if points.count == 1 {
            usleep(useconds_t(seconds * 1_000_000))
        } else {
            let steps = max(points.count - 1, Int((seconds * 60).rounded()))
            for step in 1...steps {
                let position = Double(step) / Double(steps) * Double(points.count - 1)
                let index = min(Int(position), points.count - 2)
                let local = position - Double(index)
                let a = points[index], b = points[index + 1]
                usleep(1_000_000 / 60)
                try send(.move, (a.x + (b.x - a.x) * local, a.y + (b.y - a.y) * local))
            }
        }
        try send(.up, last)
        usleep(300_000)   // let the last events drain before the service goes away
        cancelService.1(service, cancelService.0)
    }

    private func send(_ phase: Phase, _ point: (x: Double, y: Double)) throws {
        // The masks WebKit's own touch synthesizer uses for a press, a move and a lift.
        let mask = phase == .move ? HID.position | HID.attribute : HID.touch | HID.identity
        let touching: Int32 = phase == .up ? 0 : 1
        let now = mach_absolute_time()
        guard let hand = createHand(nil, now, HID.handTransducer, 0, 0, mask, 0,
                                    point.x, point.y, 0, 0, 0, touching, touching, 0)?.takeRetainedValue(),
              let finger = createFinger(nil, now, 2, 2, mask, point.x, point.y, 0, Double(touching), 0,
                                        touching, touching, 0)?.takeRetainedValue() else {
            throw Failure(message: "could not create a touch event")
        }
        setInteger(hand, HID.displayIntegrated, 1)
        setInteger(finger, HID.displayIntegrated, 1)
        append(hand, finger, 0)
        guard dispatchEvent.1(service, dispatchEvent.0, hand).boolValue else {
            throw Failure(message: "the virtual touchscreen did not accept the event")
        }
    }

    // HIDVirtualEventServiceDelegate

    @objc(setProperty:forKey:forService:)
    func setProperty(_ value: Any?, forKey key: String, forService service: Any) -> Bool {
        true
    }

    @objc(propertyForKey:forService:)
    func property(forKey key: String, forService service: Any) -> Any? {
        properties[key]
    }

    /// Returns nothing, which also sidesteps the +1 ownership rule of copy-prefixed selectors.
    @objc(copyEventMatching:forService:)
    func copyEvent(matching: [AnyHashable: Any]?, forService service: Any) -> Any? {
        nil
    }

    @objc(setOutputEvent:forService:)
    func setOutputEvent(_ event: Any?, forService service: Any) -> Bool {
        true
    }

    @objc(notification:withProperty:forService:)
    func notification(_ type: Int, withProperty property: [AnyHashable: Any]?, forService service: Any) {
        if type == 10 { enumerated.signal() }   // HIDVirtualServiceNotificationTypeEnumerated
    }
}

// MARK: - Doctor

enum Doctor {
    /// Which private interfaces this runtime provides, without changing anything.
    static func checks() -> [[String: Any]] {
        var results: [[String: Any]] = []
        func check(_ name: String, _ body: () throws -> Void) {
            do {
                try body()
                results.append(["name": name, "ok": true])
            } catch let error as Unavailable {
                results.append(["name": name, "ok": false, "missing": error.name])
            } catch {
                results.append(["name": name, "ok": false, "message": "\(error)"])
            }
        }
        for symbol in HID.symbols {
            check(symbol) { _ = try function(symbol, as: UnsafeRawPointer.self) }
        }
        check("CMAngleManager") {
            let manager = try objcClass("CMAngleManager", in: Framework.coreMotion)
            _ = try objcMethod(manager, "isAvailable", as: UnsafeRawPointer.self)
            try requireInstanceMethods(manager, ["startAngleUpdatesToQueue:handler:", "stopAngleUpdates"])
        }
        check("HIDVirtualEventService") {
            let service = try objcClass("HIDVirtualEventService", in: Framework.hid)
            try requireInstanceMethods(service, ["setDelegate:", "setDispatchQueue:", "activate", "dispatchEvent:", "cancel"])
        }
        return results
    }

    private static func requireInstanceMethods(_ cls: AnyClass, _ selectors: [String]) throws {
        for selector in selectors where !class_respondsToSelector(cls, NSSelectorFromString(selector)) {
            throw Unavailable(name: "\(NSStringFromClass(cls)) \(selector)")
        }
    }
}
