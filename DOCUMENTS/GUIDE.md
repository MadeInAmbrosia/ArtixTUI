# ArtixTUI — Installation Guide

Welcome! This guide explains every option you’ll see in the installer.
Don’t worry if you don’t know what something means – that’s what this is for.

---

## 1. Installation Mode

| Mode | What it does | When to use it |
|------|-------------|----------------|
| Automatic | Full guided install, step by step | First time, clean disk |
| Manual | You partition the disk yourself, installer does the rest | You already know your disk layout |
| Resume | Continue an interrupted install | The installer crashed or you rebooted |
| Recovery | Scan /mnt for an existing broken system | Fixing a damaged installation |
| Power User | Build packages from source, Gentoo‑style | You want full control over compilation |

If you’re new to Linux or Artix, **Automatic** is the simplest way to get a working system.

---

## 2. Disk Selection

Choose the physical drive where Artix will be installed.
`/dev/sda` is usually your primary disk, `/dev/nvme0n1` is an NVMe SSD.

**Warning:** Everything on the selected disk will be permanently erased.

If your disk is an NVMe drive, the installer will automatically enable the `discard` mount option for SSDs where supported. No extra configuration is needed.

---

## 3. Init System

The init system is the first program the kernel starts; it manages all other services.

| Init | Style | Notes |
|------|-------|-------|
| OpenRC | Traditional, well‑tested | Artix default – familiar to most users |
| runit | Minimal, fast | Very lightweight, simple design |
| dinit | Modern, parallel startup | Good performance on newer hardware |
| s6 | Process supervision focus | Powerful, but steeper learning curve |
| BusyBox | Ultra‑minimal, source‑built | Only for experienced users; you’ll need to write your own service scripts |

Each init system works well; the choice largely depends on how much control you want and how you prefer to manage services.

---

## 4. Filesystem

Determines how data is organised on the disk.

| Filesystem | Strengths | Weaknesses |
|------------|-----------|------------|
| ext4 | Stable, fast, universally supported | No snapshots or compression |
| btrfs | Snapshots, compression, subvolumes | Can be slightly slower |
| xfs | Excellent for large files, quick recovery | Cannot be shrunk |
| f2fs | Optimised for flash storage (SSD, eMMC) | Not suitable for HDDs |
| bcachefs | Modern, advanced features (compression, tiering) | **Experimental** – tools still under heavy development |
| exfat | Compatible with Windows | Not suitable for a root filesystem |
| zfs | Data integrity, snapshots, RAID, encryption | High memory usage; **experimental on Artix** |

If you don’t have a specific reason to choose otherwise, ext4 is a reliable, zero‑maintenance option. btrfs is a great choice if you want snapshots and compression.

---

## 5. Bootloader

The software that loads your operating system when you switch on the computer.

| Bootloader | Description |
|------------|-------------|
| GRUB | The most widely‑used bootloader; supports dual‑boot, theming, and encrypted partitions. **If you’re unsure, use GRUB.** |
| rEFInd | A graphical boot manager that auto‑detects installed operating systems. |
| EFIStub | Boots the Linux kernel directly from your UEFI firmware – no separate bootloader needed. Very fast, but requires compatible firmware and manual setup. |
| UKI (Unified Kernel Image) | Bundles the kernel, initramfs and command line into a single .efi file. Perfect for Secure Boot and very clean, but UEFI‑only. |

All choices work; GRUB is the most forgiving for beginners and the easiest to troubleshoot.

---

## 6. Kernel

The core of the operating system.

| Kernel | Description | Stability |
|--------|-------------|-----------|
| linux | Stable, general‑purpose kernel | Very stable |
| linux-zen | Tweaked for desktop responsiveness | Stable |
| linux-lts | Long‑term support; receives only security fixes | Very stable |
| linux-hardened | Security‑focused with extra protections | Stable |
| linux-libre | Completely free software (removes non‑free firmware) | **May break hardware** – Wi‑Fi, Bluetooth, NVIDIA often fail |
| linux-cachyos-bore | Performance‑optimised, uses BORE scheduler | Generally stable |
| linux-bazzite-bin | Gaming‑focused, includes extra patches | May occasionally have issues |
| xanmod | Aggressive performance tweaks | May be less stable than mainline |
| tkg | Fully customisable; build with your own configuration | Stability depends entirely on your choices |

Standard `linux` is a safe choice. If you do a lot of interactive work or gaming, `linux-zen` or `linux-cachyos-bore` may feel snappier. Avoid `linux-libre` unless you are certain your hardware works without proprietary firmware.

---

## 7. Desktop Environment

Your graphical interface.

| DE / WM | Type | Notes |
|---------|------|-------|
| KDE Plasma | Full desktop | Feature‑rich, customisable |
| XFCE | Full desktop | Lightweight, traditional |
| LXQt | Full desktop | Very lightweight, modular |
| LXDE | Full desktop | Even lighter, older |
| Hyprland | Wayland compositor | Modern, eye‑candy, requires Arch repos |
| Sway | Wayland compositor | i3‑compatible, stable |
| Niri | Wayland compositor | Scrollable tiling, experimental |
| i3 | Tiling window manager | Keyboard‑driven, very light |
| dwm | Tiling window manager | Minimal, configured via source code |
| IceWM | Stacking window manager | Extremely light, familiar look |
| MangoWM | Wayland compositor | Lightweight, active development |
| none | No desktop | You’ll start from a terminal |

All of these can produce a comfortable environment. KDE and XFCE are the most popular; Hyprland and Sway are great if you like tinkering.

---

## 8. Display Stack (X11 / Wayland)

Most desktop environments will automatically select the appropriate display stack. If you choose a Wayland compositor (Hyprland, Sway, Niri), the X stack is irrelevant. For XFCE, LXQt, LXDE, or i3/dwm, you’ll usually want `X.Org` (But let's be real - Artix is focused on `xLibre`, so you should probably use that whenever possible).

---

## 9. Network Stack

How your system connects to the internet.

| Stack | Description |
|-------|-------------|
| NetworkManager | GUI‑friendly, auto‑connects, widely used |
| dhcpcd + iwd | Lightweight, fast, manual configuration |
| ConnMan | Compact, designed for embedded use |
| None | You’ll set up networking manually after boot |

NetworkManager is the easiest to live with on a daily‑use machine.

---

## 10. Audio Stack

| Stack | Description |
|-------|-------------|
| PipeWire | Modern, low‑latency, replaces both PulseAudio and JACK |
| PulseAudio | Older, well‑tested, still fully functional |
| None | No sound |

PipeWire is now the standard on most distributions and works great.

---

## 11. Privilege Escalation

How you run commands as root.

| Tool | Description |
|------|-------------|
| sudo | The de‑facto standard; feature‑rich, well‑known |
| doas | Minimalist, inspired by OpenBSD; simpler syntax |

Both are secure. `sudo` is more familiar; `doas` is loved by minimalists.

---

## 12. Coreutils (Power User only)

The basic command‑line tools (`ls`, `cp`, `cat`, …).

| Implementation | Description |
|---------------|-------------|
| GNU | Full‑featured, standard on most Linux systems |
| BusyBox | Lightweight, fewer options, smaller footprint |
| uutils | Rust rewrite of GNU coreutils, modern |
| ArtixTUI | Our own debloated set (based on BusyBox with selectable features) |
| Custom | Write your own recipe – full control |

GNU coreutils are the safest choice for compatibility with scripts and existing habits. BusyBox is perfect for minimal systems. uutils is exciting but still maturing.

---

## 13. Disk Encryption (LUKS)

Encrypts your entire root partition. Requires a passphrase at boot.

LUKS works well with any filesystem. If you also enable LVM, the encryption wraps around the LVM physical volume – this combination (LUKS on LVM) is powerful but the bootloader configuration must be correct, especially with GRUB or EFIStub. The installer handles this automatically, but if you manually edit things later, be careful.

---

## 14. Logical Volume Management (LVM)

Allows you to resize, move, and combine partitions easily without rebooting.

LVM is especially useful on servers or if you need to resize partitions frequently. It adds a small amount of complexity but is transparent once set up.

---

## 15. Power User Mode – Source Compilation

If you selected Power User mode, you can compile packages from source instead of using pre‑built binaries. This gives you:

- Custom optimisation flags for your CPU
- The ability to enable/disable specific features
- A kernel built exactly for your hardware

**Warning:** Compiling from source is time‑consuming and can fail if dependencies are missing. The installer offers a “fallback kernel” option so you can install a binary kernel if the compilation fails. Be especially careful if you choose to build `glibc` (the C library) – a broken glibc will make your system unbootable.

---

## 15.1. Community Recipes

ArtixTUI can download additional recipes from the community repository at
[ArtixTUI-recipes](https://github.com/realvolk/ArtixTUI-recipes).

Use `gartix sync` to pull the latest recipe list and download new recipes.
By default, only tested OFFICIAL recipes are included. You can enable
COMMUNITY recipes through the "Manage recipe sections" option in `gartix --tui`.

To contribute your own recipes, see the [ArtixTUI-recipes](https://github.com/realvolk/ArtixTUI-recipes) repository.

---

## 16. Quick Install Profiles

Instead of answering every question, you can pick a pre‑made profile:

- **Desktop** – KDE Plasma, NetworkManager, PipeWire, flatpak, sudo, Arch repos enabled.
- **Server** – No desktop, dhcpcd+iwd, doas, basic tools.
- **Minimal** – No extras, just the base system.
- **Embedded** – BusyBox init, BusyBox coreutils, no desktop, no network, minimal kernel.

Profiles are a starting point; you can still tweak anything afterwards in the main menu.

---

## 17. Sanity Warnings

Before the installation begins, the installer will warn you about potentially unsafe choices, such as:

- No fallback kernel when building your own
- Using experimental filesystems (ZFS, bcachefs)
- No desktop environment selected
- Non‑GNU coreutils
- BusyBox init
- No privilege escalation tool
- Offline mode

Read these warnings carefully – they exist because the combination you chose may require manual intervention after installation.

---

## Common Questions

**Will this erase my other operating systems?**
Only if you choose the wrong disk. The installer wipes the entire disk you select, so be sure it’s the right one.

**Can I dual‑boot?**
Yes. Use Manual mode, create partitions for Artix alongside your existing OS, and GRUB will usually detect other systems automatically.

**What if the installer stops or crashes?**
Reboot, start the installer again, and pick **Resume** from the main menu. It will continue from the last completed stage.

**Where can I get help?**
Open an issue on [GitHub](https://github.com/realvolk/ArtixTUI/issues) or visit the Artix community forums.

---

## Quick Reference

| If you want… | Consider… |
|--------------|-----------|
| A simple, stable desktop | Automatic, ext4, GRUB, linux, KDE, NetworkManager, PipeWire, sudo |
| A snappy gaming machine | As above + linux-zen or linux-cachyos-bore |
| A lightweight laptop | XFCE or LXQt, linux-lts |
| A headless server | No desktop, dhcpcd+iwd, ext4, doas, possibly LVM |
| A minimal, embedded system | Power User, BusyBox init, linux-lts, BusyBox coreutils |
| Total customisation | Power User, build your own kernel, choose every component yourself |

---

Remember: the best choice is the one that fits *your* needs. This guide is here to explain, not to prescribe. If something goes wrong, the community is here to help.