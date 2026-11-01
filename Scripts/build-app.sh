#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
mkdir -p build
source_sha=$(git rev-parse HEAD)
python3 Scripts/source-manifest.py > build/source-before.sha256
swift build -c release --disable-sandbox
python3 Scripts/source-manifest.py > build/source-after.sha256
cmp build/source-before.sha256 build/source-after.sha256
test "$source_sha" = "$(git rev-parse HEAD)"
app="$PWD/build/ScrollCapture.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/ScrollCapture "$app/Contents/MacOS/ScrollCapture"
cp Resources/Info.plist "$app/Contents/Info.plist"
printf '%s\n' "$source_sha" > "$app/Contents/Resources/source-sha.txt"
if test -z "$(git status --porcelain --untracked-files=normal)"; then dirty=no; else dirty=yes; fi
printf 'working_tree_dirty=%s\n' "$dirty" >> "$app/Contents/Resources/source-sha.txt"
cp build/source-before.sha256 "$app/Contents/Resources/source-files.sha256"
codesign --force --sign "${SCROLLCAPTURE_SIGN_IDENTITY:--}" --identifier com.yocruzer.ScrollCapture "$app"
codesign --verify --strict "$app"
printf '%s\n' "$app"
