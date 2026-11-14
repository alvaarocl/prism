import Darwin
// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import IOKit
import IOKit.pwr_mgt
import PrismCore
import PrismHardware

final class Runtime: @unchecked Sendable {
  let queue = DispatchQueue(label: "com.alvaarocl.prism.agent", qos: .utility)
  let hardware = HIDService()
  var status = AgentStatus(pid: getpid())
  var observer: DispatchSourceFileSystemObject?
  var lastRequest: UUID?
  var restored = Set<String>()
  var rootPort: io_connect_t = 0
  var powerPort: IONotificationPortRef?
  var notifier: io_object_t = 0
  init() throws {
    try AgentFiles.prepare()
    status.applied = AgentFiles.read([String: Lighting].self, from: "applied.json") ?? [:]
    status.polling = AgentFiles.read([String: Int].self, from: "polling.json") ?? [:]
    lastRequest = AgentFiles.read(AgentRequest.self, from: "request.json")?.id
    let fd = open(AgentFiles.directory.path, O_EVTONLY)
    guard fd >= 0 else { throw CocoaError(.fileReadNoPermission) }
    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fd, eventMask: [.write, .rename], queue: queue)
    source.setEventHandler { [weak self] in self?.command() }
    source.setCancelHandler { close(fd) }
    observer = source
    source.resume()
    hardware.changed = { [weak self] devices in
      guard let self else { return }
      self.queue.async {
        self.status.devices = devices
        self.restored.formIntersection(Set(devices.map(\.id)))
        self.publish()
        for device in devices where device.driver == .hyperX && !self.restored.contains(device.id) {
          guard let light = self.status.applied[device.identifier] else { continue }
          self.restored.insert(device.id)
          self.hardware.apply(device, lighting: light) { error in
            self.queue.async {
              self.status.error = error
              self.publish()
            }
          }
        }
      }
    }
    hardware.failed = { [weak self] error in
      guard let self else { return }
      self.queue.async {
        self.status.error = error
        self.publish()
      }
    }
    hardware.start()
  }
  func publish() { try? AgentFiles.write(status, to: "status.json") }
  func command() {
    guard let request = AgentFiles.read(AgentRequest.self, from: "request.json"),
      request.id != lastRequest
    else { return }
    lastRequest = request.id
    guard let device = status.devices.first(where: { $0.id == request.deviceID }) else {
      status.completedRequest = request.id
      status.error = "Dispositivo desconectado."
      publish()
      return
    }
    hardware.apply(device, lighting: request.lighting, polling: request.polling) { [self] error in
      queue.async {
        if error == nil, let light = request.lighting {
          self.status.applied[device.identifier] = light
          if device.driver == .hyperX { self.restored.insert(device.id) }
          try? AgentFiles.write(self.status.applied, to: "applied.json")
        }
        if error == nil, let rate = request.polling {
          self.status.polling?[device.identifier] = rate
          try? AgentFiles.write(self.status.polling ?? [:], to: "polling.json")
        }
        self.status.completedRequest = request.id
        self.status.error = error
        self.publish()
      }
    }
  }
  func power(_ type: UInt32, _ argument: UnsafeMutableRawPointer?) {
    // IOMessage.h iokit_common_msg values; these C macros do not import into Swift.
    switch type {
    case 0xe000_0270: IOAllowPowerChange(rootPort, Int(bitPattern: argument))
    case 0xe000_0280:
      hardware.suspend()
      IOAllowPowerChange(rootPort, Int(bitPattern: argument))
    case 0xe000_0300:
      queue.async {
        self.restored.removeAll()
        self.hardware.refresh()
      }
    default: break
    }
  }
  func registerPower() {
    rootPort = IORegisterForSystemPower(
      Unmanaged.passUnretained(self).toOpaque(), &powerPort,
      { context, _, type, argument in
        guard let context else { return }
        Unmanaged<Runtime>.fromOpaque(context).takeUnretainedValue().power(type, argument)
      }, &notifier)
    if let powerPort,
      let source = IONotificationPortGetRunLoopSource(powerPort)?.takeUnretainedValue()
    {
      CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }
  }
}
try AgentFiles.prepare()
let lockFD = open(
  AgentFiles.directory.appendingPathComponent("agent.lock").path, O_CREAT | O_RDWR, 0o600)
guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { exit(0) }
let runtime = try Runtime()
runtime.registerPower()
CFRunLoopRun()
