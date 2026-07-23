#!/usr/bin/env bash
# Render a command card: a black frame with a terminal command in white monospace, centered.
# A command card is a beat. Output goes to beats/NN.mp4 (silent), then finish-beat.sh adds
# narration and the caption. Run from the ddev project root with TUT_SLUG set.
#   ./make-card.sh 05 4 "composer require drupal/commerce"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

NN="$(printf '%02d' "$((10#${1:?scene number required}))")"
DUR="${2:?duration in seconds required}"
TEXT="${3:?command text required}"

# Write the command to a file so ffmpeg drawtext does not have to escape it.
printf '$ %s\n' "$TEXT" > "$HDIR/cards/${NN}.cmd.txt"

cexec "cd '$CDIR' && ffmpeg -y -f lavfi -i color=c=black:s=$RES:d=$DUR:r=$FPS \
-vf \"drawtext=fontfile=$FONT_MONO:textfile='cards/${NN}.cmd.txt':fontcolor=white:fontsize=44:x=(w-text_w)/2:y=(h-text_h)/2:line_spacing=14\" \
-codec:v libx264 -preset ultrafast -pix_fmt yuv420p 'beats/${NN}.mp4' >/dev/null 2>&1"

echo "command card beat $NN -> beats/${NN}.mp4 (${DUR}s)"
