#!/usr/bin/env python3
"""Hash only build inputs, with repository-relative paths; no private diagnostics."""
from pathlib import Path
import hashlib

paths = [Path("Package.swift")]
for root in ("Sources", "Resources", "Scripts"):
    paths += [p for p in Path(root).rglob("*") if p.is_file() and "__pycache__" not in p.parts]
for path in sorted(paths):
    print(hashlib.sha256(path.read_bytes()).hexdigest() + "  " + str(path))
