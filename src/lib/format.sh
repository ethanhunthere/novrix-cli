# ---------------------------------------------------------------------------
# format — shared jq snippets and small render helpers
# ---------------------------------------------------------------------------

# jq snippet: abbreviate a USD number (e.g. 1179803014 -> 1.18B)
readonly JQ_ABBR='def abbr: if . < 0 then ("-" + ((-.)|abbr)) elif . >= 1e12 then ((./1e12*100|round/100|tostring)+"T") elif . >= 1e9 then ((./1e9*100|round/100|tostring)+"B") elif . >= 1e6 then ((./1e6*100|round/100|tostring)+"M") elif . >= 1e3 then ((./1e3*100|round/100|tostring)+"K") else ((.*100|round/100|tostring)) end;'

# jq snippets for the metrilytics summary (values arrive as strings)
readonly JQ_META='def p2: ((.*100|round)/100|tostring); def p1: ((.*10|round)/10|tostring);'

nupl_zone() {
  local mv="$1"
  if   (( mv >= 500 ));  then echo "Euphoria"
  elif (( mv >= 250 ));  then echo "Greed"
  elif (( mv >= 0 ));    then echo "Optimism"
  elif (( mv >= -250 )); then echo "Anxiety"
  elif (( mv >= -500 )); then echo "Fear"
  else echo "Capitulation"; fi
}

pct() {
  if [[ "$1" == "nan" ]]; then printf '%8s' "-"; return; fi
  LC_ALL=C printf '%6.2f%%' "$1"
}

# like pct but unpadded, for single-line summaries
fmtpct() {
  if [[ "$1" == "nan" ]]; then printf -- "-"; return; fi
  LC_ALL=C printf '%+.2f%%' "$1"
}

# format code -> jq expression formatting the value $v
# shellcheck disable=SC2016  # these are jq programs — $v must stay literal
series_val_expr() {
  case "$1" in
    usd)   echo '(if $v < 0 then "-$" + ((-$v)|abbr) else "$" + ($v|abbr) end)' ;;
    abbr)  echo '($v|abbr)' ;;
    num0)  echo '($v|round|tostring)' ;;
    num1)  echo '(($v*10|round)/10|tostring)' ;;
    num2)  echo '(($v*100|round)/100|tostring)' ;;
    num3)  echo '(($v*1000|round)/1000|tostring)' ;;
    num4)  echo '(($v*10000|round)/10000|tostring)' ;;
    pct2)  echo '(($v*100|round)/100|tostring) + "%"' ;;
    rate4) echo '(($v*100*10000|round)/10000|tostring) + "%"' ;;
    *)     echo '($v|tostring)' ;;
  esac
}

# ---------------------------------------------------------------------------
# design — color helpers and table rules (all render plain when
# piped — color codes are only set on a TTY)
# ---------------------------------------------------------------------------

# sign_col <value> — green for positive, red for negative, plain for "-"
sign_col() {
  case "$1" in
    "-") printf '%s' "$c_reset" ;;
    -*)  printf '%s' "$c_red" ;;
    *)   printf '%s' "$c_green" ;;
  esac
}

# fg_col <score> — zone color for a fear & greed score (0-100)
fg_col() {
  local score="$1"
  if   (( score >= 75 )); then printf '%s' "$c_bold$c_green"
  elif (( score >= 55 )); then printf '%s' "$c_green"
  elif (( score >= 45 )); then printf '%s' "$c_reset"
  elif (( score >= 25 )); then printf '%s' "$c_yellow"
  else printf '%s' "$c_red"; fi
}

# hr <width> — a dim horizontal rule for table headers
hr() {
  local w="$1" s=""
  printf -v s '%*s' "$w" ''
  printf '%s%s%s\n' "$c_dim" "${s// /-}" "$c_reset"
}
