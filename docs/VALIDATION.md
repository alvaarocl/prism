# Validation: 2026-11-14

Local environment: Apple Silicon, macOS 27.0, Xcode 27.2. Deployment target macOS
14; older macOS versions and Intel have not yet been tested.

- Seven Swift Testing tests pass: keyboard packet layout and brightness bounds,
  off frames, mouse field preservation, polling flags, invalid-profile rejection,
  allowlisted identities and lighting-mode validity.
- Release build succeeds. Installed bundle passes `codesign --verify --deep --strict`.
- Native SwiftUI window checked with actual connected devices. Selecting the
  keyboard removes unsupported effects; the Razer is information-only.
- Actual discovery: HyperX 0951:16E6, Glorious 258A:0033, Razer 1532:0565.
- HyperX brightness and colour output accepted by IOKit in the installed build.
  This is transport acceptance; visible colour confirmation by the owner remains pending.
- Mouse access returned `kIOReturnNotPermitted` (0xE00002E2). No configuration
  snapshot or write completed. Input Monitoring authorisation and a relaunch
  are needed before validating it on this Mac.

## Initial footprint measurements

Release build, window visible, three peripherals discovered. `ps` resident set
and change in cumulative CPU time over a 10-second interval:

| Scenario | RSS | CPU, percentage of one core |
|---|---:|---:|
| Before applying lighting, no keepalive | 110.0 MiB | 0.1% |
| HyperX solid-colour keepalive active | 115.1 MiB | 1.0% |

Installed bundle is approximately 968 KiB before adding bundled license notices.
These are short local observations, not peak-memory, energy or long-duration
benchmarks. RSS includes shared framework pages; CPU/memory vary with macOS,
hardware, window rendering and permissions. No claims of zero RAM or zero CPU.

## Remaining checks

Visible lighting and polling-rate confirmation; mouse readback after permission;
short report handling on real firmware; disconnect/reconnect during writes;
sleep/wake and original-effect restoration behaviour; macOS 14/15 and Intel;
accessibility and translated error messages; notarisation before binary releases.

## Native workspace update, 2026-11-14

Nine tests pass after adding macro sequence bounds, persistence, modifier labels
and unique key codes. Release build and installed signature pass. Native UI checked
for mouse and keyboard sections, ACL image loading, model artwork, macro creation,
adding/removing steps and persistence across relaunch. The temporary test macro was
removed. No macro was executed into a user's application; Accessibility authorisation,
actual event delivery and live cancellation/focus-loss checks remain manual validation.
The earlier footprint observations above are for the original interface, not a
benchmark of the redesign.

## Photo and glass correction, 2026-11-14

Procedural silhouettes removed. Real manufacturer reference images were inspected
for model identity, then background-extracted with the integrated image editor.
All three selected PNGs have alpha channels and fully transparent corner pixels.
HyperX, Glorious and Razer views were visually checked over the installed dark
window, without the previous white card. Known model variants remain catalogue
references; the Model O identity does not reuse the Model D photo.

The full-window surface, edge highlight, selection motion and transitions were
reworked after reviewing Claude Launcher. Release build/signature and native
controls verified; the existing nine tests passed. No peripheral protocol or macro
execution behaviour was expanded.

## Background controller and mouse correction, 2026-11-14

- Eleven tests pass, including the real 131-byte reply regression, profile command
  echo checks, ambiguous-length rejection, long-profile marker and readback mismatch.
- Connected Model D returned report 4, command 0x11, sensor 6, active profile 1 and
  **131 bytes**. A one-level RGB change was written, read back and verified. The
  original RGB/brightness was then restored and verified. Other settings preserved.
- Bundled PrismAgent registered/running under SMAppService as a user LaunchAgent.
  `otool -L` confirms no AppKit/SwiftUI dependency.
- Closing the real configuration window terminated Prism; the same agent PID
  remained active. A 10.01-second idle sample measured **8.78 MiB RSS, 0.0% of one
  core** with the GUI absent. This sample had no keyboard keepalive active; do not
  present it as an active-keyboard energy benchmark.
- Applied mouse lighting persisted across a controller restart. Keyboard restoration
  on login/wake/reconnect is implemented; physical sleep/reconnect and visible
  restoration still need the owner's confirmation after applying a keyboard colour.
- No saved keyboard preset was present from the older UI. Its former Apply action
  did not automatically persist colour; the old unsaved choice cannot be recovered.
  This version saves every successful Apply.
