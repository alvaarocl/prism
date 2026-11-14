// SPDX-License-Identifier: GPL-2.0-or-later
// Original implementation; composition/motion visually informed by Claude Launcher.
import AppKit
import SwiftUI

struct WindowBlur: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .hudWindow
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }
  func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
struct WindowGlass: View {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  var body: some View {
    ZStack {
      if !reduceTransparency { WindowBlur() }
      if #available(macOS 26, *), !reduceTransparency {
        Color.clear.glassEffect(.clear, in: RoundedRectangle(cornerRadius: 22))
      }
      LinearGradient(
        colors: [
          Color(red: 0.105, green: 0.11, blue: 0.13).opacity(reduceTransparency ? 1 : 0.9),
          Color(red: 0.043, green: 0.043, blue: 0.051).opacity(reduceTransparency ? 1 : 0.96),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
  }
}
struct WindowAppearance: NSViewRepresentable {
  final class WindowView: NSView {
    private var configured = false
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      guard let window else { return }
      window.isOpaque = false
      window.backgroundColor = .clear
      window.titlebarAppearsTransparent = true
      window.titleVisibility = .hidden
      window.titlebarSeparatorStyle = .none
      window.styleMask.insert(.fullSizeContentView)
      window.isMovableByWindowBackground = true
      window.hasShadow = true
      if !configured {
        configured = true
        window.setContentSize(NSSize(width: 1000, height: 740))
      }
    }
  }
  func makeNSView(context: Context) -> NSView { WindowView() }
  func updateNSView(_ view: NSView, context: Context) {}
}
struct QuietButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 12)).foregroundStyle(
      .white.opacity(configuration.isPressed ? 0.9 : 0.45)
    )
    .frame(width: 28, height: 28).background(
      .white.opacity(configuration.isPressed ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 7))
  }
}
struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
      .padding(.horizontal, 18).padding(.vertical, 9)
      .background(
        Color.cobalt.opacity(configuration.isPressed ? 0.65 : 0.9),
        in: RoundedRectangle(cornerRadius: 9)
      )
      .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
  }
}

struct GhostButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 12, weight: .medium)).foregroundStyle(
      .white.opacity(0.7)
    )
    .padding(.horizontal, 13).padding(.vertical, 9)
    .background(
      .white.opacity(configuration.isPressed ? 0.10 : 0.035), in: RoundedRectangle(cornerRadius: 9)
    )
    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.07), lineWidth: 0.5))
  }
}
