#!/bin/bash
# Builds the app, then packages it as build/Keladi-Hub-<version>-macOS.dmg (drag to Applications).
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
APP="build/Keladi Hub.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="build/Keladi-Hub-$VERSION-macOS.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Keladi Hub" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "Built $DMG"
shasum -a 256 "$DMG"
