#!/bin/bash
#
# check_ollama_update.sh
#
# Checks whether a newer version of Ollama is available and, when one is
# found, optionally triggers upgrade_ollama.sh automatically.
#
# Usage:
#   ./check_ollama_update.sh [--auto-upgrade] [--silent]
#
# Options:
#   --auto-upgrade   Automatically run upgrade_ollama.sh when an update is
#                    found.  Without this flag the script exits with code 1
#                    when an update is available so the caller can decide what
#                    to do (handy for cron jobs).
#   --silent         Suppress all informational output.  Error messages are
#                    still printed to stderr.  Useful when running from cron.
#
# Exit codes:
#   0  Ollama is up to date (or was just successfully upgraded).
#   1  A newer version is available (only when --auto-upgrade is NOT used).
#   2  A runtime error occurred (Ollama not installed, network failure, etc.).
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
AUTO_UPGRADE=false
SILENT=false

for arg in "$@"; do
  case "$arg" in
    --auto-upgrade) AUTO_UPGRADE=true ;;
    --silent)       SILENT=true ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: $0 [--auto-upgrade] [--silent]" >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

info() {
  if [ "$SILENT" = false ]; then
    echo -e "${BOLD}${BLUE}${1}${NC}"
  fi
}

warn() {
  if [ "$SILENT" = false ]; then
    echo -e "${BOLD}${YELLOW}${1}${NC}"
  fi
}

success() {
  if [ "$SILENT" = false ]; then
    echo -e "${BOLD}${GREEN}${1}${NC}"
  fi
}

error() {
  # Errors always go to stderr regardless of --silent.
  echo -e "${BOLD}${RED}${1}${NC}" >&2
}

# Strip a leading 'v' from a version string so comparisons work uniformly.
# e.g.  v0.6.5  ->  0.6.5
strip_v() {
  echo "${1#v}"
}

# ---------------------------------------------------------------------------
# Locate upgrade script (same directory as this script)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPGRADE_SCRIPT="${SCRIPT_DIR}/upgrade_ollama.sh"

# ---------------------------------------------------------------------------
# Step 1 – Confirm Ollama is installed
# ---------------------------------------------------------------------------
if ! command -v ollama &>/dev/null; then
  error "❌ Ollama does not appear to be installed (ollama not found in PATH)."
  exit 2
fi

# ---------------------------------------------------------------------------
# Step 2 – Get the current installed version
# ---------------------------------------------------------------------------
RAW_CURRENT="$(ollama --version 2>&1 || true)"
# 'ollama --version' prints e.g. "ollama version 0.6.5"
CURRENT_VERSION="$(echo "$RAW_CURRENT" | grep -oP '\d+\.\d+\.\d+' | head -1 || true)"

if [ -z "$CURRENT_VERSION" ]; then
  error "❌ Could not parse the installed Ollama version from: '${RAW_CURRENT}'"
  exit 2
fi

info "ℹ️  Installed version : ${CURRENT_VERSION}"

# ---------------------------------------------------------------------------
# Step 3 – Fetch the latest release tag from GitHub
# ---------------------------------------------------------------------------
GITHUB_API_URL="https://api.github.com/repos/ollama/ollama/releases/latest"

info "🌐 Checking latest release from GitHub..."

if ! command -v curl &>/dev/null; then
  error "❌ curl is required but not installed."
  exit 2
fi

LATEST_TAG="$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  "$GITHUB_API_URL" \
  | grep -oP '"tag_name"\s*:\s*"\K[^"]+' \
  | head -1 \
  || true)"

if [ -z "$LATEST_TAG" ]; then
  error "❌ Could not retrieve the latest Ollama release from GitHub."
  error "   Check your internet connection or GitHub API rate limits."
  exit 2
fi

LATEST_VERSION="$(strip_v "$LATEST_TAG")"
info "ℹ️  Latest available   : ${LATEST_VERSION}"

# ---------------------------------------------------------------------------
# Step 4 – Compare versions
# ---------------------------------------------------------------------------
# version_gt A B — returns true when A is strictly greater than B.
# Uses sort -V (version-aware sort) so "0.6.10" > "0.6.9" is handled correctly.
version_gt() {
  [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ] && [ "$1" != "$2" ]
}

if ! version_gt "$LATEST_VERSION" "$CURRENT_VERSION"; then
  success "✅ Ollama is already up to date (${CURRENT_VERSION})."
  exit 0
fi

warn "⬆️  Update available: ${CURRENT_VERSION} → ${LATEST_VERSION}"

# ---------------------------------------------------------------------------
# Step 5 – Upgrade (if requested) or exit with code 1
# ---------------------------------------------------------------------------
if [ "$AUTO_UPGRADE" = false ]; then
  warn "   Run with --auto-upgrade to apply the update automatically."
  warn "   Or run upgrade_ollama.sh manually."
  exit 1
fi

# --- Auto-upgrade path ---
if [ ! -f "$UPGRADE_SCRIPT" ]; then
  error "❌ upgrade_ollama.sh not found at: ${UPGRADE_SCRIPT}"
  error "   Place check_ollama_update.sh and upgrade_ollama.sh in the same directory."
  exit 2
fi

if [ ! -x "$UPGRADE_SCRIPT" ]; then
  error "❌ upgrade_ollama.sh is not executable. Run: chmod +x ${UPGRADE_SCRIPT}"
  exit 2
fi

info "🚀 Launching upgrade_ollama.sh..."
exec "$UPGRADE_SCRIPT"
