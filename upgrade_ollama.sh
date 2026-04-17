#!/bin/bash
#
# A script to upgrade Ollama while preserving a custom systemd service file.
# It will automatically prompt for sudo if not run as root.
#

# Check for root privileges and re-launch with sudo if necessary.
# This must happen before set -e so that a failed sudo attempt exits cleanly.
if [ "$(id -u)" -ne 0 ]; then
  echo "This script requires root privileges to manage systemd services."
  echo "Please enter your password to continue."
  # Re-execute the script with sudo, passing all original arguments.
  sudo -- "$0" "$@"
  # Exit the original, non-privileged script.
  exit $?
fi

# Exit immediately if a command exits with a non-zero status, treat unset
# variables as errors, and propagate pipe failures.
set -euo pipefail

# Colors and formatting
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'     # No Color
BOLD='\033[1m'

# Service file path
SERVICE_FILE_PATH="/etc/systemd/system/ollama.service"

# Use a private temporary directory so the backup is not world-readable.
BACKUP_DIR="$(mktemp -d)"
BACKUP_FILE_PATH="${BACKUP_DIR}/ollama.service.bak"

# --- Functions ---
# Function to print styled status messages
print_status() {
  # Usage: print_status "Message" "$COLOR"
  echo -e "${BOLD}${2}${1}${NC}"
}

# Cleanup: remove the temporary backup directory on exit (success or failure).
cleanup() {
  rm -rf "$BACKUP_DIR"
}
trap cleanup EXIT

# --- Main Script ---
print_status "🚀 Starting Ollama upgrade process..." "$BLUE"

# Show the current version so the user can confirm the upgrade delta.
if command -v ollama &>/dev/null; then
  CURRENT_VERSION="$(ollama --version 2>&1 || true)"
  print_status "ℹ️  Current version: ${CURRENT_VERSION}" "$BLUE"
fi

# Step 1: Backup current service file (if it exists)
if [ -f "$SERVICE_FILE_PATH" ]; then
  print_status "📁 Backing up current service configuration..." "$YELLOW"
  # Use -p to preserve permissions and ownership
  cp -p "$SERVICE_FILE_PATH" "$BACKUP_FILE_PATH"
  print_status "✅ Service configuration backed up to $BACKUP_FILE_PATH" "$GREEN"

  # Remember whether the service was enabled so we can restore that state.
  if systemctl is-enabled --quiet ollama.service 2>/dev/null; then
    SERVICE_WAS_ENABLED=true
  else
    SERVICE_WAS_ENABLED=false
  fi
else
  print_status "ℹ️ No existing service file found to back up. A new one will be created." "$BLUE"
  SERVICE_WAS_ENABLED=false
fi

# Step 2: Stop Ollama service
print_status "🛑 Stopping Ollama service (if running)..." "$YELLOW"
# Use 'systemctl is-active --quiet' to avoid errors if the service is not running
if systemctl is-active --quiet ollama.service; then
  systemctl stop ollama.service
  print_status "✅ Ollama service stopped." "$GREEN"
else
  print_status "✅ Ollama service was not running." "$GREEN"
fi

# Step 3: Install the latest version of Ollama
print_status "📥 Downloading and installing latest Ollama version..." "$YELLOW"
curl -fsSL https://ollama.com/install.sh | sh
print_status "✅ Latest Ollama version installed." "$GREEN"

# Step 4: Restore custom service configuration (if a backup was made)
if [ -f "$BACKUP_FILE_PATH" ]; then
  print_status "🔄 Restoring your custom service configuration..." "$YELLOW"
  # The installer might start the service, so stop it first
  if systemctl is-active --quiet ollama.service; then
    systemctl stop ollama.service
  fi
  # Use -p to preserve permissions and ownership
  cp -p "$BACKUP_FILE_PATH" "$SERVICE_FILE_PATH"
  print_status "✅ Custom service configuration restored." "$GREEN"

  # Re-enable the service if it was enabled before the upgrade.
  if [ "$SERVICE_WAS_ENABLED" = true ]; then
    systemctl enable ollama.service
    print_status "✅ Service re-enabled." "$GREEN"
  fi
fi

# Step 5: Reload systemd and start Ollama
print_status "🔄 Reloading systemd daemon..." "$YELLOW"
systemctl daemon-reload
print_status "✅ Systemd daemon reloaded." "$GREEN"

print_status "▶️ Starting Ollama service..." "$YELLOW"
systemctl start ollama.service
print_status "✅ Ollama service started." "$GREEN"

# Step 6: Verify installation
print_status "🔍 Verifying installation..." "$BLUE"
ollama --version
print_status "✅ All systems go!" "$GREEN"
print_status "🎉 Ollama upgrade completed successfully!" "$GREEN"