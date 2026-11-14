# Compatibility

| Hardware | USB identity | Implemented | Verification |
|---|---|---|---|
| HyperX Alloy Origins Core (Kingston) | 0951:16E6 | Solid RGB, off, brightness | Discovery and USB output accepted on development Mac; packets tested; visual colour confirmation pending |
| HyperX Alloy Origins Core (HP) | 03F0:098F | Same protocol | Upstream identity; no local hardware |
| Glorious Model D / D− wired | 258A:0033 | Profile 1 RGB and polling rate | 131-byte profile read, changed one RGB level, verified readback and restored original settings on real hardware |
| Glorious Model O / O− wired | 258A:0036 | Profile 1 RGB and polling rate | Upstream protocol; no local hardware |
| Razer BlackShark V2 HS 2.4 | 1532:0565 | Information only | Discovery verified; no configuration driver |
| Other USB/Bluetooth HID | varies | Information only | No commands sent without an allowlisted driver |

All control drivers are experimental. USB IDs determine the driver, not a name
match. The mouse attached to the development Mac identifies as Model D, even if
its owner initially remembered Model O. Do not force a different driver.

Mouse reads request a 520-byte transport buffer but the connected Model D returns
a valid **131-byte configuration**. The previous implementation incorrectly
required the transfer to fill all 520 bytes. The current implementation accepts
validated 131- or 167-byte replies, derives the write marker from that length,
reads the active profile (1–3), backs up the original meaningful bytes locally,
and checks requested fields with a readback after writing. Unknown lengths,
including an ambiguous transfer of 520, remain refused. Unknown meaningful
fields are preserved; only report padding is zero-filled.

The native agent restores successfully applied HyperX settings at login, wake and
reconnect. The firmware still needs periodic direct-colour frames; closing the
configuration window leaves the agent running, not the heavy UI. Completely
stopping the agent allows the keyboard's onboard effect to take over.

## Local macro workspace

All listed devices can organise local macros in the interface, including models
with no configuration driver. Macro playback uses macOS Accessibility and posts
to an explicitly selected application. This is independent of device USB support;
it does not add onboard macros, a recording feature or physical button assignment.
Native execution on this Mac remains unverified until the user grants Accessibility.
