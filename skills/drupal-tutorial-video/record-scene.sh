#!/usr/bin/env bash
# Start or stop the x11grab screen capture for one scene. Run from the ddev project root
# with TUT_SLUG set, while the session (session.sh start) is up.
#   ./record-scene.sh start 03
#   ...drive the browser and hands...
#   ./record-scene.sh stop 03
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

cmd="${1:?usage: record-scene.sh start|stop <NN>}"
NN="$(printf '%02d' "$((10#${2:?scene number required}))")"

case "$cmd" in
  start)
    cexec "cd '$CDIR' && DISPLAY=$DISPLAY_NUM nohup ffmpeg -y -f x11grab -video_size $RES -framerate $FPS -i $DISPLAY_NUM -codec:v libx264 -preset ultrafast -pix_fmt yuv420p 'scenes/${NN}.mp4' > 'scenes/${NN}.ffmpeg.log' 2>&1 & echo \$! > 'scenes/${NN}.pid'"
    sleep 0.5
    echo "recording scene $NN -> scenes/${NN}.mp4"
    ;;
  stop)
    cexec "if [ -f '$CDIR/scenes/${NN}.pid' ]; then kill -INT \$(cat '$CDIR/scenes/${NN}.pid') 2>/dev/null || true; fi"
    # Give ffmpeg time to flush the moov atom, then confirm the process is gone.
    cexec "for i in \$(seq 1 20); do [ -f '$CDIR/scenes/${NN}.pid' ] && kill -0 \$(cat '$CDIR/scenes/${NN}.pid') 2>/dev/null || break; sleep 0.25; done; rm -f '$CDIR/scenes/${NN}.pid'"
    echo "stopped scene $NN"
    ;;
  *) die "usage: record-scene.sh start|stop <NN>" ;;
esac
