#!/usr/bin/env bash
# Finish one part: optionally freeze-pad a trailing pause so the result is easy to follow,
# and draw a text-overlay bar describing what the part shows. No audio.
# Run from the ddev project root with MT_MODULE and MT_MR set.
#   ./finish-part.sh 01
#   MT_TAIL=1.5 ./finish-part.sh 01   # longer pause after a key moment
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

NN="$(printf '%02d' "$((10#${1:?part number required}))")"
TAIL="${MT_TAIL:-1.0}"   # seconds of freeze-frame pause added to the end of the part

[ -f "$HDIR/parts/${NN}.mp4" ] || die "parts/${NN}.mp4 not found (record the part first)"

# Video filter: freeze-pad a trailing pause, then draw the overlay bar if the caption is set.
vf="tpad=stop_mode=clone:stop_duration=${TAIL}"
cap="$HDIR/final/${NN}.caption.txt"
if [ -s "$cap" ]; then
  # drawbox understands ih/iw; drawtext uses h/w, so its y-expr uses h.
  vf="${vf},drawbox=x=0:y=ih*0.91:w=iw:h=ih*0.09:color=black@0.85:t=fill,drawtext=fontfile=${FONT_REGULAR}:textfile='final/${NN}.caption.txt':fontcolor=white:fontsize=40:x=(w-text_w)/2:y=h*0.91+(h*0.09-text_h)/2"
fi

cexec "cd '$CDIR' && ffmpeg -y -i 'parts/${NN}.mp4' \
-filter_complex \"[0:v]${vf}[v]\" -map '[v]' \
-codec:v libx264 -preset medium -pix_fmt yuv420p -movflags +faststart \
'final/part-${NN}.mp4' >'final/${NN}.finish.log' 2>&1"

echo "finished part $NN -> final/part-${NN}.mp4"
