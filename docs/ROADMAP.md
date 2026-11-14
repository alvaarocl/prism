# Roadmap

## 0.1 alpha: current

Native split-view workspace, ACL branding, original model silhouettes, local macro
composition and guarded playback, local presets, real HID discovery, allowlisted HyperX and
Glorious encoders, explicit writes, protocol guard tests. HyperX USB writes
accepted locally; mouse access awaits Input Monitoring and hardware confirmation.

## Next: hardware verification

- Verify visible colour, brightness/off, disconnect during updates and sleep/wake
  on the Alloy Origins Core, including ISO layouts.
- Grant native HID permission and verify Glorious profile readback; confirm the
  exact profile size and colour response before expanding settings.
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
