// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
import SwiftUI

@MainActor enum ProductPhotos {
  private static var loaded: [String: NSImage] = [:]
  static func name(for device: Peripheral) -> String? {
    switch (device.vendor, device.product) {
    case (0x0951, 0x16e6), (0x03f0, 0x098f): "hyperx-origins-core.png"
    case (0x258a, 0x0033): "glorious-model-d.png"
    case (0x1532, 0x0565), (0x1532, 0x056e): "razer-blackshark-v2-hyperspeed.png"
    default: nil
    }
  }
  static func image(for device: Peripheral) -> NSImage? {
    guard let name = name(for: device) else { return nil }
    if let cached = loaded[name] { return cached }
    guard
      let url = Bundle.main.resourceURL?.appendingPathComponent("ProductPhotos")
        .appendingPathComponent(name),
      let image = NSImage(contentsOf: url), image.isValid
    else { return nil }
    loaded[name] = image
    return image
  }
}
struct ProductPhoto: View {
  let device: Peripheral
  var body: some View {
    if let image = ProductPhotos.image(for: device) {
      Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
        .accessibilityLabel("Fotografía del fabricante: \(device.name)")
    } else {
      Image(systemName: device.symbol).font(.system(size: 72, weight: .ultraLight))
        .foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(device.name)
    }
  }
}
