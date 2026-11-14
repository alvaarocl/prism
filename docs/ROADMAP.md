# Roadmap

## 0.1 alpha: current

Compact translucent workspace, ACL branding, manufacturer-photo cutouts, local macro
composition and guarded playback, local presets, real HID discovery, allowlisted HyperX and
Glorious encoders, explicit writes, protocol guard tests. HyperX USB writes
accepted locally; Model D RGB mutation/readback/restore verified. A minimal native
LaunchAgent maintains applied keyboard settings independently of the window.

## Next: hardware verification

- Verify visible colour, brightness/off, disconnect during updates and sleep/wake
  on the Alloy Origins Core, including ISO layouts.
- Validate additional Glorious effects and polling rates on hardware beyond the
  verified solid-colour mutation/readback/restore path.
- Test HP keyboard and original Model O units separately.
- Read current mouse settings and active profile; add explicit backup/restore of
  validated configuration, then DPI stages and debounce.
- Better permission diagnostics, localisation catalog and accessibility review.

## Broader device support

Capability-based adapters for each supported protocol; add devices from actual
hardware reports. Optional OpenRGB SDK integration for wider coverage without
claiming every device is natively supported. Wireless devices and audio settings
need their own drivers. Add per-key keyboard editing with verified layout maps.

## Distribution

Notarised releases, reproducible build provenance, release checklist and signed
updates. No binary release until hardware validation is documented. No telemetry.
