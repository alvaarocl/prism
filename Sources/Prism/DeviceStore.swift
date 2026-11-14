import AppKit
import IOKit.hid
import PrismCore
// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

@MainActor @Observable final class DeviceStore {
  var devices: [Peripheral] = []
  var selected: String?
  var light = Lighting()
  var busy = false
  var message = ""
  var isError = false
  var saved: [String: Lighting] = [:]
  let service = HIDService()
  private var sleepObserver: NSObjectProtocol?
  private var terminationObserver: NSObjectProtocol?
  var current: Peripheral? { devices.first { $0.id == selected } }
  init() {
    if let data = UserDefaults.standard.data(forKey: "lightingPresets"),
      let decoded = try? JSONDecoder().decode([String: Lighting].self, from: data)
    {
      saved = decoded
    }
    service.changed = { [weak self] devices in
      Task { @MainActor in
        guard let self else { return }
        self.devices = devices
        if !devices.contains(where: { $0.id == self.selected }) {
          self.selected = devices.first?.id
        }
      }
    }
    service.failed = { [weak self] message in
      Task { @MainActor in
        self?.message = message
        self?.isError = true
      }
    }
    sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
    ) { [weak service] _ in service?.suspend() }
    terminationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification, object: nil, queue: .main
    ) { [weak service] _ in service?.suspend() }
    service.start()
  }
  func apply(polling: Int? = nil) {
    guard let device = current, !busy else { return }
    busy = true
    isError = false
    message = "Enviando al dispositivo…"
    service.apply(device, lighting: polling == nil ? light : nil, polling: polling) {
      [weak self] error in
      Task { @MainActor in
        guard let self else { return }
        self.busy = false
        self.isError = error != nil
        self.message = error ?? "Configuración enviada. Comprueba el resultado en tu periférico."
      }
    }
  }
  func save() {
    guard let device = current else { return }
    saved[device.identifier] = light
    if let data = try? JSONEncoder().encode(saved) {
      UserDefaults.standard.set(data, forKey: "lightingPresets")
    }
    message = "Preset guardado en este Mac. No se aplica automáticamente."
    isError = false
  }
}
