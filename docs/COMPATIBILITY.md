# Compatibility

| Hardware | USB identity | Implemented | Verification |
|---|---|---|---|
| HyperX Alloy Origins Core (Kingston) | 0951:16E6 | Solid RGB, off, brightness | Discovery and USB output accepted on development Mac; packets tested; visual colour confirmation pending |
| HyperX Alloy Origins Core (HP) | 03F0:098F | Same protocol | Upstream identity; no local hardware |
| Glorious Model D / D− wired | 258A:0033 | Profile 1 RGB and polling rate | Discovery verified; packet tests pass; native access refused with kIOReturnNotPermitted (Input Monitoring needed); no profile written |
| Glorious Model O / O− wired | 258A:0036 | Profile 1 RGB and polling rate | Upstream protocol; no local hardware |
| Razer BlackShark V2 HS 2.4 | 1532:0565 | Information only | Discovery verified; no configuration driver |
| Other USB/Bluetooth HID | varies | Information only | No commands sent without an allowlisted driver |

All control drivers are experimental. USB IDs determine the driver, not a name
match. The mouse attached to the development Mac identifies as Model D, even if
its owner initially remembered Model O. Do not force a different driver.

Mouse writes require a 520-byte report, the expected report/command IDs, a known
sensor tag, a valid polling-rate nibble and a known mode. A short read is refused.
This conservative restriction can reject firmware that OpenRGB accepts. Do not
remove it to "make the button work" without understanding the returned format.

Only mouse profile 1 is accessed. The active profile is not automatically switched;
if a different onboard profile is active, a change may not be immediately visible.
No macros, DPI stages, lift-off distance or firmware are modified.
