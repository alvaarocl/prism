// SPDX-License-Identifier: GPL-2.0-or-later
// Protocol adaptation from OpenRGB; see THIRD_PARTY.md for authors and source revisions.
import Foundation

public struct RGB: Codable, Equatable, Sendable {
    public var r: UInt8; public var g: UInt8; public var b: UInt8
    public init(_ r: UInt8, _ g: UInt8, _ b: UInt8) { self.r = r; self.g = g; self.b = b }
    public static let cobalt = RGB(36, 57, 255)
}
public enum LightingMode: String, CaseIterable, Codable, Sendable {
    case solid = "Solid", rainbow = "Rainbow", breathing = "Breathing", off = "Off"
}
public struct Lighting: Codable, Equatable, Sendable {
    public var color: RGB
    public var brightness: Double
    public var mode: LightingMode
    public init(color: RGB = .cobalt, brightness: Double = 0.7, mode: LightingMode = .solid) {
        self.color = color; self.brightness = brightness; self.mode = mode
    }
}
public enum DriverKind: String, Codable, Sendable {
    case hyperX, glorious, unsupported
    public static func identify(vendor: Int, product: Int) -> Self {
        switch (vendor, product) {
        case (0x0951, 0x16e6), (0x03f0, 0x098f): .hyperX
        case (0x258a, 0x0033), (0x258a, 0x0036): .glorious
        default: .unsupported
        }
    }
    public var modes: [LightingMode] { self == .glorious ? LightingMode.allCases : [.solid, .off] }
}
public enum ProtocolError: Error, LocalizedError {
    case invalidProfile, invalidRate
    public var errorDescription: String? {
        switch self {
        case .invalidProfile: "The mouse returned an unrecognised configuration. Nothing was written."
        case .invalidRate: "Polling rate must be 125, 250, 500 or 1000 Hz."
        }
    }
}
public enum HyperXProtocol {
    // 94 LED addresses packed into a 380-byte GRB frame. Reports exclude the zero report ID.
    public static func reports(_ light: Lighting) -> [[UInt8]] {
        var frame = [UInt8](repeating: 0, count: 380)
        let color = light.mode == .off ? RGB(0, 0, 0) : light.color
        for index in 0..<94 {
            let p = (index / 12) * 48 + ((index / 6) & 1) * 8 + index % 6
            frame[p] = color.g; frame[p + 16] = color.r; frame[p + 32] = color.b
        }
        return stride(from: 0, to: 380, by: 60).enumerated().map { seq, start in
            let end = min(start + 60, 380)
            return [0xa2, UInt8(seq), 0, UInt8(end - start)] + Array(frame[start..<end])
        }
    }
    public static func brightnessReport(_ value: Double) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: 64)
        report[0] = 0xa7; report[3] = 1
        report[4] = UInt8((min(1, max(0, value.isFinite ? value : 0)) * 255).rounded())
        return report
    }
}
public enum GloriousProtocol {
    public static func validate(_ report: [UInt8]) throws {
        guard report.count == 520, report[0] == 4, report[1] == 0x11,
              [0x06, 0x08, 0x0e, 0x0f].contains(report[9]),
              (1...4).contains(report[0x0a] & 0x0f),
              report[0x35] <= 0x0a else { throw ProtocolError.invalidProfile }
    }
    // Preserve the entire original profile, including DPI stages, button settings and padding.
    public static func updating(_ original: [UInt8], lighting: Lighting? = nil, polling: Int? = nil) throws -> [UInt8] {
        try validate(original)
        var result = original
        result[3] = 0x7b
        if let polling {
            guard let index = [125, 250, 500, 1000].firstIndex(of: polling) else { throw ProtocolError.invalidRate }
            result[0x0a] = (result[0x0a] & 0xf0) | UInt8(index + 1)
        }
        if let light = lighting {
            let v = light.brightness.isFinite ? light.brightness : 0
            let brightness = UInt8((min(1, max(0, v)) * 4).rounded())
            switch light.mode {
            case .solid, .off:
                result[0x35] = 2; result[0x38] = light.mode == .off ? 0 : brightness << 4
                result[0x39] = light.color.r; result[0x3a] = light.color.b; result[0x3b] = light.color.g
            case .rainbow:
                result[0x35] = 1; result[0x36] = brightness << 4 | 2
            case .breathing:
                result[0x35] = 0x0a; result[0x7d] = brightness << 4 | 2
                result[0x7e] = light.color.r; result[0x7f] = light.color.b; result[0x80] = light.color.g
            }
        }
        return result
    }
}
