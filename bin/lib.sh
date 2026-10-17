#!/usr/bin/env bash
# Shared helpers for the `lab` runner and every lab's check.sh.
if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  CLEAR=$'\r\033[K'   # wipes a progress note so the result replaces it
else
  GREEN=""; RED=""; YELLOW=""; BOLD=""; DIM=""; RESET=""; CLEAR=""
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
