#!/usr/bin/env bash
# The browser front-end: find an element, scroll it into the safe band, and drive it with the
# visible cursor. Keeps all the ddev-exec quoting in one place. Run from the ddev project root
# with TUT_SLUG set, while a session (session.sh start) is up.
#   ./ui.sh open  <url>
#   ./ui.sh box   <kind> <value>      -> "CX CY"  (raw)
#   ./ui.sh vbox  <kind> <value>      -> "CX CY"  (scrolled into view first)
#   ./ui.sh click <kind> <value>
#   ./ui.sh move  <kind> <value>
#   ./ui.sh type  "text"              (via type64, metacharacter-safe)
#   ./ui.sh paste <fieldName> "long text"   (sets .value + fires input/change, one shot)
#   ./ui.sh key   <keyname>
#   ./ui.sh rec   start|stop <NN>
#   ./ui.sh shot  <path>
#
# Matcher kinds (four are needed, not one):
#   name  form fields; survives Drupal #ajax id regeneration. THE DEFAULT.
#   nth   same-named buttons: every Drupal submit is name="op", so "Test Connection" and "Save"
#         collide. Use "op:0", "op:1". DOM order is NOT visual order.
#   link  anchors by EXACT text; beats hidden sidebar <button>Edit</button> controls that a text
#         search would grab first.
#   any   React UIs: clickable rows are plain <div>s a curated tag list never sees. Exact text,
#         smallest visible match, so you get the row and not its container.
#   sel   raw CSS selector.
#   text  first curated-tag element whose text CONTAINS the value. Substring, so risky on admin
#         pages ("Lock" matches "Blocks"). Prefer link/any/exact for short words.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

CDP="http://127.0.0.1:${CDP_PORT}"
HANDS="${CDIR}/hands.sh"
AB() { ddev exec agent-browser --cdp "$CDP" "$@"; }

js_box_name='(()=>{const el=document.getElementsByName("__V__")[0];if(!el)return "NONE";const r=el.getBoundingClientRect();return Math.round(r.x+r.width/2)+" "+Math.round(r.y+r.height/2)})()'
js_box_sel='(()=>{const el=document.querySelector("__V__");if(!el)return "NONE";const r=el.getBoundingClientRect();return Math.round(r.x+r.width/2)+" "+Math.round(r.y+r.height/2)})()'
js_box_text='(()=>{const t="__V__".toLowerCase();const els=[...document.querySelectorAll("a,button,label,summary,input[type=submit],input[type=button],h2,h3,td,th,strong,legend,li")];const el=els.find(e=>(e.innerText||e.value||"").trim().toLowerCase().includes(t)&&e.getBoundingClientRect().width>0);if(!el)return "NONE";const r=el.getBoundingClientRect();return Math.round(r.x+r.width/2)+" "+Math.round(r.y+r.height/2)})()'

# Drupal gives every submit button on a form name="op", so "Test Connection" and "Save"
# collide. Index into getElementsByName instead: no quotes, so nothing to mangle.
js_box_nth='(()=>{const el=document.getElementsByName("__N__")[__V__];if(!el)return "NONE";const r=el.getBoundingClientRect();return Math.round(r.x+r.width/2)+" "+Math.round(r.y+r.height/2)})()'

# Any element, exact trimmed text, smallest visible match. React UIs render clickable rows as
# plain divs, which the curated-tag matcher above never sees. Smallest-area wins so we get the
# row itself rather than the panel that contains it.
js_box_any='(()=>{const t="__V__".toLowerCase();let best=null,ba=1e12;for(const e of document.querySelectorAll("*")){const tx=(e.textContent||"").trim().toLowerCase();if(tx!==t)continue;const r=e.getBoundingClientRect();if(r.width<=0||r.height<=0)continue;const a=r.width*r.height;if(a<ba){ba=a;best=r}}if(!best)return "NONE";return Math.round(best.x+best.width/2)+" "+Math.round(best.y+best.height/2)})()'

# Anchors only, exact text. Drupal admin pages have hidden <button>Edit</button> controls in
# the sidebar that beat a real "Edit" operations link on a text search.
js_box_link='(()=>{const t="__V__".toLowerCase();const el=[...document.querySelectorAll("a")].find(a=>a.textContent.trim().toLowerCase()===t&&a.getBoundingClientRect().width>0);if(!el)return "NONE";const r=el.getBoundingClientRect();return Math.round(r.x+r.width/2)+" "+Math.round(r.y+r.height/2)})()'

box() {
  local kind="$1" val="$2" js
  case "$kind" in
    any)  js="${js_box_any/__V__/$val}" ;;
    link) js="${js_box_link/__V__/$val}" ;;
    name) js="${js_box_name/__V__/$val}" ;;
    sel)  js="${js_box_sel/__V__/$val}" ;;
    text) js="${js_box_text/__V__/$val}" ;;
    nth)  js="${js_box_nth/__N__/${val%%:*}}"; js="${js/__V__/${val##*:}}" ;;
    *) echo "NONE"; return 1 ;;
  esac
  # Single quotes only inside the JS; wrap the whole call for the container shell.
  js="${js//\"/\'}"
  ddev exec bash -lc "agent-browser --cdp $CDP eval \"$js\"" 2>/dev/null | tr -d '"\r' | tail -1
}

# A click below y=1000 (or above y=80) lands outside the 1080 viewport and silently does
# nothing - the beat still records, the form just never submits. Scroll the target into the
# middle of the screen first, then re-measure.
ensure_visible() {
  local kind="$1" val="$2" cx cy
  read -r cx cy <<<"$(box "$kind" "$val")"
  [ "${cx:-NONE}" = "NONE" ] && { echo "NONE"; return; }
  if [ "$cy" -gt 1000 ] || [ "$cy" -lt 80 ]; then
    local d=$((cy - 540))
    # agent-browser has no negative scroll: a target above the fold needs "scroll up N".
    if [ "$d" -lt 0 ]; then AB scroll up "$(( -d ))" >/dev/null 2>&1; else AB scroll down "$d" >/dev/null 2>&1; fi
    sleep 1.1
    read -r cx cy <<<"$(box "$kind" "$val")"
  fi
  echo "$cx $cy"
}

case "${1:-}" in
  open) AB open "$2" >/dev/null 2>&1; ;;
  box)  box "$2" "$3" ;;
  vbox) ensure_visible "$2" "$3" ;;
  click)
    read -r cx cy <<<"$(ensure_visible "$2" "$3")"
    [ "${cx:-NONE}" = "NONE" ] && { echo "ERROR: element not found ($2 $3)" >&2; exit 1; }
    # 0,0 means the element exists but is hidden (#states) or has no box. Moving there
    # throws the cursor into the top-left corner on camera, so refuse.
    [ "$cx" = "0" ] && [ "$cy" = "0" ] && { echo "ERROR: element hidden / zero box ($2 $3)" >&2; exit 1; }
    ddev exec DISPLAY="$DISPLAY_NUM" bash "$HANDS" move "$cx" "$cy" >/dev/null 2>&1
    sleep 0.35
    ddev exec DISPLAY="$DISPLAY_NUM" bash "$HANDS" click >/dev/null 2>&1
    echo "clicked $3 at $cx,$cy"
    ;;
  move)
    read -r cx cy <<<"$(ensure_visible "$2" "$3")"
    [ "${cx:-NONE}" = "NONE" ] && { echo "ERROR: element not found ($2 $3)" >&2; exit 1; }
    [ "$cx" = "0" ] && [ "$cy" = "0" ] && { echo "ERROR: element hidden / zero box ($2 $3)" >&2; exit 1; }
    ddev exec DISPLAY="$DISPLAY_NUM" bash "$HANDS" move "$cx" "$cy" >/dev/null 2>&1
    echo "moved to $3 at $cx,$cy"
    ;;
  paste)
    # Long text key-by-key is a multi-minute beat. Set .value and fire the events Drupal core
    # listens for. Base64 in, atob in the page, so no quoting has to survive ddev exec. (React
    # controlled inputs ignore this - use the native setter + dispatch; see SKILL.md.)
    P64="$(printf %s "$3" | base64 -w0)"
    PJS="(()=>{const el=document.getElementsByName('$2')[0];if(!el)return 'NONE';el.focus();el.value=atob('$P64');el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));return el.value.length})()"
    ddev exec bash -lc "agent-browser --cdp $CDP eval \"$PJS\"" 2>/dev/null | tr -d '"\r' | tail -1
    ;;
  type)
    B64="$(printf %s "$2" | base64 -w0)"
    ddev exec DISPLAY="$DISPLAY_NUM" bash "$HANDS" type64 "$B64" >/dev/null 2>&1
    echo "typed ${#2} chars"
    ;;
  key)
    ddev exec DISPLAY="$DISPLAY_NUM" bash "$HANDS" key "$2" >/dev/null 2>&1
    echo "key $2"
    ;;
  rec)
    "$HERE/record-beat.sh" "$2" "$3" >/dev/null
    echo "rec $2 $3"
    ;;
  shot)
    AB screenshot "$2" >/dev/null 2>&1; echo "shot $2"
    ;;
  *) echo "usage: see header" >&2; exit 1 ;;
esac
