import AppKit
import IOKit.hid
import PrismCore
// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

enum WorkspaceSection: String, CaseIterable, Identifiable {
  case lighting = "Iluminación"
  case performance = "Ajustes"
  case macros = "Macros"
  case information = "Información"
  var id: String { rawValue }
  var symbol: String {
    switch self {
    case .lighting: "lightbulb"
    case .performance: "slider.horizontal.3"
    case .macros: "command.square"
    case .information: "info.circle"
    }
  }
}
struct NativeSidebar: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .sidebar
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }
  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
struct ControlGlass: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  func body(content: Content) -> some View {
    if #available(macOS 26, *), !reduceTransparency {
      content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    } else {
      content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
  }
}
struct PrismView: View {
  @Bindable var store: DeviceStore
  @State private var section: WorkspaceSection = .lighting
  @State private var polling = 1000
  @State private var showAccess = false
  private var color: Binding<Color> {
    Binding(
      get: { Color(rgb: store.light.color) },
      set: { color in
        guard let c = NSColor(color).usingColorSpace(.sRGB) else { return }
        store.light.color = RGB(
          UInt8((min(1, max(0, c.redComponent)) * 255).rounded()),
          UInt8((min(1, max(0, c.greenComponent)) * 255).rounded()),
          UInt8((min(1, max(0, c.blueComponent)) * 255).rounded()))
      })
  }
  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        HStack {
          Image(systemName: "triangle.lefthalf.filled").foregroundStyle(Color.cobalt)
          Text("Prism").font(.title2.weight(.semibold))
          Spacer()
        }.padding(.horizontal, 20).padding(.vertical, 20)
        List(selection: $store.selected) {
          Section("Dispositivos") {
            ForEach(store.devices) { device in
              HStack(spacing: 10) {
                Image(systemName: device.symbol).font(.title3).frame(width: 25)
                VStack(alignment: .leading, spacing: 4) {
                  Text(device.name).font(.system(size: 12, weight: .medium))
                  Text(device.transport).font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 5)
              }.tag(device.id)
            }
          }
        }.listStyle(.sidebar).scrollContentBackground(.hidden)
        HStack {
          BrandMark().frame(width: 46, height: 27).foregroundStyle(.primary)
          Spacer()
          Button {
            showAccess = true
          } label: {
            Image(systemName: "gearshape")
          }.buttonStyle(.borderless).help("Permisos de Prism")
        }.padding(20)
      }.background(NativeSidebar()).navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 290)
    } detail: {
      VStack(spacing: 0) {
        if let device = store.current {
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              hero(device)
              Picker("Sección", selection: $section) {
                ForEach(WorkspaceSection.allCases) { tab in
                  Label(tab.rawValue, systemImage: tab.symbol).tag(tab)
                }
              }.pickerStyle(.segmented).labelsHidden().padding(7).modifier(ControlGlass())
              Group {
                switch section {
                case .lighting: lighting(device)
                case .performance: performance(device)
                case .macros: MacroWorkspace(device: device)
                case .information: information(device)
                }
              }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(28).frame(maxWidth: 850)
              .frame(maxWidth: .infinity)
          }
          if !store.message.isEmpty && section != .macros {
            HStack(spacing: 8) {
              Image(systemName: store.isError ? "exclamationmark.circle.fill" : "checkmark.circle")
                .foregroundStyle(store.isError ? .orange : .secondary)
              Text(store.message).font(.caption).textSelection(.enabled)
              Spacer()
              Button {
                store.message = ""
              } label: {
                Image(systemName: "xmark")
              }.buttonStyle(.plain).help("Cerrar mensaje")
            }.padding(14).background(.bar).accessibilityElement(children: .contain)
          }
        } else {
          ContentUnavailableView(
            "Conecta tus periféricos", systemImage: "keyboard",
            description: Text("Selecciona un dispositivo para personalizarlo."))
        }
      }.background(Color(nsColor: .windowBackgroundColor))
    }
    .tint(.cobalt).frame(minWidth: 900, minHeight: 700)
    .toolbar {
      ToolbarItem(placement: .principal) { Text(store.current?.name ?? "Prism").font(.headline) }
      ToolbarItem {
        Button {
          store.service.refresh()
        } label: {
          Label("Actualizar", systemImage: "arrow.clockwise")
        }.help("Actualizar dispositivos")
      }
    }
    .sheet(isPresented: $showAccess) { accessSheet }
    .onChange(of: store.selected) {
      store.message = ""
      store.isError = false
      if let device = store.current {
        store.light = store.saved[device.identifier] ?? Lighting()
        if !device.driver.modes.contains(store.light.mode) { store.light.mode = .solid }
      }
    }
  }
  private func hero(_ device: Peripheral) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          Text(
            device.driver == .hyperX
              ? "HyperX"
              : device.driver == .glorious
                ? "Glorious" : device.vendor == 0x1532 ? "Razer" : "Periférico"
          ).font(.subheadline).foregroundStyle(.secondary)
          Text(device.name).font(.system(size: 28, weight: .semibold)).tracking(-0.7)
        }
        Spacer()
        Label("Conectado", systemImage: "circle.fill").font(.caption).foregroundStyle(.secondary)
          .labelStyle(ConnectionLabelStyle())
      }
      DeviceArtwork(
        device: device,
        accent: device.driver == .unsupported ? .white : Color(rgb: store.light.color)
      )
      .frame(height: 220).frame(maxWidth: .infinity)
      .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 20))
      Text("Ilustración del modelo · \(device.transport)").font(.caption2).foregroundStyle(
        .tertiary)
    }
  }
  private func group<Content: View>(
    _ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 5) {
        Text(title).font(.headline)
        if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
      }
      content()
    }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(
      .background, in: RoundedRectangle(cornerRadius: 16)
    )
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary, lineWidth: 0.6))
  }
  @ViewBuilder private func lighting(_ device: Peripheral) -> some View {
    if device.driver == .unsupported {
      ContentUnavailableView(
        "Iluminación no disponible", systemImage: "lightbulb.slash",
        description: Text(
          "Este modelo aún no tiene un controlador de iluminación. Puedes crear macros en la pestaña Macros."
        ))
    } else {
      group("Iluminación") {
        LabeledContent("Efecto") {
          Picker("Efecto", selection: $store.light.mode) {
            ForEach(device.driver.modes, id: \.self) { Text(modeTitle($0)).tag($0) }
          }.labelsHidden().frame(width: 180)
        }
        Divider()
        HStack {
          ColorPicker("Color", selection: color, supportsOpacity: false).disabled(
            ![.solid, .breathing].contains(store.light.mode))
          Spacer()
          ForEach(
            Array(
              [RGB.cobalt, RGB(241, 241, 239), RGB(255, 97, 66), RGB(100, 220, 160)].enumerated()),
            id: \.offset
          ) { _, rgb in
            Button {
              store.light.color = rgb
            } label: {
              Circle().fill(Color(rgb: rgb)).frame(width: 20, height: 20).overlay(
                Circle().stroke(.secondary.opacity(0.3)))
            }.buttonStyle(.plain).accessibilityLabel(
              String(format: "Color %02X%02X%02X", rgb.r, rgb.g, rgb.b))
          }
        }
        Divider()
        HStack {
          Text("Brillo")
          Slider(value: $store.light.brightness, in: 0...1).accessibilityLabel("Brillo")
          Text("\(Int(store.light.brightness*100)) %").font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary).frame(width: 45)
        }
        Divider()
        HStack {
          Button("Guardar preset") { store.save() }
          Spacer()
          if store.busy { ProgressView().controlSize(.small) }
          Button("Aplicar") { store.apply() }.buttonStyle(.borderedProminent).disabled(store.busy)
        }
      }
    }
  }
  @ViewBuilder private func performance(_ device: Peripheral) -> some View {
    if device.driver == .glorious {
      group("Respuesta USB", subtitle: "Configura la tasa de sondeo del perfil 1.") {
        Picker("Tasa solicitada", selection: $polling) {
          ForEach([125, 250, 500, 1000], id: \.self) { Text("\($0) Hz").tag($0) }
        }
        Text(
          "Una frecuencia mayor envía la posición del ratón más a menudo. El valor mostrado es tu selección, no una lectura del dispositivo."
        ).font(.caption).foregroundStyle(.secondary)
        HStack {
          Spacer()
          Button("Aplicar tasa") { store.apply(polling: polling) }.buttonStyle(.borderedProminent)
            .disabled(store.busy)
        }
      }
    } else {
      group(
        "Ajustes de macOS",
        subtitle: "Accede a las preferencias del sistema para este tipo de periférico."
      ) {
        Button(
          device.driver == .hyperX
            ? "Abrir ajustes de teclado…"
            : device.vendor == 0x1532 ? "Abrir ajustes de sonido…" : "Abrir ajustes del sistema…"
        ) {
          let pane =
            device.driver == .hyperX
            ? "com.apple.Keyboard-Settings.extension"
            : device.vendor == 0x1532 ? "com.apple.Sound-Settings.extension" : ""
          if let url = URL(string: "x-apple.systempreferences:\(pane)") {
            NSWorkspace.shared.open(url)
          }
        }
        Text(
          "Los ajustes propios del fabricante se añadirán cuando el protocolo de este modelo esté verificado."
        ).font(.caption).foregroundStyle(.secondary)
      }
    }
  }
  private func information(_ device: Peripheral) -> some View {
    group("Dispositivo") {
      LabeledContent("Modelo", value: device.name)
      Divider()
      LabeledContent("Conexión", value: device.transport)
      Divider()
      LabeledContent("Identificador USB", value: device.identifier)
      Divider()
      LabeledContent(
        "Control de iluminación",
        value: device.driver == .unsupported ? "No disponible" : "Experimental")
      if device.driver == .hyperX {
        Text(
          "El teclado requiere que Prism esté abierto para mantener el color. Tras suspender el Mac, vuelve a pulsar Aplicar."
        ).font(.caption).foregroundStyle(.secondary)
      }
      if device.driver == .glorious {
        Text(
          "Los cambios se escriben en el perfil 1 del ratón. DPI y asignaciones de botones todavía no están disponibles."
        ).font(.caption).foregroundStyle(.secondary)
      }
    }
  }
  private var accessSheet: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Permisos de Prism").font(.title2.bold())
      Text("Concede solo los permisos de las funciones que quieras usar.").foregroundStyle(
        .secondary)
      Divider()
      Text("Acceso USB").font(.headline)
      Text(
        "Algunos periféricos requieren Monitorización de entrada para acceder a su configuración. Prism no graba pulsaciones."
      ).font(.subheadline)
      Button("Abrir Monitorización de entrada…") {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        openPrivacy("Privacy_ListenEvent")
      }
      Divider()
      Text("Ejecución de macros").font(.headline)
      Text("Accesibilidad permite enviar las teclas que hayas definido a la aplicación que elijas.")
        .font(.subheadline)
      Button("Abrir Accesibilidad…") { openPrivacy("Privacy_Accessibility") }
      HStack {
        Spacer()
        Button("Hecho") { showAccess = false }.keyboardShortcut(.defaultAction)
      }
    }.padding(28).frame(width: 440)
  }
  private func openPrivacy(_ anchor: String) {
    NSWorkspace.shared.open(
      URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!)
  }
  private func modeTitle(_ mode: LightingMode) -> String {
    switch mode {
    case .solid: "Fijo"
    case .rainbow: "Arcoíris"
    case .breathing: "Respiración"
    case .off: "Apagado"
    }
  }
}
struct ConnectionLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 5) {
      configuration.icon.font(.system(size: 5)).foregroundStyle(.green)
      configuration.title
    }
  }
}

struct BrandMark: View {
  private static let image: NSImage? = Bundle.module.url(forResource: "ACL", withExtension: "png")
    .flatMap(NSImage.init(contentsOf:))
  var body: some View {
    if let image = Self.image {
      Image(nsImage: image).renderingMode(.template).resizable().scaledToFit().accessibilityLabel(
        "ACL")
    } else {
      Text("ACL").font(.system(size: 16, weight: .black)).accessibilityLabel("ACL")
    }
  }
}
