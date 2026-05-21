<p align="center">
  <img src="https://github.com/realvolk/ArtixTUI/blob/main/.github/artixtui.png" width="196" alt="Artix Linux">
</p>

<h1 align="center">ArtixTUI</h1>

<p align="center">
  <strong>A beautiful, modular, TUI-first installer for Artix Linux</strong><br>
  No flags. No confusion. Just a gorgeous terminal interface.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-v7.2.0.0-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash" alt="Bash">
  <img src="https://img.shields.io/badge/TUI-gum-FFB6C1?style=flat-square" alt="gum">
  <img src="https://img.shields.io/badge/License-Volk Open License 1.0-yellow?style=flat-square" alt="License">
</p>

---

# What is ArtixTUI?

ArtixTUI is a **TUI-first, modular installer** for Artix Linux (OpenRC, runit, dinit, s6).

It walks you through partitioning, filesystem creation, base system installation, bootloader setup, desktop environment, drivers, and extra tools — all from a single, beautiful terminal interface.

Built with **gum** by Charmbracelet, it looks better than `archinstall` and works with **any** Artix init system.

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
| 🟢 Automatic | The installer guides you through every configuration choice. |
| 🔵 Manual | You select a disk; the installer detects what's already done and resumes. |
| 🟡 Resume | Continue an interrupted installation from the last saved stage. |
| 🟠 Recovery | Scan `/mnt` for an existing system, reconstruct state, and repair. |
| 🔴 Power User | Source-based package compilation with Gentoo-style control. |

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
- Full-disk encryption — LUKS support with passphrase confirmation
- EFIStub, GRUB, rEFInd — all bootloaders supported
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
- `bcachefs`
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
- State persistence — all configuration saved for resume/recovery

---

## Power User Mode

- Source-based package compilation
- Hardware auto-detection
- Manual kernel configuration
- Compilation profiles
- Custom flag editor
- Feature flags per package
- Recipe system
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
│       ├── preflight.sh
│       ├── storage.sh
│       ├── base.sh
│       ├── poweruser.sh
│       ├── chroot.sh
│       ├── post.sh
│       └── finalize.sh
└── poweruser/
    ├── README.md
    ├── bin/
    │   └── gartix
    ├── lib/
    │   ├── builder.bash
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
| Init system | OpenRC, runit, dinit, s6 |
| Filesystem | ext4, btrfs, xfs, f2fs, bcachefs, exfat, zfs |
| Bootloader | GRUB, rEFInd, EFIStub |
| Kernel | linux, zen, lts, hardened, libre, cachyos-bore, bazzite, xanmod, tkg |
| Desktop | XFCE, LXQt, KDE Plasma, LXDE, Hyprland, MangoWM, Niri, Sway, i3, dwm, IceWM, none |
| Network | NetworkManager, dhcpcd+iwd, ConnMan, none |
| Audio | PipeWire, PulseAudio, none |
| Shell | bash, zsh, fish |
| Display stack | X.Org, xLibre |
| Privilege escalation | sudo, doas |
| Encryption | LUKS full-disk encryption |

---

# Contributing

Contributions are welcome and appreciated.

Please read [CONTRIBUTING](CONTRIBUTING) for guidelines on testing, submissions, and code of conduct.

---

# License

Licensed under the [Volk Open License 1.0](LICENSE) © [realvolk](https://github.com/realvolk) 2026.