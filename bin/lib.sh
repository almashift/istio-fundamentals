#!/usr/bin/env bash
# Shared helpers for the `lab` runner and every lab's check.sh.
if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  CLEAR=$'\r\033[K'   # wipes a progress note so the result replaces it
else
  GREEN=""; RED=""; YELLOW=""; CYAN=""; BOLD=""; DIM=""; RESET=""; CLEAR=""
fi
PASS_COUNT=0
FAIL_COUNT=0

die()     { echo "${RED}error:${RESET} $*" >&2; exit 1; }
warn()    { echo "${YELLOW}warn:${RESET} $*" >&2; }
info()    { echo "${BOLD}$*${RESET}"; }
section() { echo; echo "${BOLD}$*${RESET}"; }
ok()      { echo "${CLEAR}  ${GREEN}✔${RESET} $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
bad()     { echo "${CLEAR}  ${RED}✘${RESET} $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
# note "message" -> progress line during a slow step; in a terminal the next ok/bad replaces it
note() {
  if [ -n "$CLEAR" ]; then printf '%s  %s%s...%s' "$CLEAR" "$DIM" "$*" "$RESET"; else echo "  $*..."; fi
}

# render_md file -> prints a task, hint or solution readably in a terminal: headings in bold,
# code blocks indented in cyan, `code` in cyan, **bold** in bold, *italics* and other
# Markdown markers dropped.
render_md() {
  awk -v B="$BOLD" -v C="$CYAN" -v R="$RESET" '
    /^```/   { code = !code; next }
    code     { print "    " C $0 R; next }
    /^#+ /   { sub(/^#+ /, ""); print B $0 R; next }
    {
      line = $0; n = 0
      if (match(line, /^ *- /)) line = substr(line, 1, RLENGTH - 2) "• " substr(line, RLENGTH + 1)
      # Park `code` spans behind placeholders, so a * inside code is never read as emphasis.
      while (match(line, /`[^`]+`/)) {
        codes[++n] = substr(line, RSTART + 1, RLENGTH - 2)
        line = substr(line, 1, RSTART - 1) "\001" n "\002" substr(line, RSTART + RLENGTH)
      }
      while (match(line, /\*\*[^*]+\*\*/))  line = substr(line, 1, RSTART - 1) B substr(line, RSTART + 2, RLENGTH - 4) R substr(line, RSTART + RLENGTH)
      while (match(line, /\*[^* ][^*]*\*/)) line = substr(line, 1, RSTART - 1) substr(line, RSTART + 1, RLENGTH - 2) substr(line, RSTART + RLENGTH)
      for (i = 1; i <= n; i++) {
        p = "\001" i "\002"; j = index(line, p)
        line = substr(line, 1, j - 1) C codes[i] R substr(line, j + length(p))
      }
      print line
    }' "$1"
}

# check "description" command [args...]   -> pass if the command exits 0
check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

# summary -> prints the verdict; returns non-zero if anything failed
summary() {
  echo
  if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "${GREEN}${BOLD}PASS${RESET} - all ${PASS_COUNT} checks passed"
    return 0
  fi
  echo "${RED}${BOLD}FAIL${RESET} - ${FAIL_COUNT} failed, ${PASS_COUNT} passed"
  return 1
}
