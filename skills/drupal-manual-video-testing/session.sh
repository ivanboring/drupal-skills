#!/usr/bin/env bash
# Start or stop the in-container recording session: Xvfb + kiosk Chromium with remote
# debugging. Run from the ddev project root with MT_MODULE and MT_MR set.
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
  # --ignore-certificate-errors: trust ddev's mkcert https cert (untrusted inside the container).
  # No `$!` PID capture: the container runs bash with `set -u` (nounset), which trips on `$!`.
  # stop() uses `pkill -x chromium`, so no PID file is needed.
  local flags="--no-sandbox --disable-dev-shm-usage --disable-gpu \
--kiosk --window-position=0,0 --window-size=${RES/x/,} --force-device-scale-factor=1 \
--remote-debugging-port=${CDP_PORT} --remote-debugging-address=0.0.0.0 --remote-allow-origins=* \
--ignore-certificate-errors --test-type \
--no-first-run --no-default-browser-check --disable-infobars --disable-session-crashed-bubble \
--disable-features=Translate --user-data-dir=/tmp/mt-chrome"
  cexec "pgrep -x chromium >/dev/null || ( DISPLAY=$DISPLAY_NUM nohup chromium $flags '$url' >/tmp/chromium.log 2>&1 & )"

  # Wait for CDP to answer inside the container. curl exits 7 until it is up.
  local i
  for i in $(seq 1 30); do
    if cexec "curl -sf http://127.0.0.1:${CDP_PORT}/json/version >/dev/null 2>&1" 2>/dev/null; then break; fi
    sleep 1
  done
  cexec "curl -sf http://127.0.0.1:${CDP_PORT}/json/version >/dev/null 2>&1" 2>/dev/null \
    || die "Chromium CDP did not come up (see /tmp/chromium.log in the container)"

  echo "session up. Drive the browser inside the container (host CDP is blocked):"
  echo "  ddev exec agent-browser --cdp http://127.0.0.1:${CDP_PORT} <cmd>"
}

stop() {
  cexec "pkill -x chromium 2>/dev/null || true; pkill -x Xvfb 2>/dev/null || true"
  echo "session stopped."
}

case "$cmd" in
  start) start "$@" ;;
  stop)  stop ;;
  *) die "usage: session.sh start <url> | stop" ;;
esac
