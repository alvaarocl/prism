# Prism

Native macOS peripheral manager by Álvaro Carpintero. GPL-2.0-or-later.

- Keep SwiftUI/AppKit and direct IOKit; no web runtime. Hardware maintenance belongs to the minimal Foundation/IOKit PrismAgent, managed with SMAppService.
- All IOHID objects belong to PrismHardware/HIDService's serial queue. Never link SwiftUI/AppKit into PrismAgent. Never read USB synchronously on the UI thread.
- No raw input capture, telemetry or network calls. The user authorised automatic restoration of successfully applied keyboard settings on startup, wake and reconnect; never restore an un-applied draft.
- Match exact VID:PID pairs; unknown devices are information-only.
- Never expose firmware/ISP commands. Preserve unknown profile fields.
- Keep upstream authorship and license notices when adapting drivers.
- Do not claim universal support or hardware validation based only on packet tests.
- Every driver change needs meaningful packet/guard tests and a compatibility update.
- Build products live outside this Obsidian checkout. Never commit device serials, signing material or personal captures.
- Personal branding: ink #0B0B0D, bone #F1F1EF, cobalt #2439FF. Do not use laaabs branding.
- Use issues, feature branches and PRs after the initial bootstrap; do not merge without an explicit request.

Checks: `swift test --scratch-path "$HOME/Library/Caches/prism-build"` and `./scripts/build.sh`.
