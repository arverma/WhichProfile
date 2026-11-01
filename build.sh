#!/bin/bash
# Builds ProfilePicker.app and installs it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/ProfilePicker.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 Sources/*.swift -o "$APP/Contents/MacOS/ProfilePicker"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/ProfilePicker.app"
cp -R "$APP" "$HOME/Applications/ProfilePicker.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$HOME/Applications/ProfilePicker.app"
echo "Installed: $HOME/Applications/ProfilePicker.app"
