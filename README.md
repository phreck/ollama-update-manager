# Ollama Upgrade Script 🚀

Two bash scripts to safely keep [Ollama](https://ollama.com/) up to date on Ubuntu/Linux systems while preserving your custom service configurations.

| Script | Purpose |
|--------|---------|
| `upgrade_ollama.sh` | Performs the actual upgrade (backup → stop → install → restore → start). |
| `check_ollama_update.sh` | Checks whether a newer version is available and optionally triggers the upgrade automatically. |

## 🔍 Overview

`upgrade_ollama.sh` automates the process of upgrading Ollama while ensuring that your custom systemd service configuration is maintained.

`check_ollama_update.sh` queries the GitHub Releases API, compares the latest tag against the locally installed version, and can either report that an update is available (useful in cron / CI) or immediately invoke `upgrade_ollama.sh` when `--auto-upgrade` is passed.

Both scripts provide colorful, emoji-enhanced output to clearly show the progress of each step.

## ✨ Features

- 🛡️ Preserves your custom Ollama service configuration
- 🎨 Colorful, informative output with emojis
- 🔄 Seamless upgrade process with minimal downtime
- ✅ Verification steps to confirm successful installation
- 🚨 Error checking for critical operations
- 🤖 Automated version checking with configurable auto-upgrade
- 🔕 Silent mode for cron-friendly operation

## 📋 Prerequisites

- Ubuntu/Linux system with Ollama installed
- `systemd` for service management
- `curl` (for the update check and upgrade install)
- Sudo privileges

## 🚀 Usage

### Manual upgrade

1. Clone this repository:
   ```bash
   git clone https://github.com/phreck/ollama_ubuntu_upgrade.git
   cd ollama_ubuntu_upgrade
   ```

2. Make the scripts executable:
   ```bash
   chmod +x upgrade_ollama.sh check_ollama_update.sh
   ```

3. Run the upgrade script with sudo:
   ```bash
   sudo ./upgrade_ollama.sh
   ```

### Automated update check

```bash
# Check whether an update is available (exits 0 = up to date, 1 = update available, 2 = error)
./check_ollama_update.sh

# Check and automatically upgrade if a newer version is found
sudo ./check_ollama_update.sh --auto-upgrade

# Same as above but with no output (for cron jobs)
sudo ./check_ollama_update.sh --auto-upgrade --silent
```

### Scheduling with cron

To check for updates every night at 2 AM and upgrade automatically, add this line with `sudo crontab -e`:

```cron
0 2 * * * /path/to/ollama_ubuntu_upgrade/check_ollama_update.sh --auto-upgrade --silent >> /var/log/ollama_update.log 2>&1
```

Replace `/path/to/ollama_ubuntu_upgrade` with the actual path where the repository is cloned.

### Exit codes for `check_ollama_update.sh`

| Code | Meaning |
|------|---------|
| `0` | Ollama is already up to date (or was just successfully upgraded). |
| `1` | A newer version is available (`--auto-upgrade` was **not** passed). |
| `2` | A runtime error occurred (Ollama not installed, network failure, etc.). |

## 📝 What the Scripts Do

### `upgrade_ollama.sh`

1. Displays the currently installed Ollama version
2. Backs up your custom service configuration (if it exists)
3. Stops the running Ollama service
4. Downloads and installs the latest version of Ollama
5. Restores your custom service configuration and re-enables the service if it was enabled
6. Reloads systemd and restarts Ollama
7. Verifies the installation by printing the new Ollama version

### `check_ollama_update.sh`

1. Confirms Ollama is installed and reads the current version
2. Fetches the latest release tag from the GitHub API
3. Compares the two versions
4. Reports whether an update is available
5. If `--auto-upgrade` is passed and an update exists, delegates to `upgrade_ollama.sh`

## ⚠️ Important Notes

- This script is intended for systems where you have customized the Ollama systemd service
- Always ensure you have a backup of your important data before performing any system upgrades
- If you encounter any issues, please create an issue in this repository

## 📜 License

MIT License - feel free to modify and distribute as needed.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📧 Contact

If you have any questions or suggestions, please open an issue or contact phreck@phreck.com.

---

*Last updated: April 17, 2026*