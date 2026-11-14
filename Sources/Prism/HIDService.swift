// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
import IOKit.hid
import PrismCore

struct Peripheral: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let vendor: Int
    let product: Int
    let location: Int
    let transport: String
    var driver: DriverKind { .identify(vendor: vendor, product: product) }
    var identifier: String { String(format: "%04X:%04X", vendor, product) }
    var symbol: String { driver == .hyperX ? "keyboard" : driver == .glorious ? "computermouse" : "cable.connector" }
}
struct HIDFailure: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}
// All IOHID objects are confined to this serial queue; none cross into SwiftUI.
final class HIDService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.alvaarocl.prism.hid", qos: .utility)
    private var manager: IOHIDManager!
    private var interfaces: [String: [IOHIDDevice]] = [:]
    private var timer: DispatchSourceTimer?
    private var activeKeyboard: (String, Lighting)?
    private var retainedKeyboard: IOHIDDevice?
    var changed: (@Sendable ([Peripheral]) -> Void)?
    var failed: (@Sendable (String) -> Void)?

    func start() {
        queue.async { [self] in
            manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerSetDeviceMatching(manager, nil)
            let context = Unmanaged.passUnretained(self).toOpaque()
            IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, _ in
                guard let context else { return }
                let service = Unmanaged<HIDService>.fromOpaque(context).takeUnretainedValue()
                service.enumerate()
            }, context)
            IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, _ in
                guard let context else { return }
                let service = Unmanaged<HIDService>.fromOpaque(context).takeUnretainedValue()
                service.enumerate()
            }, context)
            IOHIDManagerSetDispatchQueue(manager, queue)
            IOHIDManagerActivate(manager)
            enumerate()
        }
    }
    private func number(_ device: IOHIDDevice, _ key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0
    }
    private func text(_ device: IOHIDDevice, _ key: String) -> String {
        IOHIDDeviceGetProperty(device, key as CFString) as? String ?? ""
    }
    private func enumerate() {
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        var result: [String: Peripheral] = [:]
        interfaces.removeAll(keepingCapacity: true)
        for device in devices {
            let vendor = number(device, kIOHIDVendorIDKey), product = number(device, kIOHIDProductIDKey)
            let transport = text(device, kIOHIDTransportKey)
            guard vendor != 0, vendor != 0x05ac, ["USB", "Bluetooth", "Bluetooth Low Energy"].contains(transport) else { continue }
            let location = number(device, kIOHIDLocationIDKey)
            // Distinguish Bluetooth devices and devices without a USB location by registry identity.
            var entry: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &entry)
            let suffix = location == 0 ? String(entry) : String(location)
            let id = "\(vendor):\(product):\(suffix)"
            interfaces[id, default: []].append(device)
            let name: String = switch (vendor, product) {
            case (0x258a, 0x0033): "Glorious Model D / D−"
            case (0x258a, 0x0036): "Glorious Model O / O−"
            default: text(device, kIOHIDProductKey)
            }
            result[id] = Peripheral(id: id, name: name.isEmpty ? "USB peripheral" : name, vendor: vendor, product: product, location: location, transport: transport)
        }
        if let activeKeyboard, result[activeKeyboard.0] == nil { stopKeyboard() }
        changed?(result.values.sorted { ($0.driver == .unsupported ? 1 : 0, $0.name) < ($1.driver == .unsupported ? 1 : 0, $1.name) })
    }
    func refresh() { queue.async { self.enumerate() } }
    func suspend() { queue.async { self.stopKeyboard() } }
    private func stopKeyboard() {
        timer?.cancel(); timer = nil; activeKeyboard = nil
        if let retainedKeyboard { IOHIDDeviceClose(retainedKeyboard, 0) }
        retainedKeyboard = nil
    }
    private func check(_ result: IOReturn) throws {
        guard result == kIOReturnSuccess else {
            throw HIDFailure(message: String(format: "macOS refused USB access (0x%08X). Enable Prism in Privacy & Security → Input Monitoring, then quit and reopen it. Also close other peripheral controllers.", result))
        }
    }
    private func set(_ device: IOHIDDevice, _ bytes: [UInt8], type: IOHIDReportType, id: Int) throws {
        let result = bytes.withUnsafeBufferPointer { ptr in
            IOHIDDeviceSetReport(device, type, CFIndex(id), ptr.baseAddress!, ptr.count)
        }
        try check(result)
    }
    func apply(_ peripheral: Peripheral, lighting: Lighting?, polling: Int? = nil, completion: @escaping @Sendable (String?) -> Void) {
        queue.async { [self] in
            do {
                guard let candidates = interfaces[peripheral.id], !candidates.isEmpty else { throw HIDFailure(message: "Device disconnected. Reconnect it and try again.") }
                switch peripheral.driver {
                case .hyperX:
                    guard let lighting else { throw HIDFailure(message: "This keyboard supports lighting only.") }
                    stopKeyboard()
                    guard let device = candidates.first(where: { number($0, kIOHIDPrimaryUsagePageKey) >= 0xff00 && number($0, kIOHIDMaxOutputReportSizeKey) >= 64 }) else { throw HIDFailure(message: "The keyboard's lighting interface is unavailable.") }
                    try check(IOHIDDeviceOpen(device, 0))
                    do {
                        try set(device, HyperXProtocol.brightnessReport(lighting.brightness), type: kIOHIDReportTypeOutput, id: 0)
                        try sendKeyboard(device, lighting)
                    } catch { IOHIDDeviceClose(device, 0); throw error }
                    retainedKeyboard = device; activeKeyboard = (peripheral.id, lighting)
                    // This firmware requires a keepalive even for a static colour. No timer before Apply.
                    let source = DispatchSource.makeTimerSource(queue: queue)
                    source.schedule(deadline: .now() + .milliseconds(60), repeating: .milliseconds(60), leeway: .milliseconds(5))
                    source.setEventHandler { [weak self] in
                        guard let self, let device = self.retainedKeyboard, let light = self.activeKeyboard?.1 else { return }
                        do { try self.sendKeyboard(device, light) }
                        catch { self.stopKeyboard(); self.failed?(error.localizedDescription) }
                    }
                    timer = source; source.resume()
                case .glorious:
                    try updateMouse(candidates, lighting: lighting, polling: polling)
                case .unsupported: throw HIDFailure(message: "No tested driver exists for this device yet. No commands were sent.")
                }
                completion(nil)
            } catch { completion(error.localizedDescription) }
        }
    }
    private func sendKeyboard(_ device: IOHIDDevice, _ light: Lighting) throws {
        for report in HyperXProtocol.reports(light) { try set(device, report, type: kIOHIDReportTypeOutput, id: 0) }
    }
    private func updateMouse(_ devices: [IOHIDDevice], lighting: Lighting?, polling: Int?) throws {
        // Probe only the allowlisted VID/PIDs, only interfaces declaring these exact report sizes.
        let candidates = devices.filter { number($0, kIOHIDMaxFeatureReportSizeKey) >= 520 }
        guard !candidates.isEmpty else { throw HIDFailure(message: "The mouse's configuration interface is unavailable. Enable Input Monitoring and reopen Prism.") }
        var lastError: Error = ProtocolError.invalidProfile
        for device in candidates {
            do {
                try check(IOHIDDeviceOpen(device, 0))
                defer { IOHIDDeviceClose(device, 0) }
                try set(device, [5, 0x11, 0, 0, 0, 0], type: kIOHIDReportTypeFeature, id: 5)
                var original = [UInt8](repeating: 0, count: 520); original[0] = 4
                var length = original.count
                let result = original.withUnsafeMutableBufferPointer { ptr in
                    IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 4, ptr.baseAddress!, &length)
                }
                try check(result)
                // Require a complete snapshot; never fill a short/failed read with guessed zeros.
                guard length == 520 else { throw ProtocolError.invalidProfile }
                let updated = try GloriousProtocol.updating(original, lighting: lighting, polling: polling)
                try set(device, updated, type: kIOHIDReportTypeFeature, id: 4)
                // Firmware needs 50 ms before another read; this serial queue enforces that delay.
                Thread.sleep(forTimeInterval: 0.05)
                return
            } catch { lastError = error }
        }
        throw lastError
    }
}
