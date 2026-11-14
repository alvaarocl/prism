import PrismCore
// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

extension Color {
  static let cobalt = Color(red: 36 / 255, green: 57 / 255, blue: 1)
  init(rgb: RGB) {
    self.init(red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255)
  }
}
