import AppKit
import PrismCore
import ServiceManagement
// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

@main struct PrismApp: App {
  @State private var store = DeviceStore()
  @NSApplicationDelegateAdaptor(PrismLifecycle.self) private var lifecycle
  init() {
    if CommandLine.arguments.contains("--enable-agent") {
      do {
        if AgentClient.service.status != .enabled { try AgentClient.service.register() }
        print("Agent status:", AgentClient.service.status.rawValue)
        exit(0)
      } catch {
        print(error.localizedDescription)
        exit(1)
      }
    }
    if CommandLine.arguments.contains("--diagnose") {
      if let status = AgentFiles.read(AgentStatus.self, from: "status.json") {
        print("agent pid", status.pid)
        for d in status.devices { print("\(d.identifier) | \(d.name) | \(d.driver.rawValue)") }
      }
      print("registration", AgentClient.service.status.rawValue)
      exit(0)
    }
  }
  var body: some Scene {
    WindowGroup("Prism") { PrismView(store: store) }.defaultSize(width: 1020, height: 780)
      .windowStyle(.hiddenTitleBar)
      .commands {
        CommandGroup(replacing: .appTermination) {
          Button("Cerrar configuración") { NSApp.terminate(nil) }.keyboardShortcut("q")
          Button("Detener Prism por completo") {
            do {
              try store.service.stop()
              NSApp.terminate(nil)
            } catch {
              store.message = error.localizedDescription
              store.isError = true
            }
          }
        }
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

@MainActor final class PrismLifecycle: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
