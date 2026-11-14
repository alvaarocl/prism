// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit
import IOKit.hid
import PrismCore

@MainActor @Observable final class DeviceStore {
    var devices: [Peripheral] = []
    var selected: String?
    var light = Lighting()
    var busy = false
    var message = "Los cambios solo se envían al pulsar Aplicar."
    var isError = false
    var saved: [String: Lighting] = [:]
    let service = HIDService()
    private var sleepObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    var current: Peripheral? { devices.first { $0.id == selected } }
    init() {
        if let data = UserDefaults.standard.data(forKey: "lightingPresets"),
           let decoded = try? JSONDecoder().decode([String: Lighting].self, from: data) { saved = decoded }
        service.changed = { [weak self] devices in
            Task { @MainActor in
                guard let self else { return }
                self.devices = devices
                if !devices.contains(where: { $0.id == self.selected }) { self.selected = devices.first?.id }
            }
        }
        service.failed = { [weak self] message in
            Task { @MainActor in self?.message = message; self?.isError = true }
        }
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak service] _ in service?.suspend() }
        terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak service] _ in service?.suspend() }
        service.start()
    }
    func apply(polling: Int? = nil) {
        guard let device = current, !busy else { return }
        busy = true; isError = false; message = "Enviando al dispositivo…"
        service.apply(device, lighting: polling == nil ? light : nil, polling: polling) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.busy = false; self.isError = error != nil
                self.message = error ?? "Configuración enviada. Comprueba el resultado en tu periférico."
            }
        }
    }
    func save() {
        guard let device = current else { return }
        saved[device.identifier] = light
        if let data = try? JSONEncoder().encode(saved) { UserDefaults.standard.set(data, forKey: "lightingPresets") }
        message = "Preset guardado en este Mac. No se aplica automáticamente."; isError = false
    }
}
extension Color {
    static let ink = Color(red: 11/255, green: 11/255, blue: 13/255)
    static let panel = Color(red: 20/255, green: 21/255, blue: 25/255)
    static let cobalt = Color(red: 36/255, green: 57/255, blue: 255/255)
    static let bone = Color(red: 241/255, green: 241/255, blue: 239/255)
    init(rgb: RGB) { self.init(red: Double(rgb.r)/255, green: Double(rgb.g)/255, blue: Double(rgb.b)/255) }
}
struct PrismView: View {
    @Bindable var store: DeviceStore
    @State private var polling = 1000
    private var colorBinding: Binding<Color> {
        Binding(get: { Color(rgb: store.light.color) }, set: { color in
            guard let c = NSColor(color).usingColorSpace(.sRGB) else { return }
            store.light.color = RGB(UInt8((min(1,max(0,c.redComponent))*255).rounded()), UInt8((min(1,max(0,c.greenComponent))*255).rounded()), UInt8((min(1,max(0,c.blueComponent))*255).rounded()))
        })
    }
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 248)
            Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("TU ESCRITORIO, A TU MANERA").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
                        Text(store.current?.name ?? "Tus periféricos").font(.system(size: 27, weight: .bold)).tracking(-0.8)
                    }
                    Spacer()
                    Text("ALPHA 0.1").font(.system(size: 10, weight: .semibold, design: .monospaced)).padding(8).background(.white.opacity(0.05), in: Capsule())
                }
                if let device = store.current {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            deviceCard(device)
                            if device.driver != .unsupported {
                                lightingCard(device)
                                if device.driver == .glorious { performanceCard }
                            } else {
                                ContentUnavailableView("Dispositivo detectado", systemImage: "cable.connector", description: Text("Todavía no hay un controlador para este modelo. Prism no enviará comandos a un dispositivo desconocido."))
                                    .frame(minHeight: 180)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Conecta tu escritorio", systemImage: "keyboard", description: Text("Los periféricos USB y Bluetooth aparecerán aquí. No necesitas una cuenta."))
                    Spacer()
                }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: store.isError ? "exclamationmark.circle" : "info.circle").foregroundStyle(store.isError ? .orange : .secondary)
                    Text(store.message).font(.system(size: 12)).foregroundStyle(store.isError ? .orange : .secondary).textSelection(.enabled)
                    Spacer(minLength: 0)
                }.frame(minHeight: 34, alignment: .top).accessibilityElement(children: .combine)
            }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }.background(Color.ink).foregroundStyle(Color.bone).tint(.cobalt).preferredColorScheme(.dark)
            .frame(minWidth: 880, minHeight: 650)
            .onChange(of: store.selected) {
                store.message = "Los cambios solo se envían al pulsar Aplicar."; store.isError = false
                if let device = store.current {
                    store.light = store.saved[device.identifier] ?? Lighting()
                    if !device.driver.modes.contains(store.light.mode) { store.light.mode = .solid }
                }
            }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "triangle.lefthalf.filled").font(.system(size: 27)).foregroundStyle(Color.cobalt)
                Text("prism").font(.system(size: 32, weight: .heavy)).tracking(-1.5)
            }.padding(.top, 30).padding(.bottom, 5)
            Text("by Álvaro Carpintero").font(.system(size: 11)).foregroundStyle(.secondary).padding(.bottom, 34)
            HStack { Text("DISPOSITIVOS").font(.system(size: 10, weight: .semibold)).tracking(1.5); Spacer(); Text("\(store.devices.count)").monospacedDigit() }.foregroundStyle(.secondary).padding(.bottom, 12)
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(store.devices) { device in
                        Button { store.selected = device.id } label: {
                            HStack(spacing: 10) {
                                Image(systemName: device.symbol).font(.system(size: 19)).frame(width: 24)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.name).font(.system(size: 12, weight: .medium)).multilineTextAlignment(.leading)
                                    Text(device.driver == .unsupported ? "Solo información" : "USB directo · experimental").font(.system(size: 9)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(store.selected == device.id ? Color.cobalt.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(store.selected == device.id ? Color.cobalt.opacity(0.45) : .clear))
                        }.buttonStyle(.plain)
                    }
                }
            }
            Spacer(minLength: 20)
            Button { store.service.refresh() } label: { Label("Actualizar dispositivos", systemImage: "arrow.clockwise") }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary).padding(.bottom, 16)
            Button("Permisos de acceso USB") {
                IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
            }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary).padding(.bottom, 16)
            Divider().padding(.bottom, 16)
            HStack(spacing: 6) { Circle().fill(.green).frame(width: 5, height: 5); Text("Local. Sin cuentas. Sin telemetría.").font(.system(size: 9)) }.foregroundStyle(.secondary)
            Link("Código abierto ↗", destination: URL(string: "https://github.com/alvaarocl/prism")!).font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 10)
        }.padding(.horizontal, 20).padding(.bottom, 22).background(Color.panel)
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18, content: content).padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.07)))
    }
    private func deviceCard(_ device: Peripheral) -> some View {
        card {
            HStack(spacing: 20) {
                Image(systemName: device.symbol).font(.system(size: 40, weight: .light)).foregroundStyle(device.driver == .unsupported ? .secondary : Color(rgb: store.light.color)).frame(width: 65, height: 55)
                VStack(alignment: .leading, spacing: 6) {
                    Text(device.transport + " conectado").font(.system(size: 13, weight: .semibold))
                    Text(device.identifier).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                    Text(device.driver == .hyperX ? "Color por USB · requiere Prism abierto" : device.driver == .glorious ? "Perfil 1 · los cambios se guardan en el ratón" : "Lectura de información").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(.green).frame(width: 7, height: 7).accessibilityLabel("Conectado")
            }
        }
    }
    private func lightingCard(_ device: Peripheral) -> some View {
        card {
            HStack { Label("Iluminación", systemImage: "lightbulb").font(.system(size: 16, weight: .semibold)); Spacer(); Text("RGB").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary) }
            Picker("Efecto", selection: $store.light.mode) { ForEach(device.driver.modes, id: \.self) { Text(modeTitle($0)).tag($0) } }.pickerStyle(.segmented)
            HStack {
                ColorPicker("Color", selection: colorBinding, supportsOpacity: false).disabled(store.light.mode != .solid && store.light.mode != .breathing)
                Spacer()
                ForEach(Array([RGB.cobalt, RGB(241,241,239), RGB(255,97,66), RGB(100,220,160)].enumerated()), id: \.offset) { _, rgb in
                    Button { store.light.color = rgb } label: { Circle().fill(Color(rgb: rgb)).frame(width: 22, height: 22).overlay(Circle().stroke(.white.opacity(0.25))) }.buttonStyle(.plain).accessibilityLabel(String(format: "Color %02X%02X%02X", rgb.r,rgb.g,rgb.b))
                }
            }
            HStack { Text("Brillo").font(.system(size: 12)); Slider(value: $store.light.brightness, in: 0...1).accessibilityLabel("Brillo"); Text("\(Int(store.light.brightness * 100)) %").font(.system(size: 11, design: .monospaced)).frame(width: 46) }
            Divider()
            HStack {
                Button("Guardar preset") { store.save() }.buttonStyle(.bordered)
                Spacer()
                if store.busy { ProgressView().controlSize(.small) }
                Button("Aplicar al dispositivo") { store.apply() }.buttonStyle(.borderedProminent).disabled(store.busy).keyboardShortcut(.return, modifiers: .command)
            }
        }
    }
    private func modeTitle(_ mode: LightingMode) -> String {
        switch mode { case .solid: "Fijo"; case .rainbow: "Arcoíris"; case .breathing: "Respiración"; case .off: "Apagado" }
    }
    private var performanceCard: some View {
        card {
            Label("Rendimiento", systemImage: "speedometer").font(.system(size: 16, weight: .semibold))
            Text("Tasa de sondeo experimental. El resto del perfil se conserva. DPI y botones llegarán con controladores verificados.").font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Picker("USB", selection: $polling) { ForEach([125,250,500,1000], id: \.self) { Text("\($0) Hz").tag($0) } }.frame(maxWidth: 250)
                Spacer()
                Button("Aplicar tasa") { store.apply(polling: polling) }.disabled(store.busy)
            }
        }
    }
}
@main struct PrismApp: App {
    @State private var store = DeviceStore()
    init() {
        if CommandLine.arguments.contains("--diagnose") {
            let service = HIDService()
            service.changed = { devices in
                for d in devices { print("\(d.identifier) | \(d.name) | \(d.driver.rawValue) | \(d.transport)") }
                exit(0)
            }
            service.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { print("HID discovery timed out"); exit(1) }
            dispatchMain()
        }
    }
    var body: some Scene {
        WindowGroup("Prism") { PrismView(store: store) }.defaultSize(width: 940, height: 740)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Acerca de Prism") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [.applicationName: "Prism", .applicationVersion: "0.1.0 alpha", .credits: NSAttributedString(string: "By Álvaro Carpintero\nNative macOS peripheral control.\nGPL-2.0-or-later. Drivers adapted from OpenRGB.\nSee THIRD_PARTY.md in the public repository.")])
                }
            }
        }
    }
}
