# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in ArtixForge, please report it privately
to **realvolk** via a private GitHub security advisory or email.

Do not open a public issue for security issues.

## Supported Versions

| Version | Supported |
|---------|-----------|
| v8.3.0.x | Yes |
| v8.2.3.x | Yes |
| v8.2.0.x | Critical fixes only |
| v8.1.1.x | Critical fixes only |
| < v8.1.0.0 | No |

## Scope

Security concerns include, but are not limited to:

- Password or passphrase exposure in logs, temporary files, or process listings
- Unsafe handling of LUKS passphrases (storage in memory, passing to `cryptsetup`)
- LUKS + LVM combinations where encryption boundaries are incorrectly configured
- Privilege escalation within the installer or the resulting system
- Unsafe package downloads (missing or weak checksum verification)
- Source‑compiled packages that introduce vulnerabilities via untrusted upstream sources
- BusyBox init configurations that leave the system insecure (unprotected ttys, weak shutdown)
- UKI images signed with keys that are not properly protected
- `doas` or `sudo` misconfiguration that grants unintended access
- Custom coreutils recipes that replace security‑sensitive binaries (`su`, `passwd`, `mount`)
- State files (`state.conf`, `artix-installer.conf`) that may contain sensitive configuration
- Recovery mode operations that mount, repair, or modify an existing installation
- Rootkit scanning results that may reveal sensitive system information

## Best Practices

- ArtixForge never writes plaintext passwords to disk. Passwords are hashed with `openssl passwd -6` before being passed to the target system.
- LUKS passphrases are held in memory only during the installation and are not persisted.
- Recipe sources should use verified checksums. The `SKIP` placeholder is for development only and should never appear in published recipes.
- The installer does not expose network services during installation. Any network configuration (WiFi passwords, static IPs) is applied to the target system, not the live environment.
- Post‑installation, `gartix` runs with root privileges. Users should audit recipes before building, especially those obtained from third‑party sources.
- The installer's state directory (`/tmp/artix-installer/`) lives on a tmpfs and is lost on reboot. The target configuration file (`/mnt/etc/artix-installer.conf`) is shredded or removed during the finalize stage.