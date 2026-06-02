<h1 align="center">ArtixForge</h1>

<p align="center">
  <strong>A modular, TUI-first installer and distribution toolkit for Artix Linux</strong><br>
  No flags. No confusion. Just a terminal interface that works.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-v8.4.2.1-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash" alt="Bash">
  <img src="https://img.shields.io/badge/TUI-gum-FFB6C1?style=flat-square" alt="gum">
  <img src="https://img.shields.io/badge/License-Volk Open License 1.0-yellow?style=flat-square" alt="License">
</p>

---

# What is ArtixForge?

ArtixForge is a **TUI-first, modular installer** for Artix Linux (OpenRC, runit, dinit, s6).

It walks you through partitioning, filesystem creation, base system installation, bootloader setup, desktop environment, drivers, and extra tools — all from a single terminal interface.

- Built with gum by Charmbracelet, it supports all major Artix init systems — including BusyBox init in Power User mode.
- **Custom colour themes** — choose from Gentoo Purple, Artix Blue, Jet Black, Mono, or Retro Amber. Theme persists across install and is inherited by `gartix`.
- **Resilience hardened** — automatic pacman lock recovery, retry with exponential backoff for failed downloads, mid‑build resume for interrupted compilations, disk space checks at every stage.

  Over 9 trillion system configurations in a standard install.
  Over 1 000 000 000 000 000 000 (1 quintillion) when Power User mode is enabled.
  No two installations need ever be the same.



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

| Mode | Description |
|------|-------------|
| 🟢 Automatic | Guided installation with full configuration flow. |
| 🔵 Manual | Detect existing setup progress and continue manually. |
| 🟡 Resume | Continue from the last saved installation stage. |
| 🟠 Recovery | Auto-detect full system config, smart issue detection, surgical repair, filesystem repair (safe/destructive), rootkit/malware scanning. |
| 🔴 Power User | Gentoo-style source builds, BusyBox init, custom coreutils, advanced system control. |
| ⚡ Quick Profiles | Desktop, Server, Minimal, Embedded, Gaming, Development, Media, Volk's Personal, and custom profile loading. |

A debug toggle is available for every mode from the same menu.

---

# Features

## Core Installer

- Tabbed full-screen TUI — navigate steps with keyboard, jump between tabs, see completed steps with checkmarks
- Modular architecture — separate scripts for storage, install, post, and stages
- Universal logger — every message is written to:
  - `/tmp/artix-installer/install.log`
  - `/mnt/var/log/artix-installer.log`
- Safe passwords — hashed with `openssl passwd -6`, never written to disk
- Quick install profiles — Desktop, Server, Minimal, Embedded
- Network pre-configuration — WiFi, DHCP, or static IP setup before installation
- Optional mirror ranking using `rankmirrors`
- Full-disk encryption — LUKS support with passphrase confirmation
- LVM support — PV/VG/LV creation with optional LUKS integration
- UKI, EFIStub, GRUB, rEFInd — multiple boot methods supported
- Optional Secure Boot signing for UKI images using `sbsign`
- Privilege escalation choice — `sudo` or `doas`
- Custom colour themes with live preview — Gentoo (default), Artix, Jet Black, Mono, Retro
- Resilience features: disk space checks, pacman lock recovery, download retry, mid‑build resume
- Offline mode with cached packages
- State persistence for full resume/recovery
- Privacy‑respecting — collects nothing, removes itself after installation

### Supported Kernels

- `linux`
- `zen`
- `lts`
- `hardened`
- `libre`
- `cachyos`
- `bazzite`
- `xanmod`
- `tkg`

### Supported Filesystems

- `ext4`
- `btrfs` (with snapper snapshot support + GRUB boot entries)
- `xfs`
- `f2fs`
- `bcachefs` (Unstable/Unsupported)
- `exfat`
- `zfs`

### Desktop Environments / WMs

- XFCE
- LXQt
- KDE Plasma
- LXDE
- Hyprland
- MangoWM
- Niri
- Sway
- i3
- dwm
- vxwm
- IceWM

### GPU Detection

- NVIDIA
- Intel
- AMD
- VESA fallback
- VM guest drivers

### Extras

Categorized package selection across System Tools, Editors, Browsers, File Managers,
Terminals, Shell & Prompt, Monitoring, and Media. Includes:

- flatpak
- firewalld
- bluez
- zram
- fzf
- zoxide
- starship
- eza
- btop
- tmux
- rsvc
- more

- Offline mode — install from cached packages when network is unavailable
- Offline source bootstrap for Power User builds
- State persistence — all configuration saved for resume/recovery

---

## Power User Mode

- Source-based package compilation
- BusyBox init support
- Swappable coreutils:
  - GNU coreutils
  - BusyBox
  - uutils (Rust)
  - ArtixForge minimal coreutils
  - Custom recipes
- Hardware auto-detection
- Manual kernel configuration
- Compilation profiles
- Per-package feature flags
- Recipe system
- Offline source bootstrap
- Build queue with resume
- Error recovery
- Live build log viewer
- Post-build validation
- Mid‑build resume — interrupted compilations pick up where they left off
- Partial download resume for source tarballs
- `gartix` package manager with full TUI, recipe editor, and offline source bootstrap
- Recipe linting and validation before build
- Hardware auto-detection with `localmodconfig` support

---

# Dependencies

ArtixForge requires `gum` for its TUI.

If it is not already installed, the installer will build it from source during the preflight stage (requires `go`, which will also be installed automatically).

Everything else is handled by the installer itself.

---

# Project Structure

```text
ArtixForge/
├── DOCUMENTS/
│   ├── CHANGELOG.md
│   ├── CONTRIBUTING
│   ├── GUIDE.md
│   ├── LICENSE
│   ├── OSI.md
│   ├── PRIVACY_POLICY.md
│   └── SECURITY.md
├── install
├── VERSION
├── README.md
├── scripts/
│   ├── common.sh
│   ├── state.sh
│   ├── kernels.sh
│   ├── tui/
│   │   ├── core.sh
│   │   ├── menus.sh
│   │   ├── summary.sh
│   │   └── menus/
│   │       ├── main.sh
│   │       ├── desktop.sh
│   │       ├── user.sh
│   │       ├── network_audio.sh
│   │       ├── extras.sh
│   │       ├── advanced.sh
│   │       ├── quick_profiles.sh
│   │       ├── sanity.sh
│   │       └── poweruser.sh
│   ├── recovery/
│   │   ├── core.sh
│   │   ├── detect.sh
│   │   └── repair.sh
│   ├── storage/
│   │   ├── partition.sh
│   │   ├── filesystem.sh
│   │   └── mount.sh
│   ├── install/
│   │   ├── basestrap.sh
│   │   ├── bootloader.sh
│   │   ├── handoff.sh
│   │   ├── services.sh
│   │   ├── system.sh
│   │   └── users.sh
│   ├── post/
│   │   ├── networking.sh
│   │   ├── drivers.sh
│   │   ├── desktop.sh
│   │   ├── audio.sh
│   │   ├── kernel.sh
│   │   └── extras.sh
│   └── stages/
│       ├── init.sh
│       ├── preflight.sh
│       ├── storage.sh
│       ├── base.sh
│       ├── poweruser.sh
│       ├── chroot.sh
│       ├── post.sh
│       └── finalize.sh
└── poweruser/
    ├── VERSION
    ├── README.md
    ├── bin/
    │   ├── gartix
    │   ├── gartix_common.bash
    │   ├── gartix_cli.bash
    │   ├── gartix_tui.bash
    │   └── gartix_recovery.bash
    ├── lib/
    │   ├── builder.bash
    │   ├── common.sh
    │   ├── cache.bash
    │   ├── deps.bash
    │   ├── flags.bash
    │   ├── hwdetect.bash
    │   ├── kconfig.bash
    │   ├── queue.bash
    │   ├── rebuild.bash
    │   ├── recipe.bash
    │   └── validate.bash
    ├── profile/
    │   ├── default.sh
    │   ├── hardened.sh
    │   ├── performance.sh
    │   └── safe.sh
    ├── recipes/
    │   └── template.sh
    ├── tui/
    │   ├── menu_poweruser.sh
    │   ├── progress.sh
    │   └── menup/
    │       ├── profile.sh
    │       ├── packages.sh
    │       ├── kernel_config.sh
    │       ├── recipes.sh
    │       ├── summary.sh
    │       └── config.sh
    ├── world/
    │   └── world.txt
    ├── db/
    │   └── local.db
    └── build/
        ├── artifacts/
        ├── logs/
        ├── queue/
        ├── sources/
        └── work/
```

# Supported Configurations

| Category | Options |
|---|---|
| Init system | OpenRC, runit, dinit, s6, BusyBox init |
| Filesystem | ext4, btrfs, xfs, f2fs, bcachefs, exfat, zfs |
| Storage | Standard partitions, LVM, LUKS, LVM-on-LUKS |
| Boot method | UKI, GRUB, rEFInd, EFIStub, Limine |
| Kernel | linux, zen, lts, hardened, libre, cachyos-bore, bazzite, xanmod, tkg |
| Desktop | XFCE, LXQt, KDE Plasma, LXDE, Hyprland, MangoWM, Niri, Sway, i3, dwm, vxwm, IceWM, none |
| Network | NetworkManager, dhcpcd+iwd, ConnMan, none |
| Audio | PipeWire, PulseAudio, none |
| Shell | bash, zsh, fish |
| Display stack | X.Org, xLibre |
| Coreutils | GNU, BusyBox, uutils, ArtixForge minimal, Custom |
| Privilege escalation | sudo, doas |
| Encryption | LUKS full-disk encryption, LUKS-on-LVM |
| Recovery | Smart issue detection, surgical repair, filesystem repair (safe/destructive), untrusted recovery (rootkit/malware scan) |
| Power User | Source compilation, custom kernel config, community recipes, recipe self-healing |
| Quick Profiles | Desktop, Server, Minimal, Embedded, Gaming, Development, Media, Volk's Personal |
| Theme | Gentoo, Artix, Jet Black, Mono, Retro |
---

# Contributing

Contributions are welcome and appreciated.

Please read [CONTRIBUTING](DOCUMENTS/CONTRIBUTING) for guidelines on testing,
submissions, and code of conduct.

---

# License

Licensed under the [Volk Open License 1.0](DOCUMENTS/LICENSE) © [realvolk](https://github.com/realvolk) 2026.