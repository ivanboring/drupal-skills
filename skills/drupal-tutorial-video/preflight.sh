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
mkdir -p "$HDIR"/{beats,audio,cards,final,assets}
cp "$HERE/hands.sh" "$HDIR/hands.sh"
chmod +x "$HDIR/hands.sh"
ok "build dir $HDIR ready"

# 3. Container packages + exposed CDP port, via a ddev config drop-in.
CONF=".ddev/config.tutorial-video.yaml"
NEED_RESTART=0
if [ ! -f "$CONF" ]; then
  cat > "$CONF" <<YAML
# Added by the drupal-tutorial-video skill.
# fonts-noto-cjk so non-Latin target languages (Japanese/Chinese/Korean) render, not tofu.
# The post-start hook installs agent-browser (npm) in the container; CDP only works from
# inside the container, so agent-browser has to live there. npm-global installs do not
# persist across rebuilds, so the hook re-installs it if missing on every start.
webimage_extra_packages:
  - ffmpeg
  - xvfb
  - xdotool
  - chromium
  - x11-utils
  - fonts-dejavu-core
  - fonts-noto-cjk
hooks:
  post-start:
    - exec: "command -v agent-browser >/dev/null 2>&1 || npm install -g agent-browser"
YAML
  ok "wrote $CONF"
  NEED_RESTART=1
else
  ok "$CONF already present"
fi

# Do the container packages exist yet?
if ! cexec "command -v ffmpeg && command -v Xvfb && command -v xdotool && command -v chromium" >/dev/null 2>&1; then
  NEED_RESTART=1
fi
if [ "$NEED_RESTART" = 1 ]; then
  info "ddev restart (builds container packages, runs the agent-browser hook)"
  ddev restart
fi
cexec "command -v ffmpeg >/dev/null"  || die "ffmpeg missing in web container after restart"
cexec "command -v Xvfb >/dev/null"    || die "Xvfb missing in web container after restart"
cexec "command -v xdotool >/dev/null" || die "xdotool missing in web container after restart"
cexec "command -v chromium >/dev/null" || die "chromium missing in web container after restart"
ok "container has ffmpeg, Xvfb, xdotool, chromium"

# 4. agent-browser must live in the container (CDP only works from localhost inside it).
if ! cexec "command -v agent-browser >/dev/null 2>&1" >/dev/null 2>&1; then
  info "installing agent-browser in the web container (npm install -g agent-browser)"
  ddev exec npm install -g agent-browser
fi
cexec "command -v agent-browser >/dev/null 2>&1" >/dev/null 2>&1 \
  || die "agent-browser missing in the web container (needs Node/npm there)"
ok "agent-browser present in the container"

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
  warn "ELEVENLABS_API_KEY is not set. Export it before recording. The key needs the Text to Speech and Voices (read) permissions, or awaz fails with missing_permissions."
fi

# 5. Montserrat font (variable font from Google Fonts; drawtext renders the default instance).
if [ ! -f "$HDIR/assets/Montserrat-Regular.ttf" ]; then
  info "downloading Montserrat (Google Fonts) to /tmp"
  curl -fsSL -o /tmp/Montserrat.ttf \
    "https://github.com/google/fonts/raw/main/ofl/montserrat/Montserrat%5Bwght%5D.ttf"
  cp /tmp/Montserrat.ttf "$HDIR/assets/Montserrat-Regular.ttf"
fi
ok "Montserrat font in $HDIR/assets"

echo "== preflight complete =="
