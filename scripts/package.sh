#!/usr/bin/env bash
# Build the release zip: dist/ReactWheel-<version>.zip containing a top-level ReactWheel/ folder with only the addon files.
# Usage: scripts/package.sh [version]   (default: the Version line in ReactWheel.toc)
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:-$(sed -n 's/^## Version: *//p' ReactWheel.toc | tr -d '\r')}"
version="${version#v}"
out="dist/ReactWheel-${version}.zip"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

mkdir -p "$stage/ReactWheel"
cp ./*.lua ./*.xml LICENSE README.md CHANGELOG.md "$stage/ReactWheel/"
cp -r Textures "$stage/ReactWheel/Textures"
sed "s/^## Version:.*/## Version: ${version}/" ReactWheel.toc > "$stage/ReactWheel/ReactWheel.toc"

# every file the .toc lists must be in the package
while read -r line; do
	case "$line" in "##"*|"") continue ;; esac
	f="${line%$'\r'}"
	[ -f "$stage/ReactWheel/$f" ] || { echo "missing from package: $f" >&2; exit 1; }
done < "$stage/ReactWheel/ReactWheel.toc"

mkdir -p dist
rm -f "$out"
(cd "$stage" && python3 -c "
import sys, zipfile, os
out = sys.argv[1]
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk('ReactWheel'):
        for f in sorted(files):
            p = os.path.join(root, f)
            z.write(p, p)
" "$OLDPWD/$out")
echo "built $out"
python3 -c "import zipfile,sys; [print('  ', n) for n in sorted(zipfile.ZipFile(sys.argv[1]).namelist())]" "$out"
