# ArtixForge — Installation Guide

Welcome! This guide explains every option you’ll see in the installer.
Don’t worry if you don’t know what something means – that’s what this is for.

---

## 1. Installation Interface

ArtixForge offers **two interfaces** that are fully feature‑identical:

| Interface | When it appears | How to use |
|-----------|----------------|------------|
| **Terminal UI (TUI)** | Default in a TTY or when `DISPLAY` is not set | Keyboard only, works on any terminal |
| **Graphical UI (GUI)** | When a desktop environment (KDE, XFCE, etc.) is detected | Mouse + keyboard, native FILLY windows |

Both interfaces use the same **hub layout**: a list of configuration categories on the left
(Disk & Storage, Bootloader, Kernel, Desktop, etc.) and the settings for the selected category
on the right. Action buttons at the bottom let you apply a quick profile, view a summary of your
choices, or proceed with installation.

If you boot an ArtixForge‑generated ISO with a desktop environment, you'll see a desktop icon.
Double‑click it to launch the GUI installer. Alternatively, run `sudo ./install` in a terminal
and answer "Yes" when asked if you want to use the GUI.

Both interfaces collect the same configuration, produce the same state file, and run the same
installation backend. Choose whichever feels comfortable.

---

## 2. Installation Mode

| Mode | What it does | When to use it |
|------|-------------|----------------|
| Automatic | Full guided install, step by step | First time, clean disk |
| Manual | You partition the disk yourself, installer does the rest | You already know your disk layout |
| Resume | Continue an interrupted install | The installer crashed or you rebooted |
| Recovery | Scan `/mnt` for an existing system, auto-detect issues, repair | Fixing a damaged installation with smart detection |
| Power User | Build packages from source, Gentoo‑style | You want full control over compilation |
| Build ISO | Create a custom Artix live ISO from a profile | You want a personalised rescue or installation disk |
| System Migration | Convert init system or desktop environment on an installed system | Change your mind after installation without reinstalling |

If you’re new to Linux or Artix, **Automatic** is the simplest way to get a working system.

---

## 3. Disk Selection

Choose the physical drive where Artix will be installed.
`/dev/sda` is usually your primary disk, `/dev/nvme0n1` is an NVMe SSD.

**Warning:** Everything on the selected disk will be permanently erased.

If your disk is an NVMe drive, the installer will automatically enable the `discard` mount option for SSDs where supported. No extra configuration is needed.

---

## 4. Init System

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

## 5. Filesystem

Determines how data is organised on the disk.

| Filesystem | Strengths | Weaknesses |
|------------|-----------|------------|
| ext4 | Stable, fast, universally supported | No snapshots or compression |
| btrfs | Snapshots, compression, subvolumes | Can be slightly slower |
| xfs | Excellent for large files, quick recovery | Cannot be shrunk |
| f2fs | Optimised for flash storage (SSD, eMMC) | Not suitable for HDDs |

If you don’t have a specific reason to choose otherwise, ext4 is a reliable, zero‑maintenance option. btrfs is a great choice if you want snapshots and compression.

---

## 6. Bootloader

The software that loads your operating system when you switch on the computer.

| Bootloader | Description |
|------------|-------------|
| GRUB | The most widely‑used bootloader; supports dual‑boot, theming, and encrypted partitions. **If you're unsure, use GRUB.** |
| rEFInd | A graphical boot manager that auto‑detects installed operating systems. |
| EFIStub | Boots the Linux kernel directly from your UEFI firmware – no separate bootloader needed. Very fast, but requires compatible firmware and manual setup. |
| Limine | Modern, portable, multiprotocol bootloader. Clean config syntax, BTRFS snapshot booting, Windows chainloading. UEFI‑only on ArtixForge. |

All choices work; GRUB is the most forgiving for beginners and the easiest to troubleshoot.
Limine is a great choice if you want a clean, modern config and BTRFS rollback support.

**UKI (Unified Kernel Image)** is not a bootloader, but an optional feature that bundles the kernel,
initramfs and command line into a single `.efi` file. It works with GRUB, Limine, or EFIStub.
Enable it on the Bootloader page if you want a Secure‑Boot‑friendly single file.

---

## 7. Kernel

The core of the operating system.

| Kernel | Description | Stability |
|--------|-------------|-----------|
| linux | Stable, general‑purpose kernel | Very stable |
| linux-zen | Tweaked for desktop responsiveness | Stable |
| linux-lts | Long‑term support; receives only security fixes | Very stable |
| linux-hardened | Security‑focused with extra protections | Stable |
| linux-libre | Completely free software (removes non‑free firmware) | **May break hardware** – Wi‑Fi, Bluetooth, NVIDIA often fail |
| linux-cachyos-* | Performance‑optimised kernels | Generally stable |
| linux-bazzite-bin | Gaming‑focused, includes extra patches | May occasionally have issues |
| xanmod | Aggressive performance tweaks | May be less stable than mainline |
| tkg | Fully customisable; build with your own configuration | Stability depends entirely on your choices |

Standard `linux` is a safe choice. If you do a lot of interactive work or gaming, `linux-zen` or `linux-cachyos-*` may feel snappier. Avoid `linux-libre` unless you are certain your hardware works without proprietary firmware.

---

## 8. Desktop Environment

Your graphical interface.

| DE / WM | Type | Notes |
|---------|------|-------|
| KDE Plasma | Full desktop | Feature‑rich, customisable |
| XFCE | Full desktop | Lightweight, traditional |
| LXQt | Full desktop | Very lightweight, modular |
| LXDE | Full desktop | Even lighter, older |
| Cinnamon | Full desktop | Traditional, Windows-like |
| Budgie | Full desktop | Modern, clean design |
| Moksha | Full desktop | Enlightenment-based, community |
| COSMIC | Full desktop | Rust-based, alpha software |
| Hyprland | Wayland compositor | Modern, eye‑candy, requires Arch repos |
| Sway | Wayland compositor | i3‑compatible, stable |
| Niri | Wayland compositor | Scrollable tiling, experimental |
| i3 | Tiling window manager | Keyboard‑driven, very light |
| dwm | Tiling window manager | Minimal, configured via source code |
| IceWM | Stacking window manager | Extremely light, familiar look |
| MangoWM | Wayland compositor | Lightweight, active development |
| SonicDE | Full Desktop | Third-party KDE 6.7 X11 fork |
| none | No desktop | You'll start from a terminal |

All of these can produce a comfortable environment. KDE and XFCE are the most popular; Hyprland and Sway are great if you like tinkering.
---

## 9. Display Stack (X11 / Wayland)

Most desktop environments will automatically select the appropriate display stack. If you choose a Wayland compositor (Hyprland, Sway, Niri), the X stack is irrelevant. For XFCE, LXQt, LXDE, or i3/dwm, you’ll usually want `X.Org` (but Artix is focused on `xLibre`, so use that whenever possible).

---

## 10. Network Stack

How your system connects to the internet.

| Stack | Description |
|-------|-------------|
| NetworkManager | GUI‑friendly, auto‑connects, widely used |
| dhcpcd + iwd | Lightweight, fast, manual configuration |
| ConnMan | Compact, designed for embedded use |
| None | You’ll set up networking manually after boot |

NetworkManager is the easiest to live with on a daily‑use machine.

---

## 11. Audio Stack

| Stack | Description |
|-------|-------------|
| PipeWire | Modern, low‑latency, replaces both PulseAudio and JACK |
| PulseAudio | Older, well‑tested, still fully functional |
| None | No sound |

PipeWire is now the standard on most distributions and works great.

---

## 12. Privilege Escalation

How you run commands as root.

| Tool | Description |
|------|-------------|
| sudo | The de‑facto standard; feature‑rich, well‑known |
| doas | Minimalist, inspired by OpenBSD; simpler syntax |

Both are secure. `sudo` is more familiar; `doas` is loved by minimalists.

## 12a. User Accounts

ArtixForge lets you create multiple user accounts during installation.

| Option | What it does |
|--------|-------------|
| Add User | Create a new user with username, password, shell, groups, and sudo access |
| Edit User | Modify an existing user's details |
| Remove User | Delete a user account |

For each user you can configure:

- **Username** — must start with a letter, no spaces
- **Password** — hashed before storage, never written to disk in plaintext
- **Shell** — bash, zsh, or fish
- **Groups** — wheel (admin), audio, video, storage, lp, network, optical, scanner, users
- **Sudo access** — yes/no, applies to sudo or doas depending on your privilege escalation choice

At least one user account is required. The first user's name is also used
for AUR package builds and source compilation if those features are enabled.

**Root password** is set separately from user accounts. You can skip setting
a root password if you prefer to use sudo for all administrative tasks.

---

## 13. Coreutils (Power User only)

The basic command‑line tools (`ls`, `cp`, `cat`, …).

| Implementation | Description |
|---------------|-------------|
| GNU | Full‑featured, standard on most Linux systems |
| BusyBox | Lightweight, fewer options, smaller footprint |
| uutils | Rust rewrite of GNU coreutils, modern |
| ArtixForge | Our own debloated set (based on BusyBox with selectable features) |
| Custom | Write your own recipe – full control |

GNU coreutils are the safest choice for compatibility with scripts and existing habits. BusyBox is perfect for minimal systems. uutils is exciting but still maturing.

---

## 14. Disk Encryption (LUKS)

Encrypts your entire root partition. Requires a passphrase at boot.

LUKS works well with any filesystem. If you also enable LVM, the encryption wraps around the LVM physical volume – this combination (LUKS on LVM) is powerful but the bootloader configuration must be correct, especially with GRUB or EFIStub. The installer handles this automatically, but if you manually edit things later, be careful.

---

## 15. Logical Volume Management (LVM)

Allows you to resize, move, and combine partitions easily without rebooting.

LVM is especially useful on servers or if you need to resize partitions frequently. It adds a small amount of complexity but is transparent once set up.

---

## 16. Power User Mode – Source Compilation

If you selected Power User mode, you can compile packages from source instead of using pre‑built binaries. This gives you:

- Custom optimisation flags for your CPU
- The ability to enable/disable specific features
- A kernel built exactly for your hardware (using `localmodconfig` for reliable module detection)

**Warning:** Compiling from source is time‑consuming and can fail if dependencies are missing. The installer offers a “fallback kernel” option so you can install a binary kernel if the compilation fails. Be especially careful if you choose to build `glibc` (the C library) – a broken glibc will make your system unbootable.

---

## 16.1. Community Recipes

ArtixForge can download additional recipes from the community repository at
[ArtixForge-recipes](https://github.com/realvolk/ArtixForge-recipes).

Use `anvil sync` to pull the latest recipe list and download new recipes.
By default, only tested OFFICIAL recipes are included. You can enable
COMMUNITY recipes through the "Manage recipe sections" option in `anvil --tui`.

To contribute your own recipes, see the [ArtixForge-recipes](https://github.com/realvolk/ArtixForge-recipes) repository.

If a source download fails during a build (404, checksum mismatch),
ArtixForge can now automatically detect newer upstream versions and
heal the recipe. Select "Heal recipe" from the build failure menu.

---

## 17. Quick Install Profiles

Instead of answering every question, you can pick a pre‑made profile:

- **Desktop** – KDE Plasma, NetworkManager, PipeWire, flatpak, sudo, Arch repos enabled.
- **Server** – No desktop, dhcpcd+iwd, doas, basic tools.
- **Minimal** – No extras, just the base system.
- **Embedded** – BusyBox init, BusyBox coreutils, no desktop, no network, minimal kernel.
- **Gaming** – KDE minimal, linux-zen kernel, PipeWire, flatpak, gaming-oriented extras.
- **Development** – XFCE, base-devel, git, neovim, development tools.
- **Media** – KDE minimal, mpv, feh, media-oriented extras.
- **Volk's Personal** – dinit, KDE minimal, LightDM, source-built kernel.

Profiles are a starting point; you can still tweak anything afterwards in the main menu.

You can also **load a custom profile** from a saved configuration file
(e.g., `/etc/artixforge-profile.conf` from a previous installation).
Select "Load custom profile" from the Quick Profiles menu and provide the file path.

---

## 18. ISO Generation (Build ISO mode)

ArtixForge can build a fully customised Artix live ISO.

When you select **Build ISO** from the main menu, you will be asked:

| Option | What it does |
|--------|-------------|
| Live Desktop | Includes a full desktop environment (KDE, XFCE, etc.) and the ArtixForge installer on the desktop. Boot into a graphical environment, then double‑click the installer icon. |
| Installer | Boots directly into the ArtixForge TUI. No desktop, no extra packages. Minimal and fast. |

After choosing the boot mode, you can either:

- **Pick a Quick Profile** – Desktop, Server, Minimal, Embedded, Gaming, Development, Media, or Volk's Personal.
- **Customise everything** – Same detailed configuration as a normal installation.
- **Load a saved profile** – Reuse a configuration from a previous installation.

You can also add extra packages to the ISO and choose **Offline ISO** to bundle all packages
so the installer can run without an internet connection.

The built ISO will be placed in `~/ArtixForge-ISO/` along with a build log.
You can burn it to a USB stick or boot it in a virtual machine.

**GUI ISO Builder:** includes a file browser for loading saved profiles and a target system configuration page for offline builds.

---

## 19. System Migration (Convert init, desktop, or Arch Linux)

If you already have Artix installed and want to change your init system or desktop environment
**without reinstalling**, select **System Migration** from the main menu (run from a live ISO
or from within the installed system).

### Init Migration

Convert between OpenRC, runit, dinit, s6, and even systemd (if you have Arch repos enabled).

The migration will:

- Back up your current init configuration to `/root/init-backup-*`
- Detect all enabled services and map them to the new init system
- Handle custom (non‑package) services by saving them separately
- Install the new init packages and enable the appropriate services

Not all service names are identical across init systems. ArtixForge includes mapping tables
for common services; for less common ones, you will receive a warning and the service will
need to be migrated manually.

### Desktop Migration

Convert between any of the supported desktop environments and window managers.

The migration will:

- Back up your user configurations (`~/.config`, `~/.local`, `~/.cache`)
- Remove the old desktop packages
- Install the new desktop and its recommended packages
- Optionally change the display manager, display stack, audio stack, and network stack
- Preserve or reinstall your selected extra packages

After migration, reboot to start the new environment.

**GUI Migration:** the current init system and desktop environment are auto‑detected and displayed
when you open the migration hub. Desktop migration includes sub‑categories for display manager,
display stack, audio stack, network stack, and extra package selection — all in the same hub layout.

### ATA (Arch to Artix) — Experimental

Convert an existing Arch Linux installation to Artix Linux without reinstalling.

**This feature is experimental.** Make a full system backup before proceeding.

The migration will:

- Audit your entire system (packages, services, users, configs, credentials)
- Back up everything to `/arch-migration-backup-YYYYMMDD-HHMMSS/`
- Convert systemd-specific components:
  - Services → init-specific equivalents
  - Timers → cron jobs (OnCalendar and basic monotonic)
  - PAM modules (`pam_systemd.so` → `pam_elogind.so`)
  - mkinitcpio hooks (`systemd` → `udev`, `sd-encrypt` → `encrypt`)
  - DNS resolver (stub replaced)
  - pacman hooks (systemd-dependent ones quarantined)
  - crypttab entries → kernel command line parameters
  - systemd-boot → GRUB (auto-install)
  - systemd-homed users → standard `/home` users
  - systemd `--user` services → XDG autostart entries
- Preserve and restore:
  - All user files and home directories
  - WiFi passwords and network configurations
  - SSH keys and host configs
  - Firewall rules and cron jobs
  - Flatpaks, AppImages, and Docker containers
- Reinstall all packages from Artix repositories
- Reinstall your desktop environment from Artix repos
- Attempt batch reinstall of AUR packages with your chosen helper
- Rebuild DKMS modules and initramfs

**What does NOT migrate automatically:**

- Snap packages (require systemd — will not function on Artix)
- Complex monotonic systemd timers (best-effort loop script used)
- Custom systemd unit files (backed up, not converted)
- systemd-networkd configurations (backed up, manual NM/ConnMan conversion)

After migration, reboot to start Artix. AUR packages that failed to reinstall
are listed in the backup directory for manual follow-up.

---

## 20. Sanity Warnings

Before the installation begins, the installer will warn you about potentially unsafe choices, such as:

- No fallback kernel when building your own
- No desktop environment selected
- Non‑GNU coreutils
- BusyBox init
- No privilege escalation tool
- Offline mode

Read these warnings carefully – they exist because the combination you chose may require manual intervention after installation.

---

## 21. Recovery Mode

If your system fails to boot or behaves unexpectedly, ArtixForge can help.
Boot the live ISO, mount your root partition to `/mnt`, and select
**Recovery** from the main menu.

Recovery will automatically detect your system's configuration:

- Init system, filesystem, bootloader, kernel, desktop environment
- Display manager, network stack, audio stack, coreutils
- Whether LUKS, LVM, UKI, or Power User mode were used
- Broken fstab entries, missing kernels, stale pacman locks
- Packages with missing or corrupted files

You can then choose:

| Option | What it does |
|--------|-------------|
| View system status | Display the full detection report |
| Repair detected issues | Surgically fix only what's broken (fstab, pacman, boot, kernel) |
| Fix everything (nuclear) | Rebuild fstab, reinstall base packages, reinstall kernel, regenerate initramfs and GRUB — everything at once |
| Scan for rootkits | Run rkhunter against the installation |
| Full reinstall | Continue with a fresh installation |
| Repair filesystem corruption | Check and optionally repair the root filesystem (safe or destructive) |
| Untrusted Recovery | Rootkit scan, malware indicator check, optional ClamAV |

After installation, you can also run `anvil recovery` from the installed
system to check and repair source‑built packages.

**Filesystem repair** will unmount your root partition and run filesystem-specific
tools. Choose "Safe" for a non‑destructive check; "Destructive" to attempt aggressive
repairs that may discard corrupted data. Always back up first.

**Untrusted Recovery** is a read-only threat scan. It does not modify anything,
but the scans themselves may trigger anti-malware alerts on a running system.

---

## 22. GUI Installer Notes

The GUI installer presents a **two‑pane hub**: categories on the left, editable settings on the
right, and action buttons (Quick Profile, View Summary, Proceed) at the bottom. This is the same
layout as the TUI — every option available in the terminal is also available in the GUI.

Key features of the GUI:

- **Dynamic extras search** — the Extras category opens a searchable dialog populated from the
  full `world` and `galaxy` package repositories. You can filter and select any available package.
- **Searchable timezone, locale, and keyboard layout** — each field provides a dropdown with
  type‑to‑search, populated from system data (`/usr/share/zoneinfo`, `/etc/locale.gen`, keymaps).
- **TKG kernel configuration** — when `tkg` is selected as the kernel, a TKG Configuration page
  becomes available with scheduler, build type, compiler, optimisation, patches, and CPU count.
- **Quick profiles with confirmation** — selecting a profile shows a preview of all settings
  before applying, so you can review what will change.
- **Kernel hardware configuration** — a tabbed notebook with checklists for GPU, Network,
  Filesystems, Sound, USB, Security, Virtualization, and Debugging, plus preemption model,
  timer frequency, and CPU governor.
- **User manager** — add, edit, and remove user accounts with username, password, shell,
  group memberships, and sudo access, all through a dedicated dialog.
- **Theme preview** — a coloured swatch updates live when you change the title and accent colours.
- **Recovery with live status** — the recovery hub shows detected system state and offers a
  refresh button to re‑scan the installation.
- **Migration auto‑detection** — init and desktop migration hubs automatically detect the
  current system and pre‑fill the source fields.
- **ISO offline target config** — when building an offline ISO with a live desktop, a second
  hub appears to configure the target system's packages.
- **Conditional visibility** — settings like swap size and BTRFS layout only appear when their
  parent option (swap enabled, btrfs filesystem) is active.

After clicking **Proceed** (or **Install** on the summary page), the GUI saves your configuration
and starts the non‑interactive backend. A progress window displays live logs from the installation
with a pulsing progress bar that fills as each stage completes.

Passwords are hashed before being saved to the configuration file. The GUI supports five colour
themes (ArtixForge, Artix, Jet Black, Mono, Retro) with light/dark backgrounds, applied to the
entire window including buttons, dropdowns, and tabs.

You can cancel the installation from the progress window. If you do, the system will not be
modified. You can run the installer again and choose **Resume** to continue from where it stopped.

---

## Common Questions

**Will this erase my other operating systems?**
Only if you choose the wrong disk. The installer wipes the entire disk you select, so be sure it’s the right one.

**Can I dual‑boot?**
Yes. Use Manual mode, create partitions for Artix alongside your existing OS, and GRUB will usually detect other systems automatically.

**What if the installer stops or crashes?**
Reboot, start the installer again, and pick **Resume** from the main menu. It will continue from the last completed stage.

**Does the GUI work in a virtual machine?**
Yes, if the VM has graphics acceleration and a desktop environment. For headless VMs, use the TUI.

**Can I create multiple user accounts?**
Yes. The installer lets you add, edit, and remove users with custom groups, shells, and sudo access. At least one user is required.

**Where can I get help?**
Open an issue on [GitHub](https://github.com/realvolk/ArtixForge/issues) or visit the Artix community forums.

---

## Quick Reference

| If you want… | Consider… |
|--------------|-----------|
| A simple, stable desktop | Automatic, ext4, GRUB, linux, KDE, NetworkManager, PipeWire, sudo |
| A snappy gaming machine | As above + linux-zen or linux-cachyos-* |
| A lightweight laptop | XFCE or LXQt, linux-lts |
| A headless server | No desktop, dhcpcd+iwd, ext4, doas, possibly LVM |
| A minimal, embedded system | Power User, BusyBox init, linux-lts, BusyBox coreutils |
| Total customisation | Power User, build your own kernel, choose every component yourself |
| A personalised live ISO | Build ISO mode, pick a Quick Profile, enable offline mode |

---

Remember: the best choice is the one that fits *your* needs. This guide is here to explain, not to prescribe. If something goes wrong, the community is here to help.