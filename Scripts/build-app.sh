#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
swift build -c release --disable-sandbox
app="$PWD/build/ScrollCapture.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/ScrollCapture "$app/Contents/MacOS/ScrollCapture"
cp Resources/Info.plist "$app/Contents/Info.plist"
git rev-parse HEAD > "$app/Contents/Resources/source-sha.txt"
git diff --quiet && git diff --cached --quiet && dirty=no || dirty=yes
printf 'working_tree_dirty=%s\n' "$dirty" >> "$app/Contents/Resources/source-sha.txt"
codesign --force --sign "${SCROLLCAPTURE_SIGN_IDENTITY:--}" --identifier com.yocruzer.ScrollCapture "$app"
codesign --verify --strict "$app"
printf '%s\n' "$app"
