#!/usr/bin/env bash
# Print the CHANGELOG.md section for a version ("## 1.2.3" up to the next "## ").
# Usage: scripts/release_notes.sh <version>      (prints nothing when there is no such section)
set -euo pipefail
version="${1#v}"
[ -f CHANGELOG.md ] || exit 0
awk -v v="$version" '
	$0 ~ "^## " && !found { if (index($0, "## " v) == 1 && (length($0) == length("## " v) || substr($0, length("## " v) + 1, 1) ~ /[ (]/)) { found = 1; next } }
	found && /^## / { exit }
	found { print }
' CHANGELOG.md
