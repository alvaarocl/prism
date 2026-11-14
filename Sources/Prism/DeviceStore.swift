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
  var polling = 1000
  var message = ""
  var isError = false
  var saved: [String: Lighting] = [:]
  let service = AgentClient()
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
        for (key, value) in self.service.applied { self.saved[key] = value }
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
        if error == nil, let rate = self.service.polling[device.identifier] { self.polling = rate }
        self.message =
          error
          ?? (device.driver == .glorious
            ? "Cambio confirmado por el ratón."
            : "Ajuste aplicado. Puedes cerrar esta ventana: el controlador lo mantendrá en segundo plano.")
        if error == nil, polling == nil {
          if let applied = self.service.applied[device.identifier] {
            self.saved[device.identifier] = applied
          }
        }
      }
    }
  }
}
