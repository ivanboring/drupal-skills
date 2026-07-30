#!/usr/bin/env bash
# Trim an over-long beat capture to the part that carries the action. Which end you keep depends
# on where the meaning is:
#   ./trim.sh <NN> head <seconds>   keep the first N seconds (the action is the content: ticking
#                                   boxes, typing, opening a picker)
#   ./trim.sh <NN> tail <seconds>   keep the last  N seconds (the payoff is the result: an install
#                                   confirmation, a saved message, a JSON response)
# Keeps the untouched capture as beats/NN.orig.mp4 so any cut can be redone without re-recording.
# Run from the ddev project root with TUT_SLUG set.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
export LC_ALL=C LC_NUMERIC=C

NN="$(printf '%02d' "$((10#${1:?beat number required}))")"
MODE="${2:?head|tail required}"
SECS="${3:?seconds required}"

cexec "cd '$CDIR' && test -f beats/${NN}.orig.mp4 || cp beats/${NN}.mp4 beats/${NN}.orig.mp4"
DUR="$(cduration "$CDIR/beats/${NN}.orig.mp4")"

if [ "$MODE" = "tail" ]; then
  SS="$(awk -v d="$DUR" -v s="$SECS" 'BEGIN{v=d-s; if(v<0)v=0; printf "%.2f", v}')"
else
  SS=0
fi

cexec "cd '$CDIR' && ffmpeg -y -loglevel error -ss $SS -t $SECS -i beats/${NN}.orig.mp4 \
-codec:v libx264 -preset ultrafast -pix_fmt yuv420p beats/${NN}.mp4"
NEW="$(cduration "$CDIR/beats/${NN}.mp4")"
printf 'beat %s: %.1fs -> %.1fs (%s %s)\n' "$NN" "$DUR" "$NEW" "$MODE" "$SECS"
