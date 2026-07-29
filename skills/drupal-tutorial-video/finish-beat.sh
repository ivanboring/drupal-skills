#!/usr/bin/env bash
# Finish one beat: pad the video to the narration length, add a short lead/tail of silence,
# mux the audio, and draw the bottom caption bar. Run from the ddev project root with
# TUT_SLUG set.
#   ./finish-beat.sh 03
# Defaults give a small breath between beats. For the LAST beat of a scene, pass a longer
# tail so there is a 1-2s gap before the next scene:
#   TUT_TAIL=1.5 ./finish-beat.sh 03
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
# awk emits a comma decimal under a comma-decimal locale (e.g. LC_NUMERIC=de_DE), which the ffmpeg
# filtergraph parser reads as a filter separator ("tpad=...:stop_duration=2,65469" fails with exit
# 8). Force a C locale so every number we hand ffmpeg uses a dot. Checking LANG is not enough:
# LC_NUMERIC can differ from LANG on the same machine.
export LC_ALL=C LC_NUMERIC=C

NN="$(printf '%02d' "$((10#${1:?beat number required}))")"
LEAD="${TUT_LEAD:-0.5}"    # seconds of silence before narration
TAIL="${TUT_TAIL:-0.5}"    # seconds of silence after narration (raise for scene-final beats)
LEAD_MS="$(awk -v l="$LEAD" 'BEGIN{printf "%d", l*1000}')"

[ -f "$HDIR/beats/${NN}.mp4" ] || die "beats/${NN}.mp4 not found (record the beat first)"

vdur="$(cduration "$CDIR/beats/${NN}.mp4")"
have_audio=0
adur=0
if [ -f "$HDIR/audio/${NN}.mp3" ]; then
  have_audio=1
  adur="$(cduration "$CDIR/audio/${NN}.mp3")"
fi

# target = max(video, lead + narration + tail)
target="$(awk -v v="$vdur" -v a="$adur" -v l="$LEAD" -v t="$TAIL" \
  'BEGIN{need=l+a+t; print (v>need? v: need)}')"
vdelta="$(awk -v v="$vdur" -v tg="$target" 'BEGIN{d=tg-v; print (d>0? d: 0)}')"

# Video filter: freeze-pad to target, then draw the caption bar if the caption is non-empty.
vf="tpad=stop_mode=clone:stop_duration=${vdelta}"
cap="$HDIR/final/${NN}.caption.txt"
if [ -s "$cap" ]; then
  # drawbox understands ih/iw; drawtext does NOT (it uses h/w), so the drawtext y-expr uses h.
  # black@0.94 (not 0.85): at 0.85 the page text showed through and fought the caption.
  # expansion=none: without it drawtext parses %{...} and backslashes even from a textfile, so a
  # caption containing a path, %, or a regex renders as an empty bar with no error.
  vf="${vf},drawbox=x=0:y=ih*0.91:w=iw:h=ih*0.09:color=black@0.94:t=fill,drawtext=fontfile=${FONT_REGULAR}:textfile='final/${NN}.caption.txt':fontcolor=white:fontsize=40:x=(w-text_w)/2:y=h*0.91+(h*0.09-text_h)/2:expansion=none"
fi

if [ "$have_audio" = 1 ]; then
  cexec "cd '$CDIR' && ffmpeg -y -i 'beats/${NN}.mp4' -i 'audio/${NN}.mp3' \
-filter_complex \"[0:v]${vf}[v];[1:a]adelay=${LEAD_MS}|${LEAD_MS},apad[a]\" \
-map '[v]' -map '[a]' -t ${target} \
-codec:v libx264 -preset medium -pix_fmt yuv420p -codec:a aac -ar 44100 -movflags +faststart \
'final/beat-${NN}.mp4' >'final/${NN}.finish.log' 2>&1"
else
  cexec "cd '$CDIR' && ffmpeg -y -i 'beats/${NN}.mp4' -f lavfi -i anullsrc=r=44100:cl=stereo \
-filter_complex \"[0:v]${vf}[v]\" \
-map '[v]' -map 1:a -t ${target} \
-codec:v libx264 -preset medium -pix_fmt yuv420p -codec:a aac -ar 44100 -movflags +faststart \
'final/beat-${NN}.mp4' >'final/${NN}.finish.log' 2>&1"
fi

echo "finished beat $NN -> final/beat-${NN}.mp4 (${target}s)"
