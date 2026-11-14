import PrismCore
// SPDX-License-Identifier: GPL-2.0-or-later
// Original vector silhouettes. These identify form factors, not exact product photographs.
import SwiftUI

extension Color {
  static let cobalt = Color(red: 36 / 255, green: 57 / 255, blue: 1)
  init(rgb: RGB) {
    self.init(red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255)
  }
}
struct DeviceArtwork: View {
  let device: Peripheral
  var accent: Color = .white
  var body: some View {
    Canvas { context, size in
      let scale = min(size.width / 520, size.height / 240)
      context.translateBy(x: (size.width - 520 * scale) / 2, y: (size.height - 240 * scale) / 2)
      context.scaleBy(x: scale, y: scale)
      switch device.driver {
      case .hyperX: keyboard(&context)
      case .glorious: mouse(&context)
      case .unsupported:
        if device.vendor == 0x1532 {
          headphones(&context)
        } else {
          context.draw(
            Image(systemName: "cable.connector").resizable(),
            in: CGRect(x: 205, y: 60, width: 110, height: 120))
        }
      }
    }.accessibilityLabel("Ilustración de \(device.name)")
  }
  private func keyboard(_ c: inout GraphicsContext) {
    let base = CGRect(x: 22, y: 35, width: 476, height: 168)
    c.fill(
      Path(roundedRect: base.offsetBy(dx: 0, dy: 7), cornerRadius: 10),
      with: .color(.black.opacity(0.35)))
    c.fill(
      Path(roundedRect: base, cornerRadius: 10),
      with: .linearGradient(
        Gradient(colors: [Color(white: 0.26), Color(white: 0.11)]),
        startPoint: CGPoint(x: 0, y: 35), endPoint: CGPoint(x: 0, y: 203)))
    c.stroke(
      Path(roundedRect: base, cornerRadius: 10), with: .color(.white.opacity(0.2)), lineWidth: 1)
    func key(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 23, _ title: String = "") {
      let r = CGRect(x: x, y: y, width: w, height: 20)
      c.stroke(
        Path(roundedRect: r.insetBy(dx: -0.6, dy: -0.6), cornerRadius: 3),
        with: .color(accent.opacity(0.35)), lineWidth: 0.7)
      c.fill(
        Path(roundedRect: r, cornerRadius: 3),
        with: .linearGradient(
          Gradient(colors: [Color(white: 0.18), Color(white: 0.08)]), startPoint: r.origin,
          endPoint: CGPoint(x: x, y: y + 20)))
      c.stroke(
        Path(roundedRect: r, cornerRadius: 3), with: .color(.white.opacity(0.1)), lineWidth: 0.6)
      if !title.isEmpty {
        c.draw(
          Text(title).font(.system(size: 7, weight: .medium)).foregroundColor(.white.opacity(0.65)),
          at: CGPoint(x: x + w / 2, y: y + 10))
      }
    }
    let row1 = ["esc", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"]
    for i in 0..<13 { key(33 + CGFloat(i) * 27, 47, 23, row1[i]) }
    let chars = [
      Array("1234567890-="), Array("QWERTYUIOP[]"), Array("ASDFGHJKL;'"), Array("ZXCVBNM,./"),
    ]
    for (row, letters) in chars.enumerated() {
      let y = CGFloat(80 + row * 25)
      let offset = CGFloat(row) * 5
      key(33, y, 25 + offset, row == 0 ? "~" : row == 1 ? "tab" : row == 2 ? "caps" : "shift")
      for (i, letter) in letters.enumerated() {
        key(63 + offset + CGFloat(i) * 25, y, 22, String(letter))
      }
      let end = 63 + offset + CGFloat(letters.count) * 25
      if end < 378 { key(end, y, 378 - end, row == 2 ? "↩" : row == 0 ? "⌫" : "") }
    }
    key(33, 180, 30, "ctrl")
    key(67, 180, 26, "⊞")
    key(97, 180, 26, "alt")
    key(127, 180, 150, "")
    key(281, 180, 26, "alt")
    key(311, 180, 26, "fn")
    key(341, 180, 37, "ctrl")
    for row in 0..<2 {
      for col in 0..<3 {
        key(
          403 + CGFloat(col) * 28, 80 + CGFloat(row) * 25, 24,
          ["ins", "home", "↑", "del", "end", "↓"][row * 3 + col])
      }
    }
    key(431, 155, 24, "↑")
    key(403, 180, 24, "←")
    key(431, 180, 24, "↓")
    key(459, 180, 24, "→")
    c.draw(
      Text("ALLOY ORIGINS CORE").font(.system(size: 5, weight: .semibold)).foregroundColor(
        .white.opacity(0.35)), at: CGPoint(x: 446, y: 60))
  }
  private func mouse(_ c: inout GraphicsContext) {
    var outline = Path()
    outline.move(to: CGPoint(x: 220, y: 31))
    outline.addCurve(
      to: CGPoint(x: 316, y: 39), control1: CGPoint(x: 247, y: 18), control2: CGPoint(x: 295, y: 17)
    )
    outline.addCurve(
      to: CGPoint(x: 336, y: 181), control1: CGPoint(x: 344, y: 69),
      control2: CGPoint(x: 354, y: 144))
    outline.addCurve(
      to: CGPoint(x: 185, y: 182), control1: CGPoint(x: 318, y: 224),
      control2: CGPoint(x: 207, y: 224))
    outline.addCurve(
      to: CGPoint(x: 220, y: 31), control1: CGPoint(x: 165, y: 144),
      control2: CGPoint(x: 185, y: 56))
    outline.closeSubpath()
    c.fill(
      outline,
      with: .linearGradient(
        Gradient(colors: [Color(white: 0.28), Color(white: 0.1)]),
        startPoint: CGPoint(x: 210, y: 30), endPoint: CGPoint(x: 320, y: 210)))
    c.stroke(outline, with: .color(.white.opacity(0.4)), lineWidth: 1.2)
    var seam = Path()
    seam.move(to: CGPoint(x: 260, y: 26))
    seam.addLine(to: CGPoint(x: 258, y: 102))
    seam.move(to: CGPoint(x: 194, y: 101))
    seam.addQuadCurve(to: CGPoint(x: 338, y: 101), control: CGPoint(x: 264, y: 112))
    c.stroke(seam, with: .color(.black.opacity(0.7)), lineWidth: 2)
    c.fill(
      Path(roundedRect: CGRect(x: 250, y: 45, width: 17, height: 37), cornerRadius: 7),
      with: .color(.black))
    for i in 0..<6 {
      c.stroke(
        Path(CGRect(x: 252, y: 50 + CGFloat(i) * 4, width: 13, height: 0.5)),
        with: .color(.white.opacity(0.3)), lineWidth: 0.7)
    }
    c.fill(
      Path(roundedRect: CGRect(x: 253, y: 89, width: 12, height: 7), cornerRadius: 3),
      with: .color(.black))
    for row in 0..<6 {
      for col in 0..<7 {
        let x = 208 + CGFloat(col) * 17 + (row % 2 == 0 ? 0 : 8)
        let y = 119 + CGFloat(row) * 12
        if x < 321 && !(row > 3 && (x < 217 || x > 305)) {
          var hex = Path()
          for i in 0..<6 {
            let a = Double(i) * Double.pi / 3
            let p = CGPoint(x: x + 5 * cos(a), y: y + 5 * sin(a))
            if i == 0 { hex.move(to: p) } else { hex.addLine(to: p) }
          }
          hex.closeSubpath()
          c.fill(hex, with: .color(.black.opacity(0.65)))
          c.stroke(hex, with: .color(.white.opacity(0.12)), lineWidth: 0.7)
        }
      }
    }
    var strip = Path()
    strip.move(to: CGPoint(x: 188, y: 137))
    strip.addQuadCurve(to: CGPoint(x: 207, y: 200), control: CGPoint(x: 183, y: 183))
    strip.move(to: CGPoint(x: 335, y: 137))
    strip.addQuadCurve(to: CGPoint(x: 315, y: 201), control: CGPoint(x: 343, y: 183))
    c.stroke(strip, with: .color(accent.opacity(0.8)), lineWidth: 2)
    c.fill(
      Path(roundedRect: CGRect(x: 183, y: 77, width: 5, height: 28), cornerRadius: 2),
      with: .color(Color(white: 0.3)))
  }
  private func headphones(_ c: inout GraphicsContext) {
    var band = Path()
    band.move(to: CGPoint(x: 168, y: 153))
    band.addCurve(
      to: CGPoint(x: 352, y: 153), control1: CGPoint(x: 139, y: -17),
      control2: CGPoint(x: 379, y: -17))
    c.stroke(
      band, with: .color(Color(white: 0.15)), style: StrokeStyle(lineWidth: 22, lineCap: .round))
    c.stroke(band, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: 1))
    for (x, rotation) in [(CGFloat(155), -0.12), (CGFloat(323), 0.12)] {
      var side = c
      side.translateBy(x: x + 21, y: 161)
      side.rotate(by: .radians(rotation))
      side.fill(
        Path(roundedRect: CGRect(x: -23, y: -51, width: 46, height: 102), cornerRadius: 21),
        with: .color(Color(white: 0.08)))
      side.stroke(
        Path(roundedRect: CGRect(x: -23, y: -51, width: 46, height: 102), cornerRadius: 21),
        with: .color(.white.opacity(0.32)), lineWidth: 1)
      side.fill(
        Path(roundedRect: CGRect(x: -12, y: -42, width: 25, height: 83), cornerRadius: 12),
        with: .linearGradient(
          Gradient(colors: [Color(white: 0.3), Color(white: 0.12)]),
          startPoint: CGPoint(x: -10, y: -40), endPoint: CGPoint(x: 20, y: 40)))
      side.stroke(
        Path(CGRect(x: -15, y: -75, width: 1, height: 44)), with: .color(.white.opacity(0.5)),
        lineWidth: 2)
    }
    var mic = Path()
    mic.move(to: CGPoint(x: 164, y: 183))
    mic.addQuadCurve(to: CGPoint(x: 231, y: 215), control: CGPoint(x: 176, y: 218))
    c.stroke(
      mic, with: .color(Color(white: 0.32)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
    c.fill(
      Path(roundedRect: CGRect(x: 226, y: 208, width: 24, height: 11), cornerRadius: 5),
      with: .color(Color(white: 0.13)))
  }
}
