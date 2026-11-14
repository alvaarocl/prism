// SPDX-License-Identifier: GPL-2.0-or-later
import Testing
@testable import PrismCore

@Test func keyboardWireFormatAndPadding() {
    let packets = HyperXProtocol.reports(Lighting(color: RGB(17,34,51)))
    #expect(packets.count == 7)
    #expect(packets.map(\.count) == [64,64,64,64,64,64,24])
    var frame: [UInt8] = []
    for (i, p) in packets.enumerated() {
        #expect(p[0] == 0xa2); #expect(p[1] == UInt8(i)); #expect(p[2] == 0)
        #expect(Int(p[3]) == p.count - 4); frame += p.dropFirst(4)
    }
    #expect(frame.count == 380)
    #expect(Array(frame[0..<8]) == [34,34,34,34,34,34,0,0])
    #expect(Array(frame[16..<24]) == [17,17,17,17,17,17,0,0])
    #expect(Array(frame[32..<40]) == [51,51,51,51,51,51,0,0])
    // Address 93, final populated LED. The remaining byte is padding.
    #expect(frame[347] == 34); #expect(frame[363] == 17); #expect(frame[379] == 51)
    #expect(frame[374] == 0)
}
@Test func keyboardOffAndBrightnessBounds() {
    let packets = HyperXProtocol.reports(Lighting(mode: .off))
    #expect(packets.flatMap { $0.dropFirst(4) }.allSatisfy { $0 == 0 })
    #expect(HyperXProtocol.brightnessReport(1)[4] == 255)
    #expect(HyperXProtocol.brightnessReport(-10)[4] == 0)
    #expect(HyperXProtocol.brightnessReport(.nan)[4] == 0)
    #expect(HyperXProtocol.brightnessReport(50)[4] == 255)
}
private func fixture() -> [UInt8] {
    var bytes = (0..<520).map { UInt8($0 % 251) }
    bytes[0] = 4; bytes[1] = 0x11; bytes[9] = 6; bytes[0x0a] = 0xa4; bytes[0x35] = 2
    return bytes
}
@Test func mousePreservesUnrelatedSettingsAndTail() throws {
    let original = fixture()
    let updated = try GloriousProtocol.updating(original, lighting: Lighting(color: RGB(18,52,86), brightness: 1))
    let allowed: Set<Int> = [3,0x35,0x38,0x39,0x3a,0x3b]
    for i in original.indices where !allowed.contains(i) { #expect(updated[i] == original[i]) }
    #expect(updated[3] == 0x7b)
    #expect(updated[0x39] == 18); #expect(updated[0x3a] == 86); #expect(updated[0x3b] == 52)
    #expect(updated[0x38] == 0x40)
}
@Test func pollingPreservesFlagsAndLighting() throws {
    let original = fixture()
    let updated = try GloriousProtocol.updating(original, polling: 500)
    #expect(updated[0x0a] == 0xa3)
    for i in original.indices where i != 3 && i != 0x0a { #expect(updated[i] == original[i]) }
    #expect(throws: ProtocolError.self) { try GloriousProtocol.updating(original, polling: 8000) }
}
@Test func malformedProfilesNeverProduceWrites() {
    #expect(throws: ProtocolError.self) { try GloriousProtocol.updating([], lighting: Lighting()) }
    #expect(throws: ProtocolError.self) { try GloriousProtocol.updating([UInt8](repeating: 0, count: 520), lighting: Lighting()) }
    for index in [0,1,9,0x0a,0x35] {
        var bytes = fixture(); bytes[index] = 255
        #expect(throws: ProtocolError.self) { try GloriousProtocol.updating(bytes, lighting: Lighting()) }
    }
}
@Test func modesAndAllowlist() {
    #expect(DriverKind.identify(vendor: 0x0951, product: 0x16e6) == .hyperX)
    #expect(DriverKind.identify(vendor: 0x258a, product: 0x0033) == .glorious)
    #expect(DriverKind.identify(vendor: 0x258a, product: 0x9999) == .unsupported)
    #expect(!DriverKind.hyperX.modes.contains(.rainbow))
}
@Test func allMouseModesKeepProfileValid() throws {
    for mode in LightingMode.allCases {
        let bytes = try GloriousProtocol.updating(fixture(), lighting: Lighting(brightness: .nan, mode: mode))
        try GloriousProtocol.validate(bytes)
        #expect(bytes.count == 520)
    }
}
