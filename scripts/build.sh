#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SCRATCH="${PRISM_BUILD_PATH:-$HOME/Library/Caches/prism-build}"
DIST="${PRISM_DIST_PATH:-$HOME/Library/Caches/prism-dist}"
BUNDLE="$DIST/Prism.app"
swift build --scratch-path "$SCRATCH" -c release
BIN="$(swift build --scratch-path "$SCRATCH" -c release --show-bin-path)"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN/Prism" "$BUNDLE/Contents/MacOS/Prism"
cp "$BIN/PrismAgent" "$BUNDLE/Contents/MacOS/PrismAgent"
mkdir -p "$BUNDLE/Contents/Library/LaunchAgents"
cat > "$BUNDLE/Contents/Library/LaunchAgents/com.alvaarocl.prism.agent.plist" <<'AGENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.alvaarocl.prism.agent</string>
<key>BundleProgram</key><string>Contents/MacOS/PrismAgent</string>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
<key>ProcessType</key><string>Background</string>
<key>ThrottleInterval</key><integer>10</integer>
</dict></plist>
AGENT
for resource in "$BIN"/*.bundle; do
  [ -d "$resource" ] && ditto "$resource" "$BUNDLE/Contents/Resources/$(basename "$resource")"
done
cat > "$BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.alvaarocl.prism</string>
<key>CFBundleExecutable</key><string>Prism</string>
<key>CFBundleName</key><string>Prism</string>
<key>CFBundleDisplayName</key><string>Prism</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>Prism</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>© 2026 Álvaro Carpintero and OpenRGB contributors. GPL-2.0-or-later.</string>
</dict></plist>
PLIST
rm -rf "$BUNDLE/Contents/Resources/ProductPhotos"
if [ "${PRISM_PRODUCT_PHOTOS:-1}" != "0" ]; then
  ditto assets/product-cutouts "$BUNDLE/Contents/Resources/ProductPhotos"
fi
swift scripts/icon.swift "$DIST"
cp "$DIST/Prism.icns" "$BUNDLE/Contents/Resources/Prism.icns"
cp LICENSE THIRD_PARTY.md "$BUNDLE/Contents/Resources/"
ditto licenses "$BUNDLE/Contents/Resources/licenses"
IDENTITY="${PRISM_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -v -p codesigning | awk '/Apple Development:/{print $2; exit}')"
fi
IDENTITY="${IDENTITY:--}"
xattr -cr "$BUNDLE"
codesign --force --options runtime --timestamp=none --identifier com.alvaarocl.prism.agent --sign "$IDENTITY" "$BUNDLE/Contents/MacOS/PrismAgent"
codesign --force --deep --options runtime --timestamp=none --sign "$IDENTITY" "$BUNDLE"
codesign --verify --deep --strict "$BUNDLE"
echo "Built: $BUNDLE"
if [ "${1:-}" = "--install" ]; then
  DEST="$HOME/Applications/Prism.app"
  mkdir -p "$HOME/Applications"
  if [ -d "$DEST" ]; then
    osascript -e 'tell application "Prism" to quit' || true
    for attempt in {1..40}; do
      pgrep -x Prism >/dev/null || break
      sleep 0.1
    done
    if pgrep -x Prism >/dev/null; then
      echo "Prism is still running; quit it before installing." >&2
      exit 1
    fi
    mv "$DEST" "$HOME/.Trash/Prism-$(date +%Y%m%d-%H%M%S).app"
  fi
  ditto "$BUNDLE" "$DEST"
  if launchctl print "gui/$(id -u)/com.alvaarocl.prism.agent" >/dev/null 2>&1; then
    launchctl kickstart -k "gui/$(id -u)/com.alvaarocl.prism.agent"
  fi
  open "$DEST"
  echo "Installed: $DEST"
fi
