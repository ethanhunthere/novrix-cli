# ---------------------------------------------------------------------------
# typo — the friendly layer. First the troll easter egg (roast instead of
# resolve), then offline Levenshtein fuzzy matching, then the AI agent on
# the full phrase so novrix NEVER says "unknown command".
# ---------------------------------------------------------------------------

# edit distance (Levenshtein) via awk — POSIX, no extra deps
edit_dist() { # $1 $2 → prints the distance
  awk -v a="$1" -v b="$2" 'BEGIN{
    m=length(a); n=length(b)
    for (i=0;i<=m;i++) d[i,0]=i
    for (j=0;j<=n;j++) d[0,j]=j
    for (i=1;i<=m;i++) for (j=1;j<=n;j++){
      c=(substr(a,i,1)==substr(b,j,1))?0:1
      x=d[i-1,j]+1; y=d[i,j-1]+1; z=d[i-1,j-1]+c
      d[i,j]=(x<y?x:y)<z?(x<y?x:y):z
    }
    print d[m,n]
  }'
}

# best local guess for a mistyped command; prints "" when unsure
fuzzy_match() {
  local word
  word="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  [[ -n "$word" ]] || return 0
  local maxd=$(( ${#word} / 3 + 1 ))
  local best="" bestd=999 name d
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    d="$(edit_dist "$word" "$name")"
    if (( d < bestd )); then bestd=$d; best="$name"; fi
  done < <(known_commands)
  # reject self-matches (would loop forever) and matches too far apart —
  # e.g. 'fear' is 2 edits from 'clear' but only 4 chars, so it must fall
  # through to the AI instead of "fixing" fear → clear.
  if (( bestd <= maxd && bestd * 3 <= ${#word} )) && [[ "$best" != "$word" ]]; then
    printf '%s\n' "$best"
  fi
}

# troll easter egg — roast the user instead of resolving their input.
# Returns 0 when it roasted (nothing more to do), 1 to fall through.
troll() {
  local w phrase
  phrase="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  # politics and people — troll instead of answering, unless crypto-adjacent
  case "$phrase" in
    *putin*|*trump*|*biden*|*zelensky*)
      case "$phrase" in
        *btc*|*bitcoin*|*crypto*|*price*|*market*|*macro*|*economy*|*gold*|*oil*|*etf*|*tvl*|*mvrv*|*sentiment*|*fed*)
          : ;;   # crypto-adjacent — let data handling take it
        *)
          printf '%s: lol politics? i only track the chain, that aint my lane. try "fg" or "mvrv".\n' "$PROG" >&2
          return 0 ;;
      esac ;;
  esac
  w="${phrase%% *}"
  case "$w" in
    f*cking|f*ckin)
      printf '%s: you fucking retard 😂 "%s" aint a command. if you meant "funding", type "funding". go on, i dare you.\n' "$PROG" "$1" >&2
      return 0 ;;
    f*ck)
      printf '%s: watch your language lol, family CLI here 😤 type "help" and pretend you can read.\n' "$PROG" >&2
      return 0 ;;
    wtf|wth|damn|shit|fuckit)
      printf '%s: chill lol, "help" is right there. breathe. 😏\n' "$PROG" >&2
      return 0 ;;
    stupid|dumb|idiot|moron)
      printf '%s: calling the CLI names wont make the data come faster 😌 try "fg" or "mvrv", those actually work.\n' "$PROG" >&2
      return 0 ;;
  esac
  return 1
}

# resolve a mistyped command: local fuzzy on the first word first (instant,
# offline), then the AI agent on the full phrase — with a "hold on..." spinner
# while the model works. Exits: 0 = fixed (prints the command), 1 = nothing
# matched (caller should ask the user), 2 = the AI itself failed (reason was
# already printed to stderr, so stay quiet)
resolve_typo() {
  local word="$1" phrase="${2:-$1}" fixed list ans rc
  fixed="$(fuzzy_match "$word")"
  [[ -n "$fixed" ]] && { printf '%s\n' "$fixed"; return 0; }
  list="$(known_commands | tr '\n' ' ')"
  ans="$(spinner_run "wtf is \"$phrase\"? hold on..." ai_chat \
    "Figure out what command the user meant. The input could be a typo, garble, or plain english (like 'mvrvv' -> mvrv, 'fgredd' -> fg, 'fear and greed index' -> fg, 'bitcoin price' -> btc-price, 'prctls' -> prots). Reply with ONLY one exact command name from the list, or exactly UNKNOWN if it aint about any command. Nothing else." \
    "Commands: $list
User typed: $phrase" 30 ai_matcher)"
  rc=$?
  [[ "$rc" -ne 0 ]] && return 2
  ans="$(printf '%s' "$ans" | tr -d '[:space:]' | sed 's/[.,;:!?]*$//')"
  [[ -n "$ans" && "$ans" != "UNKNOWN" && "$ans" != "unknown" ]] || return 1
  ans="$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')"
  ans="${ALIASES[$ans]:-$ans}"
  # exact hit — as long as it isn't just echoing the input back
  if known_commands | grep -qx "$ans"; then
    [[ "$ans" == "$word" ]] && return 1
    printf '%s\n' "$ans"
    return 0
  fi
  # AI was close but not exact — let the local matcher finish the job
  fixed="$(fuzzy_match "$ans")"
  if [[ -n "$fixed" && "$fixed" != "$word" ]]; then
    printf '%s\n' "$fixed"
    return 0
  fi
  return 1
}
