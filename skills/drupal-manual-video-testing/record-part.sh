#!/usr/bin/env bash
# Start or stop the x11grab screen capture for one part of the test (one chunk of the flow
# you record before pausing to change site state, take a snapshot, or switch context).
# Run from the ddev project root with MT_MODULE and MT_MR set, while the session is up.
#   ./record-part.sh start 01
#   ...drive the browser over CDP / JS events...
#   ./record-part.sh stop 01
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

cmd="${1:?usage: record-part.sh start|stop <NN>}"
NN="$(printf '%02d' "$((10#${2:?part number required}))")"

case "$cmd" in
  start)
    # No `$!` PID capture: the container runs bash with nounset, which trips on `$!`. stop()
    # matches the ffmpeg process by its output path instead; the path is unique per part.
    cexec "cd '$CDIR' && ( DISPLAY=$DISPLAY_NUM nohup ffmpeg -y -f x11grab -video_size $RES -framerate $FPS -i $DISPLAY_NUM -codec:v libx264 -preset ultrafast -pix_fmt yuv420p 'parts/${NN}.mp4' > 'parts/${NN}.ffmpeg.log' 2>&1 & )"
    sleep 0.5
    echo "recording part $NN -> parts/${NN}.mp4"
    ;;
  stop)
    # SIGINT lets ffmpeg finalize the moov atom, then wait for it to exit.
    cexec "pkill -INT -f 'parts/${NN}.mp4' 2>/dev/null || true; for i in \$(seq 1 40); do pgrep -f 'parts/${NN}.mp4' >/dev/null 2>&1 || break; sleep 0.25; done"
    echo "stopped part $NN"
    ;;
  *) die "usage: record-part.sh start|stop <NN>" ;;
esac
