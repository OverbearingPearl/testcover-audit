#!/bin/sh
# Run the performance budgets. What is measured lives in ci/perf.el; the
# numbers live in the :perf table of ci/config.el. Without --report a budget
# that is over fails, which is what `make perf-check' runs; `make perf' passes
# --report and only prints the table.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$here/..")
emacs_bin=${EMACS:-emacs}

command -v "$emacs_bin" >/dev/null 2>&1 || {
  echo "emacs not found; install Emacs or set EMACS=/path/to/emacs" >&2
  exit 1
}

cd "$root"

# A template with the X's spelled out: BSD `mktemp -t NAME` treats NAME as a
# prefix and appends its own suffix, while GNU mktemp requires a template and
# fails with "too few X's".  The explicit form is the one both accept.
out=$(mktemp "${TMPDIR:-/tmp}/perf-out.XXXXXX")
status=$(mktemp "${TMPDIR:-/tmp}/perf-status.XXXXXX")
# Emacs's own complaints.  They used to go to /dev/null with everything else,
# which is how a run that died says nothing and reports an exit status of "".
log=$(mktemp "${TMPDIR:-/tmp}/perf-log.XXXXXX")
trap 'rm -f "$out" "$status" "$log"' EXIT

eval_form="(p/perf-main-or-die command-line-args-left)"

run_batch() {
  PERF_OUT="$out" PERF_STATUS="$status" PERF_TTY=0 \
    "$emacs_bin" -Q --batch -l "$here/config.el" -l "$here/perf.el" \
    --eval "$eval_form" -- "$@" >/dev/null 2>>"$log" || true
}

# Redisplay paints nothing in batch mode, so the redisplay benchmarks need a
# terminal. `script' is the portable way to hand one over, but its argument
# order differs between the BSD and GNU versions, so both are spelled out, and
# a run that produces no table falls back to batch mode where those two
# benchmarks report skip instead of losing the whole report.
# A terminal type has to be spelled out: CI sometimes runs with TERM=dumb,
# and Emacs refuses to paint on one of those.
run_tty() {
  TERM=${PERF_TERM:-xterm-256color}
  export TERM
  case $(uname -s) in
    Darwin)
      PERF_OUT="$out" PERF_STATUS="$status" PERF_TTY=1 script -q /dev/null \
        "$emacs_bin" -Q -nw -l "$here/config.el" -l "$here/perf.el" \
        --eval "$eval_form" -- "$@" >/dev/null 2>>"$log" || true
      ;;
    *)
      # `script -c' takes one string, so the command is assembled once and
      # run by the shell `script' starts.
      perf_cmd="'$emacs_bin' -Q -nw -l '$here/config.el' -l '$here/perf.el' --eval '$eval_form' -- $*"
      if command -v timeout >/dev/null 2>&1; then
        PERF_OUT="$out" PERF_STATUS="$status" PERF_TTY=1 \
          timeout 300 script -q -c "$perf_cmd" /dev/null \
            >/dev/null 2>>"$log" || true
      else
        PERF_OUT="$out" PERF_STATUS="$status" PERF_TTY=1 \
          script -q -c "$perf_cmd" /dev/null >/dev/null 2>>"$log" || true
      fi
      ;;
  esac
}

if command -v script >/dev/null 2>&1; then
  run_tty "$@"
fi

if [ ! -s "$out" ]; then
  run_batch "$@"
fi

cat "$out"

# No table is not a verdict: the run died before it had numbers to print, and
# whatever killed it is in the log.  Say so, and fail.
if [ ! -s "$out" ]; then
  echo "perf: no measurements were produced" >&2
  if [ -s "$log" ]; then
    cat "$log" >&2
  fi
  exit 1
fi

# mktemp creates the status file empty, and a run killed by the tty timeout
# leaves it that way.  `exit ""' is an "Illegal number" from the shell, which
# tells the reader nothing about the run; a missing verdict is a failure, not
# an invented pass.
rc=$(cat "$status" 2>/dev/null) || rc=
case $rc in
  ''|*[!0-9]*) rc=1 ;;
esac
exit "$rc"
