#!/bin/bash
# Compiles the non-UI sources together with the test runner and executes it.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

swiftc -swift-version 5 \
    Sources/Model.swift Sources/ChromeProfiles.swift Sources/Config.swift Sources/Launcher.swift Sources/Setup.swift Sources/ProfileList.swift \
    Tests/main.swift -o "$TMP/tests"
WHICHPROFILE_LOG=/dev/null "$TMP/tests"
