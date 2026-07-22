#!/usr/bin/env bash
# Preflight: check and set up everything the drupal-tutorial-video skill needs.
# Run from the ddev project root with TUT_SLUG set.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

ok()   { echo "  ok   $*"; }
info() { echo "  ..   $*"; }
warn() { echo "  WARN $*"; }

echo "== drupal-tutorial-video preflight (slug: $TUT_SLUG) =="

# 1. ddev must be installed and the project running.
command -v ddev >/dev/null || die "ddev is not installed"
ddev describe >/dev/null 2>&1 || die "no ddev project here, or it is not running (try: ddev start)"
ok "ddev project is running"

# 2. Build directory.
mkdir -p "$HDIR"/{scenes,audio,cards,final,assets}
cp "$HERE/hands.sh" "$HDIR/hands.sh"
chmod +x "$HDIR/hands.sh"
ok "build dir $HDIR ready"

# 3. Container packages + exposed CDP port, via a ddev config drop-in.
CONF=".ddev/config.tutorial-video.yaml"
NEED_RESTART=0
if [ ! -f "$CONF" ]; then
  cat > "$CONF" <<YAML
# Added by the drupal-tutorial-video skill.
webimage_extra_packages:
  - ffmpeg
  - xvfb
  - xdotool
  - chromium
  - x11-utils
  - fonts-dejavu-core
web_extra_exposed_ports:
  - name: cdp
    container_port: ${CDP_PORT}
    http_port: ${CDP_PORT}
    https_port: $((CDP_PORT + 1))
YAML
  ok "wrote $CONF"
  NEED_RESTART=1
else
  ok "$CONF already present"
fi

# Do the packages exist in the container yet?
if ! cexec "command -v ffmpeg && command -v Xvfb && command -v xdotool && command -v chromium" >/dev/null 2>&1; then
  NEED_RESTART=1
fi
if [ "$NEED_RESTART" = 1 ]; then
  info "ddev restart (builds container packages, exposes port $CDP_PORT)"
  ddev restart
fi
cexec "command -v ffmpeg >/dev/null"  || die "ffmpeg missing in web container after restart"
cexec "command -v Xvfb >/dev/null"    || die "Xvfb missing in web container after restart"
cexec "command -v xdotool >/dev/null" || die "xdotool missing in web container after restart"
cexec "command -v chromium >/dev/null" || die "chromium missing in web container after restart"
ok "container has ffmpeg, Xvfb, xdotool, chromium"

# 4. Host tools.
command -v agent-browser >/dev/null || die "agent-browser is not installed on the host (https://github.com/vercel-labs/agent-browser)"
ok "agent-browser present"

if ! command -v awaz >/dev/null; then
  if command -v npm >/dev/null; then
    info "installing awaz (npm i -g awaz)"
    npm i -g awaz
  else
    die "awaz not found and npm (Node.js) is not installed. Install Node.js (https://nodejs.org) then: npm i -g awaz"
  fi
fi
ok "awaz present"
if [ -z "${ELEVENLABS_API_KEY:-}" ]; then
  warn "ELEVENLABS_API_KEY is not set. Export it (export ELEVENLABS_API_KEY=...) before recording; awaz needs it to list voices and generate narration."
fi

# 5. Montserrat font.
if [ ! -f "$HDIR/assets/Montserrat-Regular.ttf" ]; then
  info "downloading Montserrat to /tmp"
  rm -rf /tmp/montserrat && mkdir -p /tmp/montserrat
  curl -fsSL -o /tmp/montserrat.zip "https://www.1001freefonts.com/d/5711/montserrat.zip"
  unzip -o -q /tmp/montserrat.zip -d /tmp/montserrat
  reg="$(find /tmp/montserrat -iname 'Montserrat-Regular.ttf' | head -n1)"
  bold="$(find /tmp/montserrat -iname 'Montserrat-Bold.ttf' | head -n1)"
  [ -n "$reg" ] || die "Montserrat-Regular.ttf not found in the zip"
  cp "$reg" "$HDIR/assets/Montserrat-Regular.ttf"
  [ -n "$bold" ] && cp "$bold" "$HDIR/assets/Montserrat-Bold.ttf"
fi
ok "Montserrat font in $HDIR/assets"

echo "== preflight complete =="
