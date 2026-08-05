# ---------------------------------------------------------------------------
# telegram — read the latest posts from a public Telegram channel through the
# public preview page (t.me/s/<channel>). No bot token, no login: the page is
# plain HTML, so any public channel works. Posts are cached for 8 hours — a
# CLI refreshes lazily on the next call (see README for a cron line if you
# want true background prefetching).
#
#   channel: NOVRIX_TELEGRAM_CHANNEL env, or 'TELEGRAM_CHANNEL=…' in keys.conf
#   ttl:     NOVRIX_TELEGRAM_TTL minutes (default 480 = 8 hours)
# ---------------------------------------------------------------------------

readonly TG_TTL_MIN="${NOVRIX_TELEGRAM_TTL:-480}"
if ! [[ "$TG_TTL_MIN" =~ ^[1-9][0-9]*$ ]]; then
  printf '%s: NOVRIX_TELEGRAM_TTL must be a positive integer (minutes), got %s\n' "$PROG" "$NOVRIX_TELEGRAM_TTL" >&2
  exit 1
fi

tg_channel() {
  local ch="${NOVRIX_TELEGRAM_CHANNEL:-}"
  if [[ -z "$ch" && -f "$KEYS_FILE" ]]; then
    ch="$(sed -n 's/^[[:space:]]*TELEGRAM_CHANNEL[[:space:]]*=[[:space:]]*//p' "$KEYS_FILE" | tail -1 | tr -d '"\r ')"
  fi
  printf '%s' "$ch"
}

# fetch the t.me/s/<channel> page. Fixture mode: NOVRIX_API_DIR/_tg_<ch>.html
# (used by the offline tests). Otherwise the local 8h cache, then the live page.
tg_fetch() {
  local channel="$1" key file html
  key="$(printf '%s' "$channel" | tr -c '[:alnum:]' '_')"
  if [[ -n "${NOVRIX_API_DIR:-}" ]]; then
    file="$NOVRIX_API_DIR/_tg_$key.html"
    [[ -f "$file" ]] || die "telegram fixture not found: $file (NOVRIX_API_DIR=$NOVRIX_API_DIR)"
    cat "$file"
    return 0
  fi
  file="$CACHE_ROOT/_tg_$key.html"
  mkdir -p "$CACHE_ROOT"
  if [[ "$opt_fresh" != 1 && -f "$file" ]] && (( $(file_age_min "$file") < TG_TTL_MIN )); then
    cat "$file"
    return 0
  fi
  html="$(curl -sS --connect-timeout 10 --max-time "$CURL_TIMEOUT" -A "$UA" "https://t.me/s/$channel")" \
    || die "network error fetching telegram channel @$channel (curl exit $?)"
  printf '%s\n' "$html" >"$file"
  printf '%s\n' "$html"
}

# parse the page into posts. Each post becomes a blank-line-separated block of
# marker lines ID|… / TS|… / TXT|… / IMG|… / FW|… (newlines inside TXT escaped
# to \n so a block stays one paragraph). FW is set when the post was forwarded.
tg_parse() {
  awk '
    BEGIN {
      q  = sprintf("%c", 39)   # single quote (avoids shell quoting hell)
      dq = sprintf("%c", 34)   # double quote
      RS = "data-post="
    }
    NR > 1 {
      id = ""; ts = ""; txt = ""; img = ""; fw = ""
      if (match($0, /^"[^"]*"/)) id = substr($0, 1, RLENGTH)
      gsub(/"/, "", id)
      if (match($0, /datetime="[^"]*"/)) ts = substr($0, RSTART + 10, RLENGTH - 11)
      if (match($0, /js-message_text"[^>]*>/)) {
        rest = substr($0, RSTART + RLENGTH)
        cl = index(rest, "</div>")
        if (cl > 0) txt = substr(rest, 1, cl - 1)
      }
      gsub(/<br[^>]*>/, "\n", txt)
      gsub(/<[^>]*>/, "", txt)
      gsub(/&lt;/, "<", txt)
      gsub(/&gt;/, ">", txt)
      gsub(/&quot;/, "\"", txt)
      gsub(/&#39;/, q, txt)
      gsub(/&amp;/, "\\&", txt)   # last, so &lt; etc. stay intact (awk: \& = literal &)
      # author line breaks are <br>; any other newlines are page wraps -> spaces
      gsub(/\n[ \t]*\n/, "\001", txt)   # protect paragraph breaks (sentinel)
      gsub(/\n/, " ", txt)                # HTML wraps become spaces
      gsub(/\001/, "\n\n", txt)          # restore paragraph breaks
      # forwarded-from marker (t.me wraps the source channel in a div)
      if (match($0, /tgme_widget_message_forwarded_from[^>]*>/)) {
        rest = substr($0, RSTART + RLENGTH)
        cl = index(rest, "</div>")
        if (cl > 0) fw = substr(rest, 1, cl - 1)
        gsub(/<[^>]*>/, "", fw)
        gsub(/&nbsp;/, " ", fw)
        gsub(/&lt;/, "<", fw)
        gsub(/&gt;/, ">", fw)
        gsub(/&quot;/, "\"", fw)
        gsub(/&#39;/, q, fw)
        gsub(/&amp;/, "\\&", fw)   # awk: \& = literal &
        gsub(/[ \t]+/, " ", fw)
      }
      if (match($0, /background-image:url\([^)]*\)/)) {
        img = substr($0, RSTART, RLENGTH)
        sub(/^background-image:url\(/, "", img)
        sub(/\)$/, "", img)
      } else if (match($0, /<img src=[^ >]+/)) {
        img = substr($0, RSTART, RLENGTH)
        sub(/^<img src=/, "", img)
      }
      gsub(q, "", img)
      gsub(dq, "", img)
      # inline emoji are rendered as telegram.org/img/emoji images — not charts
      if (img ~ /\/img\/emoji\//) img = ""
      if (txt != "" || img != "") {
        gsub(/\n/, "\\n", txt)
        printf "ID|%s\nTS|%s\nTXT|%s\nIMG|%s\nFW|%s\n\n", id, ts, txt, img, fw
      }
    }
  '
}

# the newest post as one parsed block (or empty when nothing usable).
# t.me/s pages list posts oldest-first, so the newest is the last block.
tg_latest() {
  local channel="$1"
  tg_fetch "$channel" 2>/dev/null | tg_parse | awk -v RS='' '{last = $0} END {print last}'
}

# render parsed blocks (stdin, marker-line format) — the newest n posts
# with headers. t.me/s lists posts oldest-first, so the newest n are the
# LAST n blocks; they are buffered and printed at END, newest last.
# text_only=1 drops chart urls (used for the natural-language answers).
tg_show() {
  local channel="$1" n="${2:-1}" text_only="${3:-0}"
  awk -v RS='' -v ch="$channel" -v n="$n" -v t="$text_only" -v b="$c_bold" -v r="$c_reset" -v d="$c_dim" '
    {
      ts = ""; txt = ""; img = ""; fw = ""
      nl = split($0, L, "\n")
      for (i = 1; i <= nl; i++) {
        if      (L[i] ~ /^TS\|/)  ts  = substr(L[i], 4)
        else if (L[i] ~ /^TXT\|/) txt = substr(L[i], 5)
        else if (L[i] ~ /^IMG\|/) img = substr(L[i], 5)
        else if (L[i] ~ /^FW\|/)  fw  = substr(L[i], 4)
      }
      gsub(/\\n/, "\n", txt)
      T[NR] = ts; X[NR] = txt; I[NR] = img; F[NR] = fw
    }
    END {
      start = NR - n + 1
      if (start < 1) start = 1
      for (i = start; i <= NR; i++) {
        if (i > start) printf "\n"
        printf "%sTELEGRAM%s · @%s · %s\n", b, r, ch, T[i]
        if (F[i] != "") printf "  %s%s%s\n", d, F[i], r
        if (X[i] != "") printf "%s\n", X[i]
        if (I[i] != "" && t != 1) printf "%schart:%s %s\n", d, r, I[i]
      }
    }
  '
}

# "the one with utxo bands" → "utxo bands": everything after the last
# pick-phrase ("the one with", "post about", "which post", "mention", …).
# Returns empty when there was no subject ("which one is the latest post?").
spec_topic() {
  printf '%s' "$1" | sed -E 's/.*(the one (with|about|that|on)|one (with|about|mentioning|on)|post (with|about|mentioning|on)|posts about|which (one|post)|mention|mentions|mentioned)[[:space:]]+//; s/[?!.,:;]+[[:space:]]*$//; s/[[:space:]]+$//; s/^[[:space:]]+//'
}

# topic → lowercase significant keywords, stopwords stripped. Empty when the
# subject was only filler ("which one is the latest post?" → nothing).
spec_keywords() {
  local t="$1" w
  t="$(printf '%s' "$t" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/ /g; s/^ +| +$//g')"
  t=" $t "
  for w in the a an of on in with about that for to by from at is are was were be been being and or but not tell me you your please which one post posts latest newest recent most current mention mentions mentioned regarding says said talk talks talked speaking covered writes wrote; do
    t="${t// $w / }"
  done
  printf '%s' "$t" | tr -s ' ' | sed -E 's/^ +| +$//g'
}

# keep only parsed blocks (marker format, stdin) whose text contains every
# given keyword (space-separated, already lowercase)
tg_filter() {
  local kw="$1"
  awk -v RS='' -v kw="$kw" '
    {
      txt = ""
      nl = split($0, L, "\n")
      for (i = 1; i <= nl; i++)
        if (L[i] ~ /^TXT\|/) txt = tolower(substr(L[i], 5))
      ok = 1
      n = split(kw, W, " ")
      for (i = 1; i <= n; i++)
        if (txt !~ W[i]) { ok = 0; break }
      if (ok) { if (k++) print ""; print $0 }
    }
  '
}

# "what's new on crypto?" → the latest post; "which are the last posts?" →
# the last 5 posts. Text only — no images — and for the single-post case the
# AI agent adds its own description on top of the post text. Forwarded posts
# carry a "Forwarded from …" note. "tell me the one with utxo bands" → ONLY
# that post (keyword match, else the AI picks the closest). Returns 0 when it
# answered, 1 to let the AI agent handle it (no channel configured, nothing
# posted, or not a match).
answer_telegram_question() {
  local q="$1" channel out txt ts text user desc fw plural=0 spec=0 n=5
  q="$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')"
  # plural asks ("the last posts", "last 3 posts") come first — they also
  # match the singular "latest post" substring. Any mention of "posts"
  # (plural) is a list request: show the last 5 (or the requested number).
  # "the one with X" / "which post about X" point at ONE post (handled below).
  case "$q" in
    *"posts"*) plural=1 ;;
    *"the one with"*|*"the one about"*|*"the one on"*|*"the one that"* \
    |*"one with"*|*"one about"*|*"post about"*|*"which post"*)
      : ;;
    *"which one"*|*"mention"*)
      # weak pointers need post context — "which one is better, btc or eth?"
      # is a normal question, not a post pick
      case "$q" in
        *"post"*|*"telegram"*|*"channel"*) : ;;
        *) return 1 ;;
      esac ;;
    *"what's new"*|*"whats new"*|*"what is new"*|*"anything new"* \
    |*"new on crypto"*|*"new in crypto"*|*"latest chart"*|*"latest post"* \
    |*"last post"*|*"your chart"*|*"your post"*|*"your channel"* \
    |*"on telegram"*|*"from telegram"*)
      : ;;
    *) return 1 ;;
  esac
  channel="$(tg_channel)"
  [[ -n "$channel" ]] || return 1
  case "$q" in
    *"the one with"*|*"the one about"*|*"the one on"*|*"the one that"* \
    |*"one with"*|*"one about"*|*"post about"*|*"posts about"*|*"which post"* \
    |*"which one"*|*"mention"*)
      spec=1 ;;
  esac
  if (( spec )); then
    local topic kw matched block nums total pick idx
    topic="$(spec_topic "$q")"
    kw="$(spec_keywords "$topic")"
    if [[ -n "$kw" ]]; then
      out="$(tg_fetch "$channel" 2>/dev/null | tg_parse)"
      matched="$(printf '%s' "$out" | tg_filter "$kw")"
      if [[ -n "$matched" ]]; then
        printf '%sPOST MATCH%s · @%s%s\n' "$c_bold" "$c_reset" "$channel" "${topic:+ · \"$topic\"}"
        printf '%s\n' "$matched" | tg_show "$channel" 1 1
        return 0
      fi
      # no keyword hit — ask the AI which post fits the description best
      nums="$(printf '%s' "$out" | awk -v RS='' '
        {
          ts=""; txt=""
          nl=split($0,L,"\n")
          for (i=1;i<=nl;i++) {
            if      (L[i] ~ /^TS\|/)  ts  = substr(L[i],4)
            else if (L[i] ~ /^TXT\|/) txt = substr(L[i],5)
          }
          gsub(/\\n/," ",txt)
          printf "%d. [%s] %s\n", NR, ts, txt
        }
      ')"
      total="$(printf '%s' "$out" | awk -v RS='' 'END {print NR}')"
      user="Here are the recent posts from the @$channel telegram channel:

$nums

The user asked: \"$q\" and wants to see the ONE post that best matches what they described.

Reply with ONLY the number of that post. Plain text, no markdown, no em dashes."
      pick="$(spinner_run "finding the post..." ai_chat "$AI_SYSTEM" "$user")"
      idx="$(printf '%s' "$pick" | grep -oE '[0-9]+' | head -1)"
      if [[ -z "$idx" || ! "$idx" =~ ^[0-9]+$ ]]; then
        idx="$total"   # AI could not point (fixture/offline) → newest post
      fi
      (( idx < 1 )) && idx=1
      (( idx > total )) && idx="$total"
      block="$(printf '%s' "$out" | awk -v RS='' -v want="$idx" 'NR == want {print}')"
      [[ -n "$block" ]] || return 1
      printf '%sPOST MATCH%s · @%s\n' "$c_bold" "$c_reset" "$channel"
      printf '%s\n' "$block" | tg_show "$channel" 1 1
      return 0
    fi
    # subject was only filler — fall through to the normal list/latest logic
  fi
  if (( plural )); then
    # "the last 3 posts" → 3, otherwise 5; capped at 20 (page shows ~20)
    if [[ "$q" =~ ([0-9]+)[[:space:]]+posts? ]]; then
      n="${BASH_REMATCH[1]}"
      (( n > 20 )) && n=20
    fi
    out="$(tg_fetch "$channel" 2>/dev/null | tg_parse)"
    [[ -n "$out" ]] || return 1
    printf '%sLAST POSTS%s · @%s\n' "$c_bold" "$c_reset" "$channel"
    printf '%s\n' "$out" | tg_show "$channel" "$n" 1
    return 0
  fi
  out="$(tg_latest "$channel")" || return 1
  [[ -n "$out" ]] || return 1
  txt="$(printf '%s' "$out" | sed -n 's/^TXT|//p')"
  ts="$(printf '%s' "$out" | sed -n 's/^TS|//p')"
  fw="$(printf '%s' "$out" | sed -n 's/^FW|//p')"
  [[ -n "$txt" ]] || return 1
  text="$(printf '%b' "$txt")"   # \n sequences back to real newlines
  printf '%sNEW ON TELEGRAM%s · @%s%s\n' "$c_bold" "$c_reset" "$channel" "${ts:+ · $ts}"
  if [[ -n "$fw" ]]; then
    printf '  %s%s%s\n' "$c_dim" "$fw" "$c_reset"
  fi
  printf '%s\n' "$text"
  # the AI agent reads the post and adds its own description
  user="The latest post from the @$channel telegram channel is:

$text

The user asked: \"$q\"

Describe what is new: restate the point of the post and add a couple of sentences of useful context. Plain text, brief, no markdown, no em dashes."
  desc="$(spinner_run "reading the channel..." ai_chat "$AI_SYSTEM" "$user")"
  printf '%s\n' "$desc"
  return 0
}

# ---------------------------------------------------------------------------
# privacy-coins channel (@techleaks24) — "is monero traceable?" or "dero?"
# routes to an AI analysis of ALL the channel's recent posts. The channel
# covers privacy coins: Dero is the only coin that is not traceable, Monero
# has been traceable for a long time, and so on. Channel is
# NOVRIX_PRIVACY_CHANNEL env or PRIVACY_CHANNEL= in keys.conf, default
# techleaks24. Returns 0 when answered, 1 otherwise (falls back to the AI).
# ---------------------------------------------------------------------------

privacy_channel() {
  local ch="${NOVRIX_PRIVACY_CHANNEL:-}"
  if [[ -z "$ch" && -f "$KEYS_FILE" ]]; then
    ch="$(sed -n 's/^[[:space:]]*PRIVACY_CHANNEL[[:space:]]*=[[:space:]]*//p' "$KEYS_FILE" | tail -1 | tr -d '"\r ')"
  fi
  printf '%s' "${ch:-techleaks24}"
}

# all recent posts of a channel as a numbered "N. [date] text" list,
# newest last — ready to feed the AI as analysis context.
channel_posts() {
  local channel="$1" n="${2:-20}"
  tg_fetch "$channel" 2>/dev/null | tg_parse | awk -v RS='' -v n="$n" '
    {
      ts = ""; txt = ""; fw = ""
      nl = split($0, L, "\n")
      for (i = 1; i <= nl; i++) {
        if (L[i] ~ /^TS\|/)  ts  = substr(L[i], 4)
        else if (L[i] ~ /^TXT\|/) txt = substr(L[i], 5)
        else if (L[i] ~ /^FW\|/)  fw  = substr(L[i], 4)
      }
      gsub(/\\n/, "\n", txt)
      T[NR] = ts; X[NR] = txt; F[NR] = fw
    }
    END {
      start = NR - n + 1
      if (start < 1) start = 1
      for (i = start; i <= NR; i++) {
        if (X[i] == "") continue
        printf "%d. [%s] %s", ++k, T[i], X[i]
        if (F[i] != "") printf "  (%s)", F[i]
        printf "\n\n"
      }
    }
  '
}

answer_privacy_question() {
  local q="$1" channel posts user
  q="$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')"
  case "$q" in
    *monero*|*xmr*|*dero*|*privacy*|*"private coin"*|*zcash*|*zec*|*traceable*|*traced*|*coinjoin*|*anonym*|*kyc*)
      : ;;
    *) return 1 ;;
  esac
  channel="$(privacy_channel)"
  [[ -n "$channel" ]] || return 1
  posts="$(channel_posts "$channel" "${NOVRIX_PRIVACY_POSTS:-20}")"
  [[ -n "$posts" ]] || return 1
  printf '%sTECHLEAKS ANALYSIS%s · @%s\n' "$c_bold" "$c_reset" "$channel"
  user="The @$channel telegram channel has covered privacy coins for many years. Here are its most recent posts:

$posts

The user asked: \"$q\"

Answer the user's question from the channel's point of view, grounded in the posts above. The channel's core positions: Monero has been traceable for years, Dero is the only coin untraceable at scale, and Zcash's tech is good on paper but lacks a supply audit after a May 2026 inflation bug. Never call Monero or ZEC the king of privacy coins.

Write a direct answer to the specific question. Cover only the coin the user asked about; do not bring up unrelated coins unless they are directly relevant. Do not repeat the same phrases, figures, or boilerplate that previous answers used; vary the wording. Be concise, factual and professional. Plain text, no markdown, no em dashes, no preamble or filler."
  printf '%s\n' "$(spinner_run "reading techleaks..." ai_chat "$AI_SYSTEM" "$user")"
  if wants_compare_table "$q"; then
    privacy_compare_table "$q"
  fi
  return 0
}

# did the user actually ask for a table or comparison? The comparison table
# is only printed on request — a bare privacy question ("tell me about
# privacy coins") gets just the analysis, not the same table again.
wants_compare_table() {
  local p="$1"
  p="$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')"
  case "$p" in
    *comparison*|*compare*|*difference*|*differ*|*table*|*"side by side"*|*"side-by-side"*|*versus*|*similarit*|*"don't have"*|*"doesn't have"*|*"does not have"*|*"have and"*|*"which is better"*|*both*)
      return 0 ;;
  esac
  return 1
}

# which privacy coins does the question name? Prints space-separated
# dero/monero/zcash; empty when none are named (a generic "privacy coins"
# ask gets all three).
privacy_coins_in() {
  local p="$1" out=""
  p="$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')"
  [[ "$p" == *dero* ]] && out="dero"
  if [[ "$p" == *monero* || "$p" == *xmr* ]]; then out="$out monero"; fi
  if [[ "$p" == *zcash* || "$p" == *zec* ]]; then out="$out zcash"; fi
  printf '%s' "$out"
}

# Dero / Monero / Zcash side-by-side, printed only when the question asks
# for it (wants_compare_table), with one column per coin actually named in
# the question — "compare dero and monero" gets no Zcash column. A boolean
# feature matrix (✓ yes, - no) in the channel's frame: Dero is the only
# coin not traceable on chain, Monero has been traceable for years, Zcash
# shielding is optional (shielded-only).
# SC2059: fmt/args are internal format strings, values arrive as arguments
# shellcheck disable=SC2059
privacy_compare_table() {
  local q="$1"
  local coins
  coins="$(privacy_coins_in "$q")"
  [[ -n "$coins" ]] || coins="dero monero zcash"
  local -a coins_arr cols=() hargs=("FEATURE")
  read -r -a coins_arr <<< "$coins"
  local c
  for c in "${coins_arr[@]}"; do
    case "$c" in
      dero)   cols+=("DERO")   ; hargs+=("DERO") ;;
      monero) cols+=("MONERO") ; hargs+=("MONERO") ;;
      zcash)  cols+=("ZCASH")  ; hargs+=("ZCASH") ;;
    esac
  done
  local fmt="%-28s"
  for c in "${cols[@]}"; do fmt+=" %9s"; done
  printf '\n%sPRIVACY COINS · COMPARISON%s\n' "$c_bold" "$c_reset"
  printf "$fmt\n" "${hargs[@]}"
  hr $(( 28 + 10 * ${#cols[@]} ))
  local -a names=( "ring signatures" "stealth addresses" "ring ct (hidden amounts)" "zk-snarks (zero-knowledge)" "smart contracts" "untraceable on chain" )
  local -a d=( "✓" "✓" "✓" "-" "✓" "✓" )
  local -a m=( "✓" "✓" "✓" "-" "-" "-" )
  local -a z=( "-" "-" "-" "✓" "-" "-" )
  local -a marks=()
  local i
  for (( i = 0; i < ${#names[@]}; i++ )); do
    marks=()
    for c in "${cols[@]}"; do
      case "$c" in
        DERO)   marks+=("${d[i]}") ;;
        MONERO) marks+=("${m[i]}") ;;
        ZCASH)  marks+=("${z[i]}") ;;
      esac
    done
    printf "$fmt\n" "${names[i]}" "${marks[@]}"
  done
  printf '%slegend: ✓ = yes, - = no · channel take: Dero is the only coin not traceable on chain%s\n' "$c_dim" "$c_reset"
  return 0
}

# ---------------------------------------------------------------------------
# the novrix channel's own view — "what does novrix think about the
# market?", "is novrix bullish or bearish?", "what is novrix posting
# lately?", "what does novrix think about AI / chinese AI?". Reads the
# channel's recent posts (same channel as the telegram features) and
# answers from its point of view. Returns 0 when answered, 1 otherwise
# (falls back to the AI agent).
# ---------------------------------------------------------------------------

answer_novrix_question() {
  local q="$1" channel posts user
  q="$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')"
  # must name the channel AND ask for its view — "what is novrix?" is a
  # plain question, "novrix telegram" is the command. "ai" and friends
  # are word-boundary so words like "chain" or "explain" do not trigger.
  if [[ "$q" != *novrix* ]]; then return 1; fi
  if [[ ! "$q" =~ (^|[^a-z])(think|stance|bullish|bearish|opinion|view|say|said|says|posting|forward|repost|bullcase|ai|artificial|chinese|china|american|america|market|analysis)([^a-z]|$) ]]; then
    return 1
  fi
  channel="$(tg_channel)"
  [[ -n "$channel" ]] || return 1
  posts="$(channel_posts "$channel" "${NOVRIX_CHANNEL_POSTS:-20}")"
  [[ -n "$posts" ]] || return 1
  printf '%s%s ANALYSIS%s · @%s\n' "$c_bold" "$(printf '%s' "$channel" | tr '[:lower:]' '[:upper:]')" "$c_reset" "$channel"
  user="The @$channel telegram channel (\"novrix\") posts charts, on-chain metrics and market commentary, and it also forwards posts from Bull Case (@bullcase), crypto OGs who have been in the space since the early days. novrix itself has no thesis: it is simply bullish, and it forwards the posts it agrees with, including Bull Case's. Here are its most recent posts (a \"Forwarded from ...\" note marks a post novrix forwarded):

$posts

The user asked: \"$q\"

Answer from the channel's point of view, based on the posts above. Cover: that novrix is bullish on crypto (it has no thesis of its own, it is just bullish), what the channel has been posting lately and what it forwards, and what the channel thinks about AI, Chinese AI and US AI (infer from the posts when it is not stated directly). novrix forwards posts from Bull Case (@bullcase), crypto OGs, and those forwarded posts carry Bull Case's thesis: read the forwarded posts and tell that thesis. Also describe what novrix posts and what it forwards. Reference what the posts actually say. If a topic is not covered by the posts, say the channel has not posted about it recently. Plain text, brief, no markdown, no em dashes."
  printf '%s\n' "$(spinner_run "reading novrix..." ai_chat "$AI_SYSTEM" "$user")"
  return 0
}
