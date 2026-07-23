#!/usr/bin/env bash
# Concatenate all finished beats into the final tutorial. Run from the ddev project root
# with TUT_SLUG set. Re-run any time after re-finishing individual beats.
#   ./concat.sh
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

shopt -s nullglob
beats=("$HDIR"/final/beat-*.mp4)
[ "${#beats[@]}" -gt 0 ] || die "no finished beats in $HDIR/final (run finish-beat.sh first)"

# Build the concat list (paths relative to the final/ directory), beats in order.
list="$HDIR/final/concat.txt"
: > "$list"
for f in $(printf '%s\n' "${beats[@]}" | sort); do
  printf "file '%s'\n" "$(basename "$f")" >> "$list"
done

cexec "cd '$CDIR/final' && ffmpeg -y -f concat -safe 0 -i concat.txt \
-codec:v libx264 -preset medium -pix_fmt yuv420p -codec:a aac -ar 44100 -movflags +faststart \
tutorial.mp4 >concat.log 2>&1"

echo "final video -> $HDIR/final/tutorial.mp4"
