#!/bin/sh
# Builds foldsim's probe app for the simulator: tests/foldsim-probe/build.sh <output-dir>
# Prints the path of FoldsimProbe.app. Uses the Xcode that DEVELOPER_DIR or xcode-select picks.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out=${1:?usage: build.sh <output-dir>}
app="$out/FoldsimProbe.app"
mkdir -p "$app"
xcrun --sdk iphonesimulator swiftc -parse-as-library -swift-version 5 -O \
    -target "$(uname -m)-apple-ios27.1-simulator" "$here/Probe.swift" -o "$app/FoldsimProbe"
cp "$here/Info.plist" "$app/Info.plist"
codesign -f -s - "$app" >/dev/null 2>&1
echo "$app"
