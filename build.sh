#!/bin/bash
# Builds WhichProfile.app and installs it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/WhichProfile.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 Sources/*.swift -o "$APP/Contents/MacOS/WhichProfile"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Version comes from the VERSION file; the build number is the number of commits.
VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/icons "$APP/Contents/Resources/icons"
codesign --force --sign - "$APP"

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# Remove the app's previous name (ProfilePicker) so only one copy is registered as a browser.
if [ -d "$HOME/Applications/ProfilePicker.app" ]; then
    "$LSREGISTER" -u "$HOME/Applications/ProfilePicker.app" || true
    rm -rf "$HOME/Applications/ProfilePicker.app"
fi

mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/WhichProfile.app"
cp -R "$APP" "$HOME/Applications/WhichProfile.app"
"$LSREGISTER" -f "$HOME/Applications/WhichProfile.app"
echo "Installed: $HOME/Applications/WhichProfile.app"
