# Changelog

All notable changes to **novrix** are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v1.0.0] — 2026-08-05

### Changed
- **When you ask what novrix thinks about crypto, the answer now comes
  from the real channel dynamic.** novrix is bullish — it has no thesis
  of its own, it is simply bullish — and a big part of what it posts are
  forwards from Bull Case (@bullcase), crypto OGs who have been in the
  space since the early days. Those forwarded posts carry Bull Case's
  thesis, and the answer reads it straight from them: whale flows, BTC
  dominance, cycle positioning. Channel post feeds now carry a
  `Forwarded from …` note on each forwarded post, so the AI always knows
  which posts novrix wrote and which it forwarded.
- 371 offline smoke checks, all green (5 new: `forward` and `bullcase`
  questions route to the novrix analysis, channel posts carry the
  forwarded-from note, and the novrix prompt names Bull Case and its
  no-thesis framing).

## [v2.9.9] — 2026-08-06

### Fixed
- **The spinner animation no longer leaks garbage into the answer.** The
  `\r`-based animation never cleared the line, so when the status text
  cycled from a long message (`reading techleaks...`) to a shorter one
  (`working...`), a leftover tail of the original message stayed on
  screen. Every frame now erases the line first, and the animation only
  runs when stderr is a terminal — piped or redirected output contains
  zero spinner noise.

## [v2.9.8] — 2026-08-06

### Changed
- **No more gauge bars.** The `[########------]` fear<->greed and NUPL
  distribution bars are gone — from the single-line views, the `fg`/`nupl`
  tables, and the AI range tables. Tables are now clean
  DATE/SCORE/ZONE (fg) and DATE/NUPL/ZONE (nupl) with no trailing bar
  column, so nothing distracts from the numbers.

### Added
- **A question can name several indicators at once** and each one answers
  as its own labeled table, so nothing gets mixed up. `nupl and fear and
  greed index` prints the NUPL table, then the FEAR & GREED table; a range
  or last-N window in the question applies to each series.
- 364 offline smoke checks, all green (11 new: no-gauge assertions and
  multi-series tables for ranges, REPL, and ordering).

## [v2.9.7] — 2026-08-06

### Changed
- **The comparison table is only printed when asked for.** A bare
  privacy question (`is monero traceable?`, `tell me more about crypto
  privacy coins`) used to end every answer with the same
  `PRIVACY COINS · COMPARISON` table, so five consecutive privacy
  questions printed five identical tables. Now the table renders only
  when the question asks for it — `compare`, `comparison`, `difference`,
  `table`, `side by side`, `versus`, `which is better`, `both`, `have
  and` / `don't have` — and a request like `make a table with everything
  that dero and monero have, don't have` produces a real table instead
  of a bulleted text list.
- **The table shows only the coins the question names.** `compare dero
  and monero` gets DERO and MONERO columns and no Zcash; only a generic
  `compare all privacy coins` ask shows all three. Each column is built
  from the coins actually mentioned (dero / monero / xmr / zcash / zec).
- **Privacy answers are less repetitive and more professional.** The
  analysis prompt now grounds each answer directly in the asked coin,
  forbids repeating phrases, figures, or boilerplate from previous
  answers, and drops the fixed `Based on techleaks analysis:` preamble
  (the `TECHLEAKS ANALYSIS · @channel` header still carries the
  attribution).
- 353 offline smoke checks, all green (3 new: table omits unasked
  coins, no table unless asked, no-table one-shot still answers).

## [v2.9.6] — 2026-08-06

### Fixed
- **REPL follow-ups inherit the previous question.** After `novrix> what
  about btc price, for yesterday?`, typing `novrix> for today?` used to
  hand the bare "for today?" to the AI agent with no context — it could
  not know what "today" referred to, so it invented numbers from memory
  (e.g. "Bitcoin's chillin around $67k … Fear and greed sittin' at 62"
  while the real figures were $62.76K and 27/100 Fear). Elliptical
  follow-ups (`for today?`, `what about eth?`, `and yesterday?`, `now?`,
  `how about gold?`, `it/that/this …`, `elaborate`, `more`, `again`) now
  inherit the previous question, so the series is detected and the answer
  comes from real data. Series-naming questions still answer with data
  first, and a follow-up with no prior question still reaches the agent.
- 350 offline smoke checks, all green (3 new: follow-up inherits the
  series in the REPL, bare follow-up one-shot, bare follow-up in the
  REPL).

## [v2.9.5] — 2026-08-06

### Fixed
- **"The …" questions reach the AI instead of the unknown-command die.**
  `novrix> the date of financial crisis beginning` (no question word, no
  `?`) used to end in `lol what even is …`. Phrases that open a question
  with a noun phrase now route to the agent: `the date of`, `the time of`,
  `the price of`, `the meaning of`, `the difference`, `the reason`, `the
  best`, `the top`, `the latest`, `the current`, `the history`, `the
  trend`, and friends. Data questions still answer with data first — `the
  price of bitcoin` prints the prices overview, `the last 10 days of fear
  and greed` still renders the full table.
- 347 offline smoke checks, all green (6 new question-routing checks,
  one-shot + REPL).

## [v2.9.4] — 2026-08-06

### Added
- **Privacy-coin answers now end with a comparison table.** After the
  techleaks analysis for monero / dero / zcash questions, novrix prints a
  `PRIVACY COINS · COMPARISON` feature matrix (✓ yes, − no) covering each
  coin's techniques — ring signatures, stealth addresses, RingCT,
  zk-SNARKs, smart contracts — and whether the coin is untraceable on
  chain, in the channel's frame (Dero is the only coin not traceable).
  The AI still writes the analysis first; the table just makes the take
  scannable at a glance.
- **`last N days` sentiment queries render as full data tables.** Fear &
  greed for the last 10 days (and every other indicator via `--days`)
  already went through the table renderer; the behavior is now locked in
  by smoke tests asserting the DATE/SCORE/ZONE/GAUGE header and one row
  per day.
- 341 offline smoke checks, all green (10 new: 7 comparison-table, 3
  fg last-10-days table).

## [v2.9.3] — 2026-08-06

### Changed
- **The AI spinner now animates with a rotating orb and live status
  texts.** While novrix is answering, the terminal shows a spinning
  braille orb with a status line that cycles every ~1.5 s:
  `thinking...` → `working...` → `answering in a sec...` →
  `wait, novrix is analyzing in depth...` (and back around). The longer
  an answer takes, the more texts it cycles through, so a slow AI call
  always looks alive instead of frozen on one line. The orb + cycling
  texts apply to every spinner — AI answers, typo fixes, and telegram
  channel reads.
- 331 offline smoke checks, all green (2 new spinner checks).

## [v2.9.2] — 2026-08-06

### Added
- **Date ranges answer the whole window, not one day.**
  `give me data of fear and greed index from 10 january to 20 january,
  2022` used to answer only the last day (2022-01-20); now it prints
  every observation in the window as a table, oldest first. All four
  phrasings work — full dates on both sides (`10 january 2022 to 20
  january 2022`), month-first (`january 10 to january 20, 2022`),
  day-first (`10 january to 20 january, 2022`), and bare days
  (`10 to 20 january 2022`) — with `to`, `through`, `until`, `thru`,
  and `and` as connectors. Fear & greed gets a DATE/SCORE/ZONE/GAUGE
  table, NUPL a zone/distribution table, monthly macro series a
  MONTH/VALUE table, and every other daily or monthly series a
  DATE/VALUE table with the same value formatting as single dates.
  Windows outside novrix history fall back to FRED (oil in the 80s,
  deep macro months), and windows in neither fall back to web research.
- 329 offline smoke checks, all green (16 new range checks).

## [v2.9.1] — 2026-08-05

### Fixed
- **Privacy mentions now trigger techleaks analysis in any phrasing.**
  Previously a privacy-coin mention only routed to the @techleaks24
  analysis when it looked like a question (`is monero traceable?`), so a
  REPL remark like `but explain dero in depth, I want to know dero tech`
  (no question mark, starts with "but") fell through to the typo handler
  and got "lol what even is...". Now the moment dero, monero, xmr, zcash,
  privacy, traceable, anonymous, coinjoin, kyc or any other privacy term
  shows up — question or not, one-shot or REPL — novrix starts analyzing
  the techleaks channel. The novrix-stance and exact-data questions still
  take priority, matching the cmd_ai order.
- 313 offline smoke checks, all green.

## [v2.9.0] — 2026-08-05

### Added
- **Straight from FRED.** When a data question names a date novrix.io
  doesn't cover — `oil price on 15 january 1988`, `unemployment rate in
  december 1989`, `cpi for january 1999` — the CLI now fetches the value
  directly from FRED (fred.stlouisfed.org) instead of the AI guessing or
  snarking about a time machine. Day queries give the exact observation,
  monthly series answer by month, and a bare year gets a min/avg/max
  summary. Covered series: oil, CPI, core CPI, PCE, unemployment,
  payrolls, claims, job openings, GDP, fed funds, M2, 10y-2y, 10y
  breakeven, U.Mich sentiment, VIX, and the S&P 500 (whose FRED history
  only starts in 2016, so dates before that still fall back to web
  research). If FRED is unreachable it degrades to the same web-research
  fallback.
- 309 offline smoke checks, all green.

## [v2.8.0] — 2026-08-05

### Added
- **The novrix channel's own view.** `what does novrix think about the
  market?`, `is novrix bullish or bearish?`, `what is novrix posting
  lately?`, or `what does novrix think about ai?` (including chinese vs
  US AI) read the channel's recent posts and answer from its point of
  view — market stance, recent posts, and its take on AI. Plain
  "what is novrix?" questions stay with the normal agent, and "latest
  post" questions still show the latest post.
- **Privacy answers fully based on techleaks.** Privacy-coin questions
  research the @techleaks24 channel (which has covered privacy coins for
  many years) and always answer from the channel's take — and never call
  Monero or ZEC the king of privacy coins.
- 302 offline smoke checks, all green.

## [v2.7.0] — 2026-08-06

### Added
- **One specific post.** `tell me the one with utxo bands`, `which post
  talked about the fed`, or `which are the last posts about cloudflare?`
  now returns ONLY the post the user pointed at (keyword match on the
  post text; newest match wins). When nothing matches, the AI agent picks
  the post closest to the user's description and returns that one.
  Weak pointers like `which one should i pick?` (no post/telegram
  context) stay with the normal AI agent.
- 287 offline smoke checks, all green.

## [v2.6.0] — 2026-08-06

### Added
- **Privacy-coins channel (@techleaks24).** Asking about monero / xmr,
  dero, zcash / zec, or anything mentioning privacy, traceable, anonymous,
  coinjoin or kyc routes to an AI analysis of the @techleaks24 channel's
  recent posts. The answer starts with `Based on techleaks analysis:` and
  reflects the channel's take (Monero has been traceable for a long time,
  Dero is the only coin that is not traceable on crypto, ZEC's supply-audit
  risks). Channel override via `NOVRIX_PRIVACY_CHANNEL` / `PRIVACY_CHANNEL=`
  in keys.conf, post count via `NOVRIX_PRIVACY_POSTS`.
- 279 offline smoke checks, all green.

## [v2.5.0] — 2026-08-05

### Added
- **"Last posts" answers.** Asking for "the last posts", "latest posts",
  "recent posts" (or "show the last N posts") lists the last 5 posts from
  your Telegram channel, text only, newest last — no images, no chart
  links. Any question mentioning "posts" is treated as a list request.
- **Forwarded-post notes.** Posts forwarded from another channel carry a
  dimmed `Forwarded from …` note in `novrix telegram` output and in the
  natural-language answers, so you know when content is reposted.
- 269 offline smoke checks, all green.

## [v2.4.0] — 2026-08-05

### Added
- **Telegram channel reader.** `novrix telegram` fetches the latest posts
  from a public Telegram channel via its `t.me/s` preview page — no bot
  token, no login. `what's new on crypto?`, `latest chart`, or `anything
  new on your channel?` answer with the text of the most recent post — no
  images, no chart links — plus an AI-written description that adds
  context. Posts are cached for 8 hours (`NOVRIX_TELEGRAM_TTL` minutes,
  `--fresh` to bypass), the channel is set with `NOVRIX_TELEGRAM_CHANNEL`
  or `TELEGRAM_CHANNEL=…` in `keys.conf`, and without a channel configured
  the questions fall back to the AI agent. `tg` is a short alias. 260 smoke
  checks, all offline.

## [v2.3.0] — 2026-08-05

### Changed
- **Casual chat works.** Bare `novrix ai` opens a chat — the agent greets
  instead of dying with a usage error — and banter like `hey`, `yes`,
  `whatever`, `hey crypto guy` or `macro guy` reaches the agent, which
  riffs back in persona instead of the "what even is" error. Unknown
  garble still gets trolled, fuzzy-matched, or asked about.
- **Design pass.** Fear & Greed now renders a colored fear<->greed gauge
  (`[##########------]`) in the one-liner, in history tables, and in the
  agent's exact-date answers; tables get a dim header rule and color-coded
  values (green/red by sign, zone-colored scores); the interactive banner
  is aligned, grouped and colored, with a tip line showing that dates and
  ranges work anywhere; the REPL prompt is colored. Piped output stays
  plain — no escape codes without a TTY.
- New smoke tests (244 checks, all offline).

### Fixed
- **Natural language after a known command no longer chokes the option
  parser.** `spx looking good, what is its price?` used to die with
  "unknown option: looking"; now it answers with the exact latest value
  (`S&P 500 · …`) when it is a data question, and hands phrases like
  `fg how does it work?` to the AI agent. Flags (`--days`, `--json`, …)
  still go straight to the real command.

## [v2.2.0] — 2026-08-05

### Added
- **Every indicator answers exact historical dates.** NUPL, MVRV, BTC
  price, SOPR and friends pull the exact value for any date from novrix's
  full charts — `novrix ai "nupl for 2014, 15 january"` → `0.652`,
  `novrix "btc price on 15 january 2014"` → `$941.22`. A bare year or month
  gets a min/avg/max summary (`novrix "mvrv for 2014"`), and monthly series
  like CPI accept day queries too (`novrix "cpi for january 2014"` →
  `235.288`). Bare commands with a date in plain language route to the
  exact-data answerer instead of ignoring the extra words, and a known
  command with a date that novrix does not have (e.g. funding rate in 2014)
  falls back to the AI agent instead of choking on the words. Indicators
  that only started later on novrix.io itself (funding rate, ETF flows,
  puell) honestly fall back to web research for earlier dates.
- **The agent answers with exact historical data.** `novrix ai "fear and
  greed on 22 december 2022"` returns the actual value for that day straight
  from novrix's API. A date or range in the question is answered before the
  AI even talks: `"last 10 days of fear and greed index"` prints the real
  table, `"mvrv on 22 december 2022"` prints the exact MVRV Z-Score.
- **Web research when novrix does not have it.** For data questions the
  agent cannot answer from novrix (offline fixtures, gaps in history), it
  runs a quick DuckDuckGo search (no key needed) and passes the snippets to
  the AI as context.
- **Off-topic questions get trolled, not answered.** Politics and people
  (`putin`, `trump`, `biden`, …) get a "i only track the chain" roast,
  unless the question is crypto-adjacent. Plain questions like
  `novrix "who are you?"` now reach the agent instead of the unknown-
  command error.
- **`novrix ai …` works inside the interactive shell** — a pasted `novrix `
  prefix is stripped automatically, so copy-pasting a one-shot command into
  the shell just works. Bare `novrix` in the shell prints usage.
- New smoke tests for all of the above (233 checks, all offline).

### Changed
- **Agent persona**: a cypherpunk crypto nerd who talks like a human (lol,
  lmao, light roasts), stays in the crypto and macro lane, and always gives
  the real number. Latest novrix values for whatever the question mentions
  are attached as context so it never guesses.
- The unknown-command path now routes questions and data questions to the
  agent before falling back to fuzzy matching; the "what even is" message
  is the last resort, not the first.
- Known commands followed by a date or range in plain language (e.g.
  `novrix "nupl 2014"`, `novrix "cpi for january 2014"`) now answer with
  exact historical data instead of running the command and ignoring the
  extra words.

### Added
- **`install.ps1`** — one-command Windows installer, fully self-sufficient:
  `irm https://raw.githubusercontent.com/ethanhunthere/novrix-cli/main/install.ps1 | iex`.
  Installs Git for Windows (winget, or direct installer download when there
  is no package manager), installs `jq` (winget → choco → scoop → direct
  download), runs the official installer into `~/.local/bin`, and puts
  `novrix` on the Git Bash PATH. No admin, no manual steps. TLS 1.2 forced
  for PowerShell 5.1.

### Changed
- `install.sh --install-deps` now works on Windows Git Bash (winget → choco →
  scoop, with a direct `jq.exe` download into the install dir as the no
  package manager fallback).
- `install.sh` always persists the install directory to your shell rc
  (`~/.bash_profile` on Git Bash, `~/.bashrc`/`~/.profile` elsewhere) even
  when it is already on the current session's PATH; opt out with `--no-path`.

### Fixed
- The documented `NOVRIX_TTL` environment variable is now actually honored —
  it was documented in `--help`/README but never read. Invalid values fail
  fast with a clear error.
- `make lint` (shellcheck) is clean, fixing the failing Linux CI lint step.
  Intentional patterns (jq programs in single quotes, REPL word splitting,
  internal printf formats) carry targeted `shellcheck disable` directives.
- `install.sh` no longer forces `-o root -g root` on sudo installs — BSDs
  have no `root` group (it is `wheel`), and sudo already owns the file.

## [v2.1.0] — 2026-08-05

### Removed
- `whales` / `tracking` and `entities` / `ents` commands removed — low
  value, nobody needs to ask about it. `whales` and `entities` now fall
  through the normal typo/AI resolution path like any unknown word.

## [v2.0.1] — 2026-08-04

### Changed
- **Human voice overhaul** — the CLI stopped talking like an AI:
  - Typo fixes now say `"fgredd"? you mean "fg". running it.` instead of
    `I read "fgredd" as "fg" — running it.`
  - The spinner says `wtf is "fgredd"? hold on...` instead of
    `AI: reading "fgredd"…`; `novrix ai` says `let me think...` instead of
    `AI: thinking…`.
  - The AI agent's system prompt is now a cypherpunk crypto nerd, not a
    corporate bot: short American words, `lol` / `lmao`, light roasts,
    no em dashes, never "this is / this isn't".
  - Troll roasts went lowercase and chiller: `chill lol, "help" is right
    there. breathe. 😏`, `watch your language lol, family CLI here 😤`,
    `go on, i dare you.`
  - Clarification is now `lol what even is "zzzzz"? 😏 i got nothing on
    that. what did you mean?` — no more "champ".
  - Em dashes stripped from every user-facing string (usage, version,
    shortcuts, banner).

## [v2.0.0] — 2026-08-04

### Added
- **Cross-platform support**: macOS (stock bash 3.2 handled with a friendly
  guard), every Linux distribution, Windows (Git Bash / MSYS2 / Cygwin / WSL),
  and the BSDs.
- **Modular source layout** under `src/` with a deterministic `build.sh`
  assembler (`bin/novrix` is the built, committed, single-file artifact).
- **OS/distro-aware installer** (`install.sh`): auto-detects OS + distro +
  arch, installs missing dependencies with the right package manager
  (`--install-deps`), supports `--local`, `--prefix`, `--version`, `--no-sudo`,
  and falls back to `wget` when `curl` is absent.
- **Windows launcher** `novrix.cmd` for Git Bash / MSYS2 / Cygwin users.
- **GitHub Actions CI** on ubuntu / macOS / windows: builds from `src/`,
  runs the offline suite, lints with shellcheck, and fails if the committed
  artifact drifted from `src/`.
- Portability hardening: `NO_COLOR` support, `tr`-based lowercase (no
  `${var,,}`), portable `stat` cache-age (no `find -mmin`), tolerant
  `set -euo pipefail` for bash < 4.

### Changed
- The repo is now modular (`src/`) — the shipped release asset is still one
  file. The old root-level `novrix` file was removed; `bin/novrix` is the
  canonical artifact.
- `make` targets updated (`build`, `test`, `lint`, `check`, `install`).

### Fixed
- Deterministic build output — CI verifies `bin/novrix` matches `src/` byte
  for byte.

## [v1.5.1] — 2026-07-28

### Added
- Troll easter egg: swearing at the CLI (`fucking`, `wtf`, `damn`, …) gets a
  roast instead of data.

## [v1.5.0] — 2026-07-27

### Added
- AI-driven command understanding: novrix never says "unknown command".
  The AI reads what you typed, maps it to the intended command, and runs it
  with a "thinking" animation.
- The AI answers what you meant; if it can't find a command meaning it asks
  what you meant.

## [v1.4.1] — 2026-07-26

### Fixed
- Infinite recursion when `fear and greed index` was mis-resolved to
  `clear` — fuzzy matcher now rejects self-matches and proportional
  mismatches.

## [v1.4.0] — 2026-07-25

### Added
- DeepSeek-powered AI agent (`novrix ai "…"`, alias `ask`).
- Automatic typo correction: wrong/partial commands are understood and run.

## [v1.3.0] — 2026-07-20

### Added
- Metrilytics commands: `tvl`, `defi`, `mkt`, `stables`, `dex`, `fees`,
  `dom`, `opts`, `prots`, `bridges`, `lending`, `prices`, `oi`.
- Tracking commands: `whales`, `ents` (entities).
- Interactive mode, `shortcuts`, `clear`.

## [v1.2.0] — 2026-07-15

### Added
- Macro commands: `cpi`, `unrate`, `gdp`, `nfp`, `claims`, `jolts`, `ccpi`,
  `pce`, `cpce`, `umich`, `oil`, `t30`, `curve`, `be`, `dxy`, `gold`, `spx`,
  `vix`, `ffr`, `m2`.

## [v1.1.0] — 2026-07-10

### Added
- `--json`, `--fresh`, `--days`, `--months`, `--top` flags.
- Local response caching (300 s TTL).

## [v1.0.0] — 2026-07-05

### Added
- First release. Sentiment commands: `fg`, `nupl`, `mvrv`, `sopr`, `puell`,
  `rhodl`, `mayer`, `rr`, `rp`, `rpf`, `rpl`, `mcap`, `btc`, `200ma`,
  `addrs`, `hash`, `scs`, `btoi`, `funding`, `etf`.

[Unreleased]: https://github.com/ethanhunthere/novrix-cli/compare/v2.9.7...main
[v2.9.8]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.9.8
[v2.9.7]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.9.7
[v2.9.6]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.9.6
[v2.9.5]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.9.5
[v2.9.4]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.9.4
[v2.9.3]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.9.3
[v2.9.2]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.9.2
[v2.9.1]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.9.1
[v2.9.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.9.0
[v2.8.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.8.0
[v2.7.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.7.0
[v2.6.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.6.0
[v2.5.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.5.0
[v2.4.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.4.0
[v2.3.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.3.0
[v2.2.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.2.0
[v2.1.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.1.0
[v2.0.1]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.0.1
[v2.0.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v2.0.0
[v1.5.1]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v1.5.1
[v1.5.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v1.5.0
[v1.4.1]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v1.4.1
[v1.4.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v1.4.0
[v1.3.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v1.3.0
[v1.2.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v1.2.0
[v1.1.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v1.1.0
[v1.0.0]: https://github.com/ethanhunthere/novrix-cli/releases/tag/v1.0.0
