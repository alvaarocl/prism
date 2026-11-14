# Architecture

Prism is a macOS-first peripheral manager. The UI uses SwiftUI and AppKit;
IOKit talks to HID devices directly. OpenRGB's process, SDK server, Qt interface
and scanners are not runtime dependencies.

## Driver boundary

`DriverKind` is an exact VID:PID allowlist with capability-specific modes.
`HyperXProtocol` and `GloriousProtocol` transform values into deterministic bytes
and are independently testable. The HID transport holds all IOHID objects on one
serial utility queue. SwiftUI receives Sendable device descriptions and completion
messages, never raw device references. Its controls use explicit Apply actions;
colour-picker drags do not flood USB or write mouse flash.

Unknown devices can be enumerated but cannot enter a write path. The manager
registers only device arrival/removal callbacks, never input-value/key callbacks.
The permission action is user initiated. Native macOS HID access can still require
Input Monitoring even without recording keystrokes.

Mouse updates read a complete snapshot and mutate only selected fields plus the
protocol's write marker. Unknown bytes and the trailing buffer remain unchanged.
Requests never contain bootloader commands. Configuration writes are serialized;
the firmware settling interval is scheduled asynchronously so it does not block keyboard maintenance or the UI thread.
A success message means macOS accepted the report, not visual verification or
readback of persistent state.

## Lifetime and performance

The user requested persistent settings with the configuration window closed. A
bundled SMAppService LaunchAgent now owns PrismHardware and the HID queue. It
links Foundation/IOKit only; no AppKit, SwiftUI, photos, macro engine or window.
The configuration app terminates after its last window closes.

A private mode-0700 Application Support directory contains bounded JSON commands,
status and applied settings; individual files are mode 0600. File event sources
react to atomic writes. Requests have UUIDs, are processed once and time out in
the UI. The agent validates the selected connected device and protocol before
writing. There is no network listener, idle polling loop or per-frame disk write.
Only successfully applied settings are persisted. Never restore a draft.

Discovery matches external transports and suppresses unchanged snapshots. The
HyperX timer stays at the known-working 60 ms interval; encoded packets are
prepared once when applying, then reused without rebuilding colour arrays every
tick. IOKit power notifications stop it for sleep and reapply saved settings on
wake. Disconnect/reconnect is event driven. The agent starts at login and can be
disabled via SMAppService/System Settings or the explicit stop command in Prism.

The mouse's actual transfer length determines its meaningful profile size. The
active profile is queried, then read/modify/write preserves that profile. A small
local binary backup precedes a write. A delayed readback must match requested
lighting/polling fields before success is reported. Mouse settings stay onboard
and do not need periodic rewrites.

The UI's normal quit command closes configuration only. Fully stopping Prism
unregisters the agent. No original-effect/brightness restoration is claimed when
the keyboard controller is completely stopped.

## Extending

Add a precise identity and capability descriptor, then a pure encoder with fixtures
from a documented protocol. Add a transport implementation without UI dependencies.
Verify discovery, denied permissions, disconnect during a write, sleep/wake and
changes on real hardware before marking a model verified. Keep DPI/buttons separate
from lighting capabilities. Firmware updates are out of scope until there is a
separate, reviewed recovery design.

An optional OpenRGB SDK adapter could expand coverage later. It would require a
separate running backend and its own compatibility tests; it is not present today.

## Native workspace and macros

The compact window uses a full-content transparent NSWindow, a native HUD blur,
an original ink gradient and a thin highlight ring. Native clear Liquid Glass is
used on macOS 26+, with an opaque fallback for Reduce Transparency. Selected device
and section backgrounds move with matched geometry; brief transitions respect
Reduce Motion. Claude Launcher (aaangelmartin/claude-launcher, revision e7cc348)
was reviewed as a visual reference for composition, borders, selection and timing.
Prism retains its own palette, ACL mark, system fonts and original implementation.
No Anthropic/Claude fonts, logos or theme tokens are bundled.

ProductPhoto loads only local PNGs matched by exact USB identity. The included
manufacturer-photo-derived cutouts have transparent backgrounds and no enclosing
photo card. Unknown/unavailable images use SF Symbols. Layout, finish and size
variants are catalogue references, not inferred exact physical appearance. Sources
and the background-removal prompt are in assets/product-cutouts/README.md.
Default builds copy these files; no image network requests occur at runtime.
The optional scripts/fetch-product-photos.py utility retrieves the original
manufacturer references only when explicitly invoked by a developer.

Macros are composed manually and stored in UserDefaults by VID:PID. No HID input
listeners, key loggers, recording taps or hardware remaps are installed. MacroPlayer
requires Accessibility, a selected running regular application and explicit Run.
It counts down for three seconds, activates that destination, verifies focus before
every step and posts a paired key-down/up directly to its PID. If the target loses
focus or terminates, playback stops. Cancellation is also requested on tab/device
changes, disappearance and sleep. Limits: 64 steps, each delay 50–5000 ms, total
delays at most one minute; no shell commands or unbounded loops. The editor shows
requested steps, not a guarantee the target app will accept every shortcut.

Macros here are a macOS facility organised alongside device controls. They do not
write the peripheral's onboard macro memory or bind a physical button. Those need
a separate validated vendor protocol, and are intentionally absent.
