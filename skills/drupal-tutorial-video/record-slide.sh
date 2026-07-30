#!/usr/bin/env bash
# Record one slide beat: open a locally rendered slide, let it settle, capture a few seconds.
# finish-beat.sh freeze-pads to the narration length, so a short capture is enough. Run from the
# ddev project root with TUT_SLUG set, while a session (session.sh start) is up.
#   TUT_SLIDES_URL=https://mysite.ddev.site/slides ./record-slide.sh 03 [seconds]
#
# Slides are static HTML you render locally and serve from the site docroot (e.g. web/slides/NN.html).
# They are the practical answer for concept/intro beats, because drupal.org serves the kiosk
# browser HTTP 406 (see SKILL.md). Keep the project URL in the beat's caption so viewers still
# know where to get the module. Leave the bottom ~15% of each slide empty for the caption bar.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

NN="$(printf '%02d' "$((10#${1:?beat number required}))")"
SECS="${2:-3}"
: "${TUT_SLIDES_URL:?set TUT_SLIDES_URL to the slides base URL, e.g. https://mysite.ddev.site/slides}"
URL="${TUT_SLIDES_URL%/}/${NN}.html"

ddev exec agent-browser --cdp "http://127.0.0.1:${CDP_PORT}" open "$URL" >/dev/null 2>&1
sleep 2
"$HERE/record-beat.sh" start "$NN" >/dev/null
sleep "$SECS"
"$HERE/record-beat.sh" stop "$NN" >/dev/null
sz="$(stat -c%s "$HDIR/beats/${NN}.mp4" 2>/dev/null || echo 0)"
echo "beat $NN slide recorded (${sz} bytes)"
