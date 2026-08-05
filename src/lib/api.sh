# ---------------------------------------------------------------------------
# api — HTTP access to novrix.io with an offline fixture mode and a local
# response cache. The freshness check is portable across GNU/macOS/busybox
# stat (no reliance on `find -mmin`, which BSD/macOS find lacks).
# ---------------------------------------------------------------------------
api_get() {
  local path="$1" ttl="${2:-$DEFAULT_TTL}"
  local key file

  # Offline / fixture mode (used by tests and demos): NOVRIX_API_DIR=<dir>
  if [[ -n "${NOVRIX_API_DIR:-}" ]]; then
    key="$(printf '%s' "$path" | tr -c '[:alnum:]' '_')"
    file="$NOVRIX_API_DIR/$key.json"
    [[ -f "$file" ]] || die "fixture not found: $file (NOVRIX_API_DIR=$NOVRIX_API_DIR)"
    cat "$file"
    return 0
  fi

  key="$(printf '%s' "$path" | tr -c '[:alnum:]' '_')"
  file="$CACHE_ROOT/$key.json"
  mkdir -p "$CACHE_ROOT"

  # serve from cache while it is younger than ttl (rounded up to whole minutes)
  if [[ "$opt_fresh" != 1 && -f "$file" ]] \
     && (( $(file_age_min "$file") < (ttl + 59) / 60 )); then
    cat "$file"
    return 0
  fi

  local body
  body="$(curl -sS --connect-timeout 10 --max-time "$CURL_TIMEOUT" -A "$UA" "$BASE_URL$path")" \
    || die "network error fetching $path (curl exit $?)"

  if ! jq -e '.success == true' <<<"$body" >/dev/null 2>&1; then
    printf '%s\n' "$body" >&2
    die "unexpected API response for $path, is novrix.io up, or are we being rate-limited?"
  fi

  printf '%s\n' "$body" >"$file"
  printf '%s\n' "$body"
}
