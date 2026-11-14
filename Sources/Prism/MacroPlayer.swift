// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
import ApplicationServices
import PrismCore

@MainActor @Observable final class MacroPlayer {
  var running = false
  var status = ""
  private var task: Task<Void, Never>?
  func cancel() {
    task?.cancel()
    status = "Ejecución cancelada."
  }
  func run(_ macro: Macro, target: NSRunningApplication) {
    guard !running else { return }
    do { try macro.validate() } catch {
      status = error.localizedDescription
      return
    }
    guard AXIsProcessTrusted() else {
      status = "Activa Prism en Privacidad y seguridad → Accesibilidad para ejecutar macros."
      return
    }
    guard !target.isTerminated,
      target.processIdentifier != ProcessInfo.processInfo.processIdentifier
    else {
      status = "Selecciona otra aplicación abierta como destino."
      return
    }
    running = true
    task = Task { [weak self] in
      guard let self else { return }
      defer {
        self.running = false
        self.task = nil
      }
      do {
        for count in (1...3).reversed() {
          self.status = "Se ejecutará en \(target.localizedName ?? "el destino") en \(count)…"
          try await Task.sleep(for: .seconds(1))
        }
        target.activate()
        try await Task.sleep(for: .milliseconds(500))
        for (index, step) in macro.steps.enumerated() {
          try Task.checkCancellation()
          guard !target.isTerminated,
            NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier
          else {
            self.status = "Se ha detenido: la aplicación de destino perdió el foco."
            return
          }
          guard let source = CGEventSource(stateID: .privateState),
            let down = CGEvent(
              keyboardEventSource: source, virtualKey: step.key.keyCode, keyDown: true),
            let up = CGEvent(
              keyboardEventSource: source, virtualKey: step.key.keyCode, keyDown: false)
          else {
            self.status = "No se pudo crear el evento de teclado."
            return
          }
          var flags: CGEventFlags = []
          if step.command { flags.insert(.maskCommand) }
          if step.option { flags.insert(.maskAlternate) }
          if step.shift { flags.insert(.maskShift) }
          if step.control { flags.insert(.maskControl) }
          down.flags = flags
          up.flags = flags
          // Post directly to the selected process; never to whichever app happens to be active.
          down.postToPid(target.processIdentifier)
          up.postToPid(target.processIdentifier)
          self.status = "Paso \(index + 1) de \(macro.steps.count)"
          try await Task.sleep(for: .milliseconds(step.delayMS))
        }
        self.status = "Macro enviada a \(target.localizedName ?? "la aplicación")."
      } catch { self.status = "Ejecución cancelada." }
    }
  }
}
