// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

public struct Peripheral: Identifiable, Hashable, Codable, Sendable {
  public let id: String
  public let name: String
  public let vendor: Int
  public let product: Int
  public let location: Int
  public let transport: String
  public init(id: String, name: String, vendor: Int, product: Int, location: Int, transport: String)
  {
    self.id = id
    self.name = name
    self.vendor = vendor
    self.product = product
    self.location = location
    self.transport = transport
  }
  public var driver: DriverKind { .identify(vendor: vendor, product: product) }
  public var identifier: String { String(format: "%04X:%04X", vendor, product) }
  public var symbol: String {
    driver == .hyperX
      ? "keyboard"
      : driver == .glorious ? "computermouse" : vendor == 0x1532 ? "headphones" : "cable.connector"
  }
}
public struct AgentRequest: Codable, Sendable {
  public var id: UUID
  public var deviceID: String
  public var lighting: Lighting?
  public var polling: Int?
  public init(deviceID: String, lighting: Lighting?, polling: Int?) {
    id = UUID()
    self.deviceID = deviceID
    self.lighting = lighting
    self.polling = polling
  }
}
public struct AgentStatus: Codable, Sendable {
  public var pid: Int32
  public var devices: [Peripheral]
  public var completedRequest: UUID?
  public var error: String?
  public var applied: [String: Lighting]
  public var polling: [String: Int]?
  public init(
    pid: Int32, devices: [Peripheral] = [], completedRequest: UUID? = nil, error: String? = nil,
    applied: [String: Lighting] = [:]
  ) {
    self.pid = pid
    self.devices = devices
    self.completedRequest = completedRequest
    self.error = error
    self.applied = applied
    self.polling = [:]
  }
}
public enum AgentFiles {
  public static var directory: URL {
    if let override = ProcessInfo.processInfo.environment["PRISM_SUPPORT_DIR"] {
      return URL(fileURLWithPath: override, isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      "Library/Application Support/com.alvaarocl.prism", isDirectory: true)
  }
  public static func prepare() throws {
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
  }
  public static func write<T: Encodable>(_ value: T, to name: String) throws {
    try prepare()
    let url = directory.appendingPathComponent(name)
    let data = try JSONEncoder().encode(value)
    try data.write(to: url, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
  }
  public static func read<T: Decodable>(_ type: T.Type, from name: String) -> T? {
    let url = directory.appendingPathComponent(name)
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attributes[.size] as? NSNumber, size.intValue <= 65536,
      let data = try? Data(contentsOf: url)
    else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }
}
