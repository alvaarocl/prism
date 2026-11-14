import AppKit
import PrismCore
// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

struct MacroWorkspace: View {
  let device: Peripheral
  @State private var macros: [Macro] = []
  @State private var selected: UUID?
  @State private var apps: [NSRunningApplication] = []
  @State private var targetPID: Int32 = 0
  @State private var player = MacroPlayer()
  private var storageKey: String { "macros.\(device.identifier)" }
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        VStack(alignment: .leading, spacing: 5) {
          Text("Macros").font(.headline)
          Text("Secuencias de teclas ejecutadas por macOS, organizadas por dispositivo.").font(
            .subheadline
          ).foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          let macro = Macro()
          macros.append(macro)
          selected = macro.id
        } label: {
          Label("Nueva macro", systemImage: "plus")
        }.disabled(player.running)
      }
      if macros.isEmpty {
        ContentUnavailableView(
          "Tu primera secuencia", systemImage: "command.square",
          description: Text("Crea combinaciones de teclas y pausas para tus tareas habituales."))
      } else {
        Picker("Macro", selection: $selected) {
          ForEach(macros) { Text($0.name.isEmpty ? "Sin nombre" : $0.name).tag(Optional($0.id)) }
        }.disabled(player.running)
        if let index = macros.firstIndex(where: { $0.id == selected }) {
          macroEditor($macros[index]).disabled(player.running)
          Divider()
          HStack {
            Picker("Enviar a", selection: $targetPID) {
              Text("Elige una aplicación").tag(Int32(0))
              ForEach(apps, id: \.processIdentifier) {
                Text($0.localizedName ?? "Aplicación").tag($0.processIdentifier)
              }
            }
            Button {
              refreshApps()
            } label: {
              Image(systemName: "arrow.clockwise")
            }.help("Actualizar aplicaciones")
          }.disabled(player.running)
          Text(
            "Se ejecuta tras una cuenta atrás de 3 segundos. Se detiene si el destino pierde el foco. No se graba ni se asigna a un botón físico del periférico."
          ).font(.caption).foregroundStyle(.secondary)
          HStack {
            Button("Eliminar macro", role: .destructive) {
              macros.remove(at: index)
              selected = macros.first?.id
            }.disabled(player.running)
            Spacer()
            if player.running {
              Button("Cancelar") { player.cancel() }.keyboardShortcut(.cancelAction)
            }
            Button(player.running ? "En ejecución…" : "Ejecutar") {
              guard let target = apps.first(where: { $0.processIdentifier == targetPID }) else {
                return
              }
              player.run(macros[index], target: target)
            }.buttonStyle(.borderedProminent).disabled(player.running || targetPID == 0)
          }
        }
      }
      if !player.status.isEmpty {
        Text(player.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
      }
    }.padding(22).background(.background, in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary, lineWidth: 0.6))
      .onChange(of: device.id, initial: true) {
        player.cancel()
        load()
        refreshApps()
      }
      .onChange(of: macros) {
        if let data = try? JSONEncoder().encode(macros) {
          UserDefaults.standard.set(data, forKey: storageKey)
        }
      }
      .onDisappear { player.cancel() }
      .onReceive(
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
      ) { _ in player.cancel() }
  }
  private func macroEditor(_ macro: Binding<Macro>) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("Nombre", text: macro.name).textFieldStyle(.roundedBorder)
      ForEach(macro.steps) { step in
        HStack(spacing: 8) {
          Picker("Tecla", selection: step.key) {
            ForEach(MacroKey.allCases, id: \.self) { Text($0.title).tag($0) }
          }.labelsHidden().frame(width: 90)
          Toggle("⌘", isOn: step.command).help("Command")
          Toggle("⌥", isOn: step.option).help("Option")
          Toggle("⇧", isOn: step.shift).help("Shift")
          Toggle("⌃", isOn: step.control).help("Control")
          Spacer(minLength: 0)
          Picker("Pausa", selection: step.delayMS) {
            ForEach([50, 100, 150, 250, 500, 1000, 2000, 5000], id: \.self) {
              Text("\($0) ms").tag($0)
            }
          }.labelsHidden().frame(width: 90).help("Pausa después de este paso")
          Button {
            macro.wrappedValue.steps.removeAll { $0.id == step.wrappedValue.id }
          } label: {
            Image(systemName: "minus.circle")
          }.buttonStyle(.borderless).help("Eliminar paso")
        }.toggleStyle(.button)
      }
      Button {
        macro.wrappedValue.steps.append(MacroStep())
      } label: {
        Label("Añadir paso", systemImage: "plus")
      }.disabled(macro.wrappedValue.steps.count >= 64)
    }
  }
  private func load() {
    macros =
      UserDefaults.standard.data(forKey: storageKey).flatMap {
        try? JSONDecoder().decode([Macro].self, from: $0)
      } ?? []
    selected = macros.first?.id
    player.status = ""
  }
  private func refreshApps() {
    apps = NSWorkspace.shared.runningApplications.filter {
      $0.activationPolicy == .regular
        && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated
    }.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    if !apps.contains(where: { $0.processIdentifier == targetPID }) { targetPID = 0 }
  }
}
