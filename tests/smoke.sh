#!/usr/bin/env bash
#
# smoke.sh — offline test suite for novrix
#
# Uses fixture responses in tests/fixtures via NOVRIX_API_DIR, so no network
# access is required. Builds bin/novrix from src/ first, then exercises the
# built artifact end-to-end. Run from the repo root:  bash tests/smoke.sh
set -euo pipefail

cd "$(dirname "$0")/.."

# assemble the single-file artifact from the src/ modules (offline + deterministic)
bash build.sh >/dev/null

BIN="./bin/novrix"
FIXTURES="$PWD/tests/fixtures"
pass=0
fail=0

ok()  { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }

check() { # check <desc> <cmd...> — expect exit 0
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

check_fails() { # check_fails <desc> <cmd...> — expect non-zero exit
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then bad "$desc"; else ok "$desc"; fi
}

printf '== build + static checks ==\n'
check "build produces artifact"   test -x "$BIN"
check "bash syntax: bin/novrix"   bash -n "$BIN"
check "bash syntax: build.sh"     bash -n build.sh
check "bash syntax: install.sh"   bash -n install.sh
check "bash syntax: smoke.sh"     bash -n "$0"
check "bash syntax: src/header.sh"    bash -n src/header.sh
check "bash syntax: src/lib/bootstrap.sh" bash -n src/lib/bootstrap.sh
check "bash syntax: src/lib/core.sh"    bash -n src/lib/core.sh
check "bash syntax: src/lib/api.sh"     bash -n src/lib/api.sh
check "bash syntax: src/lib/format.sh"  bash -n src/lib/format.sh
check "bash syntax: src/lib/data.sh"    bash -n src/lib/data.sh
check "bash syntax: src/lib/ai.sh"      bash -n src/lib/ai.sh
check "bash syntax: src/lib/telegram.sh" bash -n src/lib/telegram.sh
check "bash syntax: src/lib/typo.sh"    bash -n src/lib/typo.sh
check "bash syntax: src/lib/commands.sh" bash -n src/lib/commands.sh
check "bash syntax: src/lib/cli.sh"     bash -n src/lib/cli.sh
check "version is 1.0.0"         bash -c "$BIN --version | grep -q '1.0.0'"
check "--version works"           "$BIN" --version
check "--help works"              "$BIN" --help
check_fails "garbage command fails" bash -c "$BIN bogus"
check_fails "missing macro sub fails" bash -c "$BIN macro"

# portability guardrails — features that break bash 3.2 / busybox must not
# creep back in
check_fails "no bash-4 lowercase expansion (\${var,,})" \
  grep -nE '\$\{[a-zA-Z_]+,\,' "$BIN" src/lib/*.sh
check "pipefail tolerant" grep -q 'set -euo pipefail 2>/dev/null || set -eu' "$BIN"
check "bash-4 guard present"  grep -q 'BASH_VERSINFO' "$BIN"
check "no find -mmin (BSD/macOS)" grep -q 'file_age_min' "$BIN"
check "no hardcoded keys in repo" \
  bash -c "! grep -rn 'sk-23d8' . --include='*' | grep -v '\.git/'"

printf '\n== offline fixture tests ==\n'
export NOVRIX_API_DIR="$FIXTURES"

check "fg renders"                "$BIN" fg
check "fg --days 5 renders"       "$BIN" fg --days 5
check "fg --json is valid"        bash -c "$BIN fg --json | jq -e '.success == true'"
check "fg shows latest score"     bash -c "$BIN fg | grep -q '64'"
check_fails "fg has no gauge bar"  bash -c "$BIN fg | grep -q '\[#'"

check "nupl renders"              "$BIN" nupl
check "nupl --days 4 renders"     "$BIN" nupl --days 4
check "nupl --json is valid"      bash -c "$BIN nupl --json | jq -e '.success == true'"
check "nupl shows a zone"         bash -c "$BIN nupl | grep -qE 'Greed|Anxiety|Fear|Euphoria|Optimism|Capitulation'"
check "nupl is one line"           bash -c "[ \"\$( $BIN nupl | wc -l )\" -eq 1 ]"
check "macro cpi renders"         "$BIN" macro cpi
check "cpi alias renders"          "$BIN" cpi
check "macro cpi --months 6"       "$BIN" macro cpi --months 6
check "macro cpi --json is valid"  bash -c "$BIN macro cpi --json | jq -e '.success == true'"
check "cpi shows YoY"              bash -c "$BIN macro cpi | grep -q 'YoY'"
check "cpi is one line"            bash -c "[ \"\$( $BIN macro cpi | wc -l )\" -eq 1 ]"
check "cpi computes YoY value"     bash -c "$BIN macro cpi --months 14 | awk 'NR>2 { if (\$4 ~ /%/) y=1 } END { exit !y }'"

check "tvl renders"               "$BIN" tvl
check "tvl --top 2 renders"       "$BIN" tvl --top 2
check "tvl --json is valid"       bash -c "$BIN tvl --json | jq -e '.success == true'"
check "tvl shows ethereum"        bash -c "$BIN tvl | grep -q 'ethereum'"
check "tvl is one line"           bash -c "[ \"\$( $BIN tvl | wc -l )\" -eq 1 ]"

printf '\n== crypto sentiment series ==\n'
check "mvrv renders"              "$BIN" mvrv
check "mvrv --days 5 renders"     "$BIN" mvrv --days 5
check "mvrv --json is valid"      bash -c "$BIN mvrv --json | jq -e '.success == true'"
check "mvrv is one line"          bash -c "[ \"\$( $BIN mvrv | wc -l )\" -eq 1 ]"
check "mvrv shows value"          bash -c "$BIN mvrv | grep -q 'MVRV Z-SCORE'"
check "mvrv table has rows"       bash -c "[ \"\$( $BIN mvrv --days 5 | wc -l )\" -ge 6 ]"
check "sopr renders"              bash -c "$BIN sopr | grep -q 'SOPR'"
check "puell renders"             bash -c "$BIN puell | grep -q 'PUELL MULTIPLE'"
check "rhodl renders"             bash -c "$BIN rhodl | grep -q 'RHODL RATIO'"
check "mayer renders"             bash -c "$BIN mayer | grep -q 'MAYER MULTIPLE'"
check "reserve-risk renders"      bash -c "$BIN reserve-risk | grep -q 'RESERVE RISK'"
check "realized-price renders"    bash -c "$BIN realized-price | grep -q 'REALIZED PRICE'"
check "realized-profit renders"   bash -c "$BIN realized-profit | grep -q 'REALIZED PROFIT'"
check "realized-loss renders"     bash -c "$BIN realized-loss | grep -q 'REALIZED LOSS'"
check "realized-loss is negative" bash -c "$BIN realized-loss | grep -qF -- '-\$'"
check "market-cap renders"        bash -c "$BIN market-cap | grep -q 'MARKET CAP'"
check "btc-price renders"         bash -c "$BIN btc-price | grep -q 'BTC PRICE'"
check "btc-price value"           bash -c "$BIN btc-price | grep -q '62.76'"
check "200-week-ma renders"       bash -c "$BIN 200-week-ma | grep -q '200W MA'"
check "active-addresses renders"  bash -c "$BIN active-addresses | grep -q 'ACTIVE ADDRESSES'"
check "hashrate renders"          bash -c "$BIN hashrate | grep -q 'HASHRATE'"
check "stablecoin-supply renders" bash -c "$BIN stablecoin-supply | grep -q 'STABLECOIN SUPPLY'"
check "open-interest renders"     bash -c "$BIN open-interest | grep -q 'OPEN INTEREST'"
check "funding-rate renders"      bash -c "$BIN funding-rate | grep -q 'FUNDING RATE'"
check "etf renders"               bash -c "$BIN etf | grep -q 'ETF'"
check "etf has units"             bash -c "$BIN etf | grep -q 'BTC'"
check "sentiment series one line" bash -c "[ \"\$( $BIN mvrv | wc -l )\" -eq 1 ]"
check_fails "sentiment bad days"  bash -c "$BIN mvrv --days nope"

printf '\n== macro series ==\n'
check "unrate renders"            bash -c "$BIN unrate | grep -q 'UNEMPLOYMENT'"
check "unrate value"              bash -c "$BIN unrate | grep -q '4.3'"
check "unrate --months 4"         "$BIN" unrate --months 4
check "unrate --json is valid"    bash -c "$BIN unrate --json | jq -e '.success == true'"
check "unrate is one line"        bash -c "[ \"\$( $BIN unrate | wc -l )\" -eq 1 ]"
check "gdp renders"               bash -c "$BIN gdp | grep -q 'US GDP'"
check "payrolls renders"          bash -c "$BIN payrolls | grep -q 'PAYROLLS'"
check "claims renders"            bash -c "$BIN claims | grep -q 'CLAIMS'"
check "job-openings renders"      bash -c "$BIN job-openings | grep -q 'JOB OPENINGS'"
check "core-cpi renders"          bash -c "$BIN core-cpi | grep -q 'CORE CPI'"
check "pce renders"               bash -c "$BIN pce | grep -q 'PCE PRICE INDEX'"
check "core-pce renders"          bash -c "$BIN core-pce | grep -q 'CORE PCE'"
check "umich renders"             bash -c "$BIN umich | grep -q 'SENTIMENT'"
check "oil renders"               bash -c "$BIN oil | grep -q 'WTI OIL'"
check "us30y renders"             bash -c "$BIN us30y | grep -q '30Y YIELD'"
check "us30y value"               bash -c "$BIN us30y | grep -q '5.03'"
check "t10y2y renders"            bash -c "$BIN t10y2y | grep -q '10Y-2Y'"
check "breakeven renders"         bash -c "$BIN breakeven | grep -q 'BREAKEVEN'"
check "dxy renders"               bash -c "$BIN dxy | grep -q 'DOLLAR INDEX'"
check "gold renders"              bash -c "$BIN gold | grep -q 'GOLD'"
check "sp500 renders"             bash -c "$BIN sp500 | grep -q 'S&P 500'"
check "vix renders"               bash -c "$BIN vix | grep -q 'VIX'"
check "fedfunds renders"          bash -c "$BIN fedfunds | grep -q 'FED FUNDS'"
check "m2 renders"                bash -c "$BIN m2 | grep -q 'M2'"
check "m2 abbreviated"            bash -c "$BIN m2 | grep -q 'T'"
check "macro monthly table"       bash -c "$BIN fedfunds --months 3 | grep -q '2026-04'"
check_fails "macro bad months"    bash -c "$BIN gdp --months 0"

printf '\n== metrilytics ==\n'
check "defi renders"              bash -c "$BIN defi | grep -q 'DEFI TVL'"
check "defi is one line"          bash -c "[ \"\$( $BIN defi | wc -l )\" -eq 1 ]"
check "defi shows top chain"      bash -c "$BIN defi | grep -q 'ethereum'"
check "market renders"            bash -c "$BIN market | grep -q 'MARKET · cap'"
check "market --json is valid"    bash -c "$BIN market --json | jq -e '.success == true'"
check "stablecoins renders"       bash -c "$BIN stablecoins | grep -q 'STABLECOIN SUPPLY'"
check "dex renders"               bash -c "$BIN dex | grep -q 'DEX VOLUME'"
check "fees renders"              bash -c "$BIN fees | grep -q 'FEES 24H'"
check "options renders"           bash -c "$BIN options | grep -q 'OPTIONS VOLUME'"
check "dominance renders"         bash -c "$BIN dominance | grep -q 'DOMINANCE'"
check "dominance shows btc"       bash -c "$BIN dominance | grep -q 'BTC'"
check "prices renders"            bash -c "$BIN prices | grep -q 'PRICES'"
check "oi renders"                bash -c "$BIN oi | grep -q 'OPEN INTEREST'"
check "protocols renders"         bash -c "$BIN protocols | grep -q 'PROTOCOLS'"
check "protocols --top 5"         "$BIN" protocols --top 5
check "protocols table header"    bash -c "$BIN protocols --top 5 | grep -q 'RANK'"
check "protocols top is Binance"  bash -c "$BIN protocols --top 3 | grep -q 'Binance'"
check "protocols --json valid"    bash -c "$BIN protocols --json | jq -e '.success == true'"
check "bridges renders"           bash -c "$BIN bridges | grep -q 'BRIDGES'"
check "bridges --top 3"           bash -c "$BIN bridges --top 3 | grep -q 'WBTC'"
check "lending renders"           bash -c "$BIN lending | grep -q 'LENDING'"
check "lending --top 3"           bash -c "$BIN lending --top 3 | grep -q 'Aave'"
check_fails "rankings bad top"    bash -c "$BIN protocols --top nope"

printf '\n== short aliases ==\n'
check "shortcuts renders"         bash -c "$BIN shortcuts | grep -q 'shortest form'"
check "shortcuts lists rr"        bash -c "$BIN shortcuts | grep -q 'rr'"
check "rr = reserve-risk"         bash -c "$BIN rr | grep -q 'RESERVE RISK'"
check "rp = realized-price"       bash -c "$BIN rp | grep -q 'REALIZED PRICE'"
check "rpf = realized-profit"     bash -c "$BIN rpf | grep -q 'REALIZED PROFIT'"
check "rpl = realized-loss"       bash -c "$BIN rpl | grep -q 'REALIZED LOSS'"
check "mcap = market-cap"         bash -c "$BIN mcap | grep -q 'MARKET CAP'"
check "btc = btc-price"           bash -c "$BIN btc | grep -q 'BTC PRICE'"
check "200ma = 200-week-ma"       bash -c "$BIN 200ma | grep -q '200W MA'"
check "addrs = active-addresses"  bash -c "$BIN addrs | grep -q 'ACTIVE ADDRESSES'"
check "hash = hashrate"           bash -c "$BIN hash | grep -q 'HASHRATE'"
check "scs = stablecoin-supply"   bash -c "$BIN scs | grep -q 'STABLECOIN SUPPLY'"
check "btoi = open-interest"      bash -c "$BIN btoi | grep -q 'OPEN INTEREST'"
check "funding = funding-rate"    bash -c "$BIN funding | grep -q 'FUNDING RATE'"
check "nfp = payrolls"            bash -c "$BIN nfp | grep -q 'PAYROLLS'"
check "jolts = job-openings"      bash -c "$BIN jolts | grep -q 'JOB OPENINGS'"
check "ccpi = core-cpi"           bash -c "$BIN ccpi | grep -q 'CORE CPI'"
check "cpce = core-pce"           bash -c "$BIN cpce | grep -q 'CORE PCE'"
check "t30 = us30y"               bash -c "$BIN t30 | grep -q '30Y YIELD'"
check "curve = t10y2y"            bash -c "$BIN curve | grep -q '10Y-2Y'"
check "be = breakeven"            bash -c "$BIN be | grep -q 'BREAKEVEN'"
check "spx = sp500"               bash -c "$BIN spx | grep -q 'S&P 500'"
check "ffr = fedfunds"            bash -c "$BIN ffr | grep -q 'FED FUNDS'"
check "mkt = market"              bash -c "$BIN mkt | grep -q 'MARKET · cap'"
check "stables = stablecoins"     bash -c "$BIN stables | grep -q 'STABLECOIN SUPPLY'"
check "dom = dominance"           bash -c "$BIN dom | grep -q 'DOMINANCE'"
check "opts = options"            bash -c "$BIN opts | grep -q 'OPTIONS VOLUME'"
check "prots = protocols"         bash -c "$BIN prots | grep -q 'PROTOCOLS'"
check "prots --top 3"             bash -c "$BIN prots --top 3 | grep -q 'RANK'"
check "alias one line"            bash -c "[ \"\$( $BIN btc | wc -l )\" -eq 1 ]"
check "alias --days works"        bash -c "$BIN rr --days 3 | grep -q 'RESERVE RISK'"
check "alias --json valid"        bash -c "$BIN btc --json | jq -e '.success == true'"
check "long names still work"     bash -c "$BIN reserve-risk | grep -q 'RESERVE RISK'"

printf '\n== AI agent + typo auto-fix ==\n'
check "ai command renders"        bash -c "$BIN ai hello | grep -q 'fixture'"
check "ai alias ask works"        bash -c "$BIN ask hello | grep -q 'fixture'"
check "ai is one line"            bash -c "[ \"\$( $BIN ai hello | wc -l )\" -eq 1 ]"
check "fuzzy fixes simple typo"   bash -c "$BIN mvrvv | grep -q 'MVRV Z-SCORE'"
check "fuzzy fixes case"          bash -c "$BIN MVRV | grep -q 'MVRV Z-SCORE'"
check "fuzzy fixes missing char"  bash -c "$BIN mket | grep -q 'MARKET · cap'"
check "fuzzy typo one line"       bash -c "[ \"\$( $BIN mvrvv | wc -l )\" -eq 1 ]"
check "typo shows running it"   bash -c "$BIN mvrvv 2>&1 | grep -q 'running it'"
check "typo never says unknown"  bash -c "! $BIN mvrvv 2>&1 | grep -q 'unknown command'"
check "AI fixes hard typo"        bash -c "NOVRIX_AI_FIXTURE=ai_matcher_mvrv $BIN zzzzz 2>&1 | grep -q 'MVRV Z-SCORE'"
check "AI answer validated"       bash -c "NOVRIX_AI_FIXTURE=ai_matcher_mvrv $BIN zzzzz 2>&1 | grep -q 'running it'"
check_fails "unresolvable typo"   bash -c "$BIN zzzzz"
check_fails "far typo no AI fix"  bash -c "$BIN rrreserve"
check "AI fixes fgredd"           bash -c "NOVRIX_AI_FIXTURE=ai_matcher_fg $BIN fgredd 2>&1 | grep -q 'FEAR & GREED'"
check "AI reads fgredd"           bash -c "NOVRIX_AI_FIXTURE=ai_matcher_fg $BIN fgredd 2>&1 | grep -q 'you mean \"fg\"'"
check "AI spinner text in artifact" bash -c "grep -q 'wtf is' $BIN"
check "spinner texts in artifact"  bash -c "grep -q 'answering in a sec' $BIN"
# shellcheck disable=SC2016  # $ in bash -c test strings expands inside the subshell, intentionally
check "spinner silent when piped" bash -c 'PROG=novrix; source src/lib/core.sh; e="$(spinner_run "reading techleaks..." sleep 0.3 2>&1 >/dev/null)"; [ -z "$e" ]'
# shellcheck disable=SC2016
check "spinner cycles and erases line" bash -c 'PROG=novrix; source src/lib/core.sh; sleep 60 & p=$!; e="$(_spinner_animate "reading techleaks..." "$p" 40 2>&1 >/dev/null)"; kill "$p" 2>/dev/null; wait "$p" 2>/dev/null; case "$e" in *"working..."*"$(printf "\033[2K")"*) exit 0 ;; *) exit 1 ;; esac'
check "no-match asks what meant"  bash -c "NOVRIX_AI_FIXTURE=ai_matcher $BIN fgredd 2>&1 | grep -q 'what did you mean'"
check_fails "no-match exits nonzero" bash -c "NOVRIX_AI_FIXTURE=ai_matcher $BIN fgredd"
check "fucking trolls"            bash -c "$BIN fucking 2>&1 | grep -q 'you fucking retard'"
check_fails "fucking not funding" bash -c "$BIN fucking 2>&1 | grep -q 'FUNDING RATE'"
check "fck variant trolls"        bash -c "$BIN fck 2>&1 | grep -q 'family CLI'"
check "wtf trolls"                bash -c "$BIN wtf 2>&1 | grep -q 'chill lol'"
check "phrase trolls"             bash -c "$BIN fucking hell 2>&1 | grep -q 'retard'"
check "interactive troll"         bash -c "printf 'fucking\nquit\n' | $BIN 2>&1 | grep -q 'you fucking retard'"
check "normal cmds not trolled"   bash -c "$BIN mvrv | grep -q 'MVRV Z-SCORE'"
check "typo fix in interactive"   bash -c "printf 'mvrvv\nquit\n' | $BIN | grep -q 'MVRV Z-SCORE'"
check "ai works in interactive"   bash -c "printf 'ai hello\nquit\n' | $BIN | grep -q 'fixture'"
check "bare ai greets"            bash -c "$BIN ai | grep -q 'fixture'"
check "bare ai one line"          bash -c "[ \"\$( $BIN ai | wc -l )\" -eq 1 ]"
check "hey chats"                 bash -c "$BIN hey | grep -q 'fixture'"
check "yes chats"                 bash -c "$BIN yes | grep -q 'fixture'"
check "crypto guy chats"          bash -c "$BIN 'hey crypto guy' | grep -q 'fixture'"
check "macro guy chats"           bash -c "$BIN macro guy | grep -q 'fixture'"
check "bare ai in REPL"           bash -c "printf 'novrix ai\nquit\n' | $BIN | grep -q 'fixture'"
check "cmd words answer with data" bash -c "$BIN 'spx looking good, what is its price?' | grep -q 'S&P 500'"
check "cmd words in REPL"          bash -c "printf 'spx looking good, what is its price?\nquit\n' | $BIN | grep -q 'S&P 500'"
check "cmd words fallback to ai"   bash -c "$BIN 'fg how does it work?' | grep -q 'fixture'"
check "the date of to ai"        bash -c "$BIN 'the date of financial crisis beginning' | grep -q 'fixture'"
check "the date of in REPL"      bash -c "printf 'the date of financial crisis beginning\nquit\n' | $BIN | grep -q 'fixture'"
check "the difference to ai"     bash -c "$BIN 'the difference between a bull and a bear market' | grep -q 'fixture'"
check "the meaning of to ai"     bash -c "$BIN 'the meaning of mvrv' | grep -q 'fixture'"
check "the best to ai"           bash -c "$BIN 'the best privacy coin right now' | grep -q 'fixture'"
check "the latest to ai"         bash -c "$BIN 'the latest market outlook' | grep -q 'fixture'"
check "follow-up inherits series" bash -c "printf 'what about btc price, for yesterday?\nfor today?\nquit\n' | $BIN | grep -c '^BTC PRICE' | grep -q '^2$'"
check "bare follow-up one-shot"   bash -c "$BIN 'for today?' | grep -q 'fixture'"
check "bare follow-up in REPL"    bash -c "printf 'for today?\nquit\n' | $BIN | grep -q 'fixture'"
check "AI fixes single fear"    bash -c "NOVRIX_AI_FIXTURE=ai_matcher_fg $BIN fear | grep -q 'FEAR & GREED'"
check "AI understands phrase"   bash -c "NOVRIX_AI_FIXTURE=ai_matcher_fg $BIN fear and greed index 2>&1 | grep -q 'FEAR & GREED'"
check "phrase drops extra words" bash -c "[ \"\$( NOVRIX_AI_FIXTURE=ai_matcher_fg $BIN fear and greed index 2>/dev/null | wc -l )\" -eq 1 ]"
check "ai fg exact date"       bash -c "$BIN ai 'fear and greed on 22 december 2022' | grep -q '2022-12-22'"
check "ai fg last 10 days"     bash -c "$BIN ai 'last 10 days of fear and greed index' | grep -q 'FEAR & GREED'"
check "bare fg exact date"     bash -c "$BIN 'fear and greed index data of 22 december 2022' | grep -q '2022-12-22'"
check "bare fg 10 days"        bash -c "$BIN 'give me the last 10 days of fear and greed' | grep -q 'FEAR & GREED'"
check "fg last 10 days as table" bash -c "$BIN 'give me the last 10 days of fear and greed' | grep -q 'SCORE'"
check_fails "fg table has no gauge" bash -c "$BIN 'give me the last 10 days of fear and greed' | grep -q 'GAUGE'"
check_fails "nupl table has no bar" bash -c "$BIN nupl --days 5 | grep -q 'DISTRIBUTION'"
check "fg last 10 days rows"    bash -c "[ \"\$( $BIN 'give me the last 10 days of fear and greed' | grep -cE '^20[0-9]{2}-' )\" -ge 10 ]"
check "fg last 10 days zone col" bash -c "$BIN 'give me the last 10 days of fear and greed' | grep -q 'ZONE'"
check "mvrv exact date"        bash -c "$BIN 'mvrv on 22 december 2022' | grep -q 'MVRV Z-SCORE'"
check "nupl exact date 2014"   bash -c "$BIN 'nupl for 2014, 15 january' | grep -q '0.652'"
check "ai nupl exact date"     bash -c "$BIN ai 'nupl for 2014, 15 january' | grep -q '0.652'"
check "btc price jan 2014"     bash -c "$BIN 'btc price on 15 january 2014' | grep -q '941'"
check "year summary mvrv"      bash -c "$BIN 'mvrv for 2014' | grep -q 'avg'"
check "nupl year summary"      bash -c "$BIN 'nupl 2014' | grep -q 'avg'"
check "fg year summary"        bash -c "$BIN 'fear and greed in 2022' | grep -q 'avg'"
check "monthly collapse unrate" bash -c "$BIN 'unemployment rate in january 2014' | grep -q '6.6'"
check "cpi january 2014"       bash -c "$BIN 'cpi for january 2014' | grep -q '235'"
check "fg phrase date one-shot" bash -c "$BIN 'fear and greed index 15 january 2024' | grep -q '2024-01-15'"
check "fg cmd date args"       bash -c "$BIN fg 15 january 2025 | grep -q '2025-01-15'"
check "fg date in REPL"        bash -c "printf 'fear and greed index 15 january 2024\nquit\n' | $BIN | grep -q '2024-01-15'"
check "fg range dec 2022"      bash -c "$BIN 'give me the range of fear and greed index for 10 days from 19 december 2022 to 24 december 2022' | grep -q '2022-12-24'"
check_fails "no gauge in range" bash -c "$BIN 'give me the range of fear and greed index for 10 days from 19 december 2022 to 24 december 2022' | grep -q 'GAUGE'"

printf '\n== multiple series at once ==\n'
check "multi answers fg"         bash -c "$BIN 'nupl and fear and greed index' | grep -q 'FEAR & GREED'"
check "multi answers nupl"       bash -c "$BIN 'nupl and fear and greed index' | grep -q '^NUPL'"
check "multi latest one-liners"  bash -c "[ \"\$( $BIN 'nupl and fear and greed index' | grep -c '·' )\" -eq 2 ]"
check "multi and-split order"    bash -c "$BIN 'fear and greed index and nupl' | grep -q 'FEAR & GREED'"
check "multi with range"         bash -c "$BIN 'nupl and fear and greed from 10 to 20 august 2021' | grep -q '2021-08-20'"
check "multi in REPL"            bash -c "printf 'nupl and fear and greed index\nquit\n' | $BIN | grep -q 'FEAR & GREED'"
check_fails "price catch-all not duplicated" bash -c "$BIN 'spx looking good, what is its price?' | grep -q 'PRICES'"

printf '\n== date ranges ==\n'
check "fg range all 11 days"       bash -c "[ \"\$( $BIN 'give me data of fear and greed index from 10 january to 20 january, 2022' | grep -cE '^2022-01-1[0-9]|^2022-01-20' )\" -eq 11 ]"
check "fg range header"            bash -c "$BIN 'fear and greed from 10 january to 20 january, 2022' | grep -q 'FEAR & GREED INDEX · 2022-01-10 to 2022-01-20'"
check "fg range zone"              bash -c "$BIN 'fear and greed from 10 january to 20 january, 2022' | grep -q 'Extreme Fear'"
check "fg range bare days"         bash -c "$BIN 'fear and greed from 10 to 20 january 2022' | grep -q '2022-01-20'"
check "fg range month-first"       bash -c "$BIN 'fear and greed from january 10 to january 20, 2022' | grep -q '2022-01-10'"
check "fg range full dates"        bash -c "$BIN 'fear and greed 10 january 2022 to 20 january 2022' | grep -q '2022-01-15'"
check "fg range through"           bash -c "$BIN 'fear and greed from 10 through 20 january 2022' | grep -q '2022-01-12'"
check "generic range daily"        bash -c "$BIN 'vix from 5 to 8 january 1990' | grep -q '20.11'"
check "generic range monthly"      bash -c "$BIN 'umich from 1 january to 1 march 2022' | grep -q '2022-02'"
check "m2 range abbr"              bash -c "$BIN 'm2 from 1 january to 1 april 2022' | grep -q '21.65T'"
check "sp500 range values"         bash -c "$BIN 'sp500 from 2 to 5 january 2022' | grep -q '4796.56'"
check "nupl range renders"         bash -c "$BIN 'nupl from 1 to 3 july 2026' | grep -q '0.1589'"
check "fred range fallback"        bash -c "$BIN 'cpi from 1 december 1998 to 1 january 1999' | grep -q '164.3'"
check "fred oil range"             bash -c "$BIN 'oil from 5 to 8 january 1988' | grep -q '17.08'"
check "range empty to ai"          bash -c "NOVRIX_AI_FIXTURE=ai_chat $BIN fg from 1 to 5 january 2010 2>&1 | grep -q 'Hello from the AI fixture'"
check "range in REPL"              bash -c "printf 'vix from 5 to 8 january 1990\nquit\n' | $BIN | grep -q '20.11'"
check "missing history to ai"   bash -c "NOVRIX_AI_FIXTURE=ai_chat $BIN fg 15 january 2010 2>&1 | grep -q 'Hello from the AI fixture'"
check "fred unrate 1989 month"  bash -c "$BIN 'unemployment rate in december 1989' | grep -q '5.3%'"
check "fred unrate marks source" bash -c "$BIN 'unemployment rate in december 1989' | grep -q 'FRED'"
check "fred cpi 1999 month"      bash -c "$BIN 'cpi for january 1999' | grep -q '164.3'"
check "fred oil 1988 exact"      bash -c "$BIN 'oil price on 15 january 1988' | grep -q '17.1'"
check "fred oil 1988 year"       bash -c "$BIN 'oil in 1988' | grep -q 'avg'"
check "fred year shows source"   bash -c "$BIN 'oil in 1988' | grep -q 'FRED'"
check "fred missing to ai"       bash -c "NOVRIX_AI_FIXTURE=ai_chat $BIN tell me sp500 price on 12 december 1999 2>&1 | grep -q 'Hello from the AI fixture'"
check "question routes to ai"  bash -c "$BIN 'who are you?' | grep -q 'fixture'"
check "putin gets trolled"     bash -c "$BIN 'who is vladimir putin' 2>&1 | grep -q 'chain'"
check_fails "fear alone not fuzzy" bash -c "$BIN fearx"
check "fuzzy self-fix no loop"  bash -c "$BIN cleaar >/dev/null 2>&1"
check "one-shot clear exits"    bash -c "$BIN clear >/dev/null 2>&1"
check "case-insensitive MVRV"   bash -c "$BIN MVRV | grep -q 'MVRV Z-SCORE'"

check_fails "option validation"       bash -c "$BIN fg --days nope"

printf '\n== telegram channel ==\n'
check "telegram renders"            bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN telegram | grep -q 'TELEGRAM'"
check "telegram shows caption"      bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN telegram | grep -q 'BTC dominance'"
check "telegram shows chart url"    bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN telegram | grep -q 'chart:'"
check "telegram latest only"        bash -c "[ \"\$( NOVRIX_TELEGRAM_CHANNEL=novrix $BIN telegram | grep -c '^TELEGRAM' )\" -eq 1 ]"
check "telegram N posts"            bash -c "[ \"\$( NOVRIX_TELEGRAM_CHANNEL=novrix $BIN telegram 2 | grep -c '^TELEGRAM' )\" -eq 2 ]"
check "telegram fresh ok"           bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN telegram --fresh | grep -q 'TELEGRAM'"
check "tg alias works"              bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN tg | grep -q 'TELEGRAM'"
check "telegram decodes entities"   bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN telegram 2 | grep -q 'FEAR & GREED'"
check_fails "telegram skips emoji img" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN telegram 2 | grep -q 'emoji'"
check_fails "telegram no channel"   bash -c "HOME='$PWD' env -u XDG_CONFIG_HOME -u NOVRIX_TELEGRAM_CHANNEL $BIN telegram"
check "whats new routes to telegram" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what's new on crypto?\" | grep -q 'NEW ON TELEGRAM'"
check "whats new has AI description" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what's new on crypto?\" | grep -q 'AI fixture'"
check_fails "whats new no chart line" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what's new on crypto?\" | grep -q 'chart:'"
check "whats new in REPL"           bash -c "echo \"what's new on crypto?\" | NOVRIX_TELEGRAM_CHANNEL=novrix $BIN | grep -q 'NEW ON TELEGRAM'"
check "whats new falls back to ai"  bash -c "HOME='$PWD' env -u XDG_CONFIG_HOME -u NOVRIX_TELEGRAM_CHANNEL $BIN \"what's new on crypto?\" | grep -q 'fixture'"
check "telegram shows forwarded"    bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN telegram 4 | grep -q 'Forwarded from Bull Case'"
check "whats new mentions forwarded" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what's new on crypto?\" | grep -q 'Forwarded from Bull Case'"
check "last posts lists all posts"  bash -c "[ \"\$( NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"which are the last posts?\" | grep -c '^TELEGRAM' )\" -eq 4 ]"
check "last posts shows forwarded"  bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"which are the last posts?\" | grep -q 'Forwarded from Bull Case'"
check "last posts shows text"       bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"which are the last posts?\" | grep -q 'Whale wallets'"
check_fails "last posts no chart line" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"which are the last posts?\" | grep -q 'chart:'"
check "last posts in REPL"          bash -c "echo \"what are the last posts?\" | NOVRIX_TELEGRAM_CHANNEL=novrix $BIN | grep -q 'LAST POSTS'"
check "last 3 posts honors number"  bash -c "[ \"\$( NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"show the last 3 posts\" | grep -c '^TELEGRAM' )\" -eq 3 ]"
check "last posts falls back to ai" bash -c "HOME='$PWD' env -u XDG_CONFIG_HOME -u NOVRIX_TELEGRAM_CHANNEL $BIN \"which are the last posts?\" | grep -q 'fixture'"
check "monero routes to techleaks"  bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"is monero traceable?\" | grep -q 'TECHLEAKS ANALYSIS'"
check "techleaks answers with ai"   bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"is monero traceable?\" | grep -q 'AI fixture'"
check "techleaks channel handle"    bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"is monero traceable?\" | grep -q '@techleaks24'"
check "techleaks feeds post texts"  bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"is monero traceable?\" >/dev/null"
# shellcheck disable=SC2016  # $ expands inside the bash -c subshell, intentionally
check_fails "techleaks answer clean when piped" bash -c 'NOVRIX_TELEGRAM_CHANNEL=novrix ./bin/novrix "is monero traceable?" 2>&1 | grep -q "$(printf "\r")"'
check "xmr routes to techleaks"     bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what about xmr?\" | grep -q 'TECHLEAKS ANALYSIS'"
check "dero routes to techleaks"    bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"is dero untraceable?\" | grep -q 'TECHLEAKS ANALYSIS'"
check "zcash routes to techleaks"   bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"is zcash private?\" | grep -q 'TECHLEAKS ANALYSIS'"
check "privacy question in REPL"    bash -c "echo \"what about privacy coins?\" | NOVRIX_TELEGRAM_CHANNEL=novrix $BIN | grep -q 'TECHLEAKS ANALYSIS'"
check "privacy honors custom channel" bash -c "NOVRIX_PRIVACY_CHANNEL=novrix $BIN \"is monero traceable?\" | grep -q '@novrix'"
check_fails "whats new not privacy" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what's new on crypto?\" | grep -q 'TECHLEAKS ANALYSIS'"
check "bare dero mention to techleaks" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"but explain dero in depth\" | grep -q 'TECHLEAKS ANALYSIS'"
check "dero tech routes to techleaks" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"i want to know dero tech, what techniques do they use\" | grep -q 'TECHLEAKS ANALYSIS'"
check "bare dero mention in REPL"   bash -c "printf 'but explain dero in depth, I want to know dero tech, what techniques do they use\nquit\n' | NOVRIX_TELEGRAM_CHANNEL=novrix $BIN | grep -q 'TECHLEAKS ANALYSIS'"
check "bare privacy coin in REPL"   bash -c "printf 'explain monero to me\nquit\n' | NOVRIX_TELEGRAM_CHANNEL=novrix $BIN | grep -q 'TECHLEAKS ANALYSIS'"
check "privacy comparison header"    bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"compare dero and monero\" | grep -q 'PRIVACY COINS · COMPARISON'"
check "comparison lists dero"        bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"compare dero and monero\" | grep -q 'DERO'"
check "comparison lists monero"      bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"compare dero and monero\" | grep -q 'MONERO'"
check "comparison lists zcash"       bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"make a table comparing all privacy coins\" | grep -q 'ZCASH'"
check_fails "comparison omits unasked coin" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"compare dero and monero\" | grep -q 'ZCASH'"
check "comparison untraceable row"   bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"compare dero and monero\" | grep -q 'untraceable on chain'"
check "comparison yes marks"         bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"compare dero and monero\" | grep -q '✓'"
check "comparison channel take"      bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"compare dero and monero\" | grep -q 'only coin not traceable'"
check_fails "no table unless asked"  bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"is monero traceable?\" | grep -q 'PRIVACY COINS'"
check "no table unless asked one-shot" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"tell me anything about privacy coins?\" | grep -q 'TECHLEAKS ANALYSIS'"
check "specified post matches"     bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"which is the last posts, tell me the one with whale wallets\" | grep -q 'Whale wallets'"
check "specified post marked"      bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"which is the last posts, tell me the one with whale wallets\" | grep -q 'POST MATCH'"
check_fails "specified post only one" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"which is the last posts, tell me the one with whale wallets\" | grep -q 'MVRV Z-Score'"
check "specified post newest"      bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"which are the last posts about greed zone?\" | grep -q 'Greed zone'"
check "specified post ai pick"     bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"which post talked about the fed\" | grep -q 'dominance'"
check "specified post in REPL"     bash -c "echo \"tell me the one with whale wallets\" | NOVRIX_TELEGRAM_CHANNEL=novrix $BIN | grep -q 'Whale wallets'"
check_fails "weak which one not post" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"which one should i pick?\" | grep -q 'POST MATCH'"
check "weak which one falls to ai" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"which one should i pick?\" | grep -q 'fixture'"

printf '\n== novrix channel stance ==\n'
check "novrix stance routes"       bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what does novrix think about the market?\" | grep -q 'NOVRIX ANALYSIS'"
check "novrix stance uses ai"      bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what does novrix think about the market?\" | grep -q 'AI fixture'"
check "novrix stance in REPL"      bash -c "echo \"what does novrix think about ai?\" | NOVRIX_TELEGRAM_CHANNEL=novrix $BIN | grep -q 'NOVRIX ANALYSIS'"
check "novrix bearish"             bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"is novrix bullish or bearish right now?\" | grep -q 'NOVRIX ANALYSIS'"
check "novrix posting lately"      bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what is novrix posting lately?\" | grep -q 'NOVRIX ANALYSIS'"
check "novrix chinese ai"          bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what does novrix think about chinese ai?\" | grep -q 'NOVRIX ANALYSIS'"
check_fails "novrix what is not stance" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what is novrix?\" | grep -q 'NOVRIX ANALYSIS'"
check "novrix what is falls to ai" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what is novrix?\" | grep -q 'fixture'"
check "latest novrix post stays post" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what is the latest post on the novrix channel?\" | grep -q 'NEW ON TELEGRAM'"
check "novrix privacy goes novrix" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what does novrix think about privacy coins?\" | grep -q 'NOVRIX ANALYSIS'"
check "novrix forward routes"      bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what does novrix forward?\" | grep -q 'NOVRIX ANALYSIS'"
check "novrix bullcase routes"     bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"does novrix repost bullcase?\" | grep -q 'NOVRIX ANALYSIS'"
check "posts carry forward source" bash -c 'PROG=novrix; source src/lib/bootstrap.sh; source src/lib/core.sh; source src/lib/telegram.sh; channel_posts novrix 20 | grep -q "Forwarded from Bull Case"'
check "novrix prompt names bullcase" bash -c "grep -q 'Bull Case (@bullcase)' $BIN"
check "novrix prompt no thesis"    bash -c "grep -q 'no thesis of its own' $BIN"
check "novrix prompt no privacy coins" bash -c "grep -q 'Do not bring up Dero' $BIN"
check "privacy fully based on techleaks" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"which coin is the king of privacy coins?\" | grep -q 'TECHLEAKS ANALYSIS'"
check "privacy tech triggers"      bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"what is the best privacy tech right now?\" | grep -q 'TECHLEAKS ANALYSIS'"
check_fails "private key not privacy" bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"how do i store my private key?\" | grep -q 'TECHLEAKS ANALYSIS'"
check "private key falls to ai"    bash -c "NOVRIX_TELEGRAM_CHANNEL=novrix $BIN \"how do i store my private key?\" | grep -q 'fixture'"
check "no king guardrail in source" bash -c "grep -q 'king of privacy coins' $BIN"

printf '\n== interactive mode ==\n'
check "interactive fg works"       bash -c "printf 'fg\nquit\n' | $BIN | grep -q 'FEAR & GREED'"
check "interactive nupl works"     bash -c "printf 'nupl\nexit\n' | $BIN | grep -q 'NUPL'"
check "interactive cpi works"      bash -c "printf 'macro cpi\nquit\n' | $BIN | grep -q 'US CPI'"
check "interactive survives err"   bash -c "printf 'bogus\nfg\nquit\n' | $BIN | grep -q 'FEAR & GREED'"
check "novrix prefix in shell"     bash -c "printf 'novrix ai hello\nquit\n' | $BIN | grep -q 'fixture'"
check "novrix prefix bare"         bash -c "printf 'novrix\nquit\n' | $BIN | grep -q 'USAGE'"
check "ai question in shell"       bash -c "printf 'who are you?\nquit\n' | $BIN | grep -q 'fixture'"
check "interactive help works"     bash -c "printf 'help\nquit\n' | $BIN | grep -q 'USAGE'"
check "interactive exits clean"    bash -c "printf 'quit\n' | $BIN >/dev/null 2>&1"
check "interactive mvrv works"     bash -c "printf 'mvrv\nquit\n' | $BIN | grep -q 'MVRV Z-SCORE'"
check "interactive unrate works"   bash -c "printf 'unrate\nquit\n' | $BIN | grep -q 'UNEMPLOYMENT'"
check "interactive defi works"     bash -c "printf 'defi\nquit\n' | $BIN | grep -q 'DEFI TVL'"
check "interactive protocols"      bash -c "printf 'protocols --top 3\nquit\n' | $BIN | grep -q 'RANK'"
check "interactive banner"         bash -c "printf 'quit\n' | $BIN | grep -q 'macro:'"
check "interactive banner tip"     bash -c "printf 'quit\n' | $BIN | grep -q 'tip:'"
check "interactive btc works"     bash -c "printf 'btc\nquit\n' | $BIN | grep -q 'BTC PRICE'"
check "interactive dom works"     bash -c "printf 'dom\nquit\n' | $BIN | grep -q 'DOMINANCE'"
check "interactive shortcuts"     bash -c "printf 'shortcuts\nquit\n' | $BIN | grep -q 'shortest form'"

printf '\n== environment ==\n'
check "NOVRIX_TTL honored"          bash -c "NOVRIX_TTL=600 $BIN fg >/dev/null"
check_fails "NOVRIX_TTL invalid"    bash -c "NOVRIX_TTL=soon $BIN fg"
check "missing AI key shows hint"   bash -c "env -u NOVRIX_API_DIR -u DEEPSEEK_API_KEY -u XDG_CONFIG_HOME HOME='$PWD' $BIN zzzzzzzz 2>&1 | grep -q 'DEEPSEEK_API_KEY'"
check_fails "missing AI key exits"  bash -c "env -u NOVRIX_API_DIR -u DEEPSEEK_API_KEY -u XDG_CONFIG_HOME HOME='$PWD' $BIN zzzzzzzz >/dev/null 2>&1"
unset NOVRIX_API_DIR

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
