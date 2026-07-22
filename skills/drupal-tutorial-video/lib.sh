#!/usr/bin/env bash
# Shared config for the drupal-tutorial-video helper scripts.
# Source this from every host-side script. Run scripts from the ddev project root.
set -euo pipefail

: "${TUT_SLUG:?set TUT_SLUG to the tutorial slug, e.g. export TUT_SLUG=commerce-checkout}"

# Display / capture settings (override with TUT_* env vars if needed).
DISPLAY_NUM="${TUT_DISPLAY:-:99}"
RES="${TUT_RES:-1920x1080}"
FPS="${TUT_FPS:-25}"
CDP_PORT="${TUT_CDP_PORT:-9222}"

# Build directory: host path (relative to project root) and container path.
HDIR=".tutorial-build/${TUT_SLUG}"
CDIR="/var/www/html/.tutorial-build/${TUT_SLUG}"

# Montserrat font, in the shared mount so the container's ffmpeg can read it.
FONT_REGULAR="${CDIR}/assets/Montserrat-Regular.ttf"
# Monospace font for command cards (installed via fonts-dejavu-core).
FONT_MONO="${TUT_FONT_MONO:-/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf}"

# Run a command string inside the ddev web container.
cexec() { ddev exec bash -lc "$1"; }

# ffprobe a media file (container path) for its duration in seconds.
cduration() {
  cexec "ffprobe -v error -show_entries format=duration -of csv=p=0 '$1'"
}

die() { echo "error: $*" >&2; exit 1; }
