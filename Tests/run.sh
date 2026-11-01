#!/bin/bash
# Compiles the non-UI sources together with the test runner and executes it.
set -euo pipefail
cd "$(dirname "$0")/.."

# Guard: WhichProfile is usually the default browser, so a link opened from inside the app the
# usual way (SwiftUI Link, NSWorkspace.open) would route straight back into the app. Everything
# must go through openExternalLink in Sources/ExternalLinks.swift.
if grep -nE 'NSWorkspace\.shared\.open\(|(^|[^A-Za-z])Link\(' Sources/*.swift | grep -v '^Sources/ExternalLinks.swift'; then
    echo "FAIL: open links from the app's own UI with openExternalLink (see Sources/ExternalLinks.swift)"
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

swiftc -swift-version 5 \
    Sources/Model.swift Sources/ChromeProfiles.swift Sources/Config.swift Sources/Launcher.swift Sources/Setup.swift Sources/ProfileList.swift Sources/LinkCleaner.swift Sources/ProjectInfo.swift Sources/ExternalLinks.swift Sources/LaunchPolicy.swift \
    Tests/main.swift -o "$TMP/tests"
WHICHPROFILE_LOG=/dev/null "$TMP/tests"
