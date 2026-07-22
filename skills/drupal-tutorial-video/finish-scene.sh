#!/usr/bin/env bash
# Finish one scene: pad the video to the narration length, add ~1s lead and ~1s tail
# silence, mux the audio, and draw the bottom caption bar. Run from the ddev project root
# with TUT_SLUG set.
#   ./finish-scene.sh 03
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

NN="$(printf '%02d' "$((10#${1:?scene number required}))")"
LEAD="${TUT_LEAD:-1.0}"    # seconds of silence before narration
TAIL="${TUT_TAIL:-1.0}"    # seconds of silence after narration
LEAD_MS="$(awk -v l="$LEAD" 'BEGIN{printf "%d", l*1000}')"

[ -f "$HDIR/scenes/${NN}.mp4" ] || die "scenes/${NN}.mp4 not found (record the scene first)"

vdur="$(cduration "$CDIR/scenes/${NN}.mp4")"
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
  vf="${vf},drawbox=x=0:y=ih*0.91:w=iw:h=ih*0.09:color=black@0.85:t=fill,drawtext=fontfile=${FONT_REGULAR}:textfile='final/${NN}.caption.txt':fontcolor=white:fontsize=40:x=(w-text_w)/2:y=ih*0.91+(ih*0.09-text_h)/2"
fi

if [ "$have_audio" = 1 ]; then
  cexec "cd '$CDIR' && ffmpeg -y -i 'scenes/${NN}.mp4' -i 'audio/${NN}.mp3' \
-filter_complex \"[0:v]${vf}[v];[1:a]adelay=${LEAD_MS}|${LEAD_MS},apad[a]\" \
-map '[v]' -map '[a]' -t ${target} \
-codec:v libx264 -preset medium -pix_fmt yuv420p -codec:a aac -ar 44100 -movflags +faststart \
'final/scene-${NN}.mp4' >'final/${NN}.finish.log' 2>&1"
else
  cexec "cd '$CDIR' && ffmpeg -y -i 'scenes/${NN}.mp4' -f lavfi -i anullsrc=r=44100:cl=stereo \
-filter_complex \"[0:v]${vf}[v]\" \
-map '[v]' -map 1:a -t ${target} \
-codec:v libx264 -preset medium -pix_fmt yuv420p -codec:a aac -ar 44100 -movflags +faststart \
'final/scene-${NN}.mp4' >'final/${NN}.finish.log' 2>&1"
fi

echo "finished scene $NN -> final/scene-${NN}.mp4 (${target}s)"
