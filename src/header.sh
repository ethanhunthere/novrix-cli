#!/usr/bin/env bash
#
# novrix — a fast, tiny CLI for NOVRIX public market data (novrix.io)
#
#   market data:  fg nupl mvrv tvl …   (60+ commands)
#   AI agent:     novrix ai "ask anything"
#   typos:        novrix mvvrv  →  auto-understood, fixed, and run
#
# Dependencies: bash 4+, curl, jq. No account, no API key for market data.
#
# Source layout (this file is assembled by build.sh from src/ modules):
#   src/header.sh        shebang + banner
#   src/lib/bootstrap.sh runtime guards, constants, colors
#   src/lib/core.sh      helpers: die, need_cmd, spinner, options, cache
#   src/lib/api.sh       api_get — fixtures, caching, curl
#   src/lib/format.sh    jq snippets + render helpers
#   src/lib/data.sh      SERIES / META / ALIASES registries
#   src/lib/telegram.sh  telegram channel reader (t.me/s, no key)
#   src/lib/ai.sh        DeepSeek AI agent
#   src/lib/typo.sh      troll easter egg + fuzzy/AI typo resolution
#   src/lib/commands.sh  every cmd_* implementation
#   src/lib/cli.sh       dispatch, REPL, entry point
#
# Build:  bash build.sh   →   bin/novrix
# Test:   bash tests/smoke.sh
