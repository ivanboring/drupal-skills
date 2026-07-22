#!/usr/bin/env bash
# The "hands": visible cursor movement, clicks, and typing on the Xvfb display.
# Runs INSIDE the ddev web container. Call via:
#   ddev exec DISPLAY=:99 bash /var/www/html/.tutorial-build/<slug>/hands.sh move CX CY
#   ddev exec DISPLAY=:99 bash .../hands.sh click [CX CY]
#   ddev exec DISPLAY=:99 bash .../hands.sh type "text to type"
#   ddev exec DISPLAY=:99 bash .../hands.sh key ctrl+a
#   ddev exec DISPLAY=:99 bash .../hands.sh hover CX CY
set -euo pipefail
export DISPLAY="${DISPLAY:-:99}"

STEPS="${STEPS:-25}"          # cursor interpolation steps (higher = smoother/slower)
STEP_SLEEP="${STEP_SLEEP:-0.012}"
TYPE_DELAY="${TYPE_DELAY:-60}"  # ms between keystrokes

move() {
  local tx="$1" ty="$2" cx cy i nx ny
  eval "$(xdotool getmouselocation --shell)"   # sets X, Y
  cx="$X"; cy="$Y"
  for i in $(seq 1 "$STEPS"); do
    nx=$(( cx + (tx - cx) * i / STEPS ))
    ny=$(( cy + (ty - cy) * i / STEPS ))
    xdotool mousemove "$nx" "$ny"
    sleep "$STEP_SLEEP"
  done
}

cmd="${1:?usage: hands.sh move|click|type|key|hover ...}"; shift
case "$cmd" in
  move)  move "$1" "$2" ;;
  hover) move "$1" "$2" ;;
  click)
    if [ "$#" -ge 2 ]; then move "$1" "$2"; fi
    sleep 0.15
    xdotool click 1
    ;;
  type)  xdotool type --clearmodifiers --delay "$TYPE_DELAY" -- "$1" ;;
  key)   xdotool key --clearmodifiers -- "$1" ;;
  *) echo "unknown command: $cmd" >&2; exit 1 ;;
esac
