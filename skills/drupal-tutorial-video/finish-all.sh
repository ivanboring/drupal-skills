#!/usr/bin/env bash
# Finish every recorded beat in order (length-fit to narration, mux audio, draw the caption bar).
# Scene-final beats get a longer tail so there is a pause before the next scene. Run from the
# ddev project root with TUT_SLUG set.
#
# The scene-final list is DERIVED, never hardcoded: reordering the storyboard once left the pause
# on the wrong beat because a literal list did not move with it. Source, in priority order:
#   1. $HDIR/beats.json      {"NN": {"scene_final": true}, ...}   (needs jq)
#   2. $HDIR/scene-final.txt  whitespace-separated zero-padded beat numbers (01 07 12 ...)
#   3. none                   every beat gets the default tail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
FIN="$HERE/finish-beat.sh"

SCENE_FINAL=" "
if [ -f "$HDIR/beats.json" ] && command -v jq >/dev/null 2>&1; then
  SCENE_FINAL=" $(jq -r 'to_entries[] | select(.value.scene_final==true) | .key' "$HDIR/beats.json" | tr '\n' ' ') "
elif [ -f "$HDIR/scene-final.txt" ]; then
  SCENE_FINAL=" $(tr '\n' ' ' < "$HDIR/scene-final.txt") "
fi
echo "scene-final beats:$SCENE_FINAL"

ok=0; fail=0
shopt -s nullglob
for f in "$HDIR"/beats/*.mp4; do
  i="$(basename "$f" .mp4)"
  # Skip the trim backups; removed beats (gaps) just have no file and are skipped naturally.
  case "$i" in *.orig|*.pretrim) continue;; esac
  if [[ "$SCENE_FINAL" == *" $i "* ]]; then
    TUT_TAIL=1.5 "$FIN" "$i" >/dev/null 2>&1
  else
    "$FIN" "$i" >/dev/null 2>&1
  fi
  if [ -f "$HDIR/final/beat-$i.mp4" ]; then
    ok=$((ok+1))
  else
    echo "FAILED: beat $i"
    fail=$((fail+1))
  fi
done
echo "finished: $ok ok, $fail failed"
