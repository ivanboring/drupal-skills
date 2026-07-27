#!/usr/bin/env bash
# Save or restore a ddev database snapshot, so you can record one state, then reset and
# record the next state from the same starting point. Run from the ddev project root with
# MT_MODULE and MT_MR set.
#   ./snapshot.sh save baseline      # after reproducing the issue on the current code
#   ./snapshot.sh restore baseline   # reset before recording the fix / missing pieces
#   ./snapshot.sh list
#
# Note: `ddev snapshot` captures the DATABASE only, not the files directory. If your test
# changes uploaded files, snapshot/restore will not revert those.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

cmd="${1:?usage: snapshot.sh save|restore|list <label>}"
# Namespace snapshots by module-mr so parallel tests do not collide.
name() { echo "mt-${OUT}-${1:?snapshot label required}"; }

case "$cmd" in
  save)    ddev snapshot --name "$(name "${2:-}")" ;;
  restore) ddev snapshot restore "$(name "${2:-}")" ;;
  list)    ddev snapshot --list | grep "mt-${OUT}-" || echo "no snapshots for ${OUT}" ;;
  *) die "usage: snapshot.sh save|restore|list <label>" ;;
esac
