#!/bin/bash
#
# install_update_service.sh
#
# Installs the Ollama update-check scripts and the accompanying systemd timer
# so that Ollama is automatically checked (and upgraded) once per day.
#
# What this script does:
#   1. Copies check_ollama_update.sh and upgrade_ollama.sh to /usr/local/bin/
#   2. Copies the systemd unit files to /etc/systemd/system/
#   3. Reloads the systemd daemon
#   4. Enables and starts ollama-update-check.timer
#
# Usage:
#   sudo ./install_update_service.sh
#
# To uninstall, run:
#   sudo ./install_update_service.sh --uninstall
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Privilege check
# ---------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "This script requires root privileges."
  echo "Please enter your password to continue."
  sudo -- "$0" "$@"
  exit $?
fi

# ---------------------------------------------------------------------------
# Colors / helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

info()    { echo -e "${BOLD}${BLUE}${1}${NC}"; }
success() { echo -e "${BOLD}${GREEN}${1}${NC}"; }
warn()    { echo -e "${BOLD}${YELLOW}${1}${NC}"; }
error()   { echo -e "${BOLD}${RED}${1}${NC}" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BIN_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"

SCRIPTS=(
  "check_ollama_update.sh:${BIN_DIR}/check_ollama_update"
  "upgrade_ollama.sh:${BIN_DIR}/upgrade_ollama"
)

UNIT_FILES=(
  "ollama-update-check.service"
  "ollama-update-check.timer"
)

TIMER_NAME="ollama-update-check.timer"

# ---------------------------------------------------------------------------
# Uninstall path
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--uninstall" ]]; then
  info "🗑️  Uninstalling Ollama update-check service..."

  if systemctl is-active --quiet "$TIMER_NAME" 2>/dev/null; then
    systemctl stop "$TIMER_NAME"
    success "✅ Timer stopped."
  fi

  if systemctl is-enabled --quiet "$TIMER_NAME" 2>/dev/null; then
    systemctl disable "$TIMER_NAME"
    success "✅ Timer disabled."
  fi

  for unit in "${UNIT_FILES[@]}"; do
    target="${SYSTEMD_DIR}/${unit}"
    if [ -f "$target" ]; then
      rm -f "$target"
      success "✅ Removed ${target}."
    fi
  done

  systemctl daemon-reload

  for entry in "${SCRIPTS[@]}"; do
    target="${entry##*:}"
    if [ -f "$target" ]; then
      rm -f "$target"
      success "✅ Removed ${target}."
    fi
  done

  success "✅ Uninstall complete."
  exit 0
fi

# ---------------------------------------------------------------------------
# Install path
# ---------------------------------------------------------------------------
info "🚀 Installing Ollama update-check service..."

# 1. Copy scripts
for entry in "${SCRIPTS[@]}"; do
  src="${entry%%:*}"
  target="${entry##*:}"
  src_path="${SCRIPT_DIR}/${src}"

  if [ ! -f "$src_path" ]; then
    error "❌ Source script not found: ${src_path}"
    exit 1
  fi

  info "📄 Installing ${src} -> ${target}"
  install -m 0755 -o root -g root "$src_path" "$target"
  success "✅ Installed ${target}."
done

# 2. Copy unit files
for unit in "${UNIT_FILES[@]}"; do
  src_path="${SCRIPT_DIR}/${unit}"

  if [ ! -f "$src_path" ]; then
    error "❌ Unit file not found: ${src_path}"
    exit 1
  fi

  info "📄 Installing ${unit} -> ${SYSTEMD_DIR}/${unit}"
  install -m 0644 -o root -g root "$src_path" "${SYSTEMD_DIR}/${unit}"
  success "✅ Installed ${SYSTEMD_DIR}/${unit}."
done

# 3. Reload systemd
info "🔄 Reloading systemd daemon..."
systemctl daemon-reload
success "✅ Daemon reloaded."

# 4. Enable and start the timer
info "⏰ Enabling and starting ${TIMER_NAME}..."
systemctl enable --now "$TIMER_NAME"
success "✅ ${TIMER_NAME} is enabled and running."

echo ""
info "📋 Timer status:"
systemctl status "$TIMER_NAME" --no-pager || true

echo ""
success "🎉 Installation complete."
info "   The update check will run once daily."
info "   Logs: journalctl -u ollama-update-check.service"
info "   To uninstall: sudo ./install_update_service.sh --uninstall"
