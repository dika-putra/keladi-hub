#!/bin/bash
# Builds build/Claude Profiles.app (menu bar only, no Dock icon).
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="build/Claude Profiles.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ClaudeProfiles "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Claude Profiles</string>
<key>CFBundleIdentifier</key><string>com.dikaputra.claudeprofiles</string>
<key>CFBundleExecutable</key><string>ClaudeProfiles</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
# SIGN_ID=<codesigning identity> keeps the same signature across builds, so the Accessibility permission survives rebuilds.
codesign --force --sign "${SIGN_ID:--}" "$APP"
echo "Built $APP"
