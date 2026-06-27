<h1 align="center">ArtixForge</h1>

<p align="center">
  <strong>A modular operating system deployment framework for Artix Linux</strong><br>
  No flags. No confusion. Just a terminal interface that works.
</p>

<p align="center">
  <strong>This is the official branch for v9.</strong><br>
  Find a bug? Make an issue.
</p>



<p align="center">
  <img src="https://img.shields.io/badge/Version-v9.2.4.3-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/Artix-[galaxy--gremlins]-blue?style=flat-square&logo=artixlinux" alt="Artix Galaxy-Gremlins">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash" alt="Bash">
  <img src="https://img.shields.io/badge/TUI-forge--gui-FFB6C1?style=flat-square" alt="gum">
  <img src="https://img.shields.io/badge/GUI-GTK-61afef?style=flat-square&logo=gtk" alt="GTK">
  <img src="https://img.shields.io/badge/License-Forge Attribution License 1.0-yellow?style=flat-square" alt="License">
</p>

---

# What is ArtixForge?

ArtixForge is a **modular operating system deployment framework** for Artix Linux (OpenRC, runit, dinit, s6, and BusyBox init).

It walks you through partitioning, filesystem creation, base system installation, bootloader setup, desktop environment, drivers, and extra tools – all from a single interface.

* **Two interfaces:** Terminal UI (keyboard‑only, works in any TTY) and Graphical UI (GTK, mouse‑friendly, launches automatically in desktop environments).
* Built with `gum` for the TUI and `GTK3` + `Python` for the GUI.
* Custom colour themes (ArtixForge, Artix Blue, Jet Black, Mono, Retro) that persist to the installed system.
* Resilience hardened: automatic pacman lock recovery, exponential backoff retries, mid‑build resume, disk space checks at every stage.
* **Build custom live ISOs** from any Quick Profile or full configuration – includes offline package bundles.
* **System Migration:** convert between init systems (openrc, runit, dinit, s6, systemd), desktop environments, or Arch Linux → Artix without reinstalling.
* Over 9 trillion system configurations in a standard install, over 1 quintillion with Power User mode.

---

# Supported Configurations

| Category             | Options                                                                                                                 |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Init system          | OpenRC, runit, dinit, s6, BusyBox init                                                                                  |
| Filesystem | ext4, btrfs, xfs, f2fs |                                                                  |
| Storage              | Standard partitions, LVM, LUKS, LVM-on-LUKS                                                                             |
| Boot method          | UKI, GRUB, rEFInd, EFIStub, Limine                                                                                      |
| Kernel               | linux, zen, lts, hardened, libre, cachyos-*, bazzite, xanmod, tkg                                                    |
| Desktop              | XFCE, LXQt, KDE Plasma, LXDE, Hyprland, MangoWM, Niri, Sway, i3, dwm, vxwm, IceWM, SonicDE, Cinnamon, Budgie, Moksha, COSMIC, none |
| Network              | NetworkManager, dhcpcd+iwd, ConnMan, none                                                                               |
| Audio                | PipeWire, PulseAudio, none                                                                                              |
| Shell                | bash, zsh, fish                                                                                                         |
| Display stack        | X.Org, xLibre                                                                                                           |
| Coreutils            | GNU, BusyBox, uutils, ArtixForge minimal, Custom                                                                        |
| Privilege escalation | sudo, doas                                                                                                              |
| Encryption           | LUKS full-disk encryption, LUKS-on-LVM                                                   |                                                                           |
| Recovery             | Smart issue detection, surgical repair, filesystem repair (safe/destructive), untrusted recovery (rootkit/malware scan) |
| Power User           | Source compilation, custom kernel config, community recipes, recipe self-healing                                        |
| Quick Profiles       | Desktop, Server, Minimal, Embedded, Gaming, Development, Media, Volk's Personal                                         |
| Theme                | ArtixForge, Artix, Jet Black, Mono, Retro                                                                                   |

---

## Screenshots

<details>
<summary>Click to expand — 14 screenshots</summary>

| | | |
|:---:|:---:|:---:|
| ![1](.github/screenshots/1.png) | ![2](.github/screenshots/2.png) | ![3](.github/screenshots/3.png) |
| Mode Selection | Kernel Selection | Extras Search |
| ![4](.github/screenshots/4.png) | ![5](.github/screenshots/5.png) | ![6](.github/screenshots/6.png) |
| Installation Summary | Filesystem Creation | Package List |
| ![7](.github/screenshots/7.png) | ![8](.github/screenshots/8.png) | ![9](.github/screenshots/9.png) |
| Build Hooks | Success | LUKS + Migration |
| ![10](.github/screenshots/10.png) | ![11](.github/screenshots/11.png) | ![12](.github/screenshots/12.png) |
| Cold Reboot | DE Extras | DE Install |
| ![13](.github/screenshots/13.png) | ![14](.github/screenshots/14.png) | |
| Recovery Detection | GRUB Repair | |

</details>

---

# Installation

## Artix Linux (via galaxy-gremlins)

```bash
sudo pacman -S artixforge
sudo artixforge
```

## Alternative: Git Clone

For the latest development version or if the package is not yet available in your mirrors:

```bash
git clone --recursive https://github.com/realvolk/ArtixForge.git
cd ArtixForge
chmod +x install
sudo ./install
```

You'll be greeted by a main menu where you choose your installation mode.

**If you booted a desktop environment (KDE, XFCE, etc.)**, you will be asked whether you want to use the **Graphical UI (GTK4)** instead of the terminal interface. Answer `Yes` to launch a persistent configuration window with mouse support.

**FAIR WARNING: THE GUI IS EXPERIMENTAL.**

### Logs
If the installer fails, check the logs before reporting:

```bash
cat /tmp/artix-installer/install.log
```

When debug mode is enabled (prompted after mode selection):
```bash
cat ~/ArtixForge/artix-debug.log
```

When migration fails:
```bash
cat /tmp/artix-migration-debug.log
```

These will tell you exactly what went wrong. Include them in any GitHub issue.

---

# Installation Modes

| Mode             | Description                                                                                                                             |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| 🟢 Automatic     | Guided installation with full configuration flow.                                                                                       |
| 🔵 Manual        | Detect existing setup progress and continue manually.                                                                                   |
| 🟡 Resume        | Continue from the last saved installation, migration, or ISO build stage.                                                               |
| 🟠 Recovery      | Auto-detect full system config, smart issue detection, surgical repair, filesystem repair (safe/destructive), rootkit/malware scanning. |
| 🔴 Power User    | Gentoo-style source builds, BusyBox init, custom coreutils, advanced system control.                                                    |
| ⚡ Quick Profiles | Desktop, Server, Minimal, Embedded, Gaming, Development, Media, Volk's Personal, and custom profile loading.                           |
| 🧩 Build ISO     | Create a custom Artix live ISO from any Quick Profile or full configuration – includes offline package bundles and resumable builds.    |
| 🔄 System Migration | Convert init system (openrc ↔ runit ↔ dinit ↔ s6 ↔ systemd), desktop environment, or Arch Linux → Artix without reinstalling. Resumable on failure. |

A debug toggle is available for every mode from the same menu. If you encounter errors, it's a great way to see what actually went wrong (e.g. Debug mode + Resume for automatic installations) if the error itself is not descriptive enough.

---

# Features

## Core Installer

* **Two UIs:** Terminal (TUI) with `gum` or Graphical (GUI) with GTK4 + libadwaita – same backend, different frontend.
* Tabbed full-screen TUI – navigate steps with keyboard, jump between tabs, see completed steps with checkmarks
* Persistent GUI configuration window with 5 colour themes, progress bar, and conditional page visibility
* Modular architecture – separate scripts for storage, install, post, stages, recovery, and TUI sub-menus
* Universal logger – writes to `/tmp/artix-installer/install.log` and `/mnt/var/log/artix-installer.log`
* Safe passwords – GUI hashes before saving to state, backend hashes before writing to target
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
* **Desktop migration:** convert between any of the 17 supported desktop environments/window managers.
* Migrates display manager, display stack, audio stack, and network stack alongside the desktop.
* User configurations (`~/.config`, `~/.local`, `~/.cache`) are backed up before migration.
* **ATA (Arch to Artix):** experimental full-system conversion from Arch Linux to Artix.
* Preserves user data, credentials, configurations, packages, and AUR packages.
* Converts systemd services, timers, PAM, hooks, network configs, and bootloader automatically.

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
* `anvil` package manager (CLI + TUI) with recipe editor, offline bootstrap, and recipe self‑healing

## Extras

Categorized package selection across System Tools, Editors, Browsers, File Managers,
Terminals, Shell & Prompt, Monitoring, and Media. Includes:

* `flatpak`, `firewalld`, `bluez`, `zram`
* `fzf`, `zoxide`, `starship`, `eza`, `btop`, `tmux`, `rsvc`
* and many more

---

# Dependencies

* **TUI:** `gum` (installed automatically if missing).
* **GUI:** `gtk4`, `libadwaita`, `python-gobject`, `jsonschema` (installed automatically when GUI mode is selected).

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