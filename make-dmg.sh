#!/bin/bash
# Builds the app, then packages it as build/Kelawdi-Squad-<version>-macOS.dmg (drag to Applications).
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
APP="build/Kelawdi Squad.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="build/Kelawdi-Squad-$VERSION-macOS.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Kelawdi Squad" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "Built $DMG"
shasum -a 256 "$DMG"
