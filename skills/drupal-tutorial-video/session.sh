#!/usr/bin/env bash
# Start or stop the in-container recording session: Xvfb + kiosk Chromium with remote
# debugging. Run from the ddev project root with TUT_SLUG set.
#   ./session.sh start "https://mysite.ddev.site"
#   ./session.sh stop
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

cmd="${1:?usage: session.sh start <url> | stop}"

start() {
  local url="${2:?usage: session.sh start <url>}"

  # Xvfb on :99 if not already running.
  cexec "pgrep -x Xvfb >/dev/null || (nohup Xvfb $DISPLAY_NUM -screen 0 ${RES}x24 -ac -nolisten tcp >/tmp/xvfb.log 2>&1 & sleep 1)"

  # Kiosk Chromium on :99 with remote debugging.
  local flags="--no-sandbox --disable-dev-shm-usage --disable-gpu \
--kiosk --window-position=0,0 --window-size=${RES/x/,} --force-device-scale-factor=1 \
--remote-debugging-port=${CDP_PORT} --remote-debugging-address=0.0.0.0 --remote-allow-origins=* \
--no-first-run --no-default-browser-check --disable-infobars --disable-session-crashed-bubble \
--disable-features=Translate --user-data-dir=/tmp/tut-chrome"
  cexec "pgrep -x chromium >/dev/null || (DISPLAY=$DISPLAY_NUM nohup chromium $flags '$url' >/tmp/chromium.log 2>&1 & echo \$! > '$CDIR/chromium.pid')"

  # Wait for CDP to answer inside the container.
  local i
  for i in $(seq 1 30); do
    if cexec "curl -sf http://127.0.0.1:${CDP_PORT}/json/version >/dev/null 2>&1"; then break; fi
    sleep 1
  done
  cexec "curl -sf http://127.0.0.1:${CDP_PORT}/json/version >/dev/null" || die "Chromium CDP did not come up (see /tmp/chromium.log in the container)"

  # Focus the window so xdotool typing lands in the browser.
  cexec "DISPLAY=$DISPLAY_NUM xdotool search --class chromium windowactivate --sync >/dev/null 2>&1 || true"

  echo "session up. CDP inside container: http://127.0.0.1:${CDP_PORT}"
  if curl -sf "http://127.0.0.1:${CDP_PORT}/json/version" >/dev/null 2>&1; then
    echo "host can reach CDP: agent-browser --cdp http://127.0.0.1:${CDP_PORT} ..."
  else
    echo "host cannot reach CDP directly; run agent-browser in the container: ddev exec agent-browser --cdp http://127.0.0.1:${CDP_PORT} ..."
  fi
}

stop() {
  cexec "pkill -x chromium 2>/dev/null || true; pkill -x Xvfb 2>/dev/null || true; rm -f '$CDIR/chromium.pid'"
  echo "session stopped."
}

case "$cmd" in
  start) start "$@" ;;
  stop)  stop ;;
  *) die "usage: session.sh start <url> | stop" ;;
esac
