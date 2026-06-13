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
| User password hashes | Memory only, never written to disk | Gone when installer exits |
| LUKS passphrase | Memory only, never written to disk | Gone when installer exits |
| GUI installer state (forge-gui) | Python memory | Cleared when GUI window closes |
| Target system config | `/mnt/etc/artix-installer.conf` | Shredded or removed during finalize stage |
| Quick Profile save | `/mnt/etc/artixforge-profile.conf` | Remains on installed system for reuse |
| Installer log | `/mnt/var/log/artix-installer.log` | Remains on the installed system for debugging |
| Build logs (Power User) | `/mnt/artix-poweruser/build/logs/` | Remains on the installed system for debugging |
| Recipe database | `/mnt/usr/share/artix-poweruser/db/local.db` | Remains on the installed system |
| Recovery detection data | `/tmp/artix-installer/state.conf` (reconstructed) | Deleted on reboot (tmpfs) |

The installed system itself contains no ArtixForge-specific data collection. The installer
removes its own configuration from the target before finishing.

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

SonicDE packages are downloaded from the sonicde-artix.github.io third-party repository. The user is warned before installation that signature verification is disabled for this source.

**The GUI installer (`forge-gui`) makes no network connections of its own.**
It only reads/writes `state.conf` and spawns the non‑interactive Bash installer.

## Third-party services

The installer does not integrate with any third-party analytics, monitoring,
or data collection services. Zero. None.

## Questions

If you have any questions about privacy, open an issue on
[GitHub](https://github.com/realvolk/ArtixForge/issues).