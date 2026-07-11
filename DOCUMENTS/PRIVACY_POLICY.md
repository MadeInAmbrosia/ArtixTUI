# Privacy Policy

**ArtixForge collects nothing.**

The installer runs entirely on your local machine. It does not:

- Send telemetry or usage data anywhere
- Phone home with your hardware information
- Log your installation choices to any remote server
- Include any analytics, tracking, or monitoring code
- Store your passwords, passphrases, or personal data beyond what is needed to complete the installation

## What ArtixForge stores locally (and how it's handled)

| Data | Location | Fate |
|------|----------|------|
| Installation configuration | `/tmp/artix-installer/state.conf` | Deleted on reboot (tmpfs) |
| Stage progress markers | `/tmp/artix-installer/stages/` | Deleted on reboot (tmpfs) |
| User password hashes | `/tmp/artix-installer/state.conf` (SHA-512 crypt hash) | Deleted on reboot (tmpfs) |
| LUKS passphrase | Memory only, never written to disk | Gone when installer exits |
| GUI installer state (filly-graphical) | Python memory, writes to state.conf | Cleared when GUI window closes; state.conf on tmpfs |
| Target system config | `/mnt/etc/artix-installer.conf` | Shredded or removed during finalize stage |
| Quick Profile save | `/mnt/etc/artixforge-profile.conf` | Remains on installed system for reuse |
| Installer log | `/mnt/var/log/artix-installer.log` | Remains on the installed system for debugging |
| Build logs (Power User) | `/mnt/artix-poweruser/build/logs/` | Remains on the installed system for debugging |
| Recipe database | `/mnt/usr/share/artix-poweruser/db/local.db` | Remains on the installed system |
| Recovery detection data | `/tmp/artix-installer/state.conf` (reconstructed) | Deleted on reboot (tmpfs) |
| ATA migration backup | `/arch-migration-backup-YYYYMMDD-HHMMSS/` | Stays on disk (root-only, chmod 700); user must delete manually |
| FILLY widget temp files | `/tmp/tmp.XXXXXXXXXX` (oneshot mode) or `/tmp/filly.sock` (daemon mode) | Discarded after each widget call; any remnants deleted on reboot (tmpfs) |

The installed system itself contains no ArtixForge-specific data collection. The installer
removes its own configuration from the target before finishing.

### ATA (Arch to Artix) Migration

The ATA migration performs a full system audit and backup before converting an
Arch Linux installation to Artix. The following data is handled:

| Data | Location | Fate |
|------|----------|------|
| System audit lists | `/tmp/ata-*.txt` | Deleted on reboot (tmpfs) |
| Full system backup | `/arch-migration-backup-YYYYMMDD-HHMMSS/` | Remains on disk (root-only, chmod 700) |
| Network credentials (WiFi PSKs, NM connections) | Backup subdirectory, then restored to `/etc/NetworkManager/`, `/var/lib/iwd/`, `/etc/wpa_supplicant/` | Credential files on target are chmod 600; raw backup retained in backup dir |
| systemd journal export | Backup directory | Plaintext journal retained in backup dir |
| systemd-homed user data | Decrypted and migrated to `/home/<user>/` | Original LUKS home images left in place; user must delete manually |
| AUR package list | Backup directory lists | Retained for reference |
| Flatpak app list | Backup directory lists | Retained for reference |

The ATA backup directory is created with `chmod 700` (root access only). Network
credential subdirectories within the backup are also `chmod 700`. When credentials
are restored to the target system, files are written with `chmod 600`. The raw
backup is retained so the user can verify what was migrated and delete it manually.

No data leaves the local machine during ATA migration. The package mapping feature
queries only the local pacman database and configured repositories — no external
API calls are made for system audit or conversion.

## Network access

ArtixForge downloads packages from Artix Linux mirrors and source tarballs from
upstream URLs specified in recipes. These are standard package manager operations
— the same as running `pacman -Syu` or `git clone`. No additional network requests
are made.

The recipe self-healing feature (`heal.bash`) may check upstream URLs (kernel.org,
GitHub API, or source directory listings) to detect newer versions when a download
fails. This only happens during an active build failure — never during normal operation.

The recovery mode rootkit scanner (`rkhunter`) downloads its database updates
from the rkhunter project servers when first run. This is the only optional
third-party network request outside of package management.

SonicDE packages are downloaded from the sonicde-artix.github.io third-party repository.

**The GUI installer (`filly-graphical`):** extras search queries local pacman cache only. Power User recipe list is fetched once from the community repository at startup; individual recipe files are downloaded on demand when sections are enabled. All other data reads/writes `state.conf` and spawns the non‑interactive Bash installer. No telemetry, no analytics, no background network activity. Runs inside a Python venv at `/tmp/filly-gui-venv` with system-site-packages for GTK4 bindings.

**FILLY:** the Rust TUI binary makes no network connections. It reads JSON from a local temp file specified by `--input` and writes responses to stdout or a local temp file specified by `--output`. All rendering is done via `/dev/tty`. No data leaves the process.

## Third-party services

The installer does not integrate with any third-party analytics, monitoring,
or data collection services. Zero. None.

## Questions

If you have any questions about privacy, open an issue on
[GitHub](https://github.com/realvolk/ArtixForge/issues).