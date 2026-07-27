#!/usr/bin/env bash
# Shared config for the drupal-manual-video-testing helper scripts.
# Source this from every host-side script. Run scripts from the ddev project root.
set -euo pipefail

: "${MT_MODULE:?set MT_MODULE to the module machine name, e.g. export MT_MODULE=commerce}"
: "${MT_MR:?set MT_MR to the issue/MR id, e.g. export MT_MR=3456789}"

# Display / capture settings (override with MT_* env vars if needed).
DISPLAY_NUM="${MT_DISPLAY:-:99}"
RES="${MT_RES:-1920x1080}"
FPS="${MT_FPS:-25}"
CDP_PORT="${MT_CDP_PORT:-9222}"

# Run a command string inside the ddev web container.
cexec() { ddev exec bash -lc "$1"; }

die() { echo "error: $*" >&2; exit 1; }

# Output subdirectory: {module}-{mr#}.
OUT="${MT_MODULE}-${MT_MR}"

# Public files directory. drush resolves public:// to a container-absolute path
# (e.g. /var/www/html/web/sites/default/files); the ddev mount root /var/www/html is
# the project root on the host, so strip that prefix to get the host path.
# Override MT_PUBLIC_FILES (container path) to skip the drush lookup.
CFILES="${MT_PUBLIC_FILES:-$(cexec 'drush php:eval "echo \Drupal::service(\"file_system\")->realpath(\"public://\");"' 2>/dev/null || true)}"
[ -n "$CFILES" ] || die "could not resolve public:// files path via drush (is the site installed and drush working?)"

PROOT="$(pwd)"
HREL="${CFILES#/var/www/html/}"
HFILES="$PROOT/$HREL"

# Build directory, under the public files dir so the result lives with the site and the
# container + host share one filesystem.
CDIR="$CFILES/ai-manual-testing/$OUT"
HDIR="$HFILES/ai-manual-testing/$OUT"

# Montserrat font for the text-overlay bar, in the shared mount so the container's ffmpeg
# can read it.
FONT_REGULAR="${CDIR}/assets/Montserrat-Regular.ttf"

# ffprobe a media file (container path) for its duration in seconds.
cduration() {
  cexec "ffprobe -v error -show_entries format=duration -of csv=p=0 '$1'"
}
