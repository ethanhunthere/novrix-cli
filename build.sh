#!/usr/bin/env bash
#
# build.sh — assemble the single-file novrix CLI from the src/ modules.
#
#   bash build.sh          → bin/novrix   (also used by `make build`)
#   bash build.sh /tmp/x   → /tmp/x
#
# The build is deterministic and fully offline: modules are concatenated in
# dependency order, so the artifact is byte-identical for the same source
# tree. bin/novrix is committed to the repo — it is what the release asset
# and the install script ship, and `./novrix` stays a single self-contained
# file so installing stays one `curl | bash` away.
set -euo pipefail

cd "$(dirname "$0")"

OUT="${1:-bin/novrix}"

# build order — dependency-first; cli.sh (main) must be last
MODULES=(
  src/header.sh
  src/lib/bootstrap.sh
  src/lib/core.sh
  src/lib/api.sh
  src/lib/format.sh
  src/lib/data.sh
  src/lib/telegram.sh
  src/lib/ai.sh
  src/lib/typo.sh
  src/lib/commands.sh
  src/lib/cli.sh
)

# syntax-check every module before assembling
for m in "${MODULES[@]}"; do
  [[ -f "$m" ]] || { printf 'build: missing module %s\n' "$m" >&2; exit 1; }
  bash -n "$m" || { printf 'build: syntax error in %s\n' "$m" >&2; exit 1; }
done

mkdir -p "$(dirname "$OUT")"
: >"$OUT"
for m in "${MODULES[@]}"; do
  cat "$m" >>"$OUT"
  printf '\n' >>"$OUT"
done
chmod +x "$OUT"

bash -n "$OUT" || { printf 'build: assembled artifact has a syntax error\n' >&2; exit 1; }

printf 'built %s (%s lines, %s bytes)\n' "$OUT" "$(wc -l <"$OUT" | tr -d ' ')" "$(wc -c <"$OUT" | tr -d ' ')"
