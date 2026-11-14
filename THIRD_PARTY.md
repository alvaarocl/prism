# Third-party notices

Prism is an independent project by Álvaro Carpintero. It is not affiliated with
HyperX, HP, Kingston, Glorious, Razer, Apple or OpenRGB.

## OpenRGB

Prism's Swift packet encoders and HID transaction sequence adapt the following
OpenRGB controllers, licensed under **GPL-2.0-or-later**. This is why Prism is
also distributed under GPL-2.0-or-later. The original copyright notices remain
applicable to the adapted work.

Source: https://github.com/CalcProgrammer1/OpenRGB
Revision reviewed: `b7e34ee98f5acf1881de017174a0f380b052730c`.

- `Controllers/HyperXKeyboardController/HyperXAlloyOriginsCoreController/`:
  Copyright Volodymyr Nazarchuk (Vavooon), 2021;
  Mike White (kamaaina), 2021; carlos jordao, 2025; OpenRGB contributors.
- `Controllers/SinowealthController/SinowealthController/`:
  Copyright Niels Westphal (crashniels), 2020; OpenRGB contributors.
- `Controllers/SinowealthController/SinowealthControllerDetect.cpp`:
  OpenRGB contributors. USB identifiers and controller matching.

Modifications in Prism (2026): Swift rewrite of the selected encoders; native
IOKit transport; complete-buffer validation and preservation for mouse writes;
serial operations; capability filtering; SwiftUI interface. Prism does not bundle
or launch the OpenRGB binary. See LICENSE for the full GPL version 2 text;
you may choose version 2 or any later version.

## Glorious Lights

Protocol reference consulted, not a runtime dependency:
https://github.com/ArshansGithub/glorious-lights/blob/982e5511cd551deff62e83d0f5254643c3ee7ce3/docs/mouse-protocol.md

Revision: `982e5511cd551deff62e83d0f5254643c3ee7ce3`.
Its notes informed the complete-buffer guard, RBG colour order, conservative
polling-rate mutation and report-size checks. Copyright (c) 2026 Glorious Lights
contributors, MIT. The MIT notice is included in `licenses/glorious-lights-MIT.txt`.
The protocol notes explicitly document Model O; Model D functionality in Prism
is experimental and additionally follows OpenRGB's Model D detector.

## Identity and system frameworks

The Prism icon, UI and device silhouettes are original to this project, using Álvaro Carpintero's
personal palette (ink, bone, cobalt). Typography and symbols use macOS system
resources. The ACL monogram comes from the owner's existing personal brand assets. Device
illustrations are original, approximate silhouettes rather than vendor photos or
exact product/layout reproductions. Vendor names identify hardware; no vendor
logos or fonts are bundled. No third-party Swift packages are required.
