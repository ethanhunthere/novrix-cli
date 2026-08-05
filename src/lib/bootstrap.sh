# ---------------------------------------------------------------------------
# bootstrap — runtime guards, constants, colors
# (part of the novrix CLI; see src/header.sh for build notes)
# ---------------------------------------------------------------------------

set -euo pipefail 2>/dev/null || set -eu   # tolerant of bash < 4.0 pipefail

readonly PROG="novrix"
readonly VERSION="1.0.0"

# bash 3.2 (the version Apple ships on macOS) lacks associative arrays and
# other features we rely on — fail fast with a fix instead of a wall of
# confusing errors. This guard runs before the registries in data.sh load.
if (( BASH_VERSINFO[0] < 4 )); then
  printf 'error: %s needs bash 4+ (found %s).\n' "$PROG" "${BASH_VERSION:-unknown}"
  printf '  macOS ships bash 3.2, install a newer one, then run it explicitly:\n'
  printf '    brew install bash\n'
  printf '    /opt/homebrew/bin/bash %s ...\n' "${BASH_SOURCE[0]:-$0}"
  printf '  or install novrix again (install.sh handles this for you).\n'
  exit 1
fi

readonly BASE_URL="${NOVRIX_API_BASE:-https://novrix.io}"
readonly CACHE_ROOT="${NOVRIX_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/$PROG}"
readonly UA="$PROG/$VERSION (+https://novrix.io)"
readonly CURL_TIMEOUT=20
# response cache TTL in seconds — overridable via NOVRIX_TTL (die() is not
# defined yet at this point, so validate with a plain printf + exit)
readonly DEFAULT_TTL="${NOVRIX_TTL:-300}"
if ! [[ "$DEFAULT_TTL" =~ ^[1-9][0-9]*$ ]]; then
  printf '%s: NOVRIX_TTL must be a positive integer (seconds), got %s\n' "$PROG" "$NOVRIX_TTL" >&2
  exit 1
fi

# metrilytics endpoints require this version stamp
readonly META_V="full-history-20260513b"

# AI agent (DeepSeek)
readonly DEEPSEEK_BASE="${DEEPSEEK_API_BASE:-https://api.deepseek.com}"
readonly CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$PROG"
readonly KEYS_FILE="$CONF_DIR/keys.conf"

# options
opt_json=0
opt_fresh=0
opt_days=""
opt_top=""
opt_months=""

# colors — only when stdout is a TTY and NO_COLOR is not set
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  c_reset=$'\e[0m'; c_dim=$'\e[2m'; c_bold=$'\e[1m'
  c_red=$'\e[31m'; c_yellow=$'\e[33m'; c_green=$'\e[32m'
else
  c_reset=""; c_dim=""; c_bold=""; c_red=""; c_yellow=""; c_green=""
fi
