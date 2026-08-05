# novrix

> **Market data for crypto, macro, and DeFi — right in your terminal.**
> A single-file CLI that turns [NOVRIX](https://novrix.io) public APIs into
> clean one-line summaries and tables, understands your typos, and comes with
> a DeepSeek-powered AI agent that always knows what you meant.

[![Release](https://img.shields.io/github/v/release/ethanhunthere/novrix-cli?style=flat-square&logo=github&color=4f46e5)](https://github.com/ethanhunthere/novrix-cli/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/ethanhunthere/novrix-cli/ci.yml?branch=main&style=flat-square&label=CI&logo=githubactions&logoColor=white)](https://github.com/ethanhunthere/novrix-cli/actions)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows%20%7C%20BSD-64748b?style=flat-square)]()

**60+ commands** · **bash + curl + jq only** · **no API key for market data** ·
**auto-fixing typos** · **AI agent** · **interactive REPL** · **offline-tested**

---

## Table of contents

- [Features](#features)
- [Quick start](#quick-start)
- [Installation](#installation)
  - [macOS](#macos)
  - [Linux (all distributions)](#linux-all-distributions)
  - [Windows](#windows)
  - [BSD](#bsd)
  - [Manual download](#manual-download)
  - [From source](#from-source)
- [Requirements](#requirements)
- [Usage](#usage)
- [Commands](#commands)
- [Interactive mode](#interactive-mode)
- [Sample output](#sample-output)
- [Options](#options)
- [Environment variables](#environment-variables)
- [AI agent](#ai-agent)
- [Typo auto-fix](#typo-auto-fix)
- [Troll easter egg](#troll-easter-egg)
- [Caching & rate-limit etiquette](#caching--rate-limit-etiquette)
- [Architecture](#architecture)
- [Development](#development)
- [FAQ](#faq)
- [Security](#security)
- [Contributing](#contributing)

---

## Features

| What | Why you care |
| --- | --- |
| **60+ commands, one file** | Fear & Greed, MVRV, NUPL, CPI, unemployment, DeFi TVL, market dominance… all with short, easy-to-type names. |
| **Runs everywhere** | macOS (including stock bash 3.2 workflows), every Linux distribution (Debian, RHEL, Arch, Alpine…), Windows (Git Bash / MSYS2 / Cygwin / WSL), and the BSDs. Pure script — no binaries, so any CPU architecture works. |
| **Lightweight** | A single ~120 KB bash script. Dependencies: `bash` 4+, `curl`, `jq`. No Node, no Python, no Docker, no install daemons. |
| **AI agent** | `novrix ai "…"` — a crypto-native agent that answers with **real numbers**. Ask for exact history (`fear and greed on 22 december 2022`, `nupl for 2014, 15 january`) or a range (`last 10 days of fear and greed`, `fear and greed from 10 january to 20 january, 2022`) and it pulls the exact data from novrix's full charts — a range answers with **every day in the window** as a table, oldest first, not just the last day, and `last N days` also renders as a proper DATE/SCORE/ZONE-style data table instead of one line. Every indicator answers: NUPL, MVRV, BTC price and SOPR go back to 2010–2013, CPI answers by month, and a bare year or month gets a min/avg/max summary. A question that names several indicators at once — `nupl and fear and greed index` — answers each one with its latest value on its own labeled line (or its own table when you ask for a range or `last N days`), so nothing gets mixed up. When a data question names a date novrix.io doesn't cover (oil in 1988, US CPI in 1999, unemployment in 1989…), it fetches the value straight from FRED — no time machine needed. Privacy-coin questions (monero / dero / zcash…) get the channel's take, and a **side-by-side comparison table** when you ask for one — with one column per coin you actually named, no unsolicited extras. Casual chat — `hey`, `yes`, `hey crypto guy`, `macro guy` — gets riffed back in persona. In the interactive shell, follow-ups inherit the subject — after `what about btc price?`, `for today?` answers with the real price, not a guess. Off-topic stuff (politics, people) gets trolled, not answered. While it works, a spinning orb cycles live status texts — `thinking...`, `working...`, `answering in a sec...`, `wait, novrix is analyzing in depth...` — and the longer the answer takes, the more texts it goes through (the animation only runs on a terminal; piped or redirected output stays clean, with no spinner noise). |
| **Never says "unknown command"** | `novrix mvvrv` → runs `mvrv`. `novrix fear and greed index` → runs `fg`. Local fuzzy matching first, then the AI, with a spinning-orb animation whose status text cycles `thinking...` / `working...` / `answering in a sec...` / `wait, novrix is analyzing in depth...` while it figures you out. Questions don't even need a question word or a `?` — `the date of financial crisis beginning`, `the difference between a bull and a bear market`, `the meaning of mvrv` all reach the agent and get answered. `novrix "who are you?"` → the agent just answers. || **Troll easter egg** | Tell the CLI it's a piece of shit and it will roast you back. Ask it about Putin and it will tell you it only tracks the chain. It's a CLI with personality. |
| **Polite by default** | Local response caching (300 s TTL) so we never hammer novrix.io. |
| **Script-friendly** | Every command supports `--json` for the raw API response. |

## Quick start

```sh
# one command, anywhere:
curl -fsSL https://raw.githubusercontent.com/ethanhunthere/novrix-cli/main/install.sh | bash

novrix fg          # Fear & Greed, right now
novrix mvrv        # MVRV Z-Score
novrix tvl --top 5 # DeFi TVL, top 5 chains
novrix ai "explain MVRV in one sentence"
novrix ai "fear and greed on 22 december 2022"  # exact historical data
novrix ai "last 10 days of fear and greed index"   # → data table, every day
novrix ai "nupl for 2014, 15 january"           # any indicator, any date
novrix "fear and greed from 10 to 20 january 2022"  # date range → table, every day
novrix "compare dero and monero"              # techleaks analysis + comparison table (only the coins you name)
novrix "mvrv for 2014"                          # bare year → min/avg/max
novrix "hey crypto guy"                         # casual chat — it riffs back
novrix "spx looking good, what is its price?"   # words after a command work too
novrix "the date of financial crisis beginning" # no ? needed — the agent answers
novrix             # interactive shell (novrix ai … works in here too)
# in the shell, plain language + dates just work:
#   novrix> fear and greed index 15 january 2024
#   FEAR & GREED · 2024-01-15 · 52/100 (Neutral)  [########--------]
#   novrix> for today?   # follow-ups inherit the subject → real data, not a guess
```

## Installation

The installer detects your OS, distribution, and architecture, checks that
`bash` 4+, `curl` and `jq` are available (installing them with your package
manager when you pass `--install-deps`), downloads the latest release,
smoke-tests it, and puts `novrix` on your `PATH`.

```sh
# latest release, installs to /usr/local/bin (sudo when needed)
curl -fsSL https://raw.githubusercontent.com/ethanhunthere/novrix-cli/main/install.sh | bash

# no-sudo install to ~/.local/bin — great for containers, CI, and Windows
curl -fsSL https://raw.githubusercontent.com/ethanhunthere/novrix-cli/main/install.sh | bash -s -- --local

# pin a specific release and auto-install missing dependencies
NOVRIX_VERSION=v2.0.0 bash install.sh --install-deps
```

### macOS

macOS ships an ancient bash 3.2 — the installer detects it and tells you
exactly what to do. The recommended setup is Homebrew:

```sh
brew install bash jq curl
# then install novrix with the new bash:
/opt/homebrew/bin/bash install.sh          # or: curl … | /opt/homebrew/bin/bash
# or just let the installer handle everything:
curl -fsSL https://raw.githubusercontent.com/ethanhunthere/novrix-cli/main/install.sh | bash -s -- --install-deps
```

> **Why the bash 4+ requirement?** `novrix` uses associative arrays and
> modern shell features that simply don't exist in Apple's bash 3.2. This is
> a deliberate trade-off: one small, readable file instead of two
> implementations. `brew install bash` is a one-liner, and the version guard
> fails fast with friendly instructions rather than a wall of errors.

### Linux (all distributions)

Debian/Ubuntu, RHEL/Fedora/CentOS, Arch/Manjaro, Alpine, openSUSE — the
installer maps your distro to the right package manager (`apt`, `dnf`, `yum`,
`pacman`, `apk`, `zypper`) when `--install-deps` is passed. Otherwise it
prints the exact command to run.

```sh
curl -fsSL https://raw.githubusercontent.com/ethanhunthere/novrix-cli/main/install.sh | bash
```

Or install dependencies manually:

```sh
# Debian / Ubuntu
sudo apt-get install -y curl jq bash
# RHEL / Fedora / CentOS
sudo dnf install -y curl jq bash
# Arch
sudo pacman -S --noconfirm curl jq bash
# Alpine
sudo apk add --no-cache curl jq bash
```

### Windows

One command, straight from PowerShell. No admin needed:

```powershell
irm https://raw.githubusercontent.com/ethanhunthere/novrix-cli/main/install.ps1 | iex
```

That installs Git for Windows and `jq` when missing (winget, or direct
download if you have no package manager), installs `novrix` into
`~/.local/bin`, and puts it on your Git Bash PATH. Then open a **new** Git
Bash window and run `novrix --help`.

Already on WSL? Just use the Linux instructions above.

### BSD

FreeBSD, OpenBSD, NetBSD are supported by the installer; install `bash`,
`curl` and `jq` via `pkg` first (and note their bash lives at
`/usr/local/bin/bash`).

### Manual download

No installer, no trust in curl-pipes — grab the release asset yourself:

```sh
curl -fsSL -o novrix https://github.com/ethanhunthere/novrix-cli/releases/latest/download/novrix
chmod +x novrix
sudo mv novrix /usr/local/bin/
```

The release asset is the *same single file* the installer smoke-tests, with a
checked-in, reproducible build (see [Architecture](#architecture)).

### From source

```sh
git clone https://github.com/ethanhunthere/novrix-cli.git
cd novrix-cli
bash build.sh            # → bin/novrix (also: make build)
bash tests/smoke.sh      # offline test suite
sudo make install        # or: bash install.sh --local
```

## Requirements

| Tool | Version | Why |
| --- | --- | --- |
| `bash` | 4.0+ | The runtime. (macOS: `brew install bash`) |
| `curl` | any | Fetches API responses. `wget` also works in the installer. |
| `jq` | 1.6+ | JSON processing — one of the most common tools on earth. |

Optional, only for the AI agent:

- A [DeepSeek](https://platform.deepseek.com) API key
  (`DEEPSEEK_API_KEY` or `~/.config/novrix/keys.conf`). Without it, data
  commands (`fg`, `mvrv`, `cpi`, …) still work — only the conversational
  agent needs the key.

The agent answers with exact numbers from novrix's own API. If a metric
isn't on novrix, it does a quick web search (DuckDuckGo, no key needed)
and cites what it finds. If the question is off-topic, it trolls you.

Market data itself needs **no API key, no account, no login**.

## Usage

```sh
novrix                # interactive shell
novrix fg             # Fear & Greed
novrix mvrv --days 30 # MVRV Z-Score, last 30 days
novrix btc            # Bitcoin price (short name)
novrix macro cpi      # US CPI
novrix tvl --top 5    # DeFi TVL, top 5 chains
novrix prots --top 10 # Top DeFi protocols
novrix shortcuts      # print the command map
novrix ai "is the market greedy right now?"
novrix ai "fear and greed on 22 december 2022"  # exact number, straight from novrix
novrix ai "last 10 days of fear and greed index"
novrix ai "nupl for 2014, 15 january"           # exact value from 2014
novrix "btc price on 15 january 2014"           # bare command + date works too
novrix "cpi for january 2014"                   # monthly series, exact month
novrix "mvrv for 2014"                          # bare year → min/avg/max summary
novrix "fg from 10 to 20 january 2022"          # date range → every day as a table
novrix "who is vladimir putin"                  # trolled, not answered
novrix mvvrv          # typo → auto-fixed to mvrv, and it runs
```

Every command is **case-insensitive** (`MVRV`, `Fear`, `SPX` all work),
and every command supports `--json`, `--fresh`, and its relevant
`--days`/`--months`/`--top` flags.

## Commands

### Crypto sentiment — on-chain & market (novrix.io/sentiment)

```
fg nupl mvrv sopr puell rhodl mayer rr rp rpf rpl mcap btc 200ma addrs
hash scs btoi funding etf
```

| Short | Full name | Short | Full name |
| --- | --- | --- | --- |
| `fg` | Fear & Greed index | `nupl` | Net Unrealized Profit/Loss |
| `mvrv` | MVRV Z-Score | `sopr` | Spent Output Profit Ratio |
| `puell` | Puell Multiple | `rhodl` | RHODL Ratio |
| `mayer` | Mayer Multiple | `rr` | reserve-risk |
| `rp` | realized-price | `rpf` | realized-profit |
| `rpl` | realized-loss | `mcap` | market-cap |
| `btc` | btc-price | `200ma` | 200-week-ma |
| `addrs` | active-addresses | `hash` | hashrate |
| `scs` | stablecoin-supply | `btoi` | open-interest |
| `funding` | funding-rate | `etf` | BTC ETF flows |

### Macro — US economics & markets (FRED, DXY, gold…)

```
cpi unrate gdp nfp claims jolts ccpi pce cpce umich oil t30 curve be dxy
gold spx vix ffr m2
```

| Short | Full name | Short | Full name |
| --- | --- | --- | --- |
| `cpi` | US CPI (MoM/YoY) | `unrate` | Unemployment |
| `gdp` | Real GDP | `nfp` | payrolls |
| `claims` | Initial jobless claims | `jolts` | job-openings |
| `ccpi` | core-cpi | `cpce` | core-pce |
| `umich` | U.Mich sentiment | `oil` | WTI oil |
| `t30` | us30y | `curve` | t10y2y |
| `be` | breakeven | `dxy` | Dollar index |
| `gold` | Gold | `spx` | sp500 |
| `vix` | VIX | `ffr` | fedfunds |
| `m2` | M2 money supply | | |

### Metrilytics — DeFi & markets dashboard (novrix.io/metrilytics)

```
tvl defi mkt stables dex fees dom opts prots bridges lending prices oi
```

| Short | Full name | Short | Full name |
| --- | --- | --- | --- |
| `tvl` | TVL per chain | `defi` | DeFi TVL snapshot |
| `mkt` | market | `stables` | stablecoins |
| `dex` | 24h DEX volume | `fees` | Protocol fees |
| `dom` | dominance | `opts` | options |
| `prots` | protocols | `bridges` | Top bridges |
| `lending` | Top lending | `prices` | BTC/ETH/SOL spot |
| `oi` | Open interest | | |

### System

```
shortcuts help clear exit · ai ask
```

## Interactive mode

Running `novrix` with no arguments drops you into a shell where every command
works without the prefix:

```text
$ novrix
novrix 2.9.0, interactive mode. type a command and hit enter.

  sentiment     fg nupl mvrv sopr puell rhodl mayer rr rp rpf rpl mcap btc 200ma addrs hash scs btoi funding etf
  macro:        cpi unrate gdp nfp claims jolts ccpi pce cpce umich oil t30 curve be dxy gold spx vix ffr m2
  metrilytics   tvl defi mkt stables dex fees dom opts prots bridges lending prices oi
  ai            ask anything, it answers with real data
  system        shortcuts · help · clear · exit
  tip:          dates and ranges work anywhere - 'nupl for 2014, 15 january', 'last 10 days of fg'

novrix> btc
BTC PRICE · $62.76K · 2026-08-03
novrix> mvvrv
novrix: "mvvrv"? you mean "mvrv". running it.
MVRV Z-SCORE · 0.38 · 2026-07-28
novrix> ai "what is a high MVRV?"
MVRV Z-Score measures the ratio of market value to realized value; values above 3.5 have historically marked cycle tops.
novrix> exit
bye
```

`help` shows the full manual, `shortcuts` prints the command map, `clear`
clears the screen, and `exit`/`quit`/`q` leave.

## Sample output

Every command defaults to a single summary line; add `--days` / `--months` /
`--top` for full tables.

```text
$ novrix fg
FEAR & GREED · 64/100 (Greed) · 2026-08-04  [##########------]

$ novrix nupl
NUPL · 0.437 (Greed) · 2026-08-03

$ novrix mvrv
MVRV Z-SCORE · 0.38 · 2026-07-28

$ novrix rpl
REALIZED LOSS · -$445.28M · 2026-08-02

$ novrix macro cpi
US CPI · 331.2 · MoM +0.27% · YoY +2.38% · 2026-08

$ novrix defi
DEFI TVL · $73.98B · top: ethereum · Binance CEX

$ novrix mkt
MARKET · cap $2.58T · 24h vol $60.06B · BTC dom 57.33% · 2026-05-30
```

Tables with `--days` / `--top`:

```text
$ novrix mvrv --days 5
MVRV Z-SCORE, last 5 · latest: 0.38 · 2026-07-28
DATE                  VALUE
2026-07-24             0.42
2026-07-25             0.39
2026-07-26              0.4
2026-07-27             0.43
2026-07-28             0.38

$ novrix prots --top 5
RANK PROTOCOL               CATEGORY          TVL (USD)     SHARE
1    Binance CEX            CEX                $137.82B    66.31%
2    OKX                    CEX                 $21.17B    10.19%
3    Lido                   Liquid Staki        $17.44B     8.39%
4    Bitfinex               CEX                 $16.98B     8.17%
5    Aave                   -                   $14.42B     6.94%

Source: novrix.io/api/metrilytics/protocols · 80 protocols
```

## Options

| Option | Effect |
| --- | --- |
| `--json` | Print the raw API JSON instead of the table (script-friendly). |
| `--fresh` | Bypass the local cache. |
| `--days N` | Recent N data points (series: `mvrv`, `unrate`, `hash`, …). |
| `--months N` | Same as `--days` for monthly series (`cpi`, `unrate`, …). |
| `--top N` | Top N rows (`tvl`, `prots`, `bridges`, `lending`). |
| `--help`, `-h` | Show help. |
| `--version`, `-v` | Show version. |

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `NOVRIX_API_BASE` | `https://novrix.io` | Override the API base URL. |
| `NOVRIX_TTL` | `300` | Response cache TTL in seconds. |
| `NOVRIX_CACHE_DIR` | `$XDG_CACHE_HOME/novrix` | Cache location. |
| `NOVRIX_TELEGRAM_CHANNEL` | — | Telegram channel for `telegram` / `what's new on crypto?`. |
| `NOVRIX_TELEGRAM_TTL` | `480` | Telegram post cache TTL in minutes (default 8 h). |
| `NOVRIX_PRIVACY_CHANNEL` | `techleaks24` | Channel analyzed for privacy-coin questions (monero, dero, zcash…). |
| `NOVRIX_PRIVACY_POSTS` | `20` | How many of the channel's posts the AI reads for privacy answers. |
| `NOVRIX_CHANNEL_POSTS` | `20` | How many of the channel's posts the AI reads for novrix-stance answers. |
| `DEEPSEEK_API_KEY` | — | DeepSeek key for the AI agent. |
| `DEEPSEEK_API_BASE` | `https://api.deepseek.com` | DeepSeek API endpoint. |
| `NO_COLOR` | unset | Disable colored output (any non-empty value). |
| `NOVRIX_API_DIR` | — | Offline fixture mode (used by the test suite). |

The DeepSeek key can also live in `~/.config/novrix/keys.conf`
(`DEEPSEEK_API_KEY=sk-…`, file permissions `0600`). It is never stored
anywhere else, and never in the repo.

## AI agent

`novrix ai "your question"` asks the DeepSeek AI agent anything about crypto,
macro, DeFi — or life, it's a friendly CLI. It answers in plain text, briefly,
and points you at the right `novrix` command when one exists.

```sh
novrix ai "explain MVRV in one sentence"
novrix ask "what's the 10y-2y saying?"      # 'ask' is an alias
novrix ai "nupl for 2014, 15 january"       # exact value, straight from the charts
novrix "fear and greed in 2022"             # bare year → min/avg/max summary
```

When the question names a **date**, it answers with the exact historical value
from novrix.io instead of guessing: `nupl for 2014, 15 january` → `0.652`,
`cpi for january 2014` → `235.288`. A bare year or month gets a
min/avg/max summary for that window, and monthly series (CPI, unemployment,
GDP…) accept day queries too. Indicators with full charts answer anything
back to 2010–2013 (NUPL, MVRV, BTC price, SOPR); ones that only started later
on novrix.io itself (funding rate, ETF flows, puell) honestly fall back to web
research for earlier dates.

**Before** that web-research fallback, dates that predate novrix.io's history
get fetched straight from **FRED** (fred.stlouisfed.org): `oil price on 15
january 1988` → `WTI OIL · $17.1 · 1988-01-15 · FRED`, `unemployment rate in
december 1989` → `US UNEMPLOYMENT · 5.3% · 1989-12 · FRED`, `cpi for january
1999` → `US CPI · 164.3 · 1999-01 · FRED`. Day queries on daily series (oil)
give the exact observation; monthly series give the month's value; a bare year
gives a min/avg/max summary. Covered series: oil, CPI, core CPI, PCE,
unemployment, payrolls, claims, job openings, GDP, fed funds, M2, 10y-2y,
10y breakeven, U.Mich sentiment, VIX, and the S&P 500 (whose FRED series only
starts in 2016 — so `sp500 price on 12 december 1999` still gets the honest
"dusty archive" web-research answer).

It also powers the **typo resolution**: when you type something that isn't a
command, the AI reads the *whole phrase* and maps it to the command you meant.

## Telegram channel

novrix can read your **public** Telegram channel and answer with your latest
chart text — no bot token, no login. It reads the channel's public preview
page (`t.me/s/<channel>`), so it works for any public channel.

```sh
export NOVRIX_TELEGRAM_CHANNEL=my-channel     # or add TELEGRAM_CHANNEL=my-channel
                                              # to ~/.config/novrix/keys.conf
novrix telegram                               # latest post (caption + chart link)
novrix telegram 5                             # last 5 posts
novrix "what's new on crypto?"                 # answers with your latest chart text
novrix "which are the last posts?"             # the last 5 posts, text only
```

Posts are cached for 8 hours (`NOVRIX_TELEGRAM_TTL` minutes) and refetched
lazily on the next call — effectively refreshing every 8 h. For true
background prefetching, add a cron entry:

```sh
0 */8 * * * /usr/local/bin/novrix telegram --fresh >/dev/null 2>&1
```

Ask anything like `what's new on crypto?`, `latest chart`, or `anything new on
your channel?` and novrix answers with the text of the most recent post — no
images, no chart links — plus an AI-written description that adds context to
the post. Ask for "the last posts" / "latest posts" / "recent posts" and it
lists the last 5 posts (text only, newest last); say "the last N posts" to
pick the count. Posts that were forwarded carry a `Forwarded from …` note.
Point at one post and novrix shows only that one: `tell me the one with
utxo bands`, `which post talked about the fed`, `which are the last posts
about cloudflare?` — a keyword match picks it, and when nothing matches the
AI agent picks the post closest to your description.
Ask about the channel itself — `what does novrix think about the market?`,
`is novrix bullish or bearish?`, `what does novrix forward?`, `does novrix
repost bullcase?`, `what is novrix posting lately?`, `what does novrix
think about ai?` (including chinese vs US AI) — and novrix reads the
channel's recent posts and answers from its point of view: novrix is
bullish (it has no thesis of its own, it is simply bullish), and much of
what it posts are forwards from Bull Case (@bullcase), crypto OGs. Those
forwarded posts carry Bull Case's thesis, and the answer reads it straight
from them — whale flows, BTC dominance, cycle positioning — alongside what
novrix itself has been posting and its take on AI. Posts that novrix
forwarded carry a `Forwarded from …` note in the context, so the answer
always knows which is which. The answer stays on the market, charts and
Bull Case's thesis — privacy coins (Dero, Monero, Zcash) belong to the
separate @techleaks24 analyzer and stay out of novrix answers, even when
a post happens to mention them.
Without a channel configured, those questions fall back to the AI agent.

## Privacy coins

The moment a privacy coin is mentioned — **monero / xmr, dero, zcash / zec**,
or anything mentioning *privacy, privacy tech, traceable, anonymous,
coinjoin, kyc* — novrix starts analyzing the **@techleaks24** channel (which
has covered privacy coins for many years) and bases the answer on what it
says. The mention triggers the analysis no matter how it's phrased — a
question with a question mark, a statement, a mid-conversation remark in
the REPL, even a phrase that starts with a word like "but":
The answers are grounded in the channel's long-running take (Monero has
been traceable for a long time now, Dero is the only coin that is not
traceable on crypto, ZEC's supply audit risks, and so on), written
directly to the question asked — they never call Monero or ZEC the king
of privacy coins, and they cover only the coin you asked about, without
repeating boilerplate from previous answers.
The comparison table is printed **only when you ask for it** — ask to
compare, to see the difference, or for a table — and it contains **one
column per coin you named**: "compare dero and monero" gets DERO and
MONERO columns and no Zcash. The rows cover the coins' techniques — ring
signatures, stealth addresses, RingCT, zk-SNARKs, smart contracts, and
whether the coin is untraceable on chain — as a ✓ / − feature matrix:

```
PRIVACY COINS · COMPARISON
FEATURE                     DERO  MONERO
ring signatures               ✓      ✓
stealth addresses             ✓      ✓
ring ct (hidden amounts)      ✓      ✓
zk-snarks (zero-knowledge)    -      -
smart contracts               ✓      -
untraceable on chain          ✓      -
```

```sh
novrix "compare dero and monero"       # → analysis + table with DERO and MONERO only
novrix "make a table with everything that dero and monero have, don't have"  # → same table
novrix "what about dero?"               # → the channel's Dero take, no table
novrix "is monero traceable?"           # → analysis only — no table unless asked
novrix "but explain dero in depth"      # → still the Dero take (no "?" needed)
novrix "make a table comparing all privacy coins"  # → DERO / MONERO / ZCASH columns
```

The channel defaults to `techleaks24` and can be changed with the
`NOVRIX_PRIVACY_CHANNEL` env var or `PRIVACY_CHANNEL=` in
`~/.config/novrix/keys.conf`. Posts are cached like the main channel
(`NOVRIX_TELEGRAM_TTL`). Questions that don't mention a privacy topic fall
through to the normal AI agent.

## Typo auto-fix

novrix never says *"unknown command"*. The resolution chain is:

1. **Offline fuzzy matching** — a Levenshtein-distance matcher compares your
   input against every known command and picks the closest (with a sanity
   guard so `fear` doesn't become `clear`).
2. **The AI agent** — for harder cases, the whole phrase goes to DeepSeek
   with a spinning-orb animation (status text cycles `thinking...` /
   `working...` / `answering in a sec...` / `wait, novrix is analyzing in
   depth...`), which maps garble and plain language to a
   command: `fgredd` → `fg`, `fear and greed index` → `fg`,
   `bitcoin price` → `btc-price`.
3. If it genuinely can't tell, it asks: *"lol what even is that? 😏 i got nothing, what did you mean?"* and
   suggests `help` or `novrix ai`.

```text
$ novrix mvvrv
novrix: "mvvrv"? you mean "mvrv". running it.
MVRV Z-SCORE · 0.38 · 2026-07-28

$ novrix fgredd
wtf is "fgredd"? hold on... ⠼
novrix: "fgredd"? you mean "fg". running it.
FEAR & GREED · 64/100 (Greed) · 2026-08-04  [##########------]
```

## Troll easter egg

The CLI has a personality. Swearing at it doesn't trigger funding data — it
triggers a roast:

```text
$ novrix fucking
novrix: you fucking retard 😂 "fucking" aint a command. if you meant "funding", type "funding". go on, i dare you.
```

Try `fck`, `wtf`, `damn`, `shit`, `stupid`, `dumb`… it has a response for
each. All in good fun — it still tells you the right command.

## Caching & rate-limit etiquette

NOVRIX is a public service — please treat it gently:

- Responses are cached locally (default TTL **300 s**, `NOVRIX_TTL` to
  change) and re-fetched only when stale or with `--fresh`.
- The CLI sends a descriptive `User-Agent` so the server can identify us.
- If the API errors or rate-limits us, `novrix` prints the server's response
  instead of guessing.

## Architecture

`novrix` is a single-file CLI **assembled from small, focused modules** so it
stays easy to read, review, and extend:

```
novrix-cli/
├── src/                     ← the real source of truth (assembled by build.sh)
│   ├── header.sh            shebang + banner
│   └── lib/
│       ├── bootstrap.sh     runtime guards, constants, colors
│       ├── core.sh          die, need_cmd, spinner, options, cache age
│       ├── api.sh           api_get — fixtures, caching, curl
│       ├── format.sh        jq snippets + render helpers
│       ├── data.sh          SERIES / META / ALIASES registries
│       ├── telegram.sh      Telegram channel reader + privacy analysis
│       ├── ai.sh            DeepSeek AI agent + data-question answering
│       ├── typo.sh          troll easter egg + fuzzy/AI typo resolution
│       ├── commands.sh      every cmd_* implementation
│       └── cli.sh           dispatch, interactive REPL, entry point
├── bin/novrix               ← the BUILT single file (committed, released)
├── build.sh                 deterministic, offline assembler (cat + checks)
├── Makefile                 build / test / lint / install shortcuts
├── install.sh               OS/distro-aware installer (macOS/Linux/Win/BSD)
├── install.ps1              one-command Windows installer (PowerShell)
├── novrix.cmd               Windows batch launcher
├── tests/
│   ├── smoke.sh             offline test suite (fixture-driven, 371 checks)
│   └── fixtures/            canned API + AI + FRED + Telegram responses
├── CHANGELOG.md             Keep-a-Changelog history
├── CONTRIBUTING.md          contributor guide
├── SECURITY.md              vulnerability reporting
└── .github/workflows/ci.yml CI on ubuntu / macOS / windows
```

Design decisions:

- **Single-file distribution.** The release asset is one self-contained bash
  script — installation is a `curl | bash` one-liner, nothing to resolve.
  `build.sh` concatenates the modules in dependency order; the output is
  byte-deterministic and CI fails if `bin/novrix` drifts from `src/`.
- **Registry-driven commands.** Adding a metric is one line in
  `src/lib/data.sh` — help text, shortcuts, and typo-matching pick it up
  automatically.
- **Portability.** Guards for bash < 4 (friendly error on macOS stock bash),
  no `find -mmin` (uses portable `stat`), no `${var,,}` (uses `tr`), and the
  installer maps every major OS/distro to the right package manager.

## Development

```sh
make build   # bash build.sh            → bin/novrix
make test    # bash tests/smoke.sh      → 371 offline checks (no network)
make lint    # shellcheck, if installed
make check   # build + test + lint
```

- Tests are **fully offline** — they run against canned responses in
  `tests/fixtures/` via `NOVRIX_API_DIR`.
- CI (`.github/workflows/ci.yml`) runs the suite on **ubuntu, macOS and
  Windows**, lints with shellcheck, and verifies the committed artifact
  matches `src/`.
- To try the AI agent locally, set `DEEPSEEK_API_KEY` and run
  `novrix fgredd` — you'll see the spinner and the fix.

## FAQ

**Do I need an API key for market data?** No. Market data is public; only
the AI agent needs a (cheap) DeepSeek key.

**Why does macOS need a newer bash?** Apple ships bash 3.2 from 2007. The CLI
uses associative arrays. `brew install bash` fixes it in one command, and
`install.sh --install-deps` does it for you.

**Is it really one file?** Yes — the release asset is a single ~120 KB bash
script. The repo is modular for maintainability; the shipped artifact is one
file for your convenience.

**Will it hammer novrix.io?** No — responses are cached for 300 s by
default, and `--fresh` is there when you need current data.

**What if the AI can't figure out my typo?** It asks what you meant and
suggests `help` / `novrix ai` — it never silently guesses wrong.

**Can I use it in scripts?** Yes: `--json` gives you raw responses,
`--fresh` bypasses the cache, and exit codes are stable (0 = success).

## Security

Found a vulnerability? Please report it privately — see
[SECURITY.md](SECURITY.md). Never open a public issue for security problems.

## Contributing

Pull requests are welcome. Please keep it **small and focused**, add a
fixture + test for any new behavior, and make sure `make check` passes.
See [CONTRIBUTING.md](CONTRIBUTING.md).

Market data comes from the NOVRIX public API — use it respectfully.
