import Darwin
// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import PrismCore
import ServiceManagement

@MainActor final class AgentClient {
  static let service = SMAppService.agent(plistName: "com.alvaarocl.prism.agent.plist")
  var changed: (@Sendable ([Peripheral]) -> Void)?
  var failed: (@Sendable (String) -> Void)?
  var applied: [String: Lighting] = [:]
  var running = false
  var polling: [String: Int] = [:]
  private var observer: DispatchSourceFileSystemObject?
  private var pending: (UUID, @Sendable (String?) -> Void)?
  private var timeout: Task<Void, Never>?
  func start() {
    guard !CommandLine.arguments.contains(where: { $0.hasPrefix("--") }) else { return }
    do {
      try AgentFiles.prepare()
      if Self.service.status == .notRegistered || Self.service.status == .notFound {
        try Self.service.register()
      }
      guard Self.service.status == .enabled else {
        failed?("Activa Prism en Ajustes → General → Ítems de inicio → Permitir en segundo plano.")
        return
      }
      let fd = open(AgentFiles.directory.path, O_EVTONLY)
      guard fd >= 0 else { throw CocoaError(.fileReadNoPermission) }
      let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: fd, eventMask: [.write, .rename], queue: .main)
      source.setEventHandler { [weak self] in self?.reload() }
      source.setCancelHandler { close(fd) }
      observer = source
      source.resume()
      reload()
    } catch { failed?("No se pudo iniciar el controlador: \(error.localizedDescription)") }
  }
  private func reload() {
    guard let status = AgentFiles.read(AgentStatus.self, from: "status.json"),
      kill(status.pid, 0) == 0
    else { return }
    running = true
    applied = status.applied
    polling = status.polling ?? [:]
    changed?(status.devices)
    if let (id, completion) = pending, status.completedRequest == id {
      pending = nil
      timeout?.cancel()
      timeout = nil
      completion(status.error)
    } else if let error = status.error, pending == nil {
      failed?(error)
    }
  }
  func refresh() { reload() }
  func apply(
    _ device: Peripheral, lighting: Lighting?, polling: Int? = nil,
    completion: @escaping @Sendable (String?) -> Void
  ) {
    guard running else {
      completion("El controlador de segundo plano no está activo. Abre los permisos de Prism.")
      return
    }
    guard pending == nil else {
      completion("Espera a que termine el cambio anterior.")
      return
    }
    do {
      let request = AgentRequest(deviceID: device.id, lighting: lighting, polling: polling)
      pending = (request.id, completion)
      try AgentFiles.write(request, to: "request.json")
      timeout = Task { [weak self] in
        do { try await Task.sleep(for: .seconds(8)) } catch { return }
        guard let self, let (_, callback) = self.pending else { return }
        self.pending = nil
        callback("El controlador no respondió. No se ha confirmado el cambio.")
      }
    } catch {
      pending = nil
      completion(error.localizedDescription)
    }
  }
  func stop() throws {
    try Self.service.unregister()
    running = false
  }
}
