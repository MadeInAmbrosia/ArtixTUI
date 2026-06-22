# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in ArtixForge, please report it privately
to **realvolk** via a private GitHub security advisory or email.

Do not open a public issue for security issues.

## Supported Versions

| Version | Supported |
|---------|-----------|
| v9.1.0.0   | Yes |
| v9.0.0.0 | Best effort |
| < v9.0.0.0 | No |

## Scope

Security concerns include, but are not limited to:

- Password or passphrase exposure in logs, temporary files, or process listings
- Unsafe handling of LUKS passphrases (storage in memory, passing to `cryptsetup`)
- LUKS + LVM combinations where encryption boundaries are incorrectly configured
- LUKS containers created without proper formatting (`luksFormat` bypass)
- LUKS keyfile exposure — keyfile stored in initramfs on encrypted partition, never on unencrypted storage
- Privilege escalation within the installer or the resulting system
- Unsafe package downloads (missing or weak checksum verification)
- Source‑compiled packages that introduce vulnerabilities via untrusted upstream sources
- Recipe self‑healing fetching from untrusted or unverified upstream URLs
- BusyBox init configurations that leave the system insecure (unprotected ttys, weak shutdown)
- UKI images signed with keys that are not properly protected
- `doas` or `sudo` misconfiguration that grants unintended access
- Custom coreutils recipes that replace security‑sensitive binaries (`su`, `passwd`, `mount`)
- State files (`state.conf`, `artix-installer.conf`) that may contain sensitive configuration
- Recovery mode operations that mount, repair, or modify an existing installation
- Recovery mode auto‑detection exposing system configuration details
- Rootkit scanning results that may reveal sensitive system information
- `rsync` usage during package installation potentially following unsafe symlinks
- Untrusted recovery: rootkit and malware scan results stored in /tmp
- Filesystem repair: unmounting and modifying the root partition with fsck/xfs_repair/btrfs check
- Third-party repositories (SonicDE, Chaotic-AUR, CachyOS) used during installation — packages are verified where possible
- **GUI installer (`forge-gui`):** runs as root, handles LUKS passphrases and user passwords, must not leak sensitive data to logs or crash in a way that exposes memory contents

## Best Practices

- ArtixForge never writes plaintext passwords to disk. Passwords are hashed with `openssl passwd -6` before being passed to the target system.
- LUKS passphrases are held in memory only during the installation and are not persisted.
- LUKS containers are properly formatted with `luksFormat --type luks2 --pbkdf pbkdf2` for GRUB compatibility.
- LUKS keyfile (`/crypto_keyfile.bin`) is embedded in initramfs with `chmod 000` permissions. It resides only in the initramfs image on the encrypted root partition and is never written to unencrypted storage.
- Recipe sources should use verified checksums. The `SKIP` placeholder is for development only and should never appear in published recipes.
- Recipe self‑healing only fetches version information from the same upstream domain as the original recipe source. New URLs are not blindly trusted.
- The installer does not expose network services during installation. Any network configuration (WiFi passwords, static IPs) is applied to the target system, not the live environment.
- Third-party repository signing keys are imported from official sources where available.
- Package installation uses `rsync --keep-dirlinks` to prevent symlink traversal attacks when writing to the target filesystem.
- Post‑installation, `anvil` runs with root privileges. Users should audit recipes before building, especially those obtained from third‑party sources.
- The installer's state directory (`/tmp/artix-installer/`) lives on a tmpfs and is lost on reboot. The target configuration file (`/mnt/etc/artix-installer.conf`) is shredded or removed during the finalize stage.
- Recovery mode requires explicit user confirmation before modifying any system files. Detection is read‑only until the user chooses a repair action.
- **GUI installer (`forge-gui`):** runs in a separate Python process. User and root passwords are hashed with `openssl passwd -6` in the GUI process before being written to `state.conf` — plaintext passwords never touch the state file or disk. LUKS passphrases are held in memory only and cleared when the config window closes. The GUI makes no network connections of its own (extras search uses local pacman cache; Power User recipe list is fetched once at startup).