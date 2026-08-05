# ---------------------------------------------------------------------------
# cli — command dispatch, interactive REPL, and the entry point
# ---------------------------------------------------------------------------

# dispatch a single command line — shared by one-shot and interactive mode
run_command() {
  local cmd="${1:-}"
  local fixed="" phrase="" rc=0
  if (( $# > 0 )); then shift; fi

  # tolerate a leading binary name in one-shot mode: `novrix novrix ai hello`
  if [[ "$cmd" == "$PROG" ]]; then
    cmd="${1:-}"
    (( $# > 0 )) && shift
  fi

  # resolve short aliases (rr, btc, spx, dom, …) to canonical names first
  cmd="${ALIASES[$cmd]:-$cmd}"
  # commands are case-insensitive: MVRV, Fear, SPX all work
  cmd="$(printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]')"
  # drop punctuation a user might paste along with the command (ai,, fg.) —
  # keep a trailing ? so question detection still works on one-shot phrases
  while [[ "$cmd" == *[.,!] ]]; do
    cmd="${cmd%[.,!]}"
  done
  if [[ -z "$cmd" ]]; then usage; return 0; fi

  # a known command with a date or range in plain language ("nupl for 2014,
  # 15 january", "fg from 10 january to 20 january, 2022") → answer with the
  # exact historical data instead of running the command and ignoring the
  # extra words
  if [[ -n "$*" ]] && [[ "$*" != -* ]]; then
    local nphrase="$cmd${*:+ $*}"
    if ( extract_date "$nphrase" || extract_range "$nphrase" || extract_count "$nphrase" ) >/dev/null 2>&1 \
       && detect_data_series "$nphrase" >/dev/null 2>&1; then
      if answer_data_question "$nphrase"; then
        return 0
      fi
      # a known metric with a date/range, but the point is not in novrix
      # history (e.g. funding rate in 2014) → the agent explains instead of
      # the command choking on the extra words
      cmd_ai "$nphrase"
      return 0
    fi
  fi

  # a known command followed by natural language that is not options —
  # "spx looking good, what's it's price?" — answer with the exact latest
  # data, or hand the phrase to the AI agent, instead of option parsing
  # choking on the words ("unknown option: looking")
  if [[ -n "$*" ]]; then
    local arg ok=1
    for arg in "$@"; do [[ "$arg" != -* ]] || ok=0; done
    if (( ok )) && known_commands | grep -qx "$cmd"; then
      local nphrase="$cmd${*:+ $*}"
      if answer_data_question "$nphrase"; then
        return 0
      fi
      if looks_like_question "$nphrase" || looks_like_chat "$nphrase"; then
        cmd_ai "$nphrase"
        return 0
      fi
    fi
  fi

  case "$cmd" in
    macro)
      local sub="${1:-}"
      if (( $# > 0 )); then shift; fi
      case "$sub" in
        cpi) parse_opts "$@"; cmd_cpi ;;
        "")  die "missing subcommand, use '$PROG macro cpi'" ;;
        *)
          if looks_like_chat "$sub" || looks_like_question "$sub"; then
            cmd_ai "macro $sub${*:+ $*}"   # "macro guy" → the agent answers in persona
          else
            die "unknown macro '$sub', supported: cpi"
          fi
          ;;
      esac
      ;;
    -h|--help|help) usage ;;
    -v|--version|version) print_version ;;
    shortcuts|aliases|map) cmd_shortcuts ;;
    fg|fear-greed) parse_opts "$@"; cmd_fg ;;
    nupl) parse_opts "$@"; cmd_nupl ;;
    cpi) parse_opts "$@"; cmd_cpi ;;      # alias for 'macro cpi'
    tvl) parse_opts "$@"; cmd_tvl ;;
    defi|stablecoins|dex|fees|options|dominance|prices|oi) parse_opts "$@"; cmd_meta "$cmd" ;;
    market) parse_opts "$@"; cmd_market ;;
    protocols|bridges|lending) parse_opts "$@"; cmd_rank "$cmd" ;;
    ai|ask) cmd_ai "$@" ;;
    telegram|tg) cmd_telegram "$@" ;;
    clear) clear 2>/dev/null || true ;;
    *)
      if [[ -n "${SERIES[$cmd]:-}" ]]; then
        parse_opts "$@"; cmd_series "$cmd"
      else
        # mistyped? troll easter egg first, then the novrix channel's stance,
        # then exact data questions, then privacy-coin mentions (techleaks
        # analysis), then plain-language questions and casual chat to the AI
        # agent, then typo fixing
        phrase="$cmd${*:+ $*}"
        if troll "$phrase"; then
          :   # roasted — nothing to resolve
        elif answer_novrix_question "$phrase"; then
          :   # "what does novrix think about..." → the channel's own take
        elif answer_data_question "$phrase"; then
          :   # answered with exact novrix data — no AI needed
        elif answer_privacy_question "$phrase"; then
          :   # dero/monero/zcash... → techleaks analysis, no AI needed
        elif looks_like_question "$phrase"; then
          cmd_ai "$phrase"   # the agent answers, trolls off-topic stuff
        elif looks_like_chat "$phrase"; then
          cmd_ai "$phrase"   # casual chat — "hey", "macro guy" — it riffs back
        else
          fixed="$(resolve_typo "$cmd" "$phrase")" || rc=$?
          if (( rc == 0 )); then
            printf '%s: "%s"? you mean "%s". running it.\n' "$PROG" "$phrase" "$fixed" >&2
            if [[ "$phrase" == "$cmd" ]]; then
              run_command "$fixed" "$@"   # single word — keep flags like --top
            else
              run_command "$fixed"        # multi-word — trailing words were natural language
            fi
          elif (( rc == 1 )); then
            die "lol what even is \"$phrase\"? 😏 i got nothing on that. what did you mean? try '$PROG help' or ask '$PROG ai \"your question\"'."
          else
            exit 1   # rc == 2 → the AI agent already explained — stay quiet
          fi
        fi
      fi
      ;;
  esac
}

# interactive mode: bare `novrix` drops you into a REPL
interactive() {
  local line last_q=""
  printf '%s%s %s%s, interactive mode. type a command and hit enter.\n' \
    "$c_bold" "$PROG" "$VERSION" "$c_reset"
  printf '\n'
  printf '  %s%-13s%s %s%s%s\n' "$c_bold" "sentiment" "$c_reset" "$c_dim" \
    "fg nupl mvrv sopr puell rhodl mayer rr rp rpf rpl mcap btc 200ma addrs hash scs btoi funding etf" "$c_reset"
  printf '  %s%-13s%s %s%s%s\n' "$c_bold" "macro:" "$c_reset" "$c_dim" \
    "cpi unrate gdp nfp claims jolts ccpi pce cpce umich oil t30 curve be dxy gold spx vix ffr m2" "$c_reset"
  printf '  %s%-13s%s %s%s%s\n' "$c_bold" "metrilytics" "$c_reset" "$c_dim" \
    "tvl defi mkt stables dex fees dom opts prots bridges lending prices oi" "$c_reset"
  printf '  %s%-13s%s %s%s%s\n' "$c_bold" "ai" "$c_reset" "$c_dim" \
    "ask anything, it answers with real data" "$c_reset"
  printf '  %s%-13s%s %s%s%s\n' "$c_bold" "telegram" "$c_reset" "$c_dim" \
    "what's new on crypto? - your latest chart text" "$c_reset"
  printf '  %s%-13s%s %s%s%s\n' "$c_bold" "system" "$c_reset" "$c_dim" \
    "shortcuts · help · clear · exit" "$c_reset"
  printf '  %s%-13s%s %s\n' "$c_dim" "tip:" "$c_reset" \
    "dates and ranges work anywhere - 'nupl for 2014, 15 january', 'last 10 days of fg'"
  printf '  %s%-13s%s %s\n' "$c_dim" "tip:" "$c_reset" \
    "follow-ups inherit the subject - ask 'what about btc price?' then 'for today?'"
  printf '\n'
  while true; do
    IFS= read -r -p "$c_green$PROG>$c_reset " -e line || { printf '\nbye\n'; return 0; }
    # trim surrounding whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    # tolerate a pasted binary name: `novrix ai ...` works right in the shell
    if [[ "$line" == "$PROG"* ]]; then
      line="${line#"$PROG"}"
      line="${line# }"
      if [[ -z "$line" ]]; then usage; continue; fi
    fi
    case "$line" in
      exit|quit|q) printf 'bye\n'; return 0 ;;
      help|h|\?) usage ;;
      clear) clear 2>/dev/null || true ;;
      *)
        # elliptical follow-ups ("for today?", "what about eth?") inherit the
        # previous question — without it the AI agent would have to guess
        # what they refer to and can invent numbers instead of real data.
        # Skip when the new line names a series itself (normal dispatch wins).
        if [[ -n "$last_q" ]] \
           && ! detect_data_series "$line" >/dev/null 2>&1 \
           && looks_like_followup "$line"; then
          line="$last_q $line"
        fi
        last_q="$line"
        # run in a subshell so a bad command doesn't kill the REPL
        # shellcheck disable=SC2086  # word splitting is the point: line -> argv
        ( run_command $line ) \
          || printf '%s: command failed, see "help"\n' "$PROG"
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# entry point
# ---------------------------------------------------------------------------
main() {
  need_cmd curl
  need_cmd jq

  # bare `novrix` → interactive shell; `novrix fg` etc. → one-shot
  if [[ $# -eq 0 ]]; then
    interactive
    return 0
  fi

  run_command "$@"
}

main "$@"
