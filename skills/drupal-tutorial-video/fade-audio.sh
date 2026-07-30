#!/usr/bin/env bash
# Fade the tail of every narration file. Runs INSIDE the ddev web container; preflight copies it
# into the build dir. Invoke with:
#   ddev exec bash /var/www/html/.tutorial-build/<slug>/fade-audio.sh
#
# ElevenLabs (via awaz) ends each line mid-sound: the last 150ms measures at -16..-29 dB, not
# silence (~-90 dB), so the narration stops abruptly against the padded silence and sounds
# clipped. Fade the last 120ms and append real silence. Always derive from an untouched .orig so
# re-running can never double-fade. Verify afterwards with volumedetect over the final 150ms; it
# should read about -91 dB.
set -uo pipefail
export LC_ALL=C
cd "$(dirname "$(readlink -f "$0")")"

n_done=0
for f in audio/*.mp3; do
  n=$(basename "$f" .mp3)
  case "$n" in *.orig) continue;; esac
  orig="audio/$n.orig.mp3"
  [ -f "$orig" ] || cp "audio/$n.mp3" "$orig"
  d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$orig")
  st=$(awk -v d="$d" 'BEGIN{v=d-0.12; if(v<0)v=0; printf "%.3f", v}')
  ffmpeg -y -v error -i "$orig" \
    -af "afade=t=out:st=$st:d=0.12,apad=pad_dur=0.35" \
    -codec:a libmp3lame -q:a 2 "audio/$n.mp3" </dev/null
  n_done=$((n_done+1))
done
echo "faded + padded $n_done narration files"
