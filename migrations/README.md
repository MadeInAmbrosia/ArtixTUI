# System Migration

In-place migration of init systems and desktop environments for Artix Linux.

---

## Usage

From the ArtixForge installer main menu, select **System Migration**, then choose the migration type.

---

# Init Systems

All 16 init system combinations are supported. Each pair maps known services between init systems and preserves custom services for manual review.

| Source | Target | Method |
|----------|----------|----------|
| openrc | dinit | Direct |
| openrc | runit | Direct |
| openrc | s6 | Direct |
| dinit | openrc | Direct |
| runit | openrc | Direct |
| s6 | openrc | Direct |
| systemd | openrc | Direct |
| dinit | runit | Hub (via OpenRC) |
| dinit | s6 | Hub (via OpenRC) |
| runit | dinit | Hub (via OpenRC) |
| runit | s6 | Hub (via OpenRC) |
| s6 | dinit | Hub (via OpenRC) |
| s6 | runit | Hub (via OpenRC) |

> **Hub Pattern:**  
> Non-OpenRC migrations are performed through OpenRC automatically. This eliminates the need for dedicated migration scripts for every possible init pair.

---

## What Gets Migrated

- Full removal of the current desktop environment
- Full installation of the target desktop environment
- Display manager selection:
  - SDDM
  - LightDM
  - None
- Display stack selection:
  - xlibre
  - Xorg
  - Wayland
- Audio stack selection:
  - PipeWire
  - PulseAudio
  - None
- Network stack selection:
  - NetworkManager
  - dhcpcd + iwd
  - ConnMan
  - None
- Extra packages (optional checklist):
  - git, flatpak, fastfetch, firewalld, bluez, zram-tools
  - fzf, zoxide, starship, eza, btop, htop, nvtop, tmux
  - nano, vim, neovim, micro, helix
  - firefox, chromium, qutebrowser
  - ranger, lf, nnn, thunar
  - alacritty, kitty, foot
  - mpv, feh

All display manager, network, and audio packages are installed with the
correct init-specific suffixes (e.g. `sddm-dinit`, `networkmanager-openrc`).

---

## What Does NOT Get Migrated

- Custom services not owned by any package
  - Backed up to `/root/init-backup-*/`
- One-shot scripts
- User-created runit service directories
- User-created dinit service definitions
- User-created s6 service directories

---

# Desktop Environments

All supported desktop environments and window managers can be migrated in any direction.

Migration is handled by four generic scripts:

| Script | Purpose |
|----------|----------|
| `any-to.sh` | Detect current desktop and prompt for target |
| `none-to.sh` | Install a desktop environment on a headless system |
| `any-to-none.sh` | Remove all desktop packages |
| `common.sh` | Generic fallback for any migration pair |

---

## What Gets Backed Up

For all local users:

- `~/.config`
- `~/.local`
- `~/.cache`

System configuration:

- `/etc/sddm.conf.d`
- `/etc/lightdm`
- `/etc/X11/xorg.conf.d`
- `/etc/NetworkManager`
- `/etc/iwd`
- `/etc/dhcpcd.conf`
---

# Warnings

## Init Migration

- A reboot is required after migration.
- If the system fails to boot:
  1. Select the previous kernel from your bootloader.
  2. Reinstall the previous init system.

## Desktop Migration

- Running a migration from an active X11 or Wayland session may cause instability.
- It is strongly recommended to perform migrations from:
  - A TTY
  - The Artix live ISO

# Migration Scripts

All pair-specific migration scripts follow the same pattern. 
Generic scripts (any-to.sh, none-to.sh, any-to-none.sh) detect the
current desktop environment automatically and prompt for the target.

To add a new desktop environment or window manager:

1. Add its package list to DE_PACKAGES in common.sh

2. Add its default display manager to DE_DISPLAY_MANAGER in common.sh

3. Create a pair script if a direct migration path is desired (optional)

4. The generic scripts handle all other combinations automatically


## Custom Services

- Custom services always require manual review after migration.

## Backups

- Backups are stored under `/root/` with timestamps.
- Backups are **not restored automatically**.
- Manual restoration is required if needed.

---

## Summary

### Init Migration

- Supports all 16 init system combinations
- Preserves known services with automatic mapping
- Backs up unsupported custom services
- Uses an OpenRC hub model for non-direct conversions

### Desktop Migration

- Supports migration between any of the 13 supported desktop environments and window managers
- Preserves user configuration through automatic backups
- Allows interactive selection of display manager, display stack, audio stack, and network stack
- Allows optional selection of extra packages to install
- All packages are installed with correct init-specific suffixes
- Supports installation, replacement, or complete removal of graphical environments

