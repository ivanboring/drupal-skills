# SLOC counter: counts source lines (non-blank, non-comment) across the files
# passed as arguments. Block-comment state resets per file (FNR==1).
#
# Parameters (set with -v):
#   bopen, bclose  block comment delimiters (e.g. "/*" "*/", "{#" "#}"); empty bopen disables
#   lc1, lc2       line comment tokens (e.g. "//"); empty disables
#
# This is a heuristic, not a parser. It does not understand strings, so a
# comment token inside a quoted string is still treated as a comment. In
# practice that only ever truncates a line that already counts as code, so the
# line total is barely affected. Comment-only lines are what get removed.

BEGIN { total = 0 }
FNR == 1 { inblock = 0 }
{
  code = strip($0)
  gsub(/^[ \t\r]+|[ \t\r]+$/, "", code)
  if (length(code) > 0) total++
}
END { print total + 0 }

function strip(s,   out, bpos, lpos, l1, l2, rest, r) {
  out = ""
  while (length(s) > 0) {
    if (inblock) {
      if (bclose == "") return out
      r = index(s, bclose)
      if (r == 0) return out
      s = substr(s, r + length(bclose))
      inblock = 0
      continue
    }
    bpos = (bopen != "") ? index(s, bopen) : 0
    lpos = 0
    if (lc1 != "") { l1 = index(s, lc1); if (l1 > 0 && (lpos == 0 || l1 < lpos)) lpos = l1 }
    if (lc2 != "") { l2 = index(s, lc2); if (l2 > 0 && (lpos == 0 || l2 < lpos)) lpos = l2 }
    if (lpos > 0 && (bpos == 0 || lpos < bpos)) {
      out = out substr(s, 1, lpos - 1)
      break
    }
    if (bpos > 0) {
      out = out substr(s, 1, bpos - 1)
      rest = substr(s, bpos + length(bopen))
      r = index(rest, bclose)
      if (r == 0) { inblock = 1; break }
      s = substr(rest, r + length(bclose))
      continue
    }
    out = out s
    break
  }
  return out
}
