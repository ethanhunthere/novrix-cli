#!/usr/bin/env bash
#
# install.sh — install the novrix CLI from GitHub Releases.
#
# One-liner (latest release):
#   curl -fsSL https://raw.githubusercontent.com/ethanhunthere/novrix-cli/main/install.sh | bash
#
# From a local checkout:
#   bash install.sh
#
# Options:
#   --local                  Install to ~/.local/bin (no sudo, recommended
#                            on macOS/Windows and for containers)
#   --prefix DIR             Install to DIR/bin
#   --version TAG            Pin a specific release (e.g. v2.0.0)
#   --install-deps           Auto-install missing prerequisites (curl, jq,
#                            bash 4+) with the system package manager
#   --no-sudo                Never use sudo; fail instead of prompting
#   --no-path                Don't add the install dir to your shell rc
#                            (novrix auto-adds it to PATH when missing)
#
# Environment:
#   NOVRIX_VERSION, PREFIX, BIN_DIR, DESTDIR (same semantics as the flags)
#
# Detects the OS/architecture, downloads the release asset "novrix" (a
# single bash script), smoke-tests it, and installs it. Works on Linux
# (every distro, incl. Alpine/busybox), macOS, Windows (Git Bash/MSYS2/Cygwin
# and WSL), FreeBSD and the other BSDs.
set -euo pipefail 2>/dev/null || set -eu

readonly REPO="ethanhunthere/novrix-cli"
readonly ASSET="novrix"
VERSION="${NOVRIX_VERSION:-latest}"
PREFIX="${PREFIX:-}"
BIN_DIR="${BIN_DIR:-}"
DESTDIR="${DESTDIR:-}"
INSTALL_DEPS=0
NO_SUDO=0
NO_PATH=0
TMP_DIR=""

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
say()  { printf 'novrix-installer: %s\n' "$*"; }
die()  { printf 'novrix-installer: error: %s\n' "$*" >&2; exit 1; }
cleanup() { [[ -n "${TMP_DIR:-}" ]] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM

# detect the OS we are running on (uname -s normalised)
detect_os() {
  local s
  s="$(uname -s 2>/dev/null || echo unknown)"
  case "$s" in
    Linux)          echo linux ;;
    Darwin)         echo macos ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    FreeBSD)        echo freebsd ;;
    OpenBSD)        echo openbsd ;;
    NetBSD)         echo netbsd ;;
    *)              echo "$s" ;;
  esac
}

# detect the Linux distribution from /etc/os-release
detect_distro() {
  [[ -r /etc/os-release ]] || return 0
  # shellcheck disable=SC1091
  . /etc/os-release
  printf '%s\n' "${ID:-linux}"
}

detect_arch() {
  uname -m 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo unknown
}

# ---------------------------------------------------------------------------
# argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)        PREFIX="$HOME/.local"; shift ;;
    --prefix)       [[ $# -ge 2 ]] || die "--prefix needs a directory"; PREFIX="$2"; shift 2 ;;
    --prefix=*)     PREFIX="${1#*=}"; shift ;;
    --version)      [[ $# -ge 2 ]] || die "--version needs a tag"; VERSION="$2"; shift 2 ;;
    --version=*)    VERSION="${1#*=}"; shift ;;
    --install-deps) INSTALL_DEPS=1; shift ;;
    --no-sudo)      NO_SUDO=1; shift ;;
    --no-path)      NO_PATH=1; shift ;;
    --help|-h)      sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)              die "unknown argument: $1 (see --help)" ;;
  esac
done

OS="$(detect_os)"
DISTRO="$(detect_distro)"
ARCH="$(detect_arch)"

# default prefix per OS — /usr/local on unix (sudo when needed), ~/.local
# on Windows (no admin required) and when the user picked --local
if [[ -z "$PREFIX" ]]; then
  case "$OS" in
    windows) PREFIX="$HOME/.local" ;;
    *)       PREFIX="/usr/local" ;;
  esac
fi
[[ -n "$BIN_DIR" ]] || BIN_DIR="$PREFIX/bin"

# ---------------------------------------------------------------------------
# prerequisites
# ---------------------------------------------------------------------------
missing() { command -v "$1" >/dev/null 2>&1 || echo "$1"; }

MISSING_DEPS=""
for tool in curl jq; do
  t="$(missing "$tool")"
  [[ -z "$t" ]] || MISSING_DEPS="$MISSING_DEPS $t"
done

# bash 4+ is required by the CLI itself
if ! command -v bash >/dev/null 2>&1; then
  MISSING_DEPS="$MISSING_DEPS bash"
elif [[ -n "${BASH_VERSINFO:-}" ]] && (( BASH_VERSINFO[0] < 4 )); then
  say "note: the system bash is too old (bash 3.x) — novrix needs bash 4+."
  say "  install a modern bash, e.g. 'brew install bash', then re-run the installer with it:"
  say "    /opt/homebrew/bin/bash install.sh"
  MISSING_DEPS="$MISSING_DEPS bash4"
fi

if [[ -n "$MISSING_DEPS" ]]; then
  say "missing prerequisites:$MISSING_DEPS (os=$OS distro=${DISTRO:-?} arch=$ARCH)"
  if (( INSTALL_DEPS )); then
    say "installing missing dependencies…"
    case "$OS:$DISTRO" in
      windows:*)
        # Git Bash already ships bash + curl — only jq may be missing.
        if command -v winget >/dev/null 2>&1; then
          winget install --id jqlang.jq -e --accept-source-agreements --accept-package-agreements || die "winget install of jq failed"
        elif command -v choco >/dev/null 2>&1; then
          choco install -y jq || die "choco install of jq failed"
        elif command -v scoop >/dev/null 2>&1; then
          scoop install jq || die "scoop install of jq failed"
        else
          # no package manager at all — drop the official jq.exe into the
          # install dir (no admin needed) and expose it for this run
          say "no package manager found — downloading the official jq.exe into $BIN_DIR"
          mkdir -p "$BIN_DIR"
          if command -v curl >/dev/null 2>&1; then
            curl -fsSL --connect-timeout 10 --max-time 120 -o "$BIN_DIR/jq.exe" \
              "https://github.com/jqlang/jq/releases/latest/download/jq-windows-amd64.exe" \
              || die "failed to download jq.exe"
          elif command -v wget >/dev/null 2>&1; then
            wget -qO "$BIN_DIR/jq.exe" \
              "https://github.com/jqlang/jq/releases/latest/download/jq-windows-amd64.exe" \
              || die "failed to download jq.exe"
          else
            die "no curl/wget available to fetch jq.exe"
          fi
          export PATH="$BIN_DIR:$PATH"
        fi
        ;;
      macos:*)
        command -v brew >/dev/null 2>&1 || die "Homebrew is required on macOS (https://brew.sh) — or install curl, jq and bash manually"
        brew install curl jq bash || die "brew install failed"
        ;;
      linux:debian|linux:ubuntu|linux:raspbian)
        { sudo apt-get update && sudo apt-get install -y curl jq bash; } || die "apt-get install failed"
        ;;
      linux:fedora|linux:rhel|linux:centos|linux:rocky|linux:almalinux)
        sudo dnf install -y curl jq bash || sudo yum install -y curl jq bash || die "dnf/yum install failed"
        ;;
      linux:arch|linux:manjaro|linux:endeavouros)
        sudo pacman -Sy --noconfirm curl jq bash || die "pacman install failed"
        ;;
      linux:alpine)
        sudo apk add --no-cache curl jq bash || die "apk install failed"
        ;;
      linux:opensuse*|linux:suse)
        sudo zypper install -y curl jq bash || die "zypper install failed"
        ;;
      *)
        die "I don't know how to install deps on $OS/$DISTRO — install curl, jq and bash manually, then re-run"
        ;;
    esac
  else
    case "$OS" in
      windows) die "install Git for Windows (https://git-scm.com) or WSL (https://learn.microsoft.com/windows/wsl), then re-run this installer inside Git Bash — or pass --install-deps" ;;
      macos)   die "install curl, jq and bash 4+, e.g. 'brew install curl jq bash' — or re-run with --install-deps" ;;
      linux)   case "$DISTRO" in
                 debian|ubuntu|raspbian)    die "run 'sudo apt-get install -y curl jq bash' or re-run with --install-deps" ;;
                 fedora|rhel|centos|rocky|almalinux) die "run 'sudo dnf install -y curl jq bash' or re-run with --install-deps" ;;
                 arch|manjaro|endeavouros)  die "run 'sudo pacman -S --noconfirm curl jq bash' or re-run with --install-deps" ;;
                 alpine)                    die "run 'sudo apk add --no-cache curl jq bash' or re-run with --install-deps" ;;
                 *) die "install curl, jq and bash for $DISTRO, then re-run (or use --install-deps)" ;;
               esac ;;
      *) die "install curl, jq and bash 4+ for $OS, then re-run (or use --install-deps)" ;;
    esac
  fi
fi

# curl is preferred; fall back to wget (busybox wget included) when absent
fetch() { # fetch <url> <dest>
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 10 --max-time 120 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    die "neither curl nor wget is available"
  fi
}

# ---------------------------------------------------------------------------
# download
# ---------------------------------------------------------------------------
say "repo: $REPO · version: $VERSION · os: $OS · distro: ${DISTRO:-n/a} · arch: $ARCH · prefix: $PREFIX"

if [[ "$VERSION" == "latest" ]]; then
  URL="https://github.com/$REPO/releases/latest/download/$ASSET"
else
  URL="https://github.com/$REPO/releases/download/$VERSION/$ASSET"
fi

TMP_DIR="$(mktemp -d)"
TARGET="$TMP_DIR/$ASSET"

say "downloading $URL"
fetch "$URL" "$TARGET" || die "download failed — does release '$VERSION' exist?"

[[ -s "$TARGET" ]] || die "downloaded file is empty"
chmod +x "$TARGET"

# ---------------------------------------------------------------------------
# smoke test — make sure the download really is novrix
# ---------------------------------------------------------------------------
head -c 2 "$TARGET" | grep -q '#!' || die "downloaded file does not look like a script"
if command -v jq >/dev/null 2>&1; then
  "$TARGET" --version >/dev/null 2>&1 || die "downloaded novrix failed its smoke test"
else
  say "note: jq not present, skipping the version smoke test (will run at first use)"
fi

# ---------------------------------------------------------------------------
# install
# ---------------------------------------------------------------------------
DEST="$DESTDIR$BIN_DIR"
mkdir -p "$DEST"

if [[ -w "$DEST" ]]; then
  install -m 0755 "$TARGET" "$DEST/$ASSET"
elif (( NO_SUDO )); then
  die "no write access to $DEST — re-run with '--local' or '--prefix ~/.local'"
else
  command -v sudo >/dev/null 2>&1 || die "no write access to $DEST and sudo is missing (try: bash install.sh --local)"
  say "installing to $DEST/$ASSET (needs sudo)"
  # no -o/-g flags: BSDs have no 'root' group (it is 'wheel'), and a
  # sudo-run install already leaves the file owned by root either way
  sudo install -m 0755 "$TARGET" "$DEST/$ASSET"
fi

# ---------------------------------------------------------------------------
# PATH setup — auto-add the install dir when it isn't on PATH
# ---------------------------------------------------------------------------
in_path() { # in_path <dir> — 0 if <dir> is on PATH
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
  esac
  return 1
}

if (( NO_PATH )); then
  say "PATH not modified (--no-path)"
else
  # always make sure the install dir is persisted in the shell rc, even if
  # it happens to be on the current session's PATH (e.g. the Windows
  # bootstrapper pre-exports it) — persistence is what matters.
  if [[ "$OS" == "windows" ]]; then
    RC_FILE="$HOME/.bash_profile"
  elif [[ -f "$HOME/.bashrc" ]]; then
    RC_FILE="$HOME/.bashrc"
  else
    RC_FILE="$HOME/.profile"
  fi
  if [[ -f "$RC_FILE" ]] && grep -qF "$BIN_DIR" "$RC_FILE"; then
    say "$BIN_DIR already listed in $RC_FILE"
  else
    printf '\n# added by the novrix installer\n%s\n' "export PATH=\"$BIN_DIR:\$PATH\"" >> "$RC_FILE"
    say "added 'export PATH=\"$BIN_DIR:\$PATH\"' to $RC_FILE"
  fi
  if in_path "$BIN_DIR"; then
    say "$BIN_DIR is on PATH for this session"
  else
    say "open a new terminal (or 'source $RC_FILE') and novrix will be on PATH"
  fi
fi

printf '\ninstalled: %s\n' "$DEST/$ASSET"
printf 'run "%s --help" to get started\n' "$DEST/$ASSET"
