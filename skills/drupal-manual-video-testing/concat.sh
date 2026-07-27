#!/usr/bin/env bash
# Concatenate all finished parts into one recording. Run from the ddev project root with
# MT_MODULE and MT_MR set. Re-run any time after re-finishing individual parts.
#   ./concat.sh
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

shopt -s nullglob
parts=("$HDIR"/final/part-*.mp4)
[ "${#parts[@]}" -gt 0 ] || die "no finished parts in $HDIR/final (run finish-part.sh first)"

# Build the concat list (paths relative to the final/ directory), parts in order.
list="$HDIR/final/concat.txt"
: > "$list"
for f in $(printf '%s\n' "${parts[@]}" | sort); do
  printf "file '%s'\n" "$(basename "$f")" >> "$list"
done

# Video-only (no audio in this skill).
cexec "cd '$CDIR/final' && ffmpeg -y -f concat -safe 0 -i concat.txt -an \
-codec:v libx264 -preset medium -pix_fmt yuv420p -movflags +faststart \
recording.mp4 >concat.log 2>&1"

echo "final recording -> $HDIR/final/recording.mp4"
