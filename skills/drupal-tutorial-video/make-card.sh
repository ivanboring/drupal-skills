#!/usr/bin/env bash
# Render a command card: a black frame with a terminal command in white monospace, centered.
# A command card is a beat. Output goes to beats/NN.mp4 (silent), then finish-beat.sh adds
# narration and the caption. Run from the ddev project root with TUT_SLUG set.
#   ./make-card.sh 05 4 "composer require drupal/commerce"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
export LC_ALL=C LC_NUMERIC=C  # keep awk's font math and any ffmpeg number formatting dot-decimal

NN="$(printf '%02d' "$((10#${1:?scene number required}))")"
DUR="${2:?duration in seconds required}"
TEXT="${3:?command text required}"

# Write the command to a file so ffmpeg drawtext does not have to escape it. The first line gets
# the "$ " prompt; continuation lines (embedded newlines in TEXT, for a wrapped command) are kept
# as-is so a multi-line command still reads correctly.
{
  first=1
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$first" = 1 ]; then printf '$ %s\n' "$line"; first=0; else printf '%s\n' "$line"; fi
  done <<< "$TEXT"
} > "$HDIR/cards/${NN}.cmd.txt"

# Fit the font to the frame instead of a fixed 44px, which ran a 4-package `composer require` off
# both edges. DejaVu Sans Mono advances ~0.6022em per glyph, so the widest line is
# maxlen*0.6022*fontsize px; shrink until it fits ~92% of the width, clamp to 16-44px.
maxlen="$(awk '{ if (length($0) > m) m = length($0) } END { print m+0 }' "$HDIR/cards/${NN}.cmd.txt")"
fontsize="$(awk -v n="$maxlen" 'BEGIN{ if (n < 1) { print 44; exit } fs = int(0.92*1920 / (n * 0.6022)); if (fs > 44) fs = 44; if (fs < 16) fs = 16; print fs }')"

# expansion=none so drawtext does not interpret %{...} or backslashes in the command text.
cexec "cd '$CDIR' && ffmpeg -y -f lavfi -i color=c=black:s=$RES:d=$DUR:r=$FPS \
-vf \"drawtext=fontfile=$FONT_MONO:textfile='cards/${NN}.cmd.txt':fontcolor=white:fontsize=${fontsize}:x=(w-text_w)/2:y=(h-text_h)/2:line_spacing=14:expansion=none\" \
-codec:v libx264 -preset ultrafast -pix_fmt yuv420p 'beats/${NN}.mp4' >/dev/null 2>&1"

echo "command card beat $NN -> beats/${NN}.mp4 (${DUR}s, font ${fontsize}px)"
