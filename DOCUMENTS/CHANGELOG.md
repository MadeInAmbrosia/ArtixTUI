# Changelog

## v8.2.0.0 (2026-05-28) — ArtixForge

### Added
- BTRFS snapshot integration with snapper + GRUB boot menu entries via `grub-btrfs`
- Snapper timeline and cleanup services enabled automatically for BTRFS installs
- `gartix checksum <recipe>` command for generating SHA256 hashes from upstream sources
- SKIP checksum warning in builder with user confirmation prompt
- Categorized extras: System Tools, Editors, Browsers, File Managers, Terminals, Shell & Prompt, Monitoring, Media
- 18 new extra packages: nano, vim, neovim, micro, helix, firefox, chromium, qutebrowser, ranger, lf, nnn, thunar, alacritty, kitty, foot, mpv, feh
- DNS lookup fallback in network connectivity check (dig/nslookup before curl/ping)
- vxwm window manager support (dwm fork with modules, compiled from source)
- Volk's Personal Quick Profile (dinit, KDE minimal, LightDM, source-built kernel)
- LightDM support for KDE Plasma with automatic SDDM replacement
- Recovery repair system: automatic fstab regeneration, pacman lock removal, base package reinstall, kernel reinstall, initramfs rebuild, and GRUB EFI entry repair
- Rootkit scanning via rkhunter in Recovery mode

### Changed
- Replaced `ufw` with `firewalld` across all profiles, extras, and sanity warnings
- ZFS services now use `enable_service` for init-agnostic configuration
- Project renamed to ArtixForge — installer paths, config files, and documentation updated
- Community recipes repository renamed to `ArtixForge-recipes`
- Desktop Quick Install profile now includes firefox, neovim, and alacritty
- Recovery mode now detects LVM, ZFS, UKI, coreutils, Power User state, privilege escalation, install progress, fstab health, boot health, and pacman integrity

### Fixed
- XFS bigtime check in post.sh now runs inside chroot with correct variable escaping
- `enable_service` used consistently for ZFS and snapper across all init systems
- KDE Plasma with LightDM no longer leaves SDDM installed as a conflicting dependency

## v8.1.1.0 (2026-05-27)

### Added
- Community recipe system: `ArtixTUI-recipes` repository with 31 recipes across OFFICIAL/Base, OFFICIAL/Other, and COMMUNITY sections
- `gartix` can fetch individual recipes, sync all enabled sections, and manage section preferences
- `.LIST` index format for recipe discovery (`pkgname|section|description`)
- Power User mode auto-fetches OFFICIAL/Base recipes on first run when the recipes directory is empty
- Recipe section selector in installer TUI (OFFICIAL/Base, OFFICIAL/Other, COMMUNITY/Base, COMMUNITY/Other)
- 20 new OFFICIAL/Other recipes: browsers, media tools, Wayland compositors, development tools, system tools, gaming, libraries, network/security, terminal
- `gartix` section management via CLI (`gartix sections`) and TUI ("Manage recipe sections")
- `gartix` recipe fetch via CLI (`gartix fetch-recipe <name>`) and TUI ("Fetch a recipe from repo")
- `ArtixTUI-recipes` repository with VERSION file and contribution structure

### Changed
- `poweruser/recipes/` now ships only `template.sh` — all other recipes moved to community repo
- `stage_poweruser` auto-downloads OFFICIAL/Base recipes when the local recipe directory is empty
- `gartix sync` now pulls `.LIST` and offers to update all enabled recipes
- `gartix fetch-all` respects enabled section filtering
- `list_recipes()` unchanged — automatically picks up downloaded recipes

### Fixed
- `gartix` theme colours now load from `/etc/gartix-theme.conf` correctly

## v8.0.2.4 (2026-05-26)

### Added
- Colour theme system with five presets: Gentoo (default), Artix, Jet Black, Mono, Retro
- Theme preview with keep/change loop during installation
- Theme persistence: saved to `/etc/gartix-theme.conf` and loaded by `gartix` on startup
- ANSI colour mapping for `log_info` and `log_warn` so log output follows the chosen theme
- `summary.sh` labels now use theme colours
- `gartix` inherits the installer's theme automatically

### Fixed
- Quick install summary now displays proper newlines instead of raw `\n`
- Removed duplicate summary display when using Quick Install profiles
- `check_disk_space` typo in preflight.sh corrected

## v8.0.1.9 (2026-05-26)

### Added
- Resilience helpers: `check_disk_space`, `retry_command`, `clean_pacman_lock`, `curl_resume` added to both `scripts/common.sh` and `poweruser/lib/common.sh`
- Disk space checks at critical stages: preflight (3GB), base (5GB), poweruser (10GB)
- Pacman lock recovery before every `pacman -S` call in basestrap, drivers, and desktop installs
- Retry with exponential backoff for pacman installs in drivers.sh and desktop.sh
- Mid‑build resume for Power User recipes via `ARTIX_RESUME_BUILD` flag — preserves work directory on retry
- Resume partial downloads via `curl_resume` in builder.bash `fetch_sources()`
- Enhanced `stage_validate()` in state.sh with real success indicators for base, poweruser, and chroot stages
- VirtIO block driver (`virtio_blk`) added to initramfs MODULES for QEMU/VirtIO VM support
- VFAT/FAT32 kernel module loading: `modprobe fat` first, then `vfat`, with `/proc/filesystems` fallback
- EFI partition check now accepts both `vfat` and `fat32` filesystem labels
- Added a PRIVACY_POLICY.md
- Moved all non-essential documentation for the installer into DOCUMENTS

### Fixed
- Stale UKI state: `state.conf` wiped before fresh auto/manual installs to prevent leaking `GENERATE_UKI=yes` between runs

## v8.0.1.4 (2026-05-24)

### Fixed
- Quick Install profiles now fully define all system variables instead of relying on defaults
- Quick Install profiles now ask for hostname, timezone, locale, keymap, username, and passwords
- Added "Customize" option after Quick Install confirmation to drop into full manual flow
- Desktop profile now uses xlibre (Artix default) instead of X.Org
- UKI preset now dynamically detects installed kernel instead of hardcoding `vmlinuz-linux-custom`
- Quick Install profiles now always run disk selection before proceeding
- Preflight: added `pacman -Sy` before package installation to prevent mirror sync issues
- `state_get`: now returns default value when stored value is empty, not just unset
- `bootloader.sh`: removed duplicate `fi` causing syntax error

## v8.0.1.1 (2026-05-24)

### Fixed
- UKI preset now dynamically detects installed kernel instead of hardcoding `vmlinuz-linux-custom`
- Quick Install profiles now always run disk selection before proceeding

## v8.0.1.0 (2026-05-23)

### Fixed
- UKI reworked as independent toggle alongside any bootloader, not a standalone option
- Removed `uki` from bootloader case in basestrap.sh
- Added `GENERATE_UKI` to state.sh, summary.sh, and handoff.sh
- Removed duplicate v8 variables from handoff.sh config block

## v8.0.0.1 (2026-05-23)

### Fixed
- state.sh: restored missing `stage_validate()` function header lost during v8 merge
- Added missing documentation files: GUIDE.md, CHANGELOG.md, SECURITY.md, OSI.md

## v8.0.0.0 (2026-05-23)

### Added
- UKI (Unified Kernel Image) boot support
- LVM (Logical Volume Management) with LUKS integration
- Swappable coreutils: GNU, BusyBox, uutils, ArtixTUI minimal, Custom
- BusyBox init system (fifth init option, Power User only)
- Quick Install profiles: Desktop, Server, Minimal, Embedded
- Network pre-configuration in require_internet()
- Custom mirror ranking via rankmirrors
- Offline source bootstrap (`gartix fetch-all`)
- UKI Secure Boot signing
- Fallback kernel toggle (keep or skip binary kernel in Power User mode)
- Binary kernel recovery option when source build fails
- Sanity warnings for dangerous feature combinations
- Installation guide (GUIDE.md)

### Changed
- Kernel recipe now starts from allnoconfig, enabling only selected hardware
- Kernel recipe ensures root filesystem driver is built-in
- Kernel recipe adds NVMe and VirtIO block to boot essentials
- gartix upgrade now versions and backs up recipes before pulling
- init system validation in chroot stage tolerates BusyBox
- Preflight installs kernel build tools when Power User mode is active
- Post-build validation checks UKI and LVM configurations
- State persistence includes all v8 variables

### Fixed
- users.sh heredoc quoting for password hashes
- builder.bash copy-to-target race condition with sync+sleep

## v7.2.0.0 (2026-05-15)

### Added
- Power User Mode: source-based package compilation
- gartix package manager (CLI + TUI)
- Hardware auto-detection for kernel configuration
- Feature flags per package
- Compilation profiles with custom flag tweaking
- Build queue with resume and error recovery
- doas as alternative to sudo
- Filesystem best practices (XFS GRUB-safe, F2FS compression, SSD discard)
- Gentoo-wiki-inspired filesystem hardening
- Tabbed TUI (gum-based)
- Recipe system (create, edit, lint, build)
- Post-build system validation
- Live build log viewer
- Binary cache and rebuild detection

## v7.1.5.0 and earlier

- Initial public release
- Basic TUI installer with gum
- Core installation pipeline (partition, format, basestrap, chroot, post)
- Multiple kernel, filesystem, desktop, and bootloader support
- LUKS encryption
- Recovery and resume modes