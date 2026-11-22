#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
mkdir -p build
source_sha=$(git rev-parse HEAD)
python3 Scripts/source-manifest.py > build/source-before.sha256
build_args=(-c release --disable-sandbox)
out="$PWD/build"
case "${1:-native}" in
    native) ;;
    intel) build_args+=(--arch x86_64 --scratch-path "$PWD/.build/intel-review"); out="$out/intel" ;;
    *) echo "usage: $0 [native|intel]" >&2; exit 2 ;;
esac
swift build "${build_args[@]}"
bin_dir=$(swift build "${build_args[@]}" --show-bin-path)
python3 Scripts/source-manifest.py > build/source-after.sha256
cmp build/source-before.sha256 build/source-after.sha256
test "$source_sha" = "$(git rev-parse HEAD)"
app="$out/ScrollCapture.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/ScrollCapture" "$app/Contents/MacOS/ScrollCapture"
cp Resources/Info.plist "$app/Contents/Info.plist"
printf '%s\n' "$source_sha" > "$app/Contents/Resources/source-sha.txt"
if test -z "$(git status --porcelain --untracked-files=normal)"; then dirty=no; else dirty=yes; fi
printf 'working_tree_dirty=%s\n' "$dirty" >> "$app/Contents/Resources/source-sha.txt"
cp build/source-before.sha256 "$app/Contents/Resources/source-files.sha256"
codesign --force --sign "${SCROLLCAPTURE_SIGN_IDENTITY:--}" --identifier com.yocruzer.ScrollCapture "$app"
codesign --verify --strict "$app"
printf '%s\n' "$app"
