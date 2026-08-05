# ---------------------------------------------------------------------------
# core — shared helpers: die, need_cmd, emit_json, pos_int, spinner, options
# ---------------------------------------------------------------------------

die() {
  printf '%s: %s\n' "$PROG" "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "requires '$1', install it and try again"
}

# print raw API body on --json, then stop (used by every command)
emit_json() {
  if (( opt_json )); then
    printf '%s\n' "$1"
    return 0
  fi
  return 1
}

pos_int() { # pos_int <value> <flag-name>
  [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--$2 must be a positive integer, got '$1'"
}

# spinner_run <message> <command...> — runs <command> with an animated
# spinner on stderr while it works, then replays the command's own stderr
# (errors, setup hints) and stdout. Returns the command's rc.
#
# The animation only runs when stderr is a terminal ([[ -t 2 ]]) — piped or
# captured output gets zero spinner noise. When it does animate, every
# frame first erases the line (\r\033[2K), so cycling to a shorter status
# text can never leave a tail of the original message on screen.
#
# The animation is a tiny braille "orb" (10 frames, one full turn, reads
# like a spinning globe) and the status text rotates every ~1.5 s:
# <message> → "thinking..." → "working..." → "answering in a sec..." →
# "wait, novrix is analyzing in depth...". The longer a call takes, the
# more texts it cycles through, so a slow AI answer always looks alive.
spinner_run() {
  local msg="$1"; shift
  local out err pid rc
  out="$(mktemp "${TMPDIR:-/tmp}/$PROG-spin-XXXXXX")" || die "mktemp failed"
  err="$(mktemp "${TMPDIR:-/tmp}/$PROG-spin-XXXXXX")" || die "mktemp failed"
  "$@" >"$out" 2>"$err" &
  pid=$!
  if [[ -t 2 ]]; then
    _spinner_animate "$msg" "$pid"
  fi
  if wait "$pid" 2>/dev/null; then rc=0; else rc=$?; fi
  # replay anything the command wrote to stderr (errors, setup hints)
  if [[ -s "$err" ]]; then cat "$err" >&2; fi
  cat "$out"
  rm -f "$out" "$err"
  return "$rc"
}

# _spinner_animate <message> <pid> — draws the spinner frames on stderr
# while <pid> is alive. Separate from spinner_run so the smoke suite can
# exercise the animation logic directly. Every frame erases the line first
# (\r\033[2K) so a shorter status text never leaves a tail of the message
# visible — "reading techleaks..." followed by "working..." must not show
# the leftover "techleaks..." text. Always clears the line at the end.
_spinner_animate() {
  local msg="$1" pid="$2" max="${3:-0}"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local statuses=("$msg" 'thinking...' 'working...' 'answering in a sec...' 'wait, novrix is analyzing in depth...')
  local si=0 i=0 t=0
  printf '\r\033[2K%s %s' "$msg" "${frames[0]}" >&2
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r\033[2K%s %s' "${statuses[si]}" "${frames[i]}" >&2
    i=$(( (i + 1) % ${#frames[@]} ))
    t=$(( t + 1 ))
    if (( t % 15 == 0 )); then
      si=$(( (si + 1) % ${#statuses[@]} ))
    fi
    if (( max > 0 && t >= max )); then break; fi
    sleep 0.1
  done
  printf '\r\033[2K' >&2
}

# age of a file in minutes — portable across GNU stat, BSD/macOS stat,
# and busybox stat. Prints an integer; 0 when the file is missing.
file_age_min() {
  local f="$1" now age
  now="$(date +%s 2>/dev/null || echo 0)"
  [[ -f "$f" ]] || { echo 0; return 0; }
  if stat -c %Y "$f" >/dev/null 2>&1; then
    age=$(( now - $(stat -c %Y "$f") ))
  elif stat -f %m "$f" >/dev/null 2>&1; then
    age=$(( now - $(stat -f %m "$f") ))
  else
    age=0
  fi
  (( age < 0 )) && age=0
  echo $(( age / 60 ))
}

parse_opts() {
  local a
  opt_json=0; opt_fresh=0; opt_days=""; opt_top=""; opt_months=""
  while [[ $# -gt 0 ]]; do
    a="$1"
    case "$a" in
      --json)        opt_json=1; shift ;;
      --fresh)       opt_fresh=1; shift ;;
      --days)        [[ $# -ge 2 ]] || die "--days needs a number"; opt_days="$2"; shift 2 ;;
      --days=*)      opt_days="${a#*=}"; shift ;;
      --top)         [[ $# -ge 2 ]] || die "--top needs a number"; opt_top="$2"; shift 2 ;;
      --top=*)       opt_top="${a#*=}"; shift ;;
      --months)      [[ $# -ge 2 ]] || die "--months needs a number"; opt_months="$2"; shift 2 ;;
      --months=*)    opt_months="${a#*=}"; shift ;;
      -h|--help)     usage; exit 0 ;;
      --version)     print_version; exit 0 ;;
      *)             die "unknown option: $a" ;;
    esac
  done
}
