# prism

Your desk, your settings. Native peripheral control for macOS, by
[Álvaro Carpintero](https://github.com/alvaarocl).

**Early alpha.** A SwiftUI interface over small, allowlisted USB drivers. No
Electron, web view, accounts, telemetry, background server or package dependencies.
Built for macOS 14 and later. Currently built and checked on Apple Silicon;
Intel has not been validated.

## What works today

- Discover connected external USB and Bluetooth HID peripherals, with hotplug
  callbacks rather than repeated device scans.
- Native split-view interface with the personal ACL monogram, system materials,
  light/dark appearance and Liquid Glass controls on macOS 26 or later.
- Original lightweight vector silhouettes for the known keyboard, mouse and headset.
- Local macro editor: keys, modifiers, pauses and explicit playback into a selected
  running application. Macros are organised by device and require Accessibility.
  They are not recorded from input or assigned to hardware buttons.
- HyperX Alloy Origins Core: solid colour, brightness and lights off.
- Glorious Model O / O− and Model D / D− wired protocols: solid colour,
  breathing, rainbow, off and USB polling-rate configuration for profile 1.
- Local lighting presets, applied explicitly. No automatic writes on launch.
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
products live in `~/Library/Caches`, outside the checkout. A previous installed
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
3. Select a colour, effect and brightness, then press **Aplicar al dispositivo**.
4. **Guardar preset** stores the selection on this Mac; it does not write hardware.
5. The **Ajustes** tab exposes polling-rate configuration on supported mice and
   links to relevant macOS settings for other devices. The displayed rate is a
   requested value, not a readback of its current rate.
6. In **Macros**, create a sequence, select a running destination and press
   **Ejecutar**. Playback starts after three seconds and stops when the target
   loses focus, when you cancel, change the device/tab, or the Mac sleeps.
   Accessibility authorisation is needed; Prism does not grant it automatically.

The HyperX protocol needs a keepalive to hold a static colour. Prism starts it
only after Apply, at roughly 17 frames/second, and stops on disconnect, sleep,
USB errors or process exit. After sleep, reapply manually. The mouse stores
changes internally and needs no keepalive. Profile restoration for the keyboard
is not implemented; quitting may leave the last colour or restore its own effect,
depending on firmware.

## Scope

This is a foundation for broader peripheral configuration, not universal hardware
support. DPI editing, onboard macros, physical button mapping, keyboard layouts/per-key
painting, wireless vendor configuration, firmware updates, automatic startup and profile migration
are not implemented. Detection of a Bluetooth device does not imply RGB support.
No firmware or bootloader commands are exposed.

The full-buffer mouse guard deliberately rejects unexpected firmware responses
instead of guessing. If your device is visible but configuration is refused,
report its VID:PID, model and error text, without uploading serial numbers or raw
USB captures containing personal input.

## Architecture and footprint

- `PrismCore`: pure Swift packet encoders, capability table and protocol guards.
- `Prism`: SwiftUI, AppKit and IOHIDManager; HID objects stay on a serial utility queue.
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
