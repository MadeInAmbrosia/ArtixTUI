<h1 align="center">ArtixForge</h1>

<p align="center">
  <strong>Modular operating system deployment for Artix Linux</strong><br>
  TUI • GUI • Installer • Migration • ISO Builder • Power User
</p>

<p align="center">
  <strong>For your own sanity, don't use this testing branch.</strong><br> I speak from experience.
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a>
  •
  <a href="#screenshots">Screenshots</a>
  •
  <a href="#installation">Installation</a>
  •
  <a href="#contributing">Contributing</a>
  •
  <a href="#license">License</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-v9.3.2.1-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/Stable-v9.1.1.4-3572a5?style=flat-square" alt="Stable Release">
  <img src="https://img.shields.io/badge/Artix-[galaxy--gremlins]-blue?style=flat-square&logo=artixlinux" alt="Artix Galaxy-Gremlins">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash" alt="Bash">
  <img src="https://img.shields.io/badge/UI-FILLY_C-FFB6C1?style=flat-square&logo=c" alt="FILLY">
  <img src="https://img.shields.io/badge/License-Forge_Attribution_1.0-yellow?style=flat-square" alt="License">
</p>

---

# Installation

## Artix Linux (via galaxy-gremlins)

```bash
sudo pacman -S artixforge
sudo artixforge
```

## Alternative: Git Clone

```bash
git clone --recursive https://github.com/realvolk/ArtixForge.git
cd ArtixForge
chmod +x install
sudo ./install
```

You'll be greeted by a main menu where you choose your installation mode.

### Logs

| Situation | Log location |
|-----------|-------------|
| Installer failure | `/tmp/artix-installer/install.log` |
| Debug mode enabled | `~/ArtixForge/artix-debug.log` |
| Migration failure | `/tmp/artix-migration-debug.log` |

Include these in any GitHub issue.

---

# What is ArtixForge?

ArtixForge is a **modular operating system deployment framework** for Artix
Linux. It handles partitioning, filesystem creation, base system installation,
bootloader setup, desktop environment, drivers, and extra tools — all from a
single interface.

- Built with [FILLY](https://github.com/realvolk/FILLY) — a pure C widget
  library with terminal, graphical, and headless backends speaking a single
  JSON protocol. No Rust. No Python. No GTK. No external dependencies beyond
  a C compiler and libsodium.
- Custom colour themes (ArtixForge, Artix Blue, Jet Black, Mono, Retro) that
  persist to the installed system.
- Resilience hardened: pacman lock recovery, exponential backoff retries,
  mid-build resume, disk space checks at every stage.
- **Build custom live ISOs** with offline package bundles.
- **System Migration:** convert init systems, desktop environments, or Arch
  Linux → Artix without reinstalling. Resumable on failure.
- Over 9 trillion system configurations in a standard install, over 1
  quintillion with Power User mode.

---

# Installation Modes

| Mode | Description |
|------|-------------|
| Automatic | Guided installation with full configuration flow |
| Manual | Detect existing setup and continue manually |
| Resume | Continue from last saved installation, migration, or ISO build stage |
| Recovery | Auto-detect system config, smart issue detection, surgical repair, filesystem repair (safe/destructive), rootkit/malware scanning |
| Power User | Source-based package compilation, BusyBox init, custom coreutils, advanced system control |
| Quick Profiles | Desktop, Server, Minimal, Embedded, Gaming, Development, Media, Volk's Personal, and custom profile loading |
| Build ISO | Create custom Artix live ISO from any profile — offline bundles, resumable builds |
| System Migration | Convert init system (openrc ↔ runit ↔ dinit ↔ s6 ↔ systemd), desktop environment, or Arch → Artix |

A debug toggle is available for every mode.

---

# Supported Configurations

| Category | Options |
|----------|---------|
| Init system | OpenRC, runit, dinit, s6, BusyBox init |
| Filesystem | ext4, btrfs, xfs, f2fs |
| Storage | Standard partitions, LVM, LUKS, LVM-on-LUKS |
| Boot method | UKI, GRUB, rEFInd, EFIStub, Limine |
| Kernel | linux, zen, lts, hardened, libre, cachyos-*, bazzite, xanmod, tkg |
| Desktop | KDE Plasma, XFCE, LXQt, LXDE, Hyprland, Sway, Niri, i3, dwm, vxwm, IceWM, MangoWM, SonicDE, Cinnamon, Budgie, Moksha, COSMIC, none |
| Network | NetworkManager, dhcpcd+iwd, ConnMan, none |
| Audio | PipeWire, PulseAudio, none |
| Shell | bash, zsh, fish |
| Display stack | X.Org, xLibre |
| Coreutils | GNU, BusyBox, uutils, ArtixForge minimal, Custom |
| Privilege escalation | sudo, doas |
| Encryption | LUKS full-disk, LUKS-on-LVM |
| Theme | ArtixForge, Artix, Jet Black, Mono, Retro |

---

## Screenshots

W.I.P

---

# Features

## Core Installer

- Two interfaces: Terminal UI and Graphical UI — same JSON protocol, same C backend via FILLY
- Configuration hub with live summary strings, conditional visibility, and inline editing
- Modular architecture — separate scripts for storage, install, post, stages, recovery, and TUI
- Universal logger — writes to `/tmp/artix-installer/install.log` and `/mnt/var/log/artix-installer.log`
- Passwords hashed before storage — plaintext never touches disk
- Quick install profiles with one-click setup
- Network pre-configuration — WiFi, DHCP, or static IP before installation
- Optional mirror ranking
- Full-disk encryption (LUKS) with passphrase confirmation and keyfile support
- LVM support with optional LUKS integration
- Multiple boot methods — UKI, EFIStub, GRUB, rEFInd, Limine
- Optional Secure Boot signing for UKI images
- Privilege escalation choice — `sudo` or `doas`
- Resilience features — disk space checks, pacman lock recovery, download retry with exponential backoff, mid-build resume
- Offline mode with cached packages and offline ISO generation
- State persistence for full resume/recovery
- Collects nothing, removes itself after installation

## ISO Generation

- Build custom Artix live ISOs from any Quick Profile or full custom configuration
- Live Desktop mode — full desktop with ArtixForge installer on the desktop
- Installer mode — boots directly into ArtixForge TUI, minimal size
- Offline ISO — bundle all packages; installation works without internet
- Extra packages beyond profile selection
- Build logs saved alongside ISO
- Resumable on failure

## System Migration

- **Init migration:** openrc ↔ runit ↔ dinit ↔ s6 ↔ systemd without reinstalling
- Automatic service mapping with hub-chaining through OpenRC
- Custom service detection and backup
- **Desktop migration:** convert between all 17 supported DEs/WMs
- Migrates display manager, display stack, audio stack, and network stack
- User configs backed up before migration
- **ATA (Arch to Artix):** full-system conversion preserving user data, credentials, configs, packages, and AUR packages
- Converts systemd services, timers, PAM, hooks, network configs, and bootloader
- Resumable on failure with stage tracking

## Power User Mode

- Source-based package compilation (Gentoo-style)
- BusyBox init support
- Swappable coreutils (GNU, BusyBox, uutils, ArtixForge minimal, custom recipes)
- Hardware auto-detection with `localmodconfig` support
- Manual kernel configuration
- Compilation profiles (default, hardened, performance, safe)
- Per-package feature flags
- Recipe system with community repository support
- Offline source bootstrap
- Build queue with resume, error recovery, and live log viewer
- Post-build validation
- `anvil` package manager (CLI + TUI) with recipe editor, offline bootstrap, and recipe self-healing

---

# Dependencies

- **FILLY** — pure C, bundled as a submodule. Builds with `gcc` and `make`.
  Installed to `/usr/local/bin/filly`. Handles all IPC, rendering, and
  input. No external runtime dependencies beyond libsodium.

Everything else is handled by the installer.

---

# Contributing

Contributions are welcome and appreciated.

**Looking for: Testers • Contributors • Distro Packagers**

Please read [CONTRIBUTING](DOCUMENTS/CONTRIBUTING) for guidelines on testing,
submissions, and [code of conduct](DOCUMENTS/CODE_OF_CONDUCT.md).

---

# License

Licensed under the [Forge Attribution License 1.0](DOCUMENTS/LICENSE)
© [Volk](https://github.com/realvolk) 2026.