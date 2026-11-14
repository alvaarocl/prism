// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import IOKit.hid
import PrismCore

struct HIDFailure: LocalizedError {
  var message: String
  var errorDescription: String? { message }
}
// All IOHID objects are confined to this serial queue; none cross into SwiftUI.
public final class HIDService: @unchecked Sendable {
  private let queue = DispatchQueue(label: "com.alvaarocl.prism.hid", qos: .utility)
  private var manager: IOHIDManager!
  private var lastDevices: [Peripheral] = []
  private var interfaces: [String: [IOHIDDevice]] = [:]
  private var mouseBusy = false
  private var timer: DispatchSourceTimer?
  private var activeKeyboard: (String, Lighting)?
  private var retainedKeyboard: IOHIDDevice?
  private var keyboardReports: [[UInt8]] = []
  public var changed: (@Sendable ([Peripheral]) -> Void)?
  public var failed: (@Sendable (String) -> Void)?

  public init() {}
  public func start() {
    queue.async { [self] in
      manager = IOHIDManagerCreate(
        kCFAllocatorDefault, IOHIDManagerOptions.independentDevices.rawValue)
      IOHIDManagerSetDeviceMatchingMultiple(
        manager,
        [
          [kIOHIDTransportKey: "USB"], [kIOHIDTransportKey: "Bluetooth"],
          [kIOHIDTransportKey: "Bluetooth Low Energy"],
        ] as CFArray)
      let context = Unmanaged.passUnretained(self).toOpaque()
      IOHIDManagerRegisterDeviceMatchingCallback(
        manager,
        { context, _, _, _ in
          guard let context else { return }
          let service = Unmanaged<HIDService>.fromOpaque(context).takeUnretainedValue()
          service.enumerate()
        }, context)
      IOHIDManagerRegisterDeviceRemovalCallback(
        manager,
        { context, _, _, _ in
          guard let context else { return }
          let service = Unmanaged<HIDService>.fromOpaque(context).takeUnretainedValue()
          service.enumerate()
        }, context)
      IOHIDManagerSetDispatchQueue(manager, queue)
      IOHIDManagerActivate(manager)
      enumerate(force: true)
    }
  }
  private func number(_ device: IOHIDDevice, _ key: String) -> Int {
    (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0
  }
  private func text(_ device: IOHIDDevice, _ key: String) -> String {
    IOHIDDeviceGetProperty(device, key as CFString) as? String ?? ""
  }
  private func enumerate(force: Bool = false) {
    let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
    var result: [String: Peripheral] = [:]
    interfaces.removeAll(keepingCapacity: true)
    for device in devices {
      let vendor = number(device, kIOHIDVendorIDKey)
      let product = number(device, kIOHIDProductIDKey)
      let transport = text(device, kIOHIDTransportKey)
      guard vendor != 0, vendor != 0x05ac,
        ["USB", "Bluetooth", "Bluetooth Low Energy"].contains(transport)
      else { continue }
      let location = number(device, kIOHIDLocationIDKey)
      // Distinguish Bluetooth devices and devices without a USB location by registry identity.
      var entry: UInt64 = 0
      IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &entry)
      let suffix = location == 0 ? String(entry) : String(location)
      let id = "\(vendor):\(product):\(suffix)"
      interfaces[id, default: []].append(device)
      let name: String =
        switch (vendor, product) {
        case (0x258a, 0x0033): "Glorious Model D / D−"
        case (0x258a, 0x0036): "Glorious Model O / O−"
        default: text(device, kIOHIDProductKey)
        }
      result[id] = Peripheral(
        id: id, name: name.isEmpty ? "USB peripheral" : name, vendor: vendor, product: product,
        location: location, transport: transport)
    }
    if let activeKeyboard, result[activeKeyboard.0] == nil { stopKeyboard() }
    let sorted = result.values.sorted {
      ($0.driver == .unsupported ? 1 : 0, $0.name) < ($1.driver == .unsupported ? 1 : 0, $1.name)
    }
    if force || sorted != lastDevices {
      lastDevices = sorted
      changed?(sorted)
    }
  }
  public func refresh() { queue.async { self.enumerate(force: true) } }
  public func suspend() { queue.async { self.stopKeyboard() } }
  private func stopKeyboard() {
    timer?.cancel()
    timer = nil
    activeKeyboard = nil
    keyboardReports.removeAll(keepingCapacity: true)
    if let retainedKeyboard { IOHIDDeviceClose(retainedKeyboard, 0) }
    retainedKeyboard = nil
  }
  private func check(_ result: IOReturn) throws {
    guard result == kIOReturnSuccess else {
      throw HIDFailure(
        message: String(
          format:
            "macOS refused USB access (0x%08X). Enable Prism in Privacy & Security → Input Monitoring, then quit and reopen it. Also close other peripheral controllers.",
          result))
    }
  }
  private func set(_ device: IOHIDDevice, _ bytes: [UInt8], type: IOHIDReportType, id: Int) throws {
    let result = bytes.withUnsafeBufferPointer { ptr in
      IOHIDDeviceSetReport(device, type, CFIndex(id), ptr.baseAddress!, ptr.count)
    }
    try check(result)
  }
  public func apply(
    _ peripheral: Peripheral, lighting: Lighting?, polling: Int? = nil,
    completion: @escaping @Sendable (String?) -> Void
  ) {
    queue.async { [self] in
      do {
        guard let candidates = interfaces[peripheral.id], !candidates.isEmpty else {
          throw HIDFailure(message: "Device disconnected. Reconnect it and try again.")
        }
        switch peripheral.driver {
        case .hyperX:
          guard let lighting else {
            throw HIDFailure(message: "This keyboard supports lighting only.")
          }
          stopKeyboard()
          guard
            let device = candidates.first(where: {
              number($0, kIOHIDPrimaryUsagePageKey) >= 0xff00
                && number($0, kIOHIDMaxOutputReportSizeKey) >= 64
            })
          else { throw HIDFailure(message: "The keyboard's lighting interface is unavailable.") }
          try check(IOHIDDeviceOpen(device, 0))
          do {
            try set(
              device, HyperXProtocol.brightnessReport(lighting.brightness),
              type: kIOHIDReportTypeOutput, id: 0)
            keyboardReports = HyperXProtocol.reports(lighting)
            try sendKeyboard(device)
          } catch {
            IOHIDDeviceClose(device, 0)
            throw error
          }
          retainedKeyboard = device
          activeKeyboard = (peripheral.id, lighting)
          // This firmware requires a keepalive even for a static colour. No timer before Apply.
          let source = DispatchSource.makeTimerSource(queue: queue)
          source.schedule(
            deadline: .now() + .milliseconds(60), repeating: .milliseconds(60),
            leeway: .milliseconds(5))
          source.setEventHandler { [weak self] in
            guard let self, let device = self.retainedKeyboard else { return }
            do { try self.sendKeyboard(device) } catch {
              self.stopKeyboard()
              self.failed?(error.localizedDescription)
            }
          }
          timer = source
          source.resume()
        case .glorious:
          try updateMouse(candidates, lighting: lighting, polling: polling, completion: completion)
          return
        case .unsupported:
          throw HIDFailure(
            message: "No tested driver exists for this device yet. No commands were sent.")
        }
        completion(nil)
      } catch { completion(error.localizedDescription) }
    }
  }
  private func sendKeyboard(_ device: IOHIDDevice) throws {
    for report in keyboardReports { try set(device, report, type: kIOHIDReportTypeOutput, id: 0) }
  }
  private func updateMouse(_ devices: [IOHIDDevice], lighting: Lighting?, polling: Int?, completion: @escaping @Sendable (String?) -> Void) throws {
    guard !mouseBusy else {throw HIDFailure(message: "Espera a que termine la configuración del ratón.")}
    // Probe only the allowlisted VID/PIDs, only interfaces declaring these exact report sizes.
    let candidates = devices.filter { number($0, kIOHIDMaxFeatureReportSizeKey) >= 520 }
    guard !candidates.isEmpty else {
      throw HIDFailure(
        message:
          "The mouse's configuration interface is unavailable. Enable Input Monitoring and reopen Prism."
      )
    }
    // Open only a configuration interface. No pointer collection, no seizing.
    guard let device = candidates.first else { throw ProtocolError.invalidProfile }
    try check(IOHIDDeviceOpen(device, 0))
    mouseBusy = true
    var retainedForReadback = false
    defer { if !retainedForReadback {IOHIDDeviceClose(device,0);mouseBusy=false} }
    func read(_ id: Int, count: Int) throws -> ([UInt8], Int) {
      var bytes = [UInt8](repeating: 0, count: count)
      bytes[0] = UInt8(id)
      var length = count
      let result = bytes.withUnsafeMutableBufferPointer {
        IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, id, $0.baseAddress!, &length)
      }
      try check(result)
      return (bytes, length)
    }
    try set(device, [5, 2, 0, 0, 0, 0], type: kIOHIDReportTypeFeature, id: 5)
    let (profileReply, profileLength) = try read(5, count: 6)
    guard profileLength == 6, profileReply[0] == 5, profileReply[1] == 2,
      (1...3).contains(profileReply[2])
    else { throw ProtocolError.invalidProfile }
    let command = UInt8(Int(profileReply[2]) * 16 + 1)
    func snapshot() throws -> ([UInt8], Int) {
      try set(device, [5, command, 0, 0, 0, 0], type: kIOHIDReportTypeFeature, id: 5)
      let (bytes, length) = try read(4, count: 520)
      return (try GloriousProtocol.normalize(bytes, transferred: length, command: command), length)
    }
    let (original, size) = try snapshot()
    let updated = try GloriousProtocol.updating(
      original, lighting: lighting, polling: polling, configSize: size)
    try AgentFiles.prepare()
    let backup = AgentFiles.directory.appendingPathComponent("mouse-before-last-change.bin")
    try Data(original.prefix(size)).write(to: backup, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
    try set(device, updated, type: kIOHIDReportTypeFeature, id: 4)
    // The settling delay must not block the keyboard's 60 ms maintenance queue.
    let transaction = MouseReadback(device:device) {
      let (actual, _) = try snapshot()
      try GloriousProtocol.verify(actual, expected: updated, lighting: lighting, polling: polling)
    }
    retainedForReadback = true
    queue.asyncAfter(deadline:.now() + .milliseconds(60)) { [self] in
      defer {IOHIDDeviceClose(transaction.device,0);mouseBusy=false}
      do {try transaction.verify();completion(nil)} catch {completion(error.localizedDescription)}
    }
  }
}

// Retains the configuration handle across a scheduled delay; every access stays on HIDService.queue.
private final class MouseReadback: @unchecked Sendable {
  let device: IOHIDDevice
  let verify: () throws -> Void
  init(device: IOHIDDevice, verify: @escaping () throws -> Void) {self.device=device;self.verify=verify}
}
