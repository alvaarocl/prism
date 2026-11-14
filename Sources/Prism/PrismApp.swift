import AppKit
// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

@main struct PrismApp: App {
  @State private var store = DeviceStore()
  init() {
    if CommandLine.arguments.contains("--diagnose") {
      let service = HIDService()
      service.changed = { devices in
        for d in devices {
          print("\(d.identifier) | \(d.name) | \(d.driver.rawValue) | \(d.transport)")
        }
        exit(0)
      }
      service.start()
      DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        print("HID discovery timed out")
        exit(1)
      }
      dispatchMain()
    }
  }
  var body: some Scene {
    WindowGroup("Prism") { PrismView(store: store) }.defaultSize(width: 1020, height: 780)
      .windowStyle(.hiddenTitleBar)
      .commands {
        CommandGroup(replacing: .appInfo) {
          Button("Acerca de Prism") {
            NSApplication.shared.orderFrontStandardAboutPanel(options: [
              .applicationName: "Prism", .applicationVersion: "0.1.0 alpha",
              .credits: NSAttributedString(
                string:
                  "By Álvaro Carpintero\nNative macOS peripheral control.\nGPL-2.0-or-later. Drivers adapted from OpenRGB.\nSee THIRD_PARTY.md in the public repository."
              ),
            ])
          }
        }
      }
  }
}
