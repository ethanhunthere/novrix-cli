# ---------------------------------------------------------------------------
# data — the command registries. Kept as flat text tables (name|field|…)
# so the CLI can stay small, predictable, and easy to extend: add one line
# here and the command exists (usage/help/shortcuts/typo-matching all pick
# it up automatically).
# ---------------------------------------------------------------------------

# series registry — generic time-series commands
#   name|path|field|label|format|unit|period
# format: usd ($+abbr) · abbr (no $) · num0/num1/num2/num4 decimals
#         pct2 (two-dec %) · rate4 (funding-rate %)
# period: daily (YYYY-MM-DD) | monthly (YYYY-MM)
declare -A SERIES=(
  # ---- crypto sentiment (fg + nupl are dedicated commands) ----
  [mvrv]="/api/mvrv-zscore|value|MVRV Z-SCORE|num2||daily"
  [sopr]="/api/sopr|sopr|SOPR|num3||daily"
  [puell]="/api/puell-multiple|value|PUELL MULTIPLE|num2||daily"
  [rhodl]="/api/rhodl-ratio|value|RHODL RATIO|num1||daily"
  [mayer]="/api/mayer-multiple|value|MAYER MULTIPLE|num2||daily"
  [reserve-risk]="/api/reserve-risk|value|RESERVE RISK|num4||daily"
  [realized-price]="/api/realized-price|value|REALIZED PRICE|usd||daily"
  [realized-profit]="/api/realized-profit|realized_profit|REALIZED PROFIT|usd||daily"
  [realized-loss]="/api/realized-loss|realized_loss|REALIZED LOSS|usd||daily"
  [market-cap]="/api/crypto-market-cap|value|CRYPTO MARKET CAP|usd||daily"
  [btc-price]="/api/btc-price|price|BTC PRICE|usd||daily"
  [200-week-ma]="/api/200-week-ma|value|200W MA|usd||daily"
  [active-addresses]="/api/active-addresses|value|ACTIVE ADDRESSES|num0||daily"
  [hashrate]="/api/hashrate|hashrate|HASHRATE|abbr|H/s|daily"
  [stablecoin-supply]="/api/stablecoin-supply|value|STABLECOIN SUPPLY|usd||daily"
  [open-interest]="/api/open-interest|value|BTC OPEN INTEREST|usd||daily"
  [funding-rate]="/api/funding-rate|value|FUNDING RATE|rate4||daily"
  [etf]="/api/etf|value|BTC ETF FLOWS|num0|BTC|daily"

  # ---- macro (cpi is a dedicated command) ----
  [unrate]="/api/fred-unrate|value|US UNEMPLOYMENT|pct2||monthly"
  [gdp]="/api/fred-gdpc1|value|US GDP|num2||monthly"
  [payrolls]="/api/fred-payems|value|NONFARM PAYROLLS|num0||monthly"
  [claims]="/api/fred-icsa|value|INITIAL CLAIMS|num0||monthly"
  [job-openings]="/api/fred-jtsjol|value|JOB OPENINGS|num0||monthly"
  [core-cpi]="/api/fred-cpilfesl|value|CORE CPI|num2||monthly"
  [pce]="/api/fred-pcepi|value|PCE PRICE INDEX|num2||monthly"
  [core-pce]="/api/fred-pcepilfe|value|CORE PCE|num2||monthly"
  [umich]="/api/fred-umcsent|value|U.MICH SENTIMENT|num2||monthly"
  [oil]="/api/fred-dcoilwtico|value|WTI OIL|usd||daily"
  [us30y]="/api/fred-dgs30|value|US 30Y YIELD|pct2||daily"
  [t10y2y]="/api/fred-t10y2y|value|10Y-2Y SPREAD|pct2||daily"
  [breakeven]="/api/fred-t10yie|value|10Y BREAKEVEN|pct2||daily"
  [dxy]="/api/dxy|value|DOLLAR INDEX|num2||daily"
  [gold]="/api/gold|value|GOLD|usd||daily"
  [sp500]="/api/sp500|value|S&P 500|num2||daily"
  [vix]="/api/vix|value|VIX|num2||daily"
  [fedfunds]="/api/fedfunds|value|FED FUNDS RATE|pct2||monthly"
  [m2]="/api/m2|value|M2 MONEY SUPPLY|usd||monthly"
)

# FRED series ids for the series that exist on fred.stlouisfed.org. Used by
# the dated-question fallback: when novrix history does not reach a date,
# fetch the observation straight from FRED (keyless fredgraph.csv export).
# Series without an entry here (fg/nupl/tvl/…, and dxy/gold with no direct
# FRED daily id) keep routing to the AI agent instead.
declare -A FRED_ID=(
  [unrate]="UNRATE"
  [gdp]="GDPC1"
  [payrolls]="PAYEMS"
  [claims]="ICSA"
  [job-openings]="JTSJOL"
  [core-cpi]="CPILFESL"
  [pce]="PCEPI"
  [core-pce]="PCEPILFE"
  [umich]="UMCSENT"
  [oil]="DCOILWTICO"
  [us30y]="DGS30"
  [t10y2y]="T10Y2Y"
  [breakeven]="T10YIE"
  [cpi]="CPIAUCSL"
  [fedfunds]="FEDFUNDS"
  [m2]="M2SL"
  [sp500]="SP500"
  [vix]="VIXCLS"
)

# metrilytics summary one-liners — name -> jq program (summary fields are strings)
declare -A META=(
  [defi]='"DEFI TVL · $" + (.summary.total_defi_tvl|tonumber|abbr) + " · top: " + .summary.top_chain_by_tvl + " · " + .summary.top_protocol_by_tvl'
  [stablecoins]='"STABLECOIN SUPPLY · $" + (.summary.total_stablecoin_supply|tonumber|abbr)'
  [dex]='"DEX VOLUME 24H · $" + (.summary.total_dex_volume_24h|tonumber|abbr)'
  [fees]='"PROTOCOL FEES 24H · $" + (.summary.protocol_fees_24h|tonumber|abbr) + " · revenue $" + (.summary.protocol_revenue_24h|tonumber|abbr)'
  [options]='"OPTIONS VOLUME 24H · $" + (.summary.options_volume_24h|tonumber|abbr)'
  [dominance]='"DOMINANCE · BTC " + (.summary.btc_dominance|tonumber|p2) + "% · ETH " + (.summary.eth_dominance|tonumber|p2) + "% · SOL " + (.summary.sol_dominance|tonumber|p2) + "%"'
  [prices]='"PRICES · BTC $" + (.summary.btc_price|tonumber|abbr) + " · ETH $" + (.summary.eth_price|tonumber|abbr) + " · SOL $" + (.summary.sol_price|tonumber|abbr)'
  [oi]='"OPEN INTEREST · BTC $" + (.summary.btc_open_interest|tonumber|abbr) + " · DEFI perps $" + (.summary.defi_perp_open_interest|tonumber|abbr)'
)

# short-name aliases — short -> canonical command name
# canonical names (SERIES/META keys, cmd_* functions) stay the same; the
# aliases below are the primary, easier-to-type names shown in the banner
# and help. Long names keep working everywhere.
declare -A ALIASES=(
  # ---- crypto sentiment ----
  [rr]="reserve-risk"
  [rp]="realized-price"
  [rpf]="realized-profit"
  [rpl]="realized-loss"
  [mcap]="market-cap"
  [btc]="btc-price"
  [200ma]="200-week-ma"
  [addrs]="active-addresses"
  [hash]="hashrate"
  [scs]="stablecoin-supply"
  [btoi]="open-interest"
  [funding]="funding-rate"
  # 'fear' / 'greed' are NOT aliases — they stay unknown so multi-word
  # phrases like 'fear and greed index' reach the AI matcher as a whole.
  # ---- macro ----
  [nfp]="payrolls"
  [jolts]="job-openings"
  [ccpi]="core-cpi"
  [cpce]="core-pce"
  [t30]="us30y"
  [curve]="t10y2y"
  [be]="breakeven"
  [spx]="sp500"
  [ffr]="fedfunds"
  # ---- metrilytics ----
  [mkt]="market"
  [stables]="stablecoins"
  # ---- telegram ----
  [tg]="telegram"
  [dom]="dominance"
  [opts]="options"
  [prots]="protocols"
)
