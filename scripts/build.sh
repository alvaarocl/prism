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
codesign --force --deep --options runtime --timestamp=none --sign "$IDENTITY" "$BUNDLE"
codesign --verify --deep --strict "$BUNDLE"
echo "Built: $BUNDLE"
if [ "${1:-}" = "--install" ]; then
  DEST="$HOME/Applications/Prism.app"
  mkdir -p "$HOME/Applications"
  if [ -d "$DEST" ]; then
    osascript -e 'tell application "Prism" to quit' || true
    mv "$DEST" "$HOME/.Trash/Prism-$(date +%Y%m%d-%H%M%S).app"
  fi
  ditto "$BUNDLE" "$DEST"
  open "$DEST"
  echo "Installed: $DEST"
fi
