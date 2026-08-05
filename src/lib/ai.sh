# ---------------------------------------------------------------------------
# ai — the DeepSeek-powered AI agent: `novrix ai "…"` plus automatic
# typo resolution. Uses an offline fixture in tests (NOVRIX_API_DIR).
# ---------------------------------------------------------------------------
ai_key() {
  local key="${DEEPSEEK_API_KEY:-}"
  if [[ -z "$key" && -f "$KEYS_FILE" ]]; then
    key="$(sed -n 's/^[[:space:]]*DEEPSEEK_API_KEY[[:space:]]*=[[:space:]]*//p' "$KEYS_FILE" | tail -1 | tr -d '"\r ')"
  fi
  printf '%s' "$key"
}

# one DeepSeek chat call — $1 system, $2 user, $3 max_tokens, $4 fixture name
ai_chat() {
  local sys="$1" user="$2" mt="${3:-400}" fix="${4:-ai_chat}"
  if [[ -n "${NOVRIX_API_DIR:-}" ]]; then
    local file="$NOVRIX_API_DIR/${NOVRIX_AI_FIXTURE:-$fix}.json"
    [[ -f "$file" ]] || die "AI fixture not found: $file (NOVRIX_API_DIR=$NOVRIX_API_DIR)"
    jq -r '.choices[0].message.content // ""' "$file"
    return 0
  fi
  local key payload resp
  key="$(ai_key)"
  [[ -n "$key" ]] || die "no DeepSeek API key. export DEEPSEEK_API_KEY or run: printf 'DEEPSEEK_API_KEY=sk-...\n' > ~/.config/novrix/keys.conf"
  payload="$(jq -cn --arg s "$sys" --arg u "$user" \
    '{model:"deepseek-chat", messages:[{role:"system",content:$s},{role:"user",content:$u}], temperature:0, max_tokens:'"$mt"'}')"
  resp="$(curl -sS --connect-timeout 10 --max-time "$CURL_TIMEOUT" \
    -H "Authorization: Bearer $key" -H "Content-Type: application/json" \
    --data "$payload" "$DEEPSEEK_BASE/chat/completions")" \
    || die "network error (curl exit $?)"
  jq -r '.error.message // .choices[0].message.content // ""' <<<"$resp"
}

# the agent's persona: a real guy, crypto and macro only, trolls off-topic
readonly AI_SYSTEM="You live inside the novrix CLI, a real guy, not some AI. Cypherpunk crypto nerd, hates banks, reads the chain all day. Talk like a human: short american words, lol and lmao, light roasts welcome. Get serious when the question is serious. No corporate speak, no robotic phrases, no em dashes, never say 'this is' or 'this isn't'. Always give the real answer, brief, plain text.
Your lane is crypto and macro: bitcoin, on-chain metrics, fear and greed, mvrv, sopr, cpi, tvl, rates, prices, macro data. If the question is outside that lane, like politics or people (who is vladimir putin?), do not answer seriously. Troll back with a joke, or say you only track the chain.
When the user asks for data, give the exact numbers. If a LATEST NOVRIX DATA line is included in the question, use those exact numbers. If a WEB RESEARCH block is included, use it as a source when you are not sure. If a novrix command shows what the user asks about, name it (fg, mvrv, cpi, tvl). If you do not know a number, say so instead of making it up."

# month word -> number (jan..dec), for date questions
month_num() {
  case "$1" in
    jan*) echo 1 ;; feb*) echo 2 ;; mar*) echo 3 ;; apr*) echo 4 ;;
    may*) echo 5 ;; jun*) echo 6 ;; jul*) echo 7 ;; aug*) echo 8 ;;
    sep*) echo 9 ;; oct*) echo 10 ;; nov*) echo 11 ;; dec*) echo 12 ;;
    *) return 1 ;;
  esac
}

# pull a date (YYYY-MM-DD, YYYY-MM, or a bare year) out of a question;
# prints nothing when there is none. Handles "22 december 2022",
# "december 22, 2022", "2014, 15 january", "january 2014", ISO.
extract_date() {
  local q="$1" m d y mon tail word
  q="$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')"
  if [[ "$q" =~ ((19|20)[0-9]{2})[-/]([0-9]{1,2})[-/]([0-9]{1,2}) ]]; then
    printf '%04d-%02d-%02d\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"
    return 0
  fi
  # "22 december 2022", "22nd of december 2022"
  if [[ "$q" =~ ([0-9]{1,2})(st|nd|rd|th)?[[:space:]]+(of[[:space:]]+)?(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[.,]?[[:space:]]+((19|20)[0-9]{2}) ]]; then
    d="${BASH_REMATCH[1]}"; mon="${BASH_REMATCH[4]}"; y="${BASH_REMATCH[5]}"
    m="$(month_num "$mon")" || return 1
    printf '%04d-%02d-%02d\n' "$y" "$m" "$d"
    return 0
  fi
  # "december 22, 2022"
  if [[ "$q" =~ (jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[[:space:]]+([0-9]{1,2})(st|nd|rd|th)?[.,]?[[:space:]]+((19|20)[0-9]{2}) ]]; then
    mon="${BASH_REMATCH[1]}"; d="${BASH_REMATCH[2]}"; y="${BASH_REMATCH[4]}"
    m="$(month_num "$mon")" || return 1
    printf '%04d-%02d-%02d\n' "$y" "$m" "$d"
    return 0
  fi
  # "2014, 15 january" — year first
  if [[ "$q" =~ ((19|20)[0-9]{2})[.,]?[[:space:]]+([0-9]{1,2})(st|nd|rd|th)?[[:space:]]+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]* ]]; then
    y="${BASH_REMATCH[1]}"; d="${BASH_REMATCH[3]}"; mon="${BASH_REMATCH[5]}"
    m="$(month_num "$mon")" || return 1
    printf '%04d-%02d-%02d\n' "$y" "$m" "$d"
    return 0
  fi
  # "january 2014", "sept 2014" — whole month only (so "mayer 2022" is
  # not read as a date)
  if [[ "$q" =~ (^|[^a-z])(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)([a-z]*)[.,]?[[:space:]]+((19|20)[0-9]{2}) ]]; then
    mon="${BASH_REMATCH[2]}"; tail="${BASH_REMATCH[3]}"; y="${BASH_REMATCH[4]}"
    word="$mon$tail"
    case "$word" in
      jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december)
        m="$(month_num "$mon")" || return 1
        printf '%04d-%02d\n' "$y" "$m"
        return 0 ;;
    esac
  fi
  if [[ "$q" =~ (19|20)[0-9]{2} ]]; then
    printf '%s\n' "${BASH_REMATCH[0]}"
    return 0
  fi
  return 1
}

# a date RANGE ("from 10 january to 20 january, 2022", "december 5 through
# december 24, 2022") -> "start end" (both YYYY-MM-DD, space separated);
# nothing when there is none. Handles full dates on both sides, month-first
# phrasing with the year only on the end date, and a bare day range
# ("10 to 20 january 2022").
extract_range() {
  local q="$1" d1 d2 m1 m2 y y2 mon
  q="$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')"

  # "10 january 2022 to 20 january 2022" — full dates on both sides
  if [[ "$q" =~ (^|[^a-z])([0-9]{1,2})(st|nd|rd|th)?[[:space:]]+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[.,]?[[:space:]]+((19|20)[0-9]{2})[[:space:]]+(to|through|until|thru|and)[[:space:]]+([0-9]{1,2})(st|nd|rd|th)?[[:space:]]+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[.,]?[[:space:]]+((19|20)[0-9]{2}) ]]; then
    d1="${BASH_REMATCH[2]}"; mon="${BASH_REMATCH[4]}"; m1="$(month_num "$mon")" || return 1
    y="${BASH_REMATCH[5]}"; d2="${BASH_REMATCH[8]}"; mon="${BASH_REMATCH[10]}"; m2="$(month_num "$mon")" || return 1
    y2="${BASH_REMATCH[11]}"
    printf '%04d-%02d-%02d %04d-%02d-%02d\n' "$y" "$m1" "$d1" "$y2" "$m2" "$d2"
    return 0
  fi

  # "january 10 to january 20, 2022" — month first, year only on the end
  if [[ "$q" =~ (^|[^a-z])(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[[:space:]]+([0-9]{1,2})(st|nd|rd|th)?[.,]?[[:space:]]+(to|through|until|thru|and)[[:space:]]+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[[:space:]]+([0-9]{1,2})(st|nd|rd|th)?[.,]?[[:space:]]+((19|20)[0-9]{2}) ]]; then
    mon="${BASH_REMATCH[2]}"; m1="$(month_num "$mon")" || return 1
    d1="${BASH_REMATCH[3]}"; mon="${BASH_REMATCH[6]}"; m2="$(month_num "$mon")" || return 1
    d2="${BASH_REMATCH[7]}"; y="${BASH_REMATCH[9]}"
    printf '%04d-%02d-%02d %04d-%02d-%02d\n' "$y" "$m1" "$d1" "$y" "$m2" "$d2"
    return 0
  fi

  # "10 january to 20 january, 2022" — day first, year only on the end date
  if [[ "$q" =~ (^|[^a-z])([0-9]{1,2})(st|nd|rd|th)?[[:space:]]+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[.,]?[[:space:]]+(to|through|until|thru|and)[[:space:]]+([0-9]{1,2})(st|nd|rd|th)?[[:space:]]+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[.,]?[[:space:]]+((19|20)[0-9]{2}) ]]; then
    d1="${BASH_REMATCH[2]}"; mon="${BASH_REMATCH[4]}"; m1="$(month_num "$mon")" || return 1
    d2="${BASH_REMATCH[6]}"; mon="${BASH_REMATCH[8]}"; m2="$(month_num "$mon")" || return 1
    y="${BASH_REMATCH[9]}"
    printf '%04d-%02d-%02d %04d-%02d-%02d\n' "$y" "$m1" "$d1" "$y" "$m2" "$d2"
    return 0
  fi

  # "10 to 20 january, 2022" — bare day range, month+year only on the end
  if [[ "$q" =~ (^|[^a-z])([0-9]{1,2})(st|nd|rd|th)?[[:space:]]+(to|through|until|thru|and)[[:space:]]+([0-9]{1,2})(st|nd|rd|th)?[[:space:]]+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[.,]?[[:space:]]+((19|20)[0-9]{2}) ]]; then
    d1="${BASH_REMATCH[2]}"; d2="${BASH_REMATCH[5]}"; mon="${BASH_REMATCH[7]}"; m1="$(month_num "$mon")" || return 1
    y="${BASH_REMATCH[8]}"
    printf '%04d-%02d-%02d %04d-%02d-%02d\n' "$y" "$m1" "$d1" "$y" "$m1" "$d2"
    return 0
  fi
  return 1
}

# "last 10 days" -> 10, "3 weeks" -> 21, "2 months" -> 60; prints nothing
# when there is no count in the question.
extract_count() {
  local q="$1" n unit
  q="$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')"
  if [[ "$q" =~ (last|past|previous)[[:space:]]+([0-9]{1,3})[[:space:]]+(days?|weeks?|months?) ]]; then
    n="${BASH_REMATCH[2]}"; unit="${BASH_REMATCH[3]}"
  elif [[ "$q" =~ ([0-9]{1,3})[[:space:]]+last[[:space:]]+(days?|weeks?|months?) ]]; then
    n="${BASH_REMATCH[1]}"; unit="${BASH_REMATCH[2]}"
  elif [[ "$q" =~ ([0-9]{1,3})[[:space:]]+(days?|weeks?|months?) ]]; then
    n="${BASH_REMATCH[1]}"; unit="${BASH_REMATCH[2]}"
  else
    return 1
  fi
  case "$unit" in
    week*) echo $((n * 7)) ;;
    month*) echo $((n * 30)) ;;
    *) echo "$n" ;;
  esac
  return 0
}

# raw "N months" count (for monthly series like cpi); prints nothing otherwise
month_count() {
  local q="$1"
  q="$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')"
  if [[ "$q" =~ ([0-9]{1,3})[[:space:]]+months? ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

# which novrix metric is the question about? Prints the command name (a SERIES
# key, fg, cpi, tvl, nupl, or a metrilytics command), or nothing when the
# question is not about any of them.
detect_data_series() {
  local q="$1" name
  q="$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')"
  # multi-word phrases, most specific first
  case "$q" in
    *"fear and greed"*|*"fear & greed"*|*"fear-greed"*|*"greed index"*)
      echo fg; return 0 ;;
    *"core cpi"*|*ccpi*) echo core-cpi; return 0 ;;
    *"core pce"*|*cpce*) echo core-pce; return 0 ;;
    *"reserve risk"*) echo reserve-risk; return 0 ;;
    *"realized price"*) echo realized-price; return 0 ;;
    *"realized profit"*) echo realized-profit; return 0 ;;
    *"realized loss"*) echo realized-loss; return 0 ;;
    *"market cap"*) echo market-cap; return 0 ;;
    *"btc price"*|*"bitcoin price"*) echo btc-price; return 0 ;;
    *"btc dominance"*|*"eth dominance"*) echo dominance; return 0 ;;
    *"200 week"*|*"200w ma"*) echo 200-week-ma; return 0 ;;
    *"active address"*) echo active-addresses; return 0 ;;
    *"hash rate"*|*hashrate*) echo hashrate; return 0 ;;
    *"stablecoin supply"*) echo stablecoin-supply; return 0 ;;
    *"open interest"*) echo open-interest; return 0 ;;
    *"funding rate"*) echo funding-rate; return 0 ;;
    *"job openings"*|*jolts*) echo job-openings; return 0 ;;
    *"michigan sentiment"*|*umich*) echo umich; return 0 ;;
    *"30 year"*|*"30y yield"*) echo us30y; return 0 ;;
    *"yield curve"*|*"10y2y"*|*"10y-2y"*) echo t10y2y; return 0 ;;
    *"dollar index"*|*dxy*) echo dxy; return 0 ;;
    *"fed funds"*|*ffr*) echo fedfunds; return 0 ;;
    *unemployment*|*unrate*) echo unrate; return 0 ;;
    *payroll*|*nfp*) echo payrolls; return 0 ;;
    *gdp*) echo gdp; return 0 ;;
    *"dominance"*) echo dominance; return 0 ;;
    *"options"*|*opts*) echo options; return 0 ;;
    *"protocols"*|*prots*) echo protocols; return 0 ;;
    *"bridges"*) echo bridges; return 0 ;;
    *"lending"*) echo lending; return 0 ;;
    *"stablecoins"*|*stables*) echo stablecoins; return 0 ;;
    *"fees"*) echo fees; return 0 ;;
  esac
  # single short names need word boundaries so typos (mvrrv) still fall
  # through to the typo fixer instead of being read as the real command
  local w
  for w in fg fng mvrv sopr nupl btc etf oil gold vix dxy gdp cpi tvl defi dex m2 spx oi dom nfp; do
    if [[ "$q" =~ (^|[^a-z])$w([^a-z]|$) ]]; then
      case "$w" in
        fng) echo fg ;;
        btc) echo btc-price ;;
        spx) echo sp500 ;;
        dom) echo dominance ;;
        nfp) echo payrolls ;;
        *) echo "$w" ;;
      esac
      return 0
    fi
  done
  # longer series names match as whole words too
  for name in "${!SERIES[@]}"; do
    [[ ${#name} -ge 5 ]] || continue
    if [[ "$q" =~ (^|[^a-z])$name([^a-z]|$) ]]; then
      echo "$name"; return 0
    fi
  done
  # catch-all: "what's the price?" → the metrilytics prices overview, but
  # only after explicit command names so "spx ... price?" reads sp500
  case "$q" in
    *"prices"*|*"price"*) echo prices; return 0 ;;
  esac
  return 1
}

# ---------------------------------------------------------------------------
# FRED fallback — historical dates the novrix API does not cover are pulled
# straight from the keyless fredgraph.csv export on fred.stlouisfed.org.
# Series ids live in FRED_ID (data.sh); any failure here means "no data" and
# the caller keeps its AI/web fallback, so FRED being down or rate-limited
# never breaks a question.
# ---------------------------------------------------------------------------

# YYYY-MM-DD of the first day of the previous month (string math only).
fred_prev_month() {
  local y="${1:0:4}" m="${1:5:2}" n
  n=$((10#$m - 1))
  if (( n < 1 )); then n=12; y=$((10#$y - 1)); fi
  printf '%04d-%02d-01\n' "$y" "$n"
}

# last day of a month, so monthly picks stay inside the requested month
fred_month_end() {
  case "${1:5:2}" in
    01|03|05|07|08|10|12) printf '31' ;;
    04|06|09|11) printf '30' ;;
    02) printf '28' ;;
  esac
}

# full FRED series as CSV (observation_date,<ID>), oldest first. Fixture
# mode: $NOVRIX_API_DIR/_fred_<ID>.csv, so the smoke suite stays offline.
fred_get() {
  local id="$1" fx file body head
  if [[ -n "${NOVRIX_API_DIR:-}" ]]; then
    fx="$NOVRIX_API_DIR/_fred_$id.csv"
    [[ -f "$fx" ]] || return 1
    cat "$fx"; return 0
  fi
  file="$CACHE_ROOT/fred_$id.csv"
  if [[ "$opt_fresh" == "0" && -f "$file" ]] && (( $(file_age_min "$file") < (DEFAULT_TTL + 59) / 60 )); then
    cat "$file"; return 0
  fi
  body="$(curl -sS --connect-timeout 10 --max-time "$CURL_TIMEOUT" -A "$UA" \
    "https://fred.stlouisfed.org/graph/fredgraph.csv?id=$id" 2>/dev/null)" || return 1
  head="$(printf '%s\n' "$body" | head -1 || true)"
  [[ "$head" == "observation_date,$id" ]] || return 1   # rate-limited/garbage → no data
  printf '%s\n' "$body" >"$file" 2>/dev/null || true
  printf '%s\n' "$body"
}

# last observation on or before a date; prints "date<TAB>value" or nothing.
fred_pick() {
  local target="$1" d v best=""
  while IFS=',' read -r d v || [[ -n "$d" ]]; do
    [[ "$d" == "observation_date" ]] && continue
    [[ -n "$v" ]] || continue
    [[ "$d" > "$target" ]] && break
    best="$d	$v"
  done
  [[ -n "$best" ]] || return 1
  printf '%s\n' "$best"
}

# one-line stats for a year: avg<TAB>min<TAB>min_date<TAB>max<TAB>max_date
fred_year_stats() {
  local yr="$1" d v avg mn mind mx maxd n
  avg=""; n=0; mn=""; mind=""; mx=""; maxd=""
  while IFS=',' read -r d v || [[ -n "$d" ]]; do
    [[ "$d" == "observation_date" ]] && continue
    [[ -n "$v" ]] || continue
    [[ "$d" =~ ^$yr- ]] || continue
    n=$((n + 1))
    avg="$(awk -v s="${avg:-0}" -v x="$v" 'BEGIN{print s+x}')"
    if [[ -z "$mn" ]] || awk -v a="$v" -v b="$mn" 'BEGIN{exit !(a<b)}'; then
      mn="$v"; mind="$d"
    fi
    if [[ -z "$mx" ]] || awk -v a="$v" -v b="$mx" 'BEGIN{exit !(a>b)}'; then
      mx="$v"; maxd="$d"
    fi
  done
  [[ -n "$mind" ]] || return 1
  avg="$(awk -v s="$avg" -v n="$n" 'BEGIN{printf "%.4f", s/n}')"
  printf '%s\t%s\t%s\t%s\t%s\n' "$avg" "$mn" "$mind" "$mx" "$maxd"
}

# answer a dated question from FRED. $1=series, $2=date (YYYY-MM-DD,
# YYYY-MM, or a year), $3=kind (day|month|year). Prints one formatted line
# with a dim "· FRED" marker; returns 0 on success, 1 when FRED has no
# observation for that date (the AI/web fallback then takes it).
fred_answer() {
  local series="$1" date="$2" kind="$3" fid label fmt period entry
  fid="${FRED_ID[$series]:-}"
  [[ -n "$fid" ]] || return 1
  if [[ "$series" == "cpi" ]]; then
    label="US CPI"; fmt="num2"; period="monthly"
  else
    entry="${SERIES[$series]:-}"
    [[ -n "$entry" ]] || return 1
    IFS='|' read -r _ _ label fmt _ period <<<"$entry" || true
  fi
  local csv ve raw d v val limit
  csv="$(fred_get "$fid")" || return 1
  [[ -n "$csv" ]] || return 1
  ve="$(series_val_expr "$fmt")"
  if [[ "$period" == "monthly" && "$kind" == "day" ]]; then
    kind="month"; date="${date%-*}"
  fi
  if [[ "$kind" == "day" ]]; then
    raw="$(printf '%s\n' "$csv" | fred_pick "$date")" || return 1
    IFS=$'\t' read -r d v <<<"$raw"
    # a stale pick (holiday/weekend) is fine, but not one from months back
    limit="$(fred_prev_month "$date")"
    [[ "$d" < "$limit" ]] && return 1
    val="$(jq -rn --argjson v "$v" "$JQ_ABBR$ve")"
    printf '%s%s%s · %s%s%s · %s %s%s%s\n' "$c_bold" "$label" "$c_reset" \
      "$(sign_col "$val")" "$val" "$c_reset" "$d" "$c_dim" "· FRED" "$c_reset"
    return 0
  fi
  if [[ "$kind" == "month" ]]; then
    raw="$(printf '%s\n' "$csv" | fred_pick "${date}-$(fred_month_end "$date")")" || return 1
    IFS=$'\t' read -r d v <<<"$raw"
    [[ "$d" == "${date}-"* ]] || return 1   # FRED has no obs in that month
    val="$(jq -rn --argjson v "$v" "$JQ_ABBR$ve")"
    printf '%s%s%s · %s%s%s · %s %s%s%s\n' "$c_bold" "$label" "$c_reset" \
      "$(sign_col "$val")" "$val" "$c_reset" "$date" "$c_dim" "· FRED" "$c_reset"
    return 0
  fi
  local st avg mn mind mx maxd af mf xf
  st="$(printf '%s\n' "$csv" | fred_year_stats "$date")" || return 1
  IFS=$'\t' read -r avg mn mind mx maxd <<<"$st"
  af="$(jq -rn --argjson v "$avg" "$JQ_ABBR$ve")"
  mf="$(jq -rn --argjson v "$mn" "$JQ_ABBR$ve")"
  xf="$(jq -rn --argjson v "$mx" "$JQ_ABBR$ve")"
  [[ "$period" == "monthly" ]] && { mind="${mind%-*}"; maxd="${maxd%-*}"; }
  printf '%s%s%s · %s · avg %s · min %s (%s) · max %s (%s) %s%s%s\n' \
    "$c_bold" "$label" "$c_reset" "$date" "$af" "$mf" "$mind" "$xf" "$maxd" \
    "$c_dim" "· FRED" "$c_reset"
  return 0
}

# answer a dated RANGE ("fear and greed from 10 january to 20 january, 2022")
# by printing every observation in the window, oldest first, as a table.
# $1=series, $2=start (YYYY-MM-DD), $3=end (YYYY-MM-DD). Returns 0 when it
# printed the window, 1 when the window is not in the data (the FRED range
# fallback below, then the AI/web research).
answer_range_question() {
  local series="$1" rs="$2" re="$3" body rows
  case "$series" in
    fg)
      body="$(api_get "/api/fear-greed?days=3000")"
      rows="$(jq -r --arg s "$rs" --arg e "$re" '
        [ .data[] | select(.timestamp[0:10] >= $s and .timestamp[0:10] <= $e) ]
        | sort_by(.timestamp)[]
        | [.timestamp[0:10], (.score|tostring), .label] | @tsv' <<<"$body")"
      if [[ -n "$rows" ]]; then
        printf '%sFEAR & GREED INDEX%s · %s to %s\n' "$c_bold" "$c_reset" "$rs" "$re"
        printf '%-12s %6s  %-14s\n' "DATE" "SCORE" "ZONE"
        hr 34
        printf '%s\n' "$rows" | while IFS=$'\t' read -r date score label; do
          local col=""
          case "$label" in
            "Extreme Fear") col="$c_red" ;;
            "Fear") col="$c_yellow" ;;
            "Greed") col="$c_green" ;;
            "Extreme Greed") col="$c_bold$c_green" ;;
          esac
          printf '%-12s %s%6s%s  %b%-14s%b\n' \
            "$date" "$(fg_col "$score")" "$score" "$c_reset" \
            "$col" "$label" "$c_reset"
        done
        return 0
      fi
      ;;
    nupl)
      body="$(api_get "/api/nupl")"
      rows="$(jq -r --arg s "$rs" --arg e "$re" '
        [ .data[] | select(.time[0:10] >= $s and .time[0:10] <= $e) ]
        | sort_by(.time)[]
        | [.time[0:10], ((.net_unrealized_profit_loss*1000)|round), (.net_unrealized_profit_loss|tostring)] | @tsv' <<<"$body")"
      if [[ -n "$rows" ]]; then
        printf '%sNUPL%s, NET UNREALIZED PROFIT/LOSS · %s to %s\n' "$c_bold" "$c_reset" "$rs" "$re"
        printf '%-12s %8s  %-16s\n' "DATE" "NUPL" "ZONE"
        hr 38
        printf '%s\n' "$rows" | while IFS=$'\t' read -r date mv val; do
          local zone col
          zone="$(nupl_zone "$mv")"
          case "$zone" in
            Euphoria|Greed) col="$c_green" ;;
            Optimism) col="$c_reset" ;;
            Anxiety) col="$c_yellow" ;;
            Fear|Capitulation) col="$c_red" ;;
          esac
          printf '%-12s %8s  %b%-16s%b\n' "$date" "$val" "$col" "$zone" "$c_reset"
        done
        return 0
      fi
      ;;
    cpi)
      body="$(api_get "/api/fred-cpiaucsl")"
      rows="$(jq -r --arg s "${rs%-*}" --arg e "${re%-*}" '
        [ .data[] | select(.time[0:7] >= $s and .time[0:7] <= $e) ]
        | sort_by(.time)[]
        | [.time[0:7], (.value|tostring)] | @tsv' <<<"$body")"
      if [[ -n "$rows" ]]; then
        printf '%sUS CPI%s, CPIAUCSL (FRED, monthly) · %s to %s\n' "$c_bold" "$c_reset" "${rs%-*}" "${re%-*}"
        printf '%-10s %10s\n' "MONTH" "CPI"
        hr 27
        printf '%s\n' "$rows" | while IFS=$'\t' read -r mon v; do
          printf '%-10s %s%10s%s\n' "$mon" "$(sign_col "$v")" "$v" "$c_reset"
        done
        return 0
      fi
      ;;
    tvl|defi|stablecoins|dex|fees|options|dominance|prices|oi|market|protocols|bridges|lending)
      return 1 ;;   # no long daily history on novrix — the AI takes it
    *)
      local entry="${SERIES[$series]:-}"
      if [[ -n "$entry" ]]; then
        local path field label2 fmt unit period ve tcol body2
        IFS='|' read -r path field label2 fmt unit period <<<"$entry" || true
        ve="$(series_val_expr "$fmt")"
        tcol='.time[0:10]'
        [[ "$period" == "monthly" ]] && tcol='.time[0:7]'
        body2="$(api_get "$path")"
        rows="$(jq -r --arg s "$rs" --arg e "$re" --arg field "$field" "$JQ_ABBR"'
          [ .data[] | select(.time[0:10] >= $s and .time[0:10] <= $e) | select(.[$field] != null) ]
          | sort_by(.time) | .[] | . as $r | $r[$field] as $v | [ '"$tcol"', ('"$ve"') ] | @tsv' <<<"$body2")"
        if [[ -n "$rows" ]]; then
          local col1
          if [[ "$period" == "monthly" ]]; then
            col1="MONTH"
          else
            col1="DATE"
          fi
          printf '%s%s%s · %s to %s\n' "$c_bold" "$label2" "$c_reset" "$rs" "$re"
          printf '%-10s %16s\n' "$col1" "VALUE"
          hr 27
          printf '%s\n' "$rows" | while IFS=$'\t' read -r d v; do
            printf '%-10s %s%16s%s\n' "$d" "$(sign_col "$v")" "$v" "$c_reset"
          done
          return 0
        fi
      fi
      ;;
  esac

  # window not in novrix history → straight from FRED for series that have
  # a FRED id (oil in the 80s, vix in the 90s, deep monthly macro history)
  local fid
  fid="${FRED_ID[$series]:-}"
  [[ -n "$fid" ]] || return 1
  local label3 fmt3 period3 entry3 csv ve3 rows3 col1
  if [[ "$series" == "cpi" ]]; then
    label3="US CPI"; fmt3="num2"; period3="monthly"
  else
    entry3="${SERIES[$series]:-}"
    [[ -n "$entry3" ]] || return 1
    IFS='|' read -r _ _ label3 fmt3 _ period3 <<<"$entry3" || true
  fi
  csv="$(fred_get "$fid")" || return 1
  [[ -n "$csv" ]] || return 1
  ve3="$(series_val_expr "$fmt3")"
  rows3="$(printf '%s\n' "$csv" | awk -F, -v s="$rs" -v e="$re" '
    NR == 1 { next }
    $1 >= s && $1 <= e && $2 != "" { print $1 "\t" $2 }')"
  [[ -n "$rows3" ]] || return 1
  if [[ "$period3" == "monthly" ]]; then
    col1="MONTH"
    printf '%s%s%s · %s to %s\n' "$c_bold" "$label3" "$c_reset" "${rs%-*}" "${re%-*}"
  else
    col1="DATE"
    printf '%s%s%s · %s to %s\n' "$c_bold" "$label3" "$c_reset" "$rs" "$re"
  fi
  printf '%-10s %16s\n' "$col1" "VALUE"
  hr 27
  printf '%s\n' "$rows3" | while IFS=$'\t' read -r d v; do
    local vf
    vf="$(jq -rn --argjson v "$v" "$JQ_ABBR$ve3")"
    [[ "$period3" == "monthly" ]] && d="${d%-*}"
    printf '%-10s %s%16s%s\n' "$d" "$(sign_col "$vf")" "$vf" "$c_reset"
  done
  return 0
}

# every series a question mentions, in order, deduped. Prints the canonical
# command names space-separated ("nupl and fear and greed index" -> "nupl fg"),
# or nothing when the question is not about any of them. Splits on "and" /
# "&" / commas ("fear and greed" is protected first because it is one phrase).
detect_data_series_all() {
  local q="$1" part s out="" found=0 d=$'\x1f'
  q="$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')"
  q="${q//fear and greed/fear-greed}"
  q="${q//fear & greed/fear-greed}"
  # split on "and" / "&" / commas ("fear and greed" is protected above
  # because it is one phrase); $d is an unlikely-in-questions delimiter so
  # this stays portable across GNU and BSD sed/tr
  q="${q// and /$d}"
  q="${q// & /$d}"
  q="${q//, /$d}"
  q="${q//,/$d}"
  while IFS= read -r part || [[ -n "$part" ]]; do
    [[ -n "$part" ]] || continue
    s="$(detect_data_series "$part")" || continue
    case " $out " in
      *" $s "*) : ;;            # already collected
      *) out="${out:+$out }$s"; found=1 ;;
    esac
  done <<<"$(printf '%s' "$q" | tr "$d" '\n')"
  [[ "$found" -eq 1 ]] || return 1
  printf '%s' "$out"
}

# a question naming several series at once ("nupl and fear and greed index")
# answers each one, each as its own table, so nothing gets mixed up. A range,
# a single date, or a last-N window from the question applies to each series.
answer_multi_series() {
  local q="$1" list="$2" s rc=1
  local _od="${opt_days:-}" _om="${opt_months:-}" _oj="${opt_json:-0}"
  local range rs re date count mc
  range="$(extract_range "$q")" || true
  date="$(extract_date "$q")" || true
  count="$(extract_count "$q")" || true
  mc="$(month_count "$q")" || true

  local -a series_arr
  read -r -a series_arr <<<"$list"
  for s in "${series_arr[@]}"; do
    printf '\n'
    # an explicit window → every observation as a table
    if [[ -n "$range" ]]; then
      read -r rs re <<<"$range"
      if answer_range_question "$s" "$rs" "$re"; then rc=0; continue; fi
    fi
    # a single day → a one-row table for that day
    if [[ -n "$date" && "$date" =~ ^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$ ]]; then
      if answer_range_question "$s" "$date" "$date"; then rc=0; continue; fi
    fi
    # otherwise the last N observations as a table (7 by default)
    local period=""
    case "$s" in
      cpi) opt_days=""; opt_months="${mc:-7}" ;;
      *)
        if [[ -n "${SERIES[$s]:-}" ]]; then
          IFS='|' read -r _ _ _ _ _ period <<<"${SERIES[$s]}" || true
          if [[ "$period" == "monthly" ]]; then opt_days=""; opt_months="${mc:-7}"
          else opt_days="${count:-7}"; opt_months=""; fi
        else
          opt_days="${count:-7}"; opt_months=""
        fi
        ;;
    esac
    opt_json=0
    case "$s" in
      fg) cmd_fg ;;
      cpi) cmd_cpi ;;
      nupl) cmd_nupl ;;
      tvl) cmd_tvl ;;
      defi|stablecoins|dex|fees|options|dominance|prices|oi) cmd_meta "$s" ;;
      market) cmd_market ;;
      protocols|bridges|lending) cmd_rank "$s" ;;
      *) cmd_series "$s" ;;
    esac
    rc=0
  done
  opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
  return "$rc"
}

# answer a data question with real numbers straight from the novrix API.
# Returns 0 when it answered (prints the data), 1 when the question needs
# the AI agent instead (an explanation, or a date novrix does not have).
answer_data_question() {
  local q="$1" series date n
  # explanation questions are for the agent, not the data dump
  case "$q" in
    *explain*|*why\ *|*how\ *|*meaning*|*what\ does*|*what\ is\ a*|*what\ are*|*difference*|*tell\ me\ about*)
      return 1 ;;
  esac

  # several series named in one question → each one as its own table
  local all
  all="$(detect_data_series_all "$q")" || return 1
  if (( $(printf '%s' "$all" | wc -w | tr -d ' ') > 1 )); then
    # the generic "price" catch-all is a fallback, not a second request —
    # drop it when the question already names a real series
    case " $all " in
      *" prices "*) all="${all// prices/}" ;;
    esac
    if (( $(printf '%s' "$all" | wc -w | tr -d ' ') > 1 )); then
      answer_multi_series "$q" "$all"
      return $?
    fi
  fi
  series="$all"

  date="$(extract_date "$q")" || true
  n="$(extract_count "$q")" || true

  local _od="${opt_days:-}" _om="${opt_months:-}" _oj="${opt_json:-0}"
  opt_days="${n:-1}"; opt_months=""; opt_json=0

  # a date RANGE ("from 10 january to 20 january, 2022") → every day in the
  # window as a table, not just the single end date
  local range rs re
  range="$(extract_range "$q")" || true
  if [[ -n "$range" ]]; then
    read -r rs re <<<"$range"
    if answer_range_question "$series" "$rs" "$re"; then
      opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
      return 0
    fi
    opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
    return 1   # the window is not in the data → web research + AI
  fi

  # a date in the question → pull the exact point from the full history
  # (a bare year or month gets a min/avg/max summary for that window)
  if [[ -n "$date" ]]; then
    local kind="day"
    case "$date" in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) kind="day" ;;
      [0-9][0-9][0-9][0-9]-[0-9][0-9]) kind="month" ;;
      [0-9][0-9][0-9][0-9]) kind="year" ;;
    esac
    case "$series" in
      fg)
        local body row ts score label
        body="$(api_get "/api/fear-greed?days=3000")"
        if [[ "$kind" == "day" ]]; then
          row="$(jq -r --arg d "$date" '.data[] | select(.timestamp | startswith($d)) | [.timestamp[0:10], (.score|tostring), .label] | @tsv' <<<"$body" | head -1 || true)"
          if [[ -n "$row" ]]; then
            IFS=$'\t' read -r ts score label <<<"$row"
            printf '%sFEAR & GREED%s · %s · %s%s/100%s (%s)\n' "$c_bold" "$c_reset" "$ts" "$(fg_col "$score")" "$score" "$c_reset" "$label"
            opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
            return 0
          fi
        else
          row="$(jq -r --arg d "$date" '
            [ .data[] | select(.timestamp | startswith($d)) ] as $y
            | if ($y|length)==0 then empty
              else ($y | map(.score)) as $vals
                | ($vals|add/length|round) as $avg
                | ($vals|min) as $mn
                | ($vals|max) as $mx
                | ($y | map(select(.score == $mn)) | .[0]) as $minp
                | ($y | map(select(.score == $mx)) | .[0]) as $maxp
                | [ $d, ($avg|tostring), ($mn|tostring), $minp.timestamp[0:10], $minp.label,
                    ($mx|tostring), $maxp.timestamp[0:10], $maxp.label ] | @tsv
              end' <<<"$body" | head -1 || true)"
          if [[ -n "$row" ]]; then
            local per avg mn mind lmn mx maxd lmx
            IFS=$'\t' read -r per avg mn mind lmn mx maxd lmx <<<"$row"
            printf '%sFEAR & GREED%s · %s · avg %s · min %s (%s %s) · max %s (%s %s)\n' "$c_bold" "$c_reset" "$per" "$avg" "$mn" "$mind" "$lmn" "$mx" "$maxd" "$lmx"
            opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
            return 0
          fi
        fi
        ;;
      nupl)
        local body3 row3 ts3 val3 mv3
        body3="$(api_get "/api/nupl")"
        if [[ "$kind" == "day" ]]; then
          row3="$(jq -r --arg d "$date" '.data[] | select(.time | startswith($d)) | [.time[0:10], ((.net_unrealized_profit_loss*1000|round)/1000|tostring), ((.net_unrealized_profit_loss*1000)|round)] | @tsv' <<<"$body3" | head -1 || true)"
          if [[ -n "$row3" ]]; then
            IFS=$'\t' read -r ts3 val3 mv3 <<<"$row3"
            printf '%sNUPL%s · %s (%s) · %s\n' "$c_bold" "$c_reset" "$val3" "$(nupl_zone "$mv3")" "$ts3"
            opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
            return 0
          fi
        else
          row3="$(jq -r --arg d "$date" '
            [ .data[] | select(.time | startswith($d)) ] as $y
            | if ($y|length)==0 then empty
              else ($y | map(.net_unrealized_profit_loss)) as $vals
                | ($vals|add/length) as $avg
                | ($vals|min) as $mn
                | ($vals|max) as $mx
                | ($y | map(select(.net_unrealized_profit_loss == $mn) | .time[0:10]) | .[0]) as $mind
                | ($y | map(select(.net_unrealized_profit_loss == $mx) | .time[0:10]) | .[0]) as $maxd
                | [ $d,
                    (($avg*1000|round)/1000|tostring), (($avg*1000)|round),
                    (($mn*1000|round)/1000|tostring), $mind,
                    (($mx*1000|round)/1000|tostring), $maxd ] | @tsv
              end' <<<"$body3" | head -1 || true)"
          if [[ -n "$row3" ]]; then
            local per3 avg3 avmv mn3 mind3 mx3 maxd3
            IFS=$'\t' read -r per3 avg3 avmv mn3 mind3 mx3 maxd3 <<<"$row3"
            printf '%sNUPL%s · %s · avg %s (%s) · min %s (%s) · max %s (%s)\n' "$c_bold" "$c_reset" "$per3" "$avg3" "$(nupl_zone "$avmv")" "$mn3" "$mind3" "$mx3" "$maxd3"
            opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
            return 0
          fi
        fi
        ;;
      cpi)
        local body4 row4 mon4 val4
        body4="$(api_get "/api/fred-cpiaucsl")"
        [[ "$kind" == "day" ]] && { date="${date%-*}"; kind="month"; }
        if [[ "$kind" == "month" ]]; then
          row4="$(jq -r --arg d "$date" '.data[] | select(.time | startswith($d)) | [.time[0:7], (.value|tostring)] | @tsv' <<<"$body4" | head -1 || true)"
          if [[ -n "$row4" ]]; then
            IFS=$'\t' read -r mon4 val4 <<<"$row4"
            printf '%sUS CPI%s · %s · %s\n' "$c_bold" "$c_reset" "$val4" "$mon4"
            opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
            return 0
          fi
        else
          row4="$(jq -r --arg d "$date" '
            [ .data[] | select(.time | startswith($d)) ] as $y
            | if ($y|length)==0 then empty
              else ($y | map(.value|tonumber)) as $vals
                | ($vals|add/length) as $avg
                | ($vals|min) as $mn
                | ($vals|max) as $mx
                | ($y | map(select((.value|tonumber) == $mn) | .time[0:7]) | .[0]) as $mind
                | ($y | map(select((.value|tonumber) == $mx) | .time[0:7]) | .[0]) as $maxd
                | [ $d, (($avg*100|round)/100|tostring), (($mn*100|round)/100|tostring), $mind, (($mx*100|round)/100|tostring), $maxd ] | @tsv
              end' <<<"$body4" | head -1 || true)"
          if [[ -n "$row4" ]]; then
            local per4 avg4 mn4 mind4 mx4 maxd4
            IFS=$'\t' read -r per4 avg4 mn4 mind4 mx4 maxd4 <<<"$row4"
            printf '%sUS CPI%s · %s · avg %s · min %s (%s) · max %s (%s)\n' "$c_bold" "$c_reset" "$per4" "$avg4" "$mn4" "$mind4" "$mx4" "$maxd4"
            opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
            return 0
          fi
        fi
        ;;
      tvl|defi|stablecoins|dex|fees|options|dominance|prices|oi|market|protocols|bridges|lending)
        : ;;   # no long daily history on novrix — let the AI take it
      *)
        local entry="${SERIES[$series]:-}"
        if [[ -n "$entry" ]]; then
          local path field label2 fmt unit period ve tcol sd body2 row2
          IFS='|' read -r path field label2 fmt unit period <<<"$entry" || true
          ve="$(series_val_expr "$fmt")"
          # shellcheck disable=SC2016  # $r / .time are jq expressions, not shell vars
          tcol='$r.time[0:10]'; sd='.time[0:10]'
          if [[ "$period" == "monthly" ]]; then
            # shellcheck disable=SC2016
            tcol='$r.time[0:7]'; sd='.time[0:7]'
          fi
          body2="$(api_get "$path")"
          if [[ "$period" == "monthly" && "$kind" == "day" ]]; then
            date="${date%-*}"   # a specific day collapses to the month
          fi
          local exact=0
          if [[ "$kind" == "day" || ( "$period" == "monthly" && "$kind" == "month" ) ]]; then
            exact=1
          fi
          if (( exact )); then
            row2="$(jq -r --arg d "$date" --arg field "$field" "$JQ_ABBR"'
              .data[] | select(.time | startswith($d)) as $r | $r[$field] as $v
              | [ '"$tcol"', ('"$ve"') ] | @tsv' <<<"$body2" | head -1 || true)"
            if [[ -n "$row2" ]]; then
              printf '%s%s%s · %s\n' "$c_bold" "$label2" "$c_reset" "$row2"
              opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
              return 0
            fi
          else
            row2="$(jq -r --arg d "$date" --arg field "$field" "$JQ_ABBR"'
              [ .data[] | select(.time | startswith($d)) | select(.[$field] != null) ] as $y
              | if ($y|length)==0 then empty
                else ($y | map(.[$field] | tonumber)) as $vals
                  | ($vals|add/length) as $avg
                  | ($vals|min) as $mn
                  | ($vals|max) as $mx
                  | ($y | map(select((.[$field]|tonumber) == $mn) | '"$sd"') | .[0]) as $mnd
                  | ($y | map(select((.[$field]|tonumber) == $mx) | '"$sd"') | .[0]) as $mxd
                  | [ $d,
                      ($avg as $v | '"$ve"'), ($mn as $v | '"$ve"'), $mnd,
                      ($mx as $v | '"$ve"'), $mxd ] | @tsv
                end' <<<"$body2" | head -1 || true)"
            if [[ -n "$row2" ]]; then
              local per2 avg2 mn2 mind2 mx2 maxd2
              IFS=$'\t' read -r per2 avg2 mn2 mind2 mx2 maxd2 <<<"$row2"
              printf '%s%s%s · %s · avg %s · min %s (%s) · max %s (%s)\n' "$c_bold" "$label2" "$c_reset" "$per2" "$avg2" "$mn2" "$mind2" "$mx2" "$maxd2"
              opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
              return 0
            fi
          fi
        fi
        ;;
    esac
    # the date predates novrix history → fetch it straight from FRED.
    # Only when FRED has no observation either does the AI/web research
    # fallback (with its dusty-archive humor) get the question.
    if fred_answer "$series" "$date" "$kind"; then
      opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
      return 0
    fi
    opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
    return 1   # not in novrix history → web research + AI
  fi

  # no date: latest value, or the last N via the real commands
  local mc="" period=""
  mc="$(month_count "$q")" || true
  if [[ -n "$mc" ]]; then
    case "$series" in
      cpi) opt_days=""; opt_months="$mc" ;;
      *)
        if [[ -n "${SERIES[$series]:-}" ]]; then
          IFS='|' read -r _ _ _ _ _ period <<<"${SERIES[$series]}" || true
          if [[ "$period" == "monthly" ]]; then opt_days=""; opt_months="$mc"; fi
        fi
        ;;
    esac
  fi
  case "$series" in
    fg) cmd_fg ;;
    cpi) cmd_cpi ;;
    nupl) cmd_nupl ;;
    tvl) cmd_tvl ;;
    defi|stablecoins|dex|fees|options|dominance|prices|oi) cmd_meta "$series" ;;
    market) cmd_market ;;
    protocols|bridges|lending) cmd_rank "$series" ;;
    *) cmd_series "$series" ;;
  esac
  local rc=$?
  opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
  return "$rc"
}

# attach the latest real value for whatever series a question mentions, so
# the AI answers with actual numbers instead of guessing
data_context() {
  local q="$1" series line
  series="$(detect_data_series "$q")" || return 0
  local _od="${opt_days:-}" _om="${opt_months:-}" _oj="${opt_json:-0}"
  opt_days=1; opt_months=""; opt_json=0
  case "$series" in
    fg) line="$(cmd_fg 2>/dev/null || true)" ;;
    cpi) line="$(cmd_cpi 2>/dev/null || true)" ;;
    nupl) line="$(cmd_nupl 2>/dev/null || true)" ;;
    tvl) line="$(cmd_tvl 2>/dev/null || true)" ;;
    defi|stablecoins|dex|fees|options|dominance|prices|oi) line="$(cmd_meta "$series" 2>/dev/null || true)" ;;
    market) line="$(cmd_market 2>/dev/null || true)" ;;
    protocols|bridges|lending) line="$(cmd_rank "$series" 2>/dev/null || true)" ;;
    *) line="$(cmd_series "$series" 2>/dev/null || true)" ;;
  esac
  opt_days="$_od"; opt_months="$_om"; opt_json="$_oj"
  [[ -n "$line" ]] && printf 'LATEST NOVRIX DATA: %s\n' "$line"
  return 0
}

# is the question asking for data at all? (decides whether to hit the web)
looks_like_data_question() {
  local q="$1"
  case "$q" in
    *date*|*data*|*history*|*index*|*price*|*rate*|*tvl*|*mvrv*|*cpi*|*fear*|*greed*|*btc*|*eth*|*sol*|*gold*|*oil*|*spx*|*vix*|*yield*|*dominance*|*volume*|*supply*|*cap*|*etf*|*sentiment*|*score*|*value*|*[0-9]*)
      return 0 ;;
  esac
  return 1
}

# best-effort web research via DuckDuckGo (no key needed). Prints an empty
# string when nothing useful comes back; callers treat it as optional
# context, never a hard dependency.
web_research() {
  local q="$1" enc html out
  enc="$(printf '%s' "$q" | sed 's/ /+/g; s/&/%26/g; s/?/%3F/g; s/,/%2C/g; s/+/%2B/g; s/:/%3A/g; s#/#%2F#g')"
  html="$(curl -sS --connect-timeout 8 --max-time 15 \
    -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36" \
    "https://html.duckduckgo.com/html/?q=$enc" 2>/dev/null || true)"
  [[ -n "$html" ]] || return 0
  out="$(printf '%s' "$html" \
    | grep -oE 'class="result__snippet"[^>]*>[^<]*' \
    | sed 's/class="result__snippet"[^>]*>//' \
    | head -3 \
    | tr '\n' ' | ' \
    | head -c 900 || true)"
  [[ -n "$out" ]] || return 0
  printf 'WEB RESEARCH: %s\n' "$out"
}

# is a bare phrase a question the AI agent should answer? (questions are
# routed to the agent instead of the "what even is" unknown-command die)
looks_like_question() {
  local p="$1"
  [[ "$p" == *"?"* ]] && return 0
  case "$p" in
    who*|what*|how*|why*|when*|where*|which*|can\ *|could\ *|tell\ *|give\ *|show\ *|is\ *|are\ *|do\ *|does\ *|explain\ *)
      return 0 ;;
    "the date of"*|"the time of"*|"the day of"*|"the price of"*|"the cost of"*|"the value of"*|"the meaning of"*|"the definition of"*|"the difference"*|"the reason"*|"the best"*|"the top"*|"the name"*|"the latest"*|"the current"*|"the last"*|"the history"*|"the trend"*)
      return 0 ;;
  esac
  return 1
}

# is a bare phrase casual chat the agent should riff on instead of the
# unknown-command die? greetings, banter, acknowledgements, addressing the
# bot ("hey crypto guy", "macro guy") — a conversation, not a command or
# a data question
looks_like_chat() {
  local p="$1"
  case "$p" in
    hey|heyy*|hi|hiya|howdy|hello|yo|sup|wazzup|whatsup|"what's up"|good\ morning*|good\ afternoon*|good\ evening*|welcome|"welcome back")
      return 0 ;;
    yes|yeah|yep|yup|sure|ok|okay|k|no|nah|nope|maybe|whatever|*whatever*|idk|"i don't know"|"i dont know"|thanks|thank\ you|thx|ty|bye|goodbye|cya|"see ya"|cool|nice|great|lol|lmao|haha|rofl|bro|dude|man|guy)
      return 0 ;;
    *"crypto guy"*|*"macro guy"*|*"hey novrix"*|*novrix*)
      return 0 ;;
  esac
  return 1
}

# is a bare phrase an elliptical follow-up ("for today?", "what about eth?",
# "and yesterday?", "now?") that only makes sense relative to the previous
# question? Such phrases carry no series name of their own — without context
# the AI agent would have to guess what they refer to and can invent numbers
# (e.g. answering "fear and greed sittin at 62" when the real index is 27).
# The REPL prefixes them with the last question before dispatching.
looks_like_followup() {
  local p="$1"
  p="$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')"
  case "$p" in
    for\ *|what\ about*|how\ about*|whats\ *|"what's"*|now*|today*|yesterday*|tonight*|and\ *|it\ *|"it's"*|that\ *|"that's"*|this\ *|them\ *|those\ *|these\ *|then\ *|elaborate*|"tell me more"*|more\ *|again\ *|about\ *|same\ *)
      return 0 ;;
  esac
  return 1
}

cmd_ai() {
  if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then usage; return 0; fi
  local q="$*"
  # bare `novrix ai` (or `ai` in the REPL) opens a chat — the agent greets
  # instead of dying with a usage error
  if [[ -z "$q" ]]; then
    printf '%s\n' "$(spinner_run "let me think..." ai_chat "$AI_SYSTEM" "hey")"
    return 0
  fi
  # politics and people: troll back, unless it is crypto-adjacent
  case "$q" in
    *putin*|*trump*|*biden*|*zelensky*|*macron*|*"kim jong"*)
      case "$q" in
        *btc*|*bitcoin*|*crypto*|*price*|*market*|*macro*|*economy*|*gold*|*oil*|*etf*|*tvl*|*mvrv*|*sentiment*|*fed*)
          : ;;   # crypto-adjacent — let the agent handle it
        *)
          printf '%s: lol i only track the chain, ask a politician about that. try \"fg\" or \"mvrv\" instead.\n' "$PROG"
          return 0 ;;
      esac ;;
  esac
  # "what does novrix think about the market?" → the channel's own take
  # (before data questions: "is novrix bullish on btc?" is a stance
  # question, not a btc price lookup)
  if answer_novrix_question "$q"; then return 0; fi
  # exact data questions first — real numbers straight from novrix
  if answer_data_question "$q"; then return 0; fi
  # privacy-coins mentions (monero, dero, zcash...) → the techleaks analysis
  if answer_privacy_question "$q"; then return 0; fi
  # "what's new on crypto?" → the latest chart text from the Telegram channel
  if answer_telegram_question "$q"; then return 0; fi
  # otherwise the AI agent, with latest data + web research as context
  local ctx="" user
  ctx="$(data_context "$q")"
  if [[ -z "${NOVRIX_API_DIR:-}" ]] && looks_like_data_question "$q"; then
    local web
    web="$(web_research "$q")"
    [[ -n "$web" ]] && ctx="${ctx:+$ctx
}$web"
  fi
  if [[ -n "$ctx" ]]; then
    user="$ctx

$q"
  else
    user="$q"
  fi
  printf '%s\n' "$(spinner_run "let me think..." ai_chat "$AI_SYSTEM" "$user")"
}

# every name a user can type (aliases, long names, system commands)
known_commands() {
  {
    printf '%s\n' fg fear-greed nupl cpi tvl \
      defi stablecoins dex fees options dominance prices oi market protocols \
      bridges lending macro shortcuts aliases map version help clear exit quit q ai ask \
      telegram tg
    printf '%s\n' "${!SERIES[@]}" "${!META[@]}" "${!ALIASES[@]}" "${ALIASES[@]}"
  } | sort -u
}
