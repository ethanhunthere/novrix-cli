# ---------------------------------------------------------------------------
# commands — usage, version, cheat-sheet, and every cmd_* implementation
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
$PROG $VERSION, market data from novrix.io, right in your terminal.

USAGE
  $PROG                      Interactive shell, type commands directly
  $PROG <command> [options]  One-shot mode (also available in the shell)

INTERACTIVE MODE
  Running $PROG with no arguments opens a shell where every command works
  without the "$PROG" prefix. Short names are primary, long names work too.
  $PROG shortcuts prints this map any time.
  Typos auto-fix. type 'mvvrv' and $PROG runs mvrv for you.

  sentiment   fg nupl mvrv sopr puell rhodl mayer rr rp rpf rpl mcap btc
              200ma addrs hash scs btoi funding etf
  macro       cpi unrate gdp nfp claims jolts ccpi pce cpce umich oil
              t30 curve be dxy gold spx vix ffr m2
  metrilytics tvl defi mkt stables dex fees dom opts prots bridges lending
              prices oi
  system      help clear exit / quit

COMMANDS
  crypto sentiment, on-chain & market sentiment (novrix.io/sentiment)
  fg      Fear & Greed index (latest + history)   (fear-greed)
  nupl    Bitcoin Net Unrealized Profit/Loss
  mvrv    MVRV Z-Score, market value vs realized value
  sopr    Spent Output Profit Ratio
  puell   Puell Multiple
  rhodl   RHODL Ratio
  mayer   Mayer Multiple
  rr      Reserve Risk                            (reserve-risk)
  rp      Bitcoin realized price                  (realized-price)
  rpf     Daily realized profit (USD)             (realized-profit)
  rpl     Daily realized loss (USD)               (realized-loss)
  mcap    Crypto total market cap                 (market-cap)
  btc     Bitcoin price                           (btc-price)
  200ma   200-week moving average                 (200-week-ma)
  addrs   Daily active addresses                  (active-addresses)
  hash    Bitcoin network hash rate               (hashrate)
  scs     Total stablecoin supply                 (stablecoin-supply)
  btoi    Bitcoin open interest                   (open-interest)
  funding Perpetual funding rate                  (funding-rate)
  etf     BTC ETF cumulative flows

  macro, US macroeconomics via FRED (novrix.io/sentiment)
  cpi     US CPI (CPIAUCSL), MoM / YoY
  unrate  US unemployment rate
  gdp     Real GDP (billions of chained dollars)
  nfp     Nonfarm payrolls (thousands)            (payrolls)
  claims  Initial jobless claims
  jolts   JOLTS job openings (thousands)          (job-openings)
  ccpi    Core CPI (CPILFESL)                     (core-cpi)
  pce     PCE price index
  cpce    Core PCE price index                    (core-pce)
  umich   University of Michigan consumer sentiment
  oil     WTI crude oil spot (\$/bbl)
  t30     30-year Treasury yield                  (us30y)
  curve   10Y - 2Y yield spread                   (t10y2y)
  be      10-year breakeven inflation rate        (breakeven)
  dxy     US dollar index (DXY)
  gold    Gold spot (\$/oz)
  spx     S&P 500 index                           (sp500)
  vix     VIX volatility index
  ffr     Effective federal funds rate            (fedfunds)
  m2      M2 money supply

  metrilytics, DeFi & markets dashboard (novrix.io/metrilytics)
  tvl     DeFi TVL per chain (with 7-day change)
  defi    Total DeFi TVL snapshot, top chain & protocol
  mkt     Market cap, 24h volume, BTC dominance   (market)
  stables Total stablecoin supply                 (stablecoins)
  dex     24h DEX volume
  fees    Protocol fees & revenue (24h)
  dom     BTC / ETH / SOL dominance               (dominance)
  opts    24h options volume                      (options)
  prots   Top protocols by TVL                    (protocols)
  bridges Top bridges by TVL
  lending Top lending protocols by TVL
  prices  BTC / ETH / SOL spot
  oi      BTC & DeFi perp open interest

  system
  shortcuts  Show the short-name command map (aliases, map)
  ai         Ask the DeepSeek AI agent anything (ask)
  telegram   Latest post from your Telegram channel
             (t.me/s/<channel>, no API key - 'what's new on crypto?' answers it)
  help       Show this help
  clear      Clear the screen (interactive mode)
  exit/quit  Leave (interactive mode)

  Typo? $PROG auto-fixes it. 'mvvrv' runs mvrv, 'spr' runs sopr, 'MVRV'
  runs mvrv. Local fuzzy matching first, then the AI agent for hard cases.

OPTIONS
  --json          Print the raw API JSON response instead of the table
  --fresh         Bypass the local response cache
  --days N        Recent N data points   (series commands, e.g. mvrv, unrate)
  --months N      Same as --days         (macro monthly series)
  --top N         Show top N rows        (tvl, prots, bridges, lending)
  --help, -h      Show this help
  --version, -v   Show version

ENVIRONMENT
  NOVRIX_API_BASE      Override the API base URL (default: https://novrix.io)
  NOVRIX_TTL           Response cache TTL in seconds (default: 300)
  NOVRIX_TELEGRAM_CHANNEL  Telegram channel for 'what's new on crypto?'
                          (or TELEGRAM_CHANNEL= in ~/.config/novrix/keys.conf)
  DEEPSEEK_API_KEY     DeepSeek key for the AI agent (or ~/.config/novrix/keys.conf)
  DEEPSEEK_API_BASE    DeepSeek API base (default: https://api.deepseek.com)

EXAMPLES
  $PROG fg
  $PROG mvrv --days 30
  $PROG btc          # same as 'btc-price'
  $PROG rr           # same as 'reserve-risk'
  $PROG macro cpi --months 24
  $PROG unrate
  $PROG tvl --top 5
  $PROG prots --top 10
  $PROG dom
  $PROG shortcuts
  $PROG ai "explain MVRV in one sentence"
  $PROG mvvrv             # typo? auto-fixed, runs mvrv

Market data needs no API key. The AI agent needs DEEPSEEK_API_KEY (see
~/.config/novrix/keys.conf). Responses are cached locally, please don't
hammer novrix.io.
EOF
}

print_version() {
  printf '%s %s, CLI for NOVRIX public market data (novrix.io)\n' "$PROG" "$VERSION"
}

# print the short -> full command map (cheat sheet)
cmd_shortcuts() {
  cat <<EOF
$PROG shortcuts, every command, shortest form first.
Long names still work everywhere.

crypto sentiment
  fg      fear & greed      sopr    sopr               rhodl   rhodl ratio
  nupl    nupl              puell   puell multiple     mayer   mayer multiple
  mvrv    mvrv z-score      rr      reserve-risk       rp      realized price
  rpf     realized profit   rpl     realized loss      mcap    market cap
  btc     btc price         200ma   200-week ma        addrs   active addresses
  hash    hashrate          scs     stablecoin supply  btoi    btc open interest
  funding funding rate      etf     btc etf flows

macro
  cpi     cpi               unrate  unemployment       gdp     gdp
  nfp     nonfarm payrolls  claims  jobless claims     jolts   job openings
  ccpi    core cpi          pce     pce                cpce    core pce
  umich   u.mich sentiment  oil     wti oil            t30     30y yield
  curve   10y-2y spread     be      breakeven          dxy     dollar index
  gold    gold              spx     s&p 500            vix     vix
  ffr     fed funds rate    m2      m2 supply

metrilytics
  tvl     tvl per chain     defi    defi tvl           mkt     market
  stables stablecoin supply dex     24h dex volume     fees    protocol fees
  dom     dominance         opts    options volume     prots   top protocols
  bridges bridges           lending lending            prices  btc/eth/sol spot
  oi      open interest

system · ai · help · clear · exit

Typos auto-fix: 'mvvrv' -> mvrv, 'spr' -> sopr, 'MVRV' -> mvrv.
$PROG <short> --help shows the full help. $PROG shortcuts repeats this list.
EOF
}

# ---------------------------------------------------------------------------
# telegram — latest posts from a public Telegram channel (t.me/s, no key)
# ---------------------------------------------------------------------------
cmd_telegram() {
  local channel n=1 out
  channel="$(tg_channel)"
  [[ -n "$channel" ]] \
    || die "no telegram channel set - export NOVRIX_TELEGRAM_CHANNEL=your-channel or add 'TELEGRAM_CHANNEL=your-channel' to $KEYS_FILE"
  if [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]; then n="$1"; shift; fi
  parse_opts "$@"
  out="$(tg_fetch "$channel" | tg_parse)"
  [[ -n "$out" ]] || die "no posts found on @$channel"
  printf '%s' "$out" | tg_show "$channel" "$n"
}

# ---------------------------------------------------------------------------
# fg — Fear & Greed
# ---------------------------------------------------------------------------
cmd_fg() {
  local days="${opt_days:-1}"
  pos_int "$days" "--days"
  local body
  body="$(api_get "/api/fear-greed?days=3000")"
  emit_json "$body" && return 0

  local latest_score latest_label latest_date
  IFS=$'\t' read -r latest_score latest_label latest_date < <(
    jq -r '.data | sort_by(.timestamp) | .[-1] | [.score, .label, .timestamp[0:10]] | @tsv' <<<"$body")

  # default view: one compact line with the score and zone
  if (( days == 1 )); then
    printf '%sFEAR & GREED%s · %s%s/100%s (%s) · %s\n' \
      "$c_bold" "$c_reset" \
      "$(fg_col "$latest_score")" "$latest_score" "$c_reset" \
      "$latest_label" "$latest_date"
    return 0
  fi

  printf '%sFEAR & GREED INDEX%s · latest: %s%s/100%s (%s) · %s\n' \
    "$c_bold" "$c_reset" \
    "$(fg_col "$latest_score")" "$latest_score" "$c_reset" \
    "$latest_label" "$latest_date"

  printf '%-12s %6s  %-14s\n' "DATE" "SCORE" "ZONE"
  hr 34
  jq -r --argjson days "$days" '
    .data | sort_by(.timestamp) | .[-($days):][]
    | [.timestamp[0:10], (.score|tostring), .label] | @tsv' <<<"$body" \
    | while IFS=$'\t' read -r date score label; do
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
}

# ---------------------------------------------------------------------------
# nupl — Net Unrealized Profit/Loss
# ---------------------------------------------------------------------------
cmd_nupl() {
  local days="${opt_days:-1}"
  pos_int "$days" "--days"
  local body
  body="$(api_get "/api/nupl")"
  emit_json "$body" && return 0

  local lv_m lv ldate
  IFS=$'\t' read -r lv_m lv ldate < <(
    jq -r '.data | sort_by(.time) | .[-1] | [((.net_unrealized_profit_loss*1000)|round), (.net_unrealized_profit_loss|tostring), .time[0:10]] | @tsv' <<<"$body")

  # default view: one compact line
  if (( days == 1 )); then
    printf '%sNUPL%s · %s (%s) · %s\n' "$c_bold" "$c_reset" "$lv" "$(nupl_zone "$lv_m")" "$ldate"
    return 0
  fi

  printf '%sNUPL%s, NET UNREALIZED PROFIT/LOSS · latest: %s (%s) · %s\n' \
    "$c_bold" "$c_reset" "$lv" "$(nupl_zone "$lv_m")" "$ldate"

  printf '%-12s %8s  %-16s\n' "DATE" "NUPL" "ZONE"
  hr 38
  jq -r --argjson days "$days" '
    .data | sort_by(.time) | .[-($days):][]
    | [.time[0:10], ((.net_unrealized_profit_loss*1000)|round), (.net_unrealized_profit_loss|tostring)] | @tsv' <<<"$body" \
    | while IFS=$'\t' read -r date mv val; do
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
  printf '\n%sZones: Euphoria ≥ 0.50 · Greed ≥ 0.25 · Optimism ≥ 0 · Anxiety ≥ -0.25 · Fear ≥ -0.50 · Capitulation < -0.50%s\n' "$c_dim" "$c_reset"
}

# ---------------------------------------------------------------------------
# cpi — US CPI (FRED / CPIAUCSL)
# ---------------------------------------------------------------------------
cmd_cpi() {
  local months="${opt_months:-1}"
  pos_int "$months" "--months"
  local body
  body="$(api_get "/api/fred-cpiaucsl")"
  emit_json "$body" && return 0

  # default view: one compact line with latest CPI + MoM/YoY
  if (( months == 1 )); then
    local line
    line="$(jq -r '
      def p2: (.*100|round)/100;
      .data | sort_by(.time) as $all | $all[-1] as $cur
      | (if ($all|length) >= 2 then $all[-2] else null end) as $prev
      | (if ($all|length) >= 13 then $all[-13] else null end) as $yoy
      | ($cur.value|tostring)
        + " " + $cur.time[0:7]
        + " " + (if $prev then (($cur.value-$prev.value)/$prev.value*100|p2|tostring) else "nan" end)
        + " " + (if $yoy then (($cur.value-$yoy.value)/$yoy.value*100|p2|tostring) else "nan" end)' <<<"$body")"
    local val mon mom yoy
    IFS=$' ' read -r val mon mom yoy <<<"$line"
    printf '%sUS CPI%s · %s · MoM %s · YoY %s · %s\n' "$c_bold" "$c_reset" "$val" "$(fmtpct "$mom")" "$(fmtpct "$yoy")" "$mon"
    return 0
  fi

  local latest_val latest_mon
  IFS=$'\t' read -r latest_val latest_mon < <(
    jq -r '.data | sort_by(.time) | .[-1] | [ (.value|tostring), .time[0:7] ] | @tsv' <<<"$body")
  printf '%sUS CPI%s, CPIAUCSL (FRED, monthly) · latest: %s · %s\n' "$c_bold" "$c_reset" "$latest_val" "$latest_mon"

  printf '%-10s %10s  %9s  %9s\n' "MONTH" "CPI" "MoM %" "YoY %"
  jq -r --argjson m "$months" '
    def p2: (.*100|round)/100;
    .data | sort_by(.time) as $all
    | ($all|length) as $L
    | $all[-($m):] as $w
    | range(0; ($w|length)) as $i
    | $w[$i] as $cur
    | (if ($L - $m + $i - 1) >= 0 then $all[$L - $m + $i - 1] else null end) as $prev
    | (if ($L - $m + $i - 12) >= 0 then $all[$L - $m + $i - 12] else null end) as $yoy
    | [ $cur.time[0:7],
        ($cur.value|tostring),
        (if $prev then (($cur.value-$prev.value)/$prev.value*100|p2|tostring) else "nan" end),
        (if $yoy then (($cur.value-$yoy.value)/$yoy.value*100|p2|tostring) else "nan" end) ] | @tsv' <<<"$body" \
    | while IFS=$'\t' read -r mon val mom yoy; do
        printf '%-10s %10s  %8s  %8s\n' "$mon" "$val" "$(pct "$mom")" "$(pct "$yoy")"
      done
}

# ---------------------------------------------------------------------------
# tvl — DeFi total value locked per chain
# ---------------------------------------------------------------------------
cmd_tvl() {
  local top="${opt_top:-10}"
  pos_int "$top" "--top"
  local body
  body="$(api_get "/api/metrilytics/chains")"
  emit_json "$body" && return 0

  # default view: one compact line with total + top chain
  if [[ -z "${opt_top:-}" ]]; then
    local line
    line="$(jq -r "$JQ_ABBR"'
      [ .chains[] as $c | { chain: $c, tvl: (((.tvl[$c] // [])[-1].tvl) // 0) } ] as $rows
      | ($rows | map(.tvl) | add) as $total
      | ($rows | sort_by(-.tvl) | .[0]) as $topc
      | "TVL · $" + ($total|abbr) + " · " + ((.chains|length)|tostring) + " chains · top: " + $topc.chain + " $" + ($topc.tvl|abbr)' <<<"$body")"
    printf '%s%s%s\n' "$c_bold" "$line" "$c_reset"
    return 0
  fi

  printf '%-12s %14s  %8s  %8s\n' "CHAIN" "TVL (USD)" "7D %" "SHARE"
  jq -r --argjson top "$top" "$JQ_ABBR"'
    [ .chains[] as $c | {
        chain: $c,
        cur: (((.tvl[$c] // [])[-1].tvl) // 0),
        prev: ((((.tvl[$c] // [])[-8].tvl) // (((.tvl[$c] // [])[0].tvl) // 0)))
      } ]
    | sort_by(-.cur)
    | .[0:($top)] as $rows
    | ($rows | map(.cur) | add) as $total
    | $rows[]
    | [ .chain,
        ("$" + (.cur|abbr)),
        ((if .prev > 0 then ((.cur - .prev)/.prev*100) else 0 end) as $d
          | (if $d >= 0 then "+" else "" end) + ((($d*100)|round)/100|tostring)),
        ((if $total > 0 then (.cur/$total*100) else 0 end) as $s
          | (((($s*100)|round)/100)|tostring)) ] | @tsv' <<<"$body" \
    | while IFS=$'\t' read -r chain tvl d7 share; do
        printf '%-12s %14s  %7s%%  %6s%%\n' "$chain" "$tvl" "$d7" "$share"
      done

  local nchains tot
  nchains="$(jq -r '.chains|length' <<<"$body")"
  tot="$(jq -r "$JQ_ABBR"' [ .chains[] as $c | (((.tvl[$c] // [])[-1].tvl) // 0) ] | add // 0 | ("$" + abbr)' <<<"$body")"
  printf '\n%sTOTAL (all %s chains): %s  ·  window: %s days  ·  source: novrix.io (DeFiLlama)%s\n' \
    "$c_dim" "$nchains" "$tot" "$(jq -r '.days // "-"' <<<"$body")" "$c_reset"
}

# ---------------------------------------------------------------------------
# generic series (driven by the SERIES registry in data.sh)
# ---------------------------------------------------------------------------
# shellcheck disable=SC2016  # tcol/ve build jq programs, $r/$v stay literal
cmd_series() {
  local name="$1"
  local entry="${SERIES[$name]:-}"
  [[ -n "$entry" ]] || die "internal error: no series '$name'"
  local path field label fmt unit period
  IFS='|' read -r path field label fmt unit period <<<"$entry"
  local body
  body="$(api_get "$path")"
  emit_json "$body" && return 0

  local n="${opt_days:-${opt_months:-1}}"
  pos_int "$n" "--days/--months"
  local ve tcol
  ve="$(series_val_expr "$fmt")"
  tcol='$r.time[0:10]'
  [[ "$period" == "monthly" ]] && tcol='$r.time[0:7]'

  if (( n <= 1 )); then
    local line val date
    line="$(jq -r --arg field "$field" "$JQ_ABBR"'
      .data | sort_by(.time) | .[-1] as $r | $r[$field] as $v
      | [ '"$ve"', '"$tcol"' ] | @tsv' <<<"$body")"
    IFS=$'\t' read -r val date <<<"$line"
    [[ -n "$unit" ]] && unit=" $unit"
    printf '%s%s%s · %s%s%s%s · %s\n' "$c_bold" "$label" "$c_reset" "$(sign_col "$val")" "$val" "$unit" "$c_reset" "$date"
    return 0
  fi

  local latest
  latest="$(jq -r --arg field "$field" "$JQ_ABBR"'
    .data | sort_by(.time) | .[-1] as $r | $r[$field] as $v
    | '"$ve"' + "\t" + '"$tcol"'' <<<"$body")"
  local lval ldate unitpad
  IFS=$'\t' read -r lval ldate <<<"$latest"
  unitpad=""
  [[ -n "$unit" ]] && unitpad=" $unit"
  printf '%s%s%s, last %s · latest: %s%s · %s\n' \
    "$c_bold" "$label" "$c_reset" "$n" "$lval" "$unitpad" "$ldate"
  printf '%-10s %16s\n' "DATE" "VALUE"
  hr 27
  jq -r --argjson n "$n" --arg field "$field" "$JQ_ABBR"'
    .data | sort_by(.time) | .[-($n):][] as $r | $r[$field] as $v
    | [ '"$tcol"', ('"$ve"') ] | @tsv' <<<"$body" \
    | while IFS=$'\t' read -r d v; do
        printf '%-10s %s%16s%s\n' "$d" "$(sign_col "$v")" "$v" "$c_reset"
      done
}

# ---------------------------------------------------------------------------
# metrilytics — summary one-liners, market snapshot, rankings
# ---------------------------------------------------------------------------
cmd_meta() {
  local name="$1"
  local prog="${META[$name]:-}"
  [[ -n "$prog" ]] || die "internal error: no metrilytics command '$name'"
  local body
  body="$(api_get "/api/metrilytics?v=$META_V")"
  emit_json "$body" && return 0
  local line
  line="$(jq -r "$JQ_ABBR$JQ_META$prog" <<<"$body")"
  printf '%s%s%s\n' "$c_bold" "$line" "$c_reset"
}

cmd_market() {
  local body
  body="$(api_get "/api/metrilytics/market?v=$META_V")"
  emit_json "$body" && return 0
  local line
  line="$(jq -r "$JQ_ABBR"'
    "MARKET · cap $" + (.market.total_market_cap_usd|abbr)
      + " · 24h vol $" + (.market.total_volume_24h_usd|abbr)
      + " · BTC dom " + ((.market.btc_dominance*100|round)/100|tostring) + "%"
      + " · " + .market.date' <<<"$body")"
  printf '%s%s%s\n' "$c_bold" "$line" "$c_reset"
}

# SC2016: rowprog is a jq program ($root/$top must stay literal)
# SC2059: rowfmt/foot are internal format strings, data arrives as arguments
# shellcheck disable=SC2016,SC2059
cmd_rank() {
  local name="$1"
  local path label rowfmt foot rowprog
  case "$name" in
    protocols)
      path="/api/metrilytics/protocols?limit=80&v=$META_V"
      label="PROTOCOLS"
      rowfmt='%-4s %-22s %-12s %14s  %7s%%\n'
      foot='Source: novrix.io/api/metrilytics/protocols · %s protocols'
      rowprog='[ .protocols[] | select(.tvl_usd != null) ] | sort_by(-.tvl_usd)
        | .[0:($top)] as $rows | ($rows | map(.tvl_usd) | add) as $total
        | $rows | to_entries[]
        | [ (.key+1|tostring),
            (.value.protocol[0:22]),
            ((.value.category // "-")[0:12]),
            ("$" + (.value.tvl_usd|abbr)),
            (((.value.tvl_usd/$total*100*100|round)/100|tostring)) ] | @tsv'
      ;;
    bridges)
      path="/api/metrilytics/bridges?limit=50&v=$META_V"
      label="BRIDGES"
      rowfmt='%-4s %-22s %-14s %14s\n'
      foot='Source: novrix.io/api/metrilytics/bridges · total $%s'
      rowprog='[ .protocols[] | select(.tvl_usd != null) ] | sort_by(-.tvl_usd)
        | .[0:($top)] | to_entries[]
        | [ (.key+1|tostring),
            (.value.protocol[0:22]),
            ((.value.chain // "-")[0:14]),
            ("$" + (.value.tvl_usd|abbr)) ] | @tsv'
      ;;
    lending)
      path="/api/metrilytics/lending?limit=50&v=$META_V"
      label="LENDING"
      rowfmt='%-4s %-20s %-12s %14s  %14s  %14s\n'
      foot='Source: novrix.io/api/metrilytics/lending · total $%s'
      rowprog='[ .protocols[] | select(.tvl_usd != null) ] | sort_by(-.tvl_usd)
        | .[0:($top)] | to_entries[]
        | [ (.key+1|tostring),
            (.value.protocol[0:20]),
            ((.value.chain // "-")[0:12]),
            ("$" + (.value.tvl_usd|abbr)),
            ("$" + ((.value.supplied_usd // 0)|abbr)),
            ("$" + ((.value.borrowed_usd // 0)|abbr)) ] | @tsv'
      ;;
    *) die "internal error: no ranking '$name'" ;;
  esac

  local top="${opt_top:-10}"
  pos_int "$top" "--top"
  local body
  body="$(api_get "$path")"
  emit_json "$body" && return 0

  # default view: one compact line
  if [[ -z "${opt_top:-}" ]]; then
    local line
    if [[ "$name" == "protocols" ]]; then
      line="$(jq -r "$JQ_ABBR"'
        . as $root | $root.protocols | sort_by(-.tvl_usd) | .[0] as $t
        | "PROTOCOLS · " + ($root.count|tostring) + " tracked · top: " + $t.protocol + " $" + ($t.tvl_usd|abbr)' <<<"$body")"
    else
      line="$(jq -r "$JQ_ABBR"'
        . as $root | $root.protocols | sort_by(-.tvl_usd) | .[0] as $t
        | "'"$label"'" + " · total $" + ($root.total|abbr) + " · top: " + $t.protocol + " $" + ($t.tvl_usd|abbr)' <<<"$body")"
    fi
    printf '%s%s%s\n' "$c_bold" "$line" "$c_reset"
    return 0
  fi

  case "$name" in
    protocols) printf '%-4s %-22s %-12s %14s  %8s\n' "RANK" "PROTOCOL" "CATEGORY" "TVL (USD)" "SHARE" ;;
    bridges)   printf '%-4s %-22s %-14s %14s\n'   "RANK" "BRIDGE" "CHAIN" "TVL (USD)" ;;
    lending)   printf '%-4s %-20s %-12s %14s  %14s  %14s\n' "RANK" "PROTOCOL" "CHAIN" "TVL (USD)" "SUPPLIED" "BORROWED" ;;
  esac
  jq -r --argjson top "$top" "$JQ_ABBR$rowprog" <<<"$body" \
    | while IFS=$'\t' read -r rank a b c d e f; do
        case "$name" in
          protocols) printf "$rowfmt" "$rank" "$a" "$b" "$c" "$d" ;;
          bridges)   printf "$rowfmt" "$rank" "$a" "$b" "$c" ;;
          lending)   printf "$rowfmt" "$rank" "$a" "$b" "$c" "$d" "$e" "$f" ;;
        esac
      done
  local footval
  if [[ "$name" == "protocols" ]]; then
    footval="$(jq -r '.count' <<<"$body")"
  else
    footval="$(jq -r "$JQ_ABBR"'.total|abbr' <<<"$body")"
  fi
  printf '\n%s%s%s\n' "$c_dim" "$(printf "$foot" "$footval")" "$c_reset"
}
