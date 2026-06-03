<h1 align="center">ArtixForge</h1>

<p align="center">
  <strong>A modular operating system deployment framework for Artix Linux</strong><br>
  No flags. No confusion. Just a terminal interface that works.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-v8.4.3.0-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash" alt="Bash">
  <img src="https://img.shields.io/badge/TUI-gum-FFB6C1?style=flat-square" alt="gum">
  <img src="https://img.shields.io/badge/License-Volk Open License 1.0-yellow?style=flat-square" alt="License">
</p>

---

# What is ArtixForge?

ArtixForge is a **modular operating system deployment framework** for Artix Linux (OpenRC, runit, dinit, s6, and BusyBox init).

It walks you through partitioning, filesystem creation, base system installation, bootloader setup, desktop environment, drivers, and extra tools — all from a single terminal interface.

* Built with `gum` by Charmbracelet.
* Custom colour themes (Gentoo Purple, Artix Blue, Jet Black, Mono, Retro) that persist to the installed system.
* Resilience hardened: automatic pacman lock recovery, exponential backoff retries, mid-build resume, disk space checks at every stage.
* Over 9 trillion system configurations in a standard install, over 1 quintillion with Power User mode.

---

# Supported Configurations

| Category             | Options                                                                                                                 |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Init system          | OpenRC, runit, dinit, s6, BusyBox init                                                                                  |
| Filesystem           | ext4, btrfs, xfs, f2fs, bcachefs, exfat, zfs                                                                            |
| Storage              | Standard partitions, LVM, LUKS, LVM-on-LUKS                                                                             |
| Boot method          | UKI, GRUB, rEFInd, EFIStub, Limine                                                                                      |
| Kernel               | linux, zen, lts, hardened, libre, cachyos-bore, bazzite, xanmod, tkg                                                    |
| Desktop              | XFCE, LXQt, KDE Plasma, LXDE, Hyprland, MangoWM, Niri, Sway, i3, dwm, vxwm, IceWM, none                                 |
| Network              | NetworkManager, dhcpcd+iwd, ConnMan, none                                                                               |
| Audio                | PipeWire, PulseAudio, none                                                                                              |
| Shell                | bash, zsh, fish                                                                                                         |
| Display stack        | X.Org, xLibre                                                                                                           |
| Coreutils            | GNU, BusyBox, uutils, ArtixForge minimal, Custom                                                                        |
| Privilege escalation | sudo, doas                                                                                                              |
| Encryption           | LUKS full-disk encryption, LUKS-on-LVM                                                                                  |
| Recovery             | Smart issue detection, surgical repair, filesystem repair (safe/destructive), untrusted recovery (rootkit/malware scan) |
| Power User           | Source compilation, custom kernel config, community recipes, recipe self-healing                                        |
| Quick Profiles       | Desktop, Server, Minimal, Embedded, Gaming, Development, Media, Volk's Personal                                         |
| Theme                | Gentoo, Artix, Jet Black, Mono, Retro                                                                                   |

---

# Quick Start

```bash
git clone https://github.com/realvolk/ArtixForge.git
cd ArtixForge
chmod +x install
sudo ./install
```

You'll be greeted by a main menu where you choose your installation mode.

---

# Installation Modes

| Mode             | Description                                                                                                                             |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| 🟢 Automatic     | Guided installation with full configuration flow.                                                                                       |
| 🔵 Manual        | Detect existing setup progress and continue manually.                                                                                   |
| 🟡 Resume        | Continue from the last saved installation stage.                                                                                        |
| 🟠 Recovery      | Auto-detect full system config, smart issue detection, surgical repair, filesystem repair (safe/destructive), rootkit/malware scanning. |
| 🔴 Power User    | Gentoo-style source builds, BusyBox init, custom coreutils, advanced system control.                                                    |
| ⚡ Quick Profiles | Desktop, Server, Minimal, Embedded, Gaming, Development, Media, Volk's Personal, and custom profile loading.                            |

A debug toggle is available for every mode from the same menu.

---

# Features

## Core Installer

* Tabbed full-screen TUI – navigate steps with keyboard, jump between tabs, see completed steps with checkmarks
* Modular architecture – separate scripts for storage, install, post, stages, recovery, and TUI sub-menus
* Universal logger – writes to `/tmp/artix-installer/install.log` and `/mnt/var/log/artix-installer.log`
* Safe passwords – hashed with `openssl passwd -6`, never written to disk
* Quick install profiles (see table above)
* Network pre-configuration – WiFi, DHCP, or static IP before installation
* Optional mirror ranking with `rankmirrors`
* Full-disk encryption (LUKS) with passphrase confirmation
* LVM support – PV/VG/LV creation with optional LUKS integration
* Multiple boot methods – UKI, EFIStub, GRUB, rEFInd, Limine
* Optional Secure Boot signing for UKI images using `sbsign`
* Privilege escalation choice – `sudo` or `doas`
* Custom colour themes with live preview
* Resilience features – disk space checks, pacman lock recovery, download retry with exponential backoff, mid-build resume
* Offline mode with cached packages
* State persistence for full resume/recovery
* Privacy-respecting – collects nothing, removes itself after installation

## Power User Mode

* Source-based package compilation
* BusyBox init support
* Swappable coreutils (GNU, BusyBox, uutils, ArtixForge minimal, custom recipes)
* Hardware auto-detection with `localmodconfig` support
* Manual kernel configuration
* Compilation profiles (default, hardened, performance, safe)
* Per-package feature flags
* Recipe system with community repository support
* Offline source bootstrap
* Build queue with resume, error recovery, and live log viewer
* Post-build validation
* `gartix` package manager (CLI + TUI) with recipe editor, offline bootstrap, and recipe self-healing

## Extras

Categorized package selection across System Tools, Editors, Browsers, File Managers,
Terminals, Shell & Prompt, Monitoring, and Media. Includes:

* `flatpak`, `firewalld`, `bluez`, `zram`
* `fzf`, `zoxide`, `starship`, `eza`, `btop`, `tmux`, `rsvc`
* and many more

---

# Dependencies

ArtixForge requires `gum` for its TUI. If not present, it will be built from source during preflight (requires `go`, also installed automatically). Everything else is handled by the installer.

---

# Contributing

Contributions are welcome and appreciated.

**🫱 Looking for: Testers • Contributors • Distro Packagers**

Please read [CONTRIBUTING](DOCUMENTS/CONTRIBUTING) for guidelines on testing,
submissions, and code of conduct.


---

# License

Licensed under the [Volk Open License 1.0](DOCUMENTS/LICENSE) © [realvolk](https://github.com/realvolk) 2026.
