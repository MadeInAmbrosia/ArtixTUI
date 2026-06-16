<h1 align="center">ArtixForge</h1>

<p align="center">
  <strong>A modular operating system deployment framework for Artix Linux</strong><br>
  No flags. No confusion. Just a terminal interface that works.
</p>

<p align="center">
  <strong>THIS IS A TESTING BRANCH FOR v9. EXPECT BUGS.</strong><br>
  Any bugs found and reported are welcome.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-v8.8.0.1-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash" alt="Bash">
  <img src="https://img.shields.io/badge/TUI-gum-FFB6C1?style=flat-square" alt="gum">
  <img src="https://img.shields.io/badge/GUI-GTK-61afef?style=flat-square&logo=gtk" alt="GTK">
  <img src="https://img.shields.io/badge/License-Forge Attribution License 1.0-yellow?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/Artix-[galaxy] *soon*-blue?style=flat-square&logo=artixlinux" alt="Artix Galaxy">
</p>

---

# **TESTING BRANCH BABOONERY**
###### We're going to milky way [galaxy] edition!
### AKA *Here's how to test v9-merger:*
```bash
git clone --branch v9-merger --recursive https://github.com/realvolk/ArtixForge.git ArtixForge
cd ArtixForge
chmod +x install
sudo ./install
```
Currently, the following needs testing:
- Does ZFS Boot properly?
- LUKS+LVM, LUKS+UKI, LUKS+LVM+UKI, LVM+UKI with any bootloader (*Pref. Grub or Limine*)
- Migrations for both DE and INITs need testing
- Does ISO building pass?
- Does the GUI render everything properly?
- Does SonicDE work?
- Does TKG compile properly?
- Does offline mode allow proper package bundling from user config?
- How well does Recovery handle edge cases?

### **FOUND A BUG? SOMETHING NOT WORKING?**

Open an issue [here](https://github.com/realvolk/ArtixForge/issues)! Please describe:

- The exact combination you tested (e.g., "LUKS+LVM+UKI with GRUB")
- Any error messages from /tmp/artix-installer/install.log
- Whether the GUI or TUI was used

---

# What is ArtixForge?

ArtixForge is a **modular operating system deployment framework** for Artix Linux (OpenRC, runit, dinit, s6, and BusyBox init).

It walks you through partitioning, filesystem creation, base system installation, bootloader setup, desktop environment, drivers, and extra tools – all from a single interface.

* **Two interfaces:** Terminal UI (keyboard‑only, works in any TTY) and Graphical UI (GTK, mouse‑friendly, launches automatically in desktop environments).
* Built with `gum` for the TUI and `GTK3` + `Python` for the GUI.
* Custom colour themes (Gentoo Purple, Artix Blue, Jet Black, Mono, Retro) that persist to the installed system.
* Resilience hardened: automatic pacman lock recovery, exponential backoff retries, mid‑build resume, disk space checks at every stage.
* **Build custom live ISOs** from any Quick Profile or full configuration – includes offline package bundles.
* **System Migration:** convert between init systems (openrc, runit, dinit, s6, systemd) or desktop environments without reinstalling.
* Over 9 trillion system configurations in a standard install, over 1 quintillion with Power User mode.

---

# Supported Configurations

| Category             | Options                                                                                                                 |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Init system          | OpenRC, runit, dinit, s6, BusyBox init                                                                                  |
| Filesystem | ext4, btrfs, xfs, f2fs, ~~bcachefs~~, ~~zfs~~ |                                                                  |
| Storage              | Standard partitions, LVM, LUKS, LVM-on-LUKS                                                                             |
| Boot method          | UKI, GRUB, rEFInd, EFIStub, Limine                                                                                      |
| Kernel               | linux, zen, lts, hardened, libre, cachyos-bore, bazzite, xanmod, tkg                                                    |
| Desktop              | XFCE, LXQt, KDE Plasma, LXDE, Hyprland, MangoWM, Niri, Sway, i3, dwm, vxwm, IceWM, SonicDE, none                        |
| Network              | NetworkManager, dhcpcd+iwd, ConnMan, none                                                                               |
| Audio                | PipeWire, PulseAudio, none                                                                                              |
| Shell                | bash, zsh, fish                                                                                                         |
| Display stack        | X.Org, xLibre                                                                                                           |
| Coreutils            | GNU, BusyBox, uutils, ArtixForge minimal, Custom                                                                        |
| Privilege escalation | sudo, doas                                                                                                              |
| Encryption           | LUKS full-disk encryption, LUKS-on-LVM, ZFS native encryption                                                           |                                                                           |
| Recovery             | Smart issue detection, surgical repair, filesystem repair (safe/destructive), untrusted recovery (rootkit/malware scan) |
| Power User           | Source compilation, custom kernel config, community recipes, recipe self-healing                                        |
| Quick Profiles       | Desktop, Server, Minimal, Embedded, Gaming, Development, Media, Volk's Personal                                         |
| Theme                | Gentoo, Artix, Jet Black, Mono, Retro                                                                                   |

---

# Installation

## Artix Linux (via future PKGBUILD)

```bash
sudo pacman -S artixforge
sudo artixforge
```

## Alternative: Git Clone

For the latest development version or if the package is not yet available in your mirrors:

```bash
git clone https://github.com/realvolk/ArtixForge.git
cd ArtixForge
chmod +x install
sudo ./install
```

You'll be greeted by a main menu where you choose your installation mode.

**If you booted a desktop environment (KDE, XFCE, etc.)**, you will be asked whether you want to use the **Graphical UI (GTK)** instead of the terminal interface. Answer `Yes` to launch a persistent configuration window with mouse support.

---

# Installation Modes

| Mode             | Description                                                                                                                             |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| 🟢 Automatic     | Guided installation with full configuration flow.                                                                                       |
| 🔵 Manual        | Detect existing setup progress and continue manually.                                                                                   |
| 🟡 Resume        | Continue from the last saved installation stage.                                                                                        |
| 🟠 Recovery      | Auto-detect full system config, smart issue detection, surgical repair, filesystem repair (safe/destructive), rootkit/malware scanning. |
| 🔴 Power User    | Gentoo-style source builds, BusyBox init, custom coreutils, advanced system control.                                                    |
| ⚡ Quick Profiles | Desktop, Server, Minimal, Embedded, Gaming, Development, Media, Volk's Personal, and custom profile loading.                           |
| 🧩 Build ISO     | Create a custom Artix live ISO from any Quick Profile or full configuration – includes offline package bundles.                         |
| 🔄 System Migration | Convert init system (openrc ↔ runit ↔ dinit ↔ s6 ↔ systemd) or desktop environment without reinstalling.                             |

A debug toggle is available for every mode from the same menu.

---

# Features

## Core Installer

* **Two UIs:** Terminal (TUI) with `gum` or Graphical (GUI) with GTK – same backend, different frontend.
* Tabbed full-screen TUI – navigate steps with keyboard, jump between tabs, see completed steps with checkmarks
* Persistent GUI configuration window – all options collected in one window, progress window during installation
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
* Custom colour themes with live preview (both TUI and GUI)
* Resilience features – disk space checks, pacman lock recovery, download retry with exponential backoff, mid‑build resume
* Offline mode with cached packages (and offline ISO generation)
* State persistence for full resume/recovery
* Privacy-respecting – collects nothing, removes itself after installation

## ISO Generation

* Build custom Artix live ISOs from any Quick Profile or full custom configuration.
* **Live Desktop mode** – includes a full desktop environment (KDE, XFCE, etc.) with the ArtixForge installer icon on the desktop.
* **Installer mode** – boots directly into the ArtixForge TUI (no desktop, minimal size).
* **Offline ISO** – bundle all packages into the ISO; installation works without an internet connection.
* Add extra packages beyond the profile selection.
* Build logs saved alongside the ISO.

## System Migration

* **Init migration:** convert between openrc, runit, dinit, s6, and systemd (if Arch repos enabled) without reinstalling.
* Automatic service mapping; custom services are backed up and listed.
* **Desktop migration:** convert between any of the 13 supported desktop environments/window managers.
* Migrates display manager, display stack, audio stack, and network stack alongside the desktop.
* User configurations (`~/.config`, `~/.local`, `~/.cache`) are backed up before migration.

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
* `gartix` package manager (CLI + TUI) with recipe editor, offline bootstrap, and recipe self‑healing

## Extras

Categorized package selection across System Tools, Editors, Browsers, File Managers,
Terminals, Shell & Prompt, Monitoring, and Media. Includes:

* `flatpak`, `firewalld`, `bluez`, `zram`
* `fzf`, `zoxide`, `starship`, `eza`, `btop`, `tmux`, `rsvc`
* and many more

---

# Dependencies

* **TUI:** `gum` (installed automatically if missing).
* **GUI:** `gtk3`, `python-gobject`, `jsonschema` (installed automatically when GUI mode is selected).

Everything else is handled by the installer.

---

# Contributing

Contributions are welcome and appreciated.

**🫱 Looking for: Testers • Contributors • Distro Packagers**

Please read [CONTRIBUTING](DOCUMENTS/CONTRIBUTING) for guidelines on testing,
submissions, and [code of conduct](DOCUMENTS/CODE_OF_CONDUCT.md).

---

# License

Licensed under the [Forge Attribution License 1.0](DOCUMENTS/LICENSE) © [Volk](https://github.com/realvolk) 2026.