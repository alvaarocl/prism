// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

public enum MacroKey: String, CaseIterable, Codable, Sendable {
  case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
  case enter, tab, escape, space, backspace, up, down, left, right
  case zero, one, two, three, four, five, six, seven, eight, nine
  case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
  case home, end, pageUp, pageDown, forwardDelete
  public var keyCode: UInt16 {
    switch self {
    case .a: 0
    case .b: 11
    case .c: 8
    case .d: 2
    case .e: 14
    case .f: 3
    case .g: 5
    case .h: 4
    case .i: 34
    case .j: 38
    case .k: 40
    case .l: 37
    case .m: 46
    case .n: 45
    case .o: 31
    case .p: 35
    case .q: 12
    case .r: 15
    case .s: 1
    case .t: 17
    case .u: 32
    case .v: 9
    case .w: 13
    case .x: 7
    case .y: 16
    case .z: 6
    case .enter: 36
    case .tab: 48
    case .escape: 53
    case .space: 49
    case .backspace: 51
    case .up: 126
    case .down: 125
    case .left: 123
    case .right: 124
    case .zero: 29
    case .one: 18
    case .two: 19
    case .three: 20
    case .four: 21
    case .five: 23
    case .six: 22
    case .seven: 26
    case .eight: 28
    case .nine: 25
    case .f1: 122
    case .f2: 120
    case .f3: 99
    case .f4: 118
    case .f5: 96
    case .f6: 97
    case .f7: 98
    case .f8: 100
    case .f9: 101
    case .f10: 109
    case .f11: 103
    case .f12: 111
    case .home: 115
    case .end: 119
    case .pageUp: 116
    case .pageDown: 121
    case .forwardDelete: 117
    }
  }
  public var title: String {
    switch self {
    case .enter: "↩"
    case .tab: "⇥"
    case .escape: "⎋"
    case .space: "Espacio"
    case .backspace: "⌫"
    case .up: "↑"
    case .down: "↓"
    case .left: "←"
    case .right: "→"
    case .zero: "0"
    case .one: "1"
    case .two: "2"
    case .three: "3"
    case .four: "4"
    case .five: "5"
    case .six: "6"
    case .seven: "7"
    case .eight: "8"
    case .nine: "9"
    case .pageUp: "Re Pág"
    case .pageDown: "Av Pág"
    case .forwardDelete: "⌦"
    default: rawValue.uppercased()
    }
  }
}
public struct MacroStep: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var key: MacroKey
  public var command: Bool
  public var option: Bool
  public var shift: Bool
  public var control: Bool
  public var delayMS: Int
  public init(
    id: UUID = UUID(), key: MacroKey = .a, command: Bool = false, option: Bool = false,
    shift: Bool = false, control: Bool = false, delayMS: Int = 150
  ) {
    self.id = id
    self.key = key
    self.command = command
    self.option = option
    self.shift = shift
    self.control = control
    self.delayMS = delayMS
  }
  public var label: String {
    (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "")
      + key.title
  }
}
public struct Macro: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var name: String
  public var steps: [MacroStep]
  public init(id: UUID = UUID(), name: String = "Nueva macro", steps: [MacroStep] = [MacroStep()]) {
    self.id = id
    self.name = name
    self.steps = steps
  }
  public func validate() throws {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 80 else {
      throw MacroError.invalidName
    }
    guard (1...64).contains(steps.count), Set(steps.map(\.id)).count == steps.count,
      steps.allSatisfy({ (50...5000).contains($0.delayMS) }),
      steps.reduce(0, { $0 + $1.delayMS }) <= 60000
    else { throw MacroError.invalidSequence }
  }
}
public enum MacroError: Error, LocalizedError {
  case invalidName, invalidSequence
  public var errorDescription: String? {
    switch self {
    case .invalidName: "Escribe un nombre de entre 1 y 80 caracteres."
    case .invalidSequence:
      "Usa de 1 a 64 pasos, pausas de 50 a 5000 ms y una duración total de hasta un minuto."
    }
  }
}
