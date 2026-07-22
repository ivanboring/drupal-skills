#!/usr/bin/env bash
#
# count-code.sh - Measure custom (agent-written) code against community code
# (Drupal core + contrib) in a Drupal codebase, split into server-side
# ("dangerous") PHP and frontend.
#
# Usage:
#   count-code.sh [PROJECT_ROOT]
#
# PROJECT_ROOT defaults to the current directory. The docroot (web/, docroot/,
# or the root itself) is detected automatically by looking for core/.
#
# "Custom" code is everything under modules/custom, themes/custom and
# profiles/custom: the code you and the agent wrote. "Community" code is Drupal
# core plus every contrib module, theme and profile. Counts are SLOC (source
# lines, skipping blank and comment-only lines).

set -euo pipefail
export LC_ALL=C   # stable number formatting (period decimal separator) and sort

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWK_FILE="$SCRIPT_DIR/sloc.awk"

ROOT="${1:-.}"
if [ ! -d "$ROOT" ]; then
  echo "error: '$ROOT' is not a directory" >&2
  exit 1
fi

# --- detect the docroot ------------------------------------------------------
DOC=""
for cand in "$ROOT/web" "$ROOT/docroot" "$ROOT"; do
  if [ -d "$cand/core" ]; then DOC="$cand"; break; fi
done
if [ -z "$DOC" ]; then
  # No core/ found. Fall back to the root and rely on modules/themes existing.
  DOC="$ROOT"
  echo "warning: no core/ directory found under '$ROOT'; community totals may be 0." >&2
fi

# --- file extensions per language bucket ------------------------------------
BACKEND_EXTS="php module inc install theme profile engine"   # server-side PHP
SCRIPT_EXTS="js jsx ts tsx mjs cjs vue"                        # frontend scripts
CSS_EXTS="css"                                                 # plain stylesheets
SCSS_EXTS="scss sass less"                                     # preprocessed styles
TWIG_EXTS="twig"                                               # templates

# --- helpers -----------------------------------------------------------------

# find_files DIR PRUNE_PATH EXT...  -> NUL-separated matching files
find_files() {
  local dir="$1"; local prune="$2"; shift 2
  [ -d "$dir" ] || return 0
  local args=(); local first=1
  local e
  for e in "$@"; do
    if [ "$first" -eq 1 ]; then args+=( -name "*.$e" ); first=0
    else args+=( -o -name "*.$e" ); fi
  done
  if [ -n "$prune" ]; then
    find "$dir" -path "$prune" -prune -o -type f \( "${args[@]}" \) -print0
  else
    find "$dir" -type f \( "${args[@]}" \) -print0
  fi
}

# producers: emit the NUL-separated file list for a bucket of extensions
list_custom() {
  find_files "$DOC/modules/custom"  "" "$@"
  find_files "$DOC/themes/custom"   "" "$@"
  find_files "$DOC/profiles/custom" "" "$@"
}
list_community() {
  find_files "$DOC/core"     ""                       "$@"
  find_files "$DOC/modules"  "$DOC/modules/custom"    "$@"
  find_files "$DOC/themes"   "$DOC/themes/custom"     "$@"
  find_files "$DOC/profiles" "$DOC/profiles/custom"   "$@"
}

# sloc STYLE PRODUCER EXT...  -> integer SLOC total
sloc() {
  local style="$1"; local producer="$2"; shift 2
  local bopen bclose lc1 lc2
  case "$style" in
    php|cslash) bopen='/*'; bclose='*/'; lc1='//'; lc2='' ;;  # // and /* */
    css)        bopen='/*'; bclose='*/'; lc1='';   lc2='' ;;  # /* */ only
    twig)       bopen='{#'; bclose='#}'; lc1='';   lc2='' ;;  # {# #}
  esac
  "$producer" "$@" \
    | xargs -0 -r awk -v bopen="$bopen" -v bclose="$bclose" \
                      -v lc1="$lc1" -v lc2="$lc2" -f "$AWK_FILE" \
    | awk '{ s += $1 } END { print s + 0 }'
}

pct() {  # pct PART WHOLE -> "NN.N" (0.0 when whole is 0)
  awk -v a="$1" -v b="$2" 'BEGIN { printf (b > 0 ? "%.1f" : "0.0"), (b > 0 ? a * 100 / b : 0) }'
}

# --- count -------------------------------------------------------------------
c_backend=$(sloc php    list_custom    $BACKEND_EXTS)
c_script=$( sloc cslash list_custom    $SCRIPT_EXTS)
c_css=$(    sloc css    list_custom    $CSS_EXTS)
c_scss=$(   sloc cslash list_custom    $SCSS_EXTS)
c_twig=$(   sloc twig   list_custom    $TWIG_EXTS)
c_front=$(( c_script + c_css + c_scss + c_twig ))

k_backend=$(sloc php    list_community $BACKEND_EXTS)
k_script=$( sloc cslash list_community $SCRIPT_EXTS)
k_css=$(    sloc css    list_community $CSS_EXTS)
k_scss=$(   sloc cslash list_community $SCSS_EXTS)
k_twig=$(   sloc twig   list_community $TWIG_EXTS)
k_front=$(( k_script + k_css + k_scss + k_twig ))

backend_total=$(( c_backend + k_backend ))
front_total=$(( c_front + k_front ))

# --- report ------------------------------------------------------------------
printf '\n'
printf 'Drupal code provenance\n'
printf 'Docroot: %s\n' "$DOC"
printf '%s\n' '======================================================================'
printf '%-26s %14s %14s\n' '' 'Custom (you)' 'Community'
printf '%s\n' '----------------------------------------------------------------------'
printf '%-26s %14d %14d\n' 'Server-side PHP (SLOC)' "$c_backend" "$k_backend"
printf '%-26s %14d %14d\n' 'Frontend JS (SLOC)'     "$c_script"  "$k_script"
printf '%-26s %14d %14d\n' 'Frontend CSS/SCSS (SLOC)' "$((c_css + c_scss))" "$((k_css + k_scss))"
printf '%-26s %14d %14d\n' 'Twig templates (SLOC)'  "$c_twig"    "$k_twig"
printf '%s\n' '----------------------------------------------------------------------'
printf '%-26s %14d %14d\n' 'Frontend subtotal'      "$c_front"   "$k_front"
printf '%s\n' '======================================================================'
printf '\n'
printf 'Dangerous code you wrote (server-side PHP):\n'
printf '  %s SLOC of %s total  =  %s%%\n' \
  "$c_backend" "$backend_total" "$(pct "$c_backend" "$backend_total")"
printf 'Frontend code you wrote:\n'
printf '  %s SLOC of %s total  =  %s%%\n' \
  "$c_front" "$front_total" "$(pct "$c_front" "$front_total")"
printf '\n'
