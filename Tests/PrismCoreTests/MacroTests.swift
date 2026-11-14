import Foundation
import Testing

@testable import PrismCore

@Test func macroRejectsUnboundedSequences() {
  #expect(throws: MacroError.self) { try Macro(name: "").validate() }
  #expect(throws: MacroError.self) { try Macro(steps: []).validate() }
  #expect(throws: MacroError.self) { try Macro(steps: [MacroStep(delayMS: -1)]).validate() }
  #expect(throws: MacroError.self) {
    try Macro(steps: Array(repeating: MacroStep(delayMS: 5000), count: 20)).validate()
  }
  let step = MacroStep()
  #expect(throws: MacroError.self) { try Macro(steps: [step, step]).validate() }
}
@Test func macrosPersistAndKeepModifierCombinations() throws {
  let macro = Macro(name: "Copiar", steps: [MacroStep(key: .c, command: true)])
  try macro.validate()
  #expect(macro.steps[0].label == "⌘C")
  #expect(macro.steps[0].key.keyCode == 8)
  let data = try JSONEncoder().encode(macro)
  #expect(try JSONDecoder().decode(Macro.self, from: data) == macro)
  #expect(Set(MacroKey.allCases.map(\.keyCode)).count == MacroKey.allCases.count)
}
