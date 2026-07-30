#!/usr/bin/env bash
# Cut only the trailing frozen tail of each beat. Runs INSIDE the ddev web container (ffmpeg
# lives there, and a 90+ beat loop must be a script file, not an inline `ddev exec bash -lc`
# loop: the host shell expands $vars before the container sees them). Preflight copies this into
# the build dir; invoke it with:
#   ddev exec bash /var/www/html/.tutorial-build/<slug>/deadair.sh dry       report proposed cuts
#   ddev exec bash /var/www/html/.tutorial-build/<slug>/deadair.sh apply     trim, verify, revert bad
#   ddev exec bash /var/www/html/.tutorial-build/<slug>/deadair.sh restore   put every beat back
#
# Two hard-won guards:
#  1. n=-75dB, not the -58dB default. At -58dB a checkbox tick counts as "frozen" and the trim
#     silently cuts the click (a beat lost both its ticks that way, ending in the pre-click state).
#  2. After trimming, the last frame of the trimmed clip is compared against the last frame of the
#     original (psnr). If they differ, the trim removed real content and it is reverted. A beat
#     that still shows the pre-action state is worse than a slow beat.
# Blind spot: a blinking text cursor in a focused input never registers as frozen, so those beats
# are left alone and need a manual head-trim + a human look at the end frame.
set -uo pipefail
export LC_ALL=C
cd "$(dirname "$(readlink -f "$0")")"
MODE="${1:-dry}"
PAD=1.0
FLOOR=2.0

if [ "$MODE" = "restore" ]; then
  n=0
  for p in beats/*.pretrim.mp4; do
    [ -f "$p" ] || continue
    b=$(basename "$p" .pretrim.mp4)
    cp "$p" "beats/$b.mp4"; n=$((n+1))
  done
  echo "restored $n beats from .pretrim"; exit 0
fi

printf '%-6s %7s %10s %8s %s\n' beat video freeze@ newlen result
for f in beats/*.mp4; do
  n=$(basename "$f" .mp4)
  case "$n" in *.orig|*.pretrim) continue;; esac
  src="beats/$n.pretrim.mp4"; [ -f "$src" ] || src="$f"
  v=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$src")

  log=$(ffmpeg -v info -i "$src" -vf "freezedetect=n=-75dB:d=0.7" -map 0:v -f null - 2>&1 </dev/null \
        | grep -o 'freeze_\(start\|end\): *[0-9.]*' | tr -d ' ')
  fs=$(echo "$log" | grep 'freeze_start' | tail -1 | cut -d: -f2)
  fe=$(echo "$log" | tail -1 | grep -c 'freeze_end')
  # Take the last freeze_start with no freeze_end after it (a freeze that runs to EOF).
  if [ -n "$fs" ] && [ "$fe" = "0" ]; then
    new=$(awk -v s="$fs" -v p="$PAD" -v fl="$FLOOR" -v vv="$v" 'BEGIN{x=s+p; if(x<fl)x=fl; if(x>vv)x=vv; printf "%.2f", x}')
  else
    new="$v"; fs=-1
  fi
  # Do not bother with static slides shorter than ~6.5s: finish-beat.sh freeze-pads them back.
  act=$(awk -v nn="$new" -v vv="$v" 'BEGIN{print (vv-nn > 1.5 && vv > 6.5) ? "TRIM" : "keep"}')

  if [ "$MODE" != "apply" ] || [ "$act" != "TRIM" ]; then
    [ "$act" = "TRIM" ] && printf '%-6s %7.2f %10s %8.2f %s\n' "$n" "$v" "$fs" "$new" "$act"
    continue
  fi

  [ -f "beats/$n.pretrim.mp4" ] || cp "$f" "beats/$n.pretrim.mp4"
  ffmpeg -y -v error -t "$new" -i "beats/$n.pretrim.mp4" \
    -codec:v libx264 -preset ultrafast -pix_fmt yuv420p "beats/$n.mp4" </dev/null

  # Verify: does the trimmed clip still end on the same picture as the original?
  ffmpeg -y -v error -sseof -0.3 -i "beats/$n.pretrim.mp4" -frames:v 1 /tmp/a.png </dev/null
  ffmpeg -y -v error -sseof -0.3 -i "beats/$n.mp4"        -frames:v 1 /tmp/b.png </dev/null
  psnr=$(ffmpeg -v info -i /tmp/a.png -i /tmp/b.png -lavfi psnr -f null - 2>&1 </dev/null \
         | grep -o 'average:[0-9.]*' | cut -d: -f2 | tail -1)
  ok=$(awk -v p="${psnr:-0}" 'BEGIN{print (p=="inf"||p+0>38) ? "ok" : "bad"}')
  if [ "$ok" = "bad" ]; then
    cp "beats/$n.pretrim.mp4" "beats/$n.mp4"
    printf '%-6s %7.2f %10s %8.2f REVERTED (psnr %s - trim cut real content)\n' "$n" "$v" "$fs" "$new" "${psnr:-?}"
  else
    printf '%-6s %7.2f %10s %8.2f trimmed (psnr %s)\n' "$n" "$v" "$fs" "$new" "${psnr:-inf}"
  fi
done
