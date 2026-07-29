#!/usr/bin/env bash
# Sanity-check one beat beyond "the file exists". Run from the ddev project root with TUT_SLUG set.
#   ./check-beat.sh 03
# Five separate failures in one run left beat files that existed at non-zero size but were wrong,
# so a size check alone is not enough. This reports the raw and finished durations, extracts a
# still frame you can eyeball, and flags the failure shapes seen live: unfinalized stubs and
# typing beats that ran minutes long. Two checks it cannot do for you:
#   - identical file size to the previous beat usually means nothing changed on screen;
#   - after a form-submit beat, read back the config the form was supposed to write
#     (drush config:get ...) - that is the strongest check that the on-camera typing landed.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
export LC_ALL=C LC_NUMERIC=C

NN="$(printf '%02d' "$((10#${1:?beat number required}))")"

raw="$HDIR/beats/${NN}.mp4"
fin="$HDIR/final/beat-${NN}.mp4"
[ -f "$raw" ] || die "beats/${NN}.mp4 not found (record the beat first)"

rdur="$(cduration "$CDIR/beats/${NN}.mp4" 2>/dev/null || echo 0)"
printf 'beat %s raw:      %ss   (%s bytes)\n' "$NN" "$rdur" "$(wc -c < "$raw")"
if [ -f "$fin" ]; then
  fdur="$(cduration "$CDIR/final/beat-${NN}.mp4" 2>/dev/null || echo 0)"
  printf 'beat %s finished: %ss   (%s bytes)\n' "$NN" "$fdur" "$(wc -c < "$fin")"
fi

# Extract a still from the middle of the raw capture so you can confirm the screen shows what the
# beat claims (caught a cropped command card and an empty caption bar in one run).
mid="$(awk -v d="$rdur" 'BEGIN{ m=d/2; print (m>0? m: 0) }')"
cexec "cd '$CDIR' && ffmpeg -y -ss ${mid} -i 'beats/${NN}.mp4' -frames:v 1 'final/${NN}.frame.png' >/dev/null 2>&1" || true
echo "frame -> $HDIR/final/${NN}.frame.png (open it to confirm the screen shows what the beat claims)"

# Flags for the two failure shapes.
if awk -v d="$rdur" 'BEGIN{exit !(d+0 < 0.4)}'; then
  echo "  WARN raw capture <0.4s: the capture may not have finalized (see record-beat.sh stop)."
fi
if awk -v d="$rdur" 'BEGIN{exit !(d+0 > 90)}'; then
  echo "  WARN raw capture >90s: likely per-key typing of a long string. Use the paste path and narrate it as 'paste in...'."
fi
