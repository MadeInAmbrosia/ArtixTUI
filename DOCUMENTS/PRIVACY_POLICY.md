# Privacy Policy

**ArtixTUI collects nothing.**

The installer runs entirely on your local machine. It does not:

- Send telemetry or usage data anywhere
- Phone home with your hardware information
- Log your installation choices to any remote server
- Include any analytics, tracking, or monitoring code
- Store your passwords, passphrases, or personal data beyond what is needed to complete the installation

## What ArtixTUI stores locally (and how it's handled)

| Data | Location | Fate |
|------|----------|------|
| Installation configuration | `/tmp/artix-installer/state.conf` | Deleted on reboot (tmpfs) |
| Stage progress markers | `/tmp/artix-installer/stages/` | Deleted on reboot (tmpfs) |
| User password hashes | Memory only, never written to disk | Gone when installer exits |
| LUKS passphrase | Memory only, never written to disk | Gone when installer exits |
| Target system config | `/mnt/etc/artix-installer.conf` | Shredded or removed during finalize stage |
| Installer log | `/mnt/var/log/artix-installer.log` | Remains on the installed system for debugging |

The installed system itself contains no ArtixTUI-specific data collection. The installer
removes its own configuration from the target before finishing.

## Network access

ArtixTUI downloads packages from Artix Linux mirrors and source tarballs from
upstream URLs specified in recipes. These are standard package manager operations
— the same as running `pacman -Syu` or `git clone`. No additional network requests
are made.

## Third-party services

The installer does not integrate with any third-party analytics, monitoring,
or data collection services. Zero. None.

## Questions

If you have any questions about privacy, open an issue on
[GitHub](https://github.com/realvolk/ArtixTUI/issues).