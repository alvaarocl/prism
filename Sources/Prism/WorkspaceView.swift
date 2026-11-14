import AppKit
import IOKit.hid
import PrismCore
import ServiceManagement
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
struct PrismView: View {
  @Bindable var store: DeviceStore
  @State private var section: WorkspaceSection = .lighting
  @State private var showAccess = false
  @State private var hoveredDevice: String?
  @State private var showModes = false
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
  @Namespace private var selectionGlow
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false
  var body: some View {
    HStack(spacing: 0) {
      sidebar.frame(width: 218)
      Rectangle().fill(.white.opacity(0.08)).frame(width: 0.5)
      VStack(alignment: .leading, spacing: 0) {
        HStack {
          Text("Dispositivos").foregroundStyle(.white.opacity(0.38))
          Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white.opacity(0.22))
          Text(store.current?.name ?? "Prism").foregroundStyle(.white.opacity(0.8))
          Spacer()
          Button {
            store.service.refresh()
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .buttonStyle(QuietButtonStyle()).help("Actualizar dispositivos")
        }.font(.system(size: 12)).padding(.horizontal, 28).frame(height: 64)
        Rectangle().fill(.white.opacity(0.07)).frame(height: 0.5)
        if let device = store.current {
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              hero(device)
              sectionBar
              Group {
                switch section {
                case .lighting: lighting(device)
                case .performance: performance(device)
                case .macros: MacroWorkspace(device: device)
                case .information: information(device)
                }
              }.id("\(device.id)-\(section.id)")
                .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 5)))
            }.padding(28).frame(maxWidth: 860).frame(maxWidth: .infinity, alignment: .top)
          }
          if !store.message.isEmpty && section != .macros {
            HStack(spacing: 8) {
              Image(systemName: store.isError ? "exclamationmark.circle.fill" : "checkmark.circle")
                .foregroundStyle(store.isError ? .orange : .white.opacity(0.55))
              Text(store.message).font(.caption).textSelection(.enabled)
              Spacer()
              Button {
                store.message = ""
              } label: {
                Image(systemName: "xmark")
              }.buttonStyle(QuietButtonStyle()).help("Cerrar mensaje")
            }.padding(14).background(.white.opacity(0.025))
          }
        } else {
          ContentUnavailableView(
            "Conecta tus periféricos", systemImage: "keyboard",
            description: Text("Selecciona un dispositivo para personalizarlo."))
        }
      }
    }
    .background(WindowGlass())
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(
        .white.opacity(0.18), lineWidth: 0.5)
    )
    .foregroundStyle(Color(red: 241 / 255, green: 241 / 255, blue: 239 / 255))
    .preferredColorScheme(.dark).tint(.white.opacity(0.9)).font(.system(size: 13))
    .frame(minWidth: 940, minHeight: 700)
    .opacity(appeared ? 1 : 0)
    .onAppear { withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.16)) { appeared = true } }
    .animation(.easeOut(duration: reduceMotion ? 0 : 0.18), value: section)
    .animation(.easeOut(duration: reduceMotion ? 0 : 0.18), value: store.selected)
    .ignoresSafeArea(.container, edges: .top)
    .background(WindowAppearance())
    .sheet(isPresented: $showAccess) { accessSheet }
    .onChange(of: store.selected, initial: true) {
      store.message = ""
      store.isError = false
      if let device = store.current {
        store.light = store.saved[device.identifier] ?? Lighting()
        store.polling = store.service.polling[device.identifier] ?? 1000
        if !device.driver.modes.contains(store.light.mode) { store.light.mode = .solid }
      }
    }
  }
  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 9) {
        Image(systemName: "triangle.lefthalf.filled").foregroundStyle(.white.opacity(0.9)).font(
          .system(size: 20))
        Text("prism").font(.system(size: 25, weight: .semibold)).tracking(-0.9)
      }.padding(.horizontal, 22).padding(.top, 52).padding(.bottom, 32)
      Text("DISPOSITIVOS").font(.system(size: 9, weight: .semibold)).tracking(1.7).foregroundStyle(
        .white.opacity(0.34)
      ).padding(.horizontal, 22).padding(.bottom, 12)
      ScrollView {
        VStack(spacing: 5) {
          ForEach(store.devices) { device in
            Button {
              store.selected = device.id
            } label: {
              HStack(spacing: 11) {
                Image(systemName: device.symbol).font(.system(size: 17, weight: .light)).frame(
                  width: 23
                ).foregroundStyle(.white.opacity(store.selected == device.id ? 0.9 : 0.4))
                VStack(alignment: .leading, spacing: 4) {
                  Text(shortName(device)).font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.leading)
                  Text(device.transport).font(.system(size: 10)).foregroundStyle(
                    .white.opacity(0.35))
                }
                Spacer(minLength: 0)
              }.padding(.horizontal, 12).padding(.vertical, 12).frame(
                maxWidth: .infinity, alignment: .leading
              )
              .background {
                if store.selected == device.id {
                  RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.075))
                    .overlay(
                      RoundedRectangle(cornerRadius: 10).strokeBorder(
                        .white.opacity(0.08), lineWidth: 0.5)
                    )
                    .matchedGeometryEffect(id: "device", in: selectionGlow)
                } else if hoveredDevice == device.id {
                  RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.035))
                }
              }
              .contentShape(RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).onHover { hoveredDevice = $0 ? device.id : nil }
          }
        }.padding(.horizontal, 10)
      }
      Spacer(minLength: 20)
      HStack {
        BrandMark().frame(width: 40, height: 23).foregroundStyle(.white.opacity(0.5))
        Spacer()
        Button {
          showAccess = true
        } label: {
          Image(systemName: "slider.horizontal.3")
        }.buttonStyle(QuietButtonStyle()).help("Permisos de Prism")
      }.padding(22)
    }.background(.black.opacity(0.12))
  }
  private var sectionBar: some View {
    HStack(spacing: 4) {
      ForEach(WorkspaceSection.allCases) { tab in
        Button {
          section = tab
        } label: {
          HStack(spacing: 7) {
            Image(systemName: tab.symbol).font(.system(size: 12))
            Text(tab.rawValue).font(.system(size: 12, weight: section == tab ? .medium : .regular))
          }.foregroundStyle(.white.opacity(section == tab ? 0.95 : 0.43)).padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background {
              if section == tab {
                RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.09))
                  .overlay(
                    RoundedRectangle(cornerRadius: 10).strokeBorder(
                      .white.opacity(0.14), lineWidth: 0.5)
                  )
                  .matchedGeometryEffect(id: "section", in: selectionGlow)
              }
            }.contentShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).accessibilityAddTraits(section == tab ? .isSelected : [])
      }
    }.padding(5).background(.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 14))
      .overlay(
        RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.07), lineWidth: 0.5))
  }
  private func shortName(_ device: Peripheral) -> String {
    if device.vendor == 0x1532 && [0x0565, 0x056e].contains(device.product) {
      return "BlackShark V2 HyperSpeed"
    }
    return device.name.replacingOccurrences(of: "HyperX ", with: "").replacingOccurrences(
      of: "Glorious ", with: ""
    ).replacingOccurrences(of: "Razer ", with: "")
  }
  private func hero(_ device: Peripheral) -> some View {
    HStack(spacing: 26) {
      ProductPhoto(device: device)
        .frame(width: 300, height: 218)
        .padding(.vertical, 8)
      VStack(alignment: .leading, spacing: 12) {
        Text(
          device.driver == .hyperX
            ? "HYPERX"
            : device.driver == .glorious
              ? "GLORIOUS" : device.vendor == 0x1532 ? "RAZER" : "PERIFÉRICO"
        )
        .font(.system(size: 9, weight: .semibold)).tracking(1.8).foregroundStyle(
          .white.opacity(0.4))
        Text(shortName(device)).font(.system(size: 27, weight: .medium)).tracking(-0.8).fixedSize(
          horizontal: false, vertical: true)
        HStack(spacing: 6) {
          Circle().fill(Color(red: 0.48, green: 0.7, blue: 0.58)).frame(width: 5, height: 5)
          Text("Conectado").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
          Text("/  \(device.transport)").font(.system(size: 11)).foregroundStyle(
            .white.opacity(0.3))
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
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
      .white.opacity(0.025), in: RoundedRectangle(cornerRadius: 14)
    )
    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.07), lineWidth: 0.5))
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
        HStack {
          Text("Efecto")
          Spacer()
          Button {
            showModes.toggle()
          } label: {
            HStack {
              Text(modeTitle(store.light.mode))
              Spacer()
              Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
            }.padding(.horizontal, 11).padding(.vertical, 9).frame(width: 162)
              .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
              .overlay(
                RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
          }.buttonStyle(.plain).accessibilityLabel("Efecto").accessibilityValue(
            modeTitle(store.light.mode)
          )
          .popover(isPresented: $showModes, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
              ForEach(device.driver.modes, id: \.self) { mode in
                Button {
                  store.light.mode = mode
                  showModes = false
                } label: {
                  HStack {
                    Image(systemName: "checkmark").opacity(store.light.mode == mode ? 1 : 0).frame(
                      width: 14)
                    Text(modeTitle(mode))
                    Spacer()
                  }.padding(9).frame(width: 150)
                    .background(
                      .white.opacity(store.light.mode == mode ? 0.08 : 0),
                      in: RoundedRectangle(cornerRadius: 7))
                }.buttonStyle(.plain)
              }
            }.padding(7).preferredColorScheme(.dark)
          }
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
          Spacer()
          if store.busy { ProgressView().controlSize(.small) }
          Button("Aplicar") { store.apply() }.buttonStyle(PrimaryButtonStyle()).disabled(store.busy)
        }
      }
    }
  }
  @ViewBuilder private func performance(_ device: Peripheral) -> some View {
    if device.driver == .glorious {
      group("Respuesta USB", subtitle: "Configura la tasa de sondeo del perfil 1.") {
        Picker("Tasa solicitada", selection: $store.polling) {
          ForEach([125, 250, 500, 1000], id: \.self) { Text("\($0) Hz").tag($0) }
        }
        Text(
          "Una frecuencia mayor envía la posición del ratón más a menudo. El valor mostrado es tu selección, no una lectura del dispositivo."
        ).font(.caption).foregroundStyle(.secondary)
        HStack {
          Spacer()
          Button("Aplicar tasa") { store.apply(polling: store.polling) }.buttonStyle(
            PrimaryButtonStyle()
          )
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
          "El controlador mantiene el color aunque cierres esta ventana y lo recupera al despertar. Para detenerlo, usa Prism → Detener Prism por completo."
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
      Text("Controlador de segundo plano").font(.headline)
      Text(store.service.running ? "Controlador activo" : "Controlador pendiente de autorización")
        .font(.caption).foregroundStyle(.secondary)
      Text(
        "Mantiene los ajustes con la ventana cerrada. Se inicia al entrar en macOS y recupera el color al despertar."
      ).font(.subheadline)
      Button("Abrir ítems de inicio…") { SMAppService.openSystemSettingsLoginItems() }
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
