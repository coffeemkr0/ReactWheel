#!/usr/bin/env bash
# Decide whether this run should publish a release. Prints key=value lines (version, tag, release).
#   release=true  when the tag v<version> does not exist yet AND
#                 - on a push: the "## Version:" line in the .toc changed in that push
#                 - on a manual run (workflow_dispatch): always (publishes the current version)
# Usage: scripts/release_check.sh <event-name> <commit-before-push>   (run from the repo root)
set -euo pipefail
event="${1:-push}"
before="${2:-}"

toc="$(ls ./*.toc | head -n1)"
version_of() { sed -n 's/^## Version: *//p' | tr -d '\r' | head -n1; }
version="$(version_of < "$toc")"
[ -n "$version" ] || { echo "no '## Version:' line in $toc" >&2; exit 1; }
tag="v$version"
release=true
reason="new version"

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
	release=false; reason="tag $tag already exists"
elif [ "$event" = "push" ]; then
	zero="0000000000000000000000000000000000000000"
	if [ -n "$before" ] && [ "$before" != "$zero" ] && git cat-file -e "${before}^{commit}" 2>/dev/null; then
		old="$(git show "${before}:${toc#./}" 2>/dev/null | version_of || true)"
		if [ "$old" = "$version" ]; then release=false; reason="version unchanged ($version)"; fi
	fi
fi

echo "version=$version"
echo "tag=$tag"
echo "release=$release"
echo "reason=$reason" >&2
