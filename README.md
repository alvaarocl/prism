# prism

Your desk, your settings. Native peripheral control for macOS, by
[Álvaro Carpintero](https://github.com/alvaarocl).

**Early alpha.** A SwiftUI interface over small, allowlisted USB drivers. No
Electron, web view, accounts, telemetry, web server or package dependencies.
Built for macOS 14 and later. Currently built and checked on Apple Silicon;
Intel has not been validated.

## What works today

- Discover connected external USB and Bluetooth HID peripherals, with hotplug
  callbacks rather than repeated device scans.
- Compact translucent window with the personal ACL monogram, ink/bone palette,
  subtle gradients and borders, sliding selection and brief transitions. Native
  Liquid Glass on macOS 26+, with blur/material fallback and accessibility settings.
- Transparent photo cutouts derived from manufacturer product images for the known
  keyboard, mouse and headset. Missing or unknown images fall back to system icons.
  See [photo provenance](assets/product-cutouts/README.md).
- Local macro editor: keys, modifiers, pauses and explicit playback into a selected
  running application. Macros are organised by device and require Accessibility.
  They are not recorded from input or assigned to hardware buttons.
- HyperX Alloy Origins Core: solid colour, brightness and lights off.
- Glorious Model O / O− and Model D / D− wired protocols: solid colour,
  breathing, rainbow, off and USB polling-rate configuration for the active onboard profile.
  Writes are read back and checked.
- Apply saves successful lighting and polling settings automatically. The small
  native agent restores applied keyboard lighting at login, wake and reconnect.
- Close the configuration window to release the entire SwiftUI process. PrismAgent
  keeps hardware state without loading AppKit, photos or the macro editor.
- Unsupported devices are visible as information only, with no configuration
  commands sent to them.

**Protocol implementation is not the same as hardware verification.** See
[compatibility](docs/COMPATIBILITY.md). Current checks verify discovery on real
hardware and encoder behaviour, not successful lighting changes on every model.
Model D shares the upstream controller but remains experimental.

## Build and install

Requires Xcode with Swift 6.2 or later. No Homebrew packages are required.

```sh
git clone https://github.com/alvaarocl/prism.git
cd prism
./scripts/build.sh --install
```

This builds a release configuration, signs with an existing Apple Development
identity (ad hoc if none exists) and opens `~/Applications/Prism.app`. Build
products live in `~/Library/Caches`, outside the checkout. The included PNG cutouts
are copied locally; the app and default build do not fetch product photos. Set
`PRISM_PRODUCT_PHOTOS=0` to build with system icons instead. A previous installed
copy moves to the Trash before replacement. This is a local development install,
not a notarised public binary.

```sh
swift test --scratch-path "$HOME/Library/Caches/prism-build"
"$HOME/Applications/Prism.app/Contents/MacOS/Prism" --diagnose
```

The diagnostic command lists names, USB IDs and driver classification. It does
not write lighting or configuration. The sidebar gear opens the permission sheet.

## Use

1. Connect a peripheral and select it in the sidebar.
2. If macOS refuses access, use the sidebar gear and **Abrir Monitorización de entrada…** to open Input Monitoring,
   allow Prism, then quit and reopen it. Close other RGB controllers.
3. Select a colour, effect and brightness, then press **Aplicar**. A successful
   change is saved automatically; an un-applied draft is never restored.
4. Close the window. Only the small controller stays running. Reopen Prism from
   Applications when you want to edit settings. The mouse keeps its own settings.
5. The **Ajustes** tab changes polling rate on the active supported mouse profile;
   its last successful selection is saved too. Other devices link to macOS settings.
6. In **Macros**, create a sequence, select a destination and press **Ejecutar**.
   Playback requires Accessibility. Macros execute only while the configuration
   interface is open; the agent never records or generates keyboard input.

Prism registers a bundled user LaunchAgent with Apple's SMAppService. If macOS
requires approval, allow Prism in **System Settings → General → Login Items →
Allow in Background**. The sidebar gear shows this setting. No administrator
password or privileged daemon is needed.

The HyperX firmware needs a keepalive for direct colour. Its 60 ms timer lives in
PrismAgent, uses cached packets and stops during sleep/disconnection. The latest
successfully applied colour and brightness are restored on wake/reconnect/login.
Closing the window or choosing **Cerrar configuración** stops only the UI.
**Prism → Detener Prism por completo** unregisters the agent; the keyboard can
then return to its onboard effect while keeping the last hardware brightness.
Prism does not claim to store a direct RGB frame in the keyboard's flash.

The earlier version did not save values just by pressing Apply. If no prior preset
exists, choose the desired keyboard colour and apply it once in this version;
Prism cannot recover an unsaved colour from a terminated older process.

## Scope

This is a foundation for broader peripheral configuration, not universal hardware
support. DPI editing, onboard macros, physical button mapping, keyboard layouts/per-key
painting, wireless vendor configuration, firmware updates and general profile migration
are not implemented. Detection of a Bluetooth device does not imply RGB support.
No firmware or bootloader commands are exposed.

The mouse guard accepts validated 131/167-byte configuration replies, preserving
the complete meaningful profile and zeroing transport padding. It rejects unknown
lengths, ambiguous 520-byte transfers and unexpected firmware responses
instead of guessing. If your device is visible but configuration is refused,
report its VID:PID, model and error text, without uploading serial numbers or raw
USB captures containing personal input.

## Architecture and footprint

- `PrismCore`: pure Swift packet encoders, capability table and protocol guards.
- `Prism`: the temporary SwiftUI/AppKit configuration interface and agent client.
- `PrismAgent`: Foundation/IOKit user service, managed by SMAppService. No UI frameworks.
- `PrismHardware`: HID objects and precomputed keyboard frames on a serial utility queue.
- `AgentMessages`: bounded local JSON requests/status with private directory/file permissions.
  Filesystem notifications replace polling; no TCP server or disk writes per keepalive.
- `Tests`: golden packet checks, bounds and malformed reads, settings preservation,
  macro bounds, key-code uniqueness and persistence.
- `MacroPlayer`: explicit, cancellable keyboard-event delivery to one selected process.
  No input recording or global event taps. Physical key codes follow the active keyboard layout.

There are no network requests, input event listeners, idle polling loops or
software RGB animation engines. The keyboard keepalive is the explicit exception
after lighting is enabled. Zero RAM is not possible for a running process;
measurements and limitations belong in [validation](docs/VALIDATION.md).

## Contributing

Read [architecture](docs/ARCHITECTURE.md) and [compatibility](docs/COMPATIBILITY.md)
before adding a driver. Each device needs an exact identity, transport contract,
capabilities and packet tests. Keep unsupported functions disabled. Please use
issues and pull requests; include your hardware and macOS version for device fixes.

## License and credits

**GPL-2.0-or-later.** The native interface and macOS integration are original;
the selected device protocols are adapted from OpenRGB, with additional protocol
research from Glorious Lights. This project is not a claim of authorship over
those upstream drivers. See [third-party notices](THIRD_PARTY.md) and [LICENSE](LICENSE).

Independent project. Not affiliated with peripheral manufacturers or Apple.
