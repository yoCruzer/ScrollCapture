#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if test "$#" -ne 1; then
  echo 'Usage: bash Scripts/build-oracle-host.sh /absolute/path/browser-oracle.png' >&2
  exit 2
fi
oracle_path="$1"
test -f "$oracle_path"
app="$PWD/artifacts/native-oracle-host/NativeOracleHost.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
swiftc -O -parse-as-library Tools/NativeOracleHost.swift -o "$app/Contents/MacOS/NativeOracleHost"
cp "$oracle_path" "$app/Contents/Resources/oracle.png"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0"?><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.yocruzer.ScrollCapture.OracleHost</string>
<key>CFBundleName</key><string>NativeOracleHost</string>
<key>CFBundleExecutable</key><string>NativeOracleHost</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
codesign --force --sign - "$app"
printf '%s\n' "$app"
