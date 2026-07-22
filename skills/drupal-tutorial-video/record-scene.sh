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
    # No `$!` PID capture: the container runs bash with `set -u` (nounset), which trips on
    # `$!`. stop() matches the ffmpeg process by its output path instead. Only one capture
    # runs at a time, and the output path is unique per scene.
    cexec "cd '$CDIR' && ( DISPLAY=$DISPLAY_NUM nohup ffmpeg -y -f x11grab -video_size $RES -framerate $FPS -i $DISPLAY_NUM -codec:v libx264 -preset ultrafast -pix_fmt yuv420p 'scenes/${NN}.mp4' > 'scenes/${NN}.ffmpeg.log' 2>&1 & )"
    sleep 0.5
    echo "recording scene $NN -> scenes/${NN}.mp4"
    ;;
  stop)
    # SIGINT lets ffmpeg finalize the moov atom, then wait for it to exit.
    cexec "pkill -INT -f 'scenes/${NN}.mp4' 2>/dev/null || true; for i in \$(seq 1 40); do pgrep -f 'scenes/${NN}.mp4' >/dev/null 2>&1 || break; sleep 0.25; done"
    echo "stopped scene $NN"
    ;;
  *) die "usage: record-scene.sh start|stop <NN>" ;;
esac
