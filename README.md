<p align="center">
  <img src="https://github.com/realvolk/ArtixTUI/blob/main/.github/artixtui.png" width="196" alt="Artix Linux">
</p>

<h1 align="center">ArtixTUI</h1>

<p align="center">
  <strong>A beautiful, modular, TUI-first installer for Artix Linux</strong><br>
  No flags. No confusion. Just a gorgeous terminal interface.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-v8.0.1.8-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash" alt="Bash">
  <img src="https://img.shields.io/badge/TUI-gum-FFB6C1?style=flat-square" alt="gum">
  <img src="https://img.shields.io/badge/License-Volk Open License 1.0-yellow?style=flat-square" alt="License">
</p>

---

# What is ArtixTUI?

ArtixTUI is a **TUI-first, modular installer** for Artix Linux (OpenRC, runit, dinit, s6).

It walks you through partitioning, filesystem creation, base system installation, bootloader setup, desktop environment, drivers, and extra tools — all from a single, beautiful terminal interface.

Built with **gum** by Charmbracelet, it looks better than `archinstall` and supports all major Artix init systems — including BusyBox init in Power User mode.

  Over 9 trillion system configurations in a standard install.
  Over 1 000 000 000 000 000 000 (1 quintillion) when Power User mode is enabled.
  No two installations need ever be the same.



---

# Quick Start

```bash
git clone https://github.com/realvolk/ArtixTUI.git
cd ArtixTUI
chmod +x install
sudo ./install
```

That's it.

No `--auto`, no `--manual`, no confusing flags.

You'll be greeted by a main menu where you choose your installation mode.

---

# Installation Modes

| Mode | Description |
|------|-------------|
| 🟢 Automatic | Guided installation with full configuration flow. |
| 🔵 Manual | Detect existing setup progress and continue manually. |
| 🟡 Resume | Continue from the last saved installation stage. |
| 🟠 Recovery | Reconstruct installer state from `/mnt` and repair installations. |
| 🔴 Power User | Gentoo-style source builds, BusyBox init, custom coreutils, advanced system control. |
| ⚡ Quick Profiles | Desktop, Server, Minimal, and Embedded presets for rapid deployment. |

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
- `btrfs`
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
- IceWM

### GPU Detection

- NVIDIA
- Intel
- AMD
- VESA fallback
- VM guest drivers

### Extras

- flatpak
- ufw
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
  - ArtixTUI minimal coreutils
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
- `gartix` package manager

---

# Dependencies

ArtixTUI requires `gum` for its TUI.

If it is not already installed, the installer will build it from source during the preflight stage (requires `go`, which will also be installed automatically).

Everything else is handled by the installer itself.

---

# Project Structure

```text
ArtixTUI/
├── .github/
│   └── artixtui.png
├── install
├── LICENSE
├── CONTRIBUTING
├── VERSION
├── scripts/
│   ├── common.sh
│   ├── state.sh
│   ├── recovery.sh
│   ├── kernels.sh
│   ├── tui/
│   │   ├── core.sh
│   │   ├── menus.sh
│   │   └── summary.sh
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
    │   └── gartix
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
    │   ├── artix-coreutils.sh
    │   ├── busybox-init.sh
    │   ├── busybox.sh
    │   ├── glibc.sh
    │   ├── mesa.sh
    │   ├── openssl.sh
    │   ├── uutils-coreutils.sh
    │   ├── zlib.sh
    │   ├── zstd.sh
    │   ├── linux.sh
    │   └── template.sh
    ├── tui/
    │   ├── menu_poweruser.sh
    │   └── progress.sh
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
| Boot method | UKI, GRUB, rEFInd, EFIStub |
| Kernel | linux, zen, lts, hardened, libre, cachyos-bore, bazzite, xanmod, tkg |
| Desktop | XFCE, LXQt, KDE Plasma, LXDE, Hyprland, MangoWM, Niri, Sway, i3, dwm, IceWM, none |
| Network | NetworkManager, dhcpcd+iwd, ConnMan, none |
| Audio | PipeWire, PulseAudio, none |
| Shell | bash, zsh, fish |
| Display stack | X.Org, xLibre |
| Coreutils | GNU, BusyBox, uutils, ArtixTUI minimal, Custom |
| Privilege escalation | sudo, doas |
| Encryption | LUKS full-disk encryption |
---

# Contributing

Contributions are welcome and appreciated.

Please read [CONTRIBUTING](CONTRIBUTING) for guidelines on testing, submissions, and code of conduct.

---

# License

Licensed under the [Volk Open License 1.0](LICENSE) © [realvolk](https://github.com/realvolk) 2026.