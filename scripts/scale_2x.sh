#!/usr/bin/env bash
#
# scale_2x.sh — derive assets/2x/<file>.png from assets/1x/<file>.png by doubling
# pixel dimensions with nearest-neighbor sampling (no interpolation), so pixel-art
# assets stay crisp instead of blurring at the higher resolution.
#
# Usage:
#   scripts/scale_2x.sh <name>...   Scale specific files (e.g. alt_t_alarm.png or alt_t_alarm)
#   scripts/scale_2x.sh --all       Scale every png in assets/1x
#
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_dir="$repo_root/assets/1x"
dst_dir="$repo_root/assets/2x"

if [[ $# -eq 0 ]]; then
	echo "usage: $0 <name>... | --all" >&2
	exit 1
fi

if [[ "$1" == "--all" ]]; then
	names=("$src_dir"/*.png)
else
	names=()
	for arg in "$@"; do
		name="${arg%.png}"
		names+=("$src_dir/$name.png")
	done
fi

for src in "${names[@]}"; do
	file="$(basename "$src")"
	if [[ ! -f "$src" ]]; then
		echo "skip: $file (not found in assets/1x)" >&2
		continue
	fi
	magick "$src" -filter point -resize 200% "$dst_dir/$file"
	echo "scaled: $file"
done
