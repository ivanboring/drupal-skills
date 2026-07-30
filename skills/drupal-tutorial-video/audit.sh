#!/usr/bin/env bash
# Audit the WHOLE beat set at once, not beat by beat: one pass comparing video / speech / final
# duration surfaces pacing problems together (a single run flagged 27). Runs INSIDE the ddev web
# container; preflight copies it into the build dir. Invoke with:
#   ddev exec bash /var/www/html/.tutorial-build/<slug>/audit.sh
# Flags:
#   AUDIO-TIGHT  less than 0.35s of silence left after the narration ends (breath too short)
#   DEAD-AIR     more than 3.5s of video beyond the speech (candidate for deadair.sh / trim.sh)
set -uo pipefail
export LC_ALL=C
cd "$(dirname "$(readlink -f "$0")")"

printf '%-6s %8s %8s %8s %9s %s\n' beat video speech final headroom note
for f in beats/*.mp4; do
  n=$(basename "$f" .mp4)
  case "$n" in *.orig|*.pretrim) continue;; esac
  v=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
  a=0; [ -f "audio/$n.mp3" ] && a=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "audio/$n.mp3")
  fi=0; [ -f "final/beat-$n.mp4" ] && fi=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "final/beat-$n.mp4")
  awk -v n="$n" -v v="$v" -v a="$a" -v f="$fi" 'BEGIN{
    head = f - (0.5 + a);          # silence left after narration ends
    dead = v - a;                  # video beyond speech
    note = "";
    if (head < 0.35) note = note "AUDIO-TIGHT ";
    if (dead > 3.5)  note = note "DEAD-AIR ";
    if (note != "") printf "%-6s %8.2f %8.2f %8.2f %9.2f %s\n", n, v, a, f, head, note;
  }'
done
