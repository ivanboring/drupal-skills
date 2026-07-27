#!/usr/bin/env bash
# Preflight: check and set up the infrastructure the drupal-manual-video-testing skill needs.
# Run from the ddev project root with MT_MODULE and MT_MR set.
#
# This checks the HARD, issue-independent prerequisites only: DDEV, a working browser
# automation stack in the container, drush, and a way to log in. The per-issue gates
# (Drupal/module version match, required secrets) are decided in the skill workflow, not
# here, because they depend on the specific issue being tested.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ok()   { echo "  ok   $*"; }
info() { echo "  ..   $*"; }
warn() { echo "  WARN $*"; }
die()  { echo "error: $*" >&2; exit 1; }

# 1. DDEV is mandatory and must be running BEFORE we can resolve paths via drush.
command -v ddev >/dev/null || die "ddev is not installed. This skill only runs under DDEV."
ddev describe >/dev/null 2>&1 || die "no ddev project here, or it is not running (try: ddev start). This skill only runs under DDEV."

source "$HERE/lib.sh"
echo "== drupal-manual-video-testing preflight (module: $MT_MODULE, mr: $MT_MR) =="
ok "ddev project is running"

# 2. Build directory (under the public files dir, shared by host and container).
mkdir -p "$HDIR"/{parts,final,assets,snapshots}
ok "build dir $HDIR ready"

# 3. Container packages + exposed CDP port, via a ddev config drop-in. No xdotool: this skill
#    drives the browser over CDP / JS events, so there is no visible mouse to move.
CONF=".ddev/config.manual-testing.yaml"
NEED_RESTART=0
if [ ! -f "$CONF" ]; then
  cat > "$CONF" <<YAML
# Added by the drupal-manual-video-testing skill.
# The post-start hook installs agent-browser (npm) in the container; CDP only works from
# inside the container, so agent-browser has to live there. npm-global installs do not
# persist across rebuilds, so the hook re-installs it if missing on every start.
webimage_extra_packages:
  - ffmpeg
  - xvfb
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

if ! cexec "command -v ffmpeg && command -v Xvfb && command -v chromium" >/dev/null 2>&1; then
  NEED_RESTART=1
fi
if [ "$NEED_RESTART" = 1 ]; then
  info "ddev restart (builds container packages, runs the agent-browser hook)"
  ddev restart
fi
cexec "command -v ffmpeg >/dev/null"   || die "ffmpeg missing in web container after restart"
cexec "command -v Xvfb >/dev/null"     || die "Xvfb missing in web container after restart"
cexec "command -v chromium >/dev/null" || die "chromium missing in web container after restart"
ok "container has ffmpeg, Xvfb, chromium"

# 4. Browser automation: agent-browser in the container (CDP only works from localhost there).
if ! cexec "command -v agent-browser >/dev/null 2>&1" >/dev/null 2>&1; then
  info "installing agent-browser in the web container (npm install -g agent-browser)"
  ddev exec npm install -g agent-browser
fi
cexec "command -v agent-browser >/dev/null 2>&1" >/dev/null 2>&1 \
  || die "agent-browser missing in the web container (needs Node/npm there). See https://github.com/vercel-labs/agent-browser"
ok "agent-browser (browser automation) present in the container"

# 5. drush must work (used for status, module versions, snapshots' companions, and login).
cexec "drush status >/dev/null 2>&1" || die "drush is not working in the container. This skill requires drush."
ok "drush is working"

# 6. Login: this skill logs in with a one-time login link from drush (drush uli), so it never
#    handles a password. Verify uli works.
if cexec "drush uli --no-browser >/dev/null 2>&1"; then
  ok "login available via 'drush uli' (one-time login link)"
else
  warn "'drush uli' did not produce a link. You need another way to log in as an admin."
  warn "Ask the user how to log in; if they cannot provide one, do not run the skill."
fi

# 7. Montserrat font for the text-overlay bar.
if [ ! -f "$HDIR/assets/Montserrat-Regular.ttf" ]; then
  info "downloading Montserrat (Google Fonts)"
  curl -fsSL -o "$HDIR/assets/Montserrat-Regular.ttf" \
    "https://github.com/google/fonts/raw/main/ofl/montserrat/Montserrat%5Bwght%5D.ttf"
fi
ok "Montserrat font in $HDIR/assets"

echo
echo "Reminder: secrets (API keys, tokens) must already be set as environment variables or"
echo "configured in the site. This skill never asks for or reads credentials. If a required"
echo "secret is missing, abort and tell the user which variable to set."
echo "== preflight complete =="
