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
if test -z "$(git status --porcelain --untracked-files=normal)"; then dirty=no; else dirty=yes; fi
printf 'working_tree_dirty=%s\n' "$dirty" >> "$app/Contents/Resources/source-sha.txt"
python3 - "$app/Contents/Resources/source-files.sha256" <<'PY'
from pathlib import Path
import hashlib, sys
paths = [Path('Package.swift')]
for root in ('Sources', 'Resources', 'Scripts'):
    paths += [p for p in Path(root).rglob('*') if p.is_file()]
Path(sys.argv[1]).write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p)+'\n' for p in sorted(paths)))
PY
codesign --force --sign "${SCROLLCAPTURE_SIGN_IDENTITY:--}" --identifier com.yocruzer.ScrollCapture "$app"
codesign --verify --strict "$app"
printf '%s\n' "$app"
