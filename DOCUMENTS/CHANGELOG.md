# Changelog

## v8.5.0.0 (2026-06-05) — ArtixForge

### Added
- System Migration: init system conversion between all 16 combinations (openrc, runit, dinit, s6, systemd)
- System Migration: automatic service mapping with hub-chaining through OpenRC for non-direct pairs
- System Migration: custom service detection and backup to `/root/init-backup-*/`
- System Migration: desktop environment migration for all 13 supported DEs/WMs
- System Migration: interactive prompts for display manager, display stack, and audio stack during DE migration
- System Migration: user config backup (~/.config, ~/.local, ~/.cache) during DE migration
- New `migrations/` module structure: `inits/` and `des/` with shared `common.sh` libraries
- System Migration entry in main installer menu

## v8.4.4.1 (2026-06-04) — ArtixForge

### Fixed
- Manual mode: disk selection now runs before partitioning — fixes "No disk selected" crash when choosing Manual installation mode
- Manual mode: user can now specify which partitions to use after manual partitioning — EFI, root, and swap partitions are prompted and stored
- `create_filesystems` and `mount_filesystems` now use manually-specified partitions when available, falling back to automatic numbering

## v8.4.4.0 (2026-06-03) — ArtixForge

### Fixed
- LUKS: `crypt_uuid` validation now verifies the UUID points to an actual `crypto_LUKS` partition — auto-corrects if the wrong UUID was derived, preventing "device not found" at boot

## v8.4.3.10 (2026-06-03) — ArtixForge

### Fixed
- UKI: `mkdir` for output directory now runs inside chroot before `ukify build` — fixes "No such file or directory" when ESP isn't mounted yet
- UKI: `efibootmgr --create` failure downgraded from `die` to `log_warn` — UKI generation completes even when EFI entry creation fails (recovery context)
- Initramfs: `sed` hook injection now anchored to `^HOOKS=` — only modifies the active HOOKS line, not commented examples in `mkinitcpio.conf`
- LUKS: `get_luks_raw_uuid` now walks the full device chain up to the raw partition — correctly resolves LUKS partition UUID for `cryptdevice=` even through LVM layers

## v8.4.3.9 (2026-06-03) — ArtixForge

### Fixed
- Recovery: `detect_luks` now walks the full device mapper chain — correctly detects LUKS even under LVM layers
- Recovery: `repair_uki` checks for UKI directory existence before scanning — fixes crash when `/boot/efi/EFI/Linux` doesn't exist

## v8.4.3.8 (2026-06-03) — ArtixForge

### Fixed
- Recovery: `recovery_mount_all()` now copies `/etc/resolv.conf` into chroot — pacman can resolve mirrors
- Recovery: `repair_pacman` checks chroot functionality before attempting repairs — skips gracefully instead of crashing
- Recovery: `detect_pacman_health` pipeline now tolerates pacman failures with `|| true` — detection completes even if pacman database is broken
- Recovery: `repair_pacman` base reinstall failure downgraded from `die` to `log_warn` — recovery continues with other repairs

## v8.4.3.6 (2026-06-03) — ArtixForge

### Added
- Recovery: `recovery_mount_all()` — auto-detects LUKS containers, prompts for unlock, activates LVM, mounts root/ESP, and bind-mounts virtual filesystems
- Recovery: `detect_boot_health` now checks for missing `cryptdevice=` in bootloader config and missing `encrypt` hook in `mkinitcpio.conf`
- Recovery: `repair_boot` can now regenerate bootloader config with correct `cryptdevice=` and re-add the `encrypt` hook to `mkinitcpio.conf` for all four bootloaders

## v8.4.3.5 (2026-06-03) — ArtixForge

### Fixed
- LUKS: mapper name now dynamic (`cryptlvm` with LVM, `cryptroot` without) – fixes boot when LUKS is used without LVM
- LUKS: `crypt_uuid` correctly derived for LUKS‑only setups (previously only worked with LVM)
- GRUB: `cryptdevice=` and correct `root=` now injected into `GRUB_CMDLINE_LINUX` when LUKS is active
- rEFInd: full kernel cmdline with `cryptdevice` and appropriate root written to `refind_linux.conf`
- EFIStub: cmdline rebuilt dynamically for LUKS/LVM combinations
- Limine: cmdline rebuilt dynamically for LUKS/LVM combinations
- UKI: cmdline now built dynamically instead of hardcoded; `cryptdevice=` only appended when LUKS enabled
- Bootloader: `grub-install` and `grub-mkconfig` wrapped with `xtrace_safe` to suppress debug fd leak noise

## v8.4.3.4 (2026-06-03) — ArtixForge

### Fixed
- LUKS+LVM: `encrypt` hook now added to `mkinitcpio.conf` when LUKS is enabled — `cryptsetup` now available in initramfs to unlock LUKS containers at boot
- LUKS+LVM: `crypt_uuid` now resolved from the underlying physical partition instead of the LV — `cryptdevice=` cmdline gets the correct UUID
- LUKS+LVM: EFIStub boot entry now includes `cryptdevice=` and `root=/dev/vg0/root` when LUKS/LVM are active
- Secure Boot: missing signing keys now log a warning instead of `die` — UKI generation completes without signing

## v8.4.3.2 (2026-06-03) — ArtixForge

### Fixed
- UKI: generation block moved after ESP detection — `esp_mount` and `root_uuid` now available when `ukify build` runs
- UKI: output path now uses `${esp_mount#/mnt}` to derive correct chroot path — fixes "No such file or directory" when `ukify` writes inside the chroot
- UKI: signing paths also use `${esp_mount}` — consistent with generated UKI location
- UKI: `mkdir` for output directory now runs inside the chroot via `artix-chroot /mnt mkdir -p`

## v8.4.3.0 (2026-06-03) — ArtixForge

### Changed
- Recovery: kernel detection now covers all nine supported kernels (linux, zen, lts, hardened, libre, cachyos-bore, bazzite, xanmod, tkg) plus custom Power User kernels
- Recovery: bootloader detection expanded to include Limine and rEFInd alongside GRUB and EFIStub
- Recovery: `repair_boot` now reinstalls the correct kernel package for any detected kernel variant
- Recovery: `repair_boot` can now reinstall Limine and rEFInd bootloaders, not just GRUB
- Recovery: install stage detection now reports Limine, rEFInd, and UKI presence
- Recovery: boot health check now detects missing UKI files and reports `no-uki`
- Recovery: `repair_uki` regenerates missing UKIs via `ukify build` when `eukify` is installed

### Fixed
- UKI: `ukify` binary now checked directly via `[[ -x /mnt/usr/bin/ukify ]]` instead of `command -v` in chroot — fixes false negative when `ukify` is installed but not found via `command -v`

## v8.4.2.5 (2026-06-03) — ArtixForge

### Fixed
- Debug mode: `xtrace_safe()` wrapper added to `common.sh` — prevents `BASH_XTRACEFD` from leaking into LVM tools and `basestrap`
- Debug mode: LVM `*create` commands and `basestrap` now wrapped with `xtrace_safe`; `mkfs` and `cryptsetup` left unwrapped for user visibility
- LVM: `pvcreate -ff` now used — suppresses "existing filesystem signature" prompt
- LVM/LUKS: stale device mapper entries and LVM volumes deactivated before disk wipe; mapper existence check added after `luksOpen`
- LVM/LUKS: `wipefs` on root partition skipped when LUKS is active — prevents destroying the LUKS header
- Partitioning: `blockdev --rereadpt` added after `partprobe` — forces kernel to reload partition table
- Limine: `limine.conf` now written to ESP (`${esp_mount}/limine.conf`) — Limine finds its config on the EFI partition
- UKI: replaced broken `uki` mkinitcpio hook with `eukify` (provides `ukify` binary) from Artix system repo — no systemd required
- UKI: removed mkinitcpio preset and hook injection; UKI generated directly via `ukify build` after initramfs creation
- UKI: Secure Boot signing restored with `sbsign` — signed UKI gets separate EFI boot entry
- UKI: all failures now hard `die` — UKI is all-or-nothing when requested

## v8.4.2.4 (2026-06-03) — ArtixForge

### Fixed
- Preflight: mirrorlist backup (`.orig`) now created unconditionally before ranking — retry always has a known-good fallback regardless of user choices
- Preflight: empty `rankmirrors` output now detected and discarded — prevents overwriting mirrorlist with nothing
- Preflight: `pacman -Sy` failure after ranking no longer silently swallowed — logged as warning, retry will attempt with original mirrors

## v8.4.2.3 (2026-06-02) — ArtixForge

### Fixed
- ZFS preflight: plain `linux` live ISO now allowed to install ZFS for `linux-zen` target — kernel ABI is compatible
- ZFS preflight: `mirrorlist_backup` variable now declared at function scope — fixes "unbound variable" crash when mirror ranking is skipped
- ZFS preflight: package install retry no longer uses nested `local` declarations that could trip `set -u`
- LVM: root partition disk-belonging check now skipped when LVM is active — logical volumes don't have a direct disk parent

## v8.4.2.2 (2026-06-02) — ArtixForge

### Changed
- Updated the README.md (Less of a clusterf...)

## v8.4.2.1 (2026-06-02) — ArtixForge

### Fixed
- Bootloader: `findmnt` Btrfs subvolume suffix (`/dev/sda3[/@]`) now stripped before block device checks — fixes "invalid root block device" crash on Btrfs installs
- Bootloader: `set -Eeuo pipefail` restored — was accidentally removed, errors now fail early instead of cascading silently
- Bootloader: rEFInd root device detection now also strips Btrfs subvolume suffix
- Bootloader: removed duplicate UKI existence check that ran before `esp_mount` was set — fixes undefined variable and false negative on UKI file detection
- UKI: `sed` hook injection no longer depends on line-start anchor — works with any `mkinitcpio.conf` formatting
- UKI: missing UKI file after `mkinitcpio -P` now triggers `die` instead of silent warning
- UKI: failed hook injection now triggers `die` — no point continuing if the `uki` hook can't be added to `mkinitcpio.conf`
- Basestrap: `BASH_XTRACEFD` now unset before `basestrap` call — prevents "invalid value for trace file descriptor" errors in post-transaction hooks

## v8.4.2.0 (2026-06-01) — ArtixForge

### Added
- Limine bootloader support — BTRFS snapshot boot entries, Windows chainloading, LUKS/LVM-aware kernel cmdline
- `limine-snapper-sync` automatically installed when BTRFS snapshot layout is selected with Limine

## v8.4.1.1 (2026-06-01) — ArtixForge

### Fixed
- Recovery mode: `detect_pacman_health` now saves the actual broken package list during detection — `repair_pacman` no longer re-detects and comes up empty
- Recovery mode: broken package reinstall uses `pacman --root /mnt` with `--overwrite '*'` in batches of 20 — avoids basestrap dependency failures on large reinstalls
- Recovery mode: broken package reinstall falls back to individual package installs for any batch that fails

## v8.4.1.0 (2026-06-01) — ArtixForge

### Added
- Recovery mode: "Repair filesystem corruption" — safe (`fsck -p`, `xfs_repair -n`, `btrfs check`) and destructive (`fsck -f -y`, `xfs_repair`, `btrfs check --repair`) options for ext4/xfs/btrfs
- Recovery mode: "Untrusted Recovery" — rootkit scan, malware indicator detection (suspicious cron, SUID binaries, SSH keys), optional ClamAV scan; read-only, no modifications

### Fixed
- Recovery mode: `detect_disk` now unwraps LUKS/LVM mappers, walks the device chain to find the physical disk, and falls back to fstab UUID or manual selection — fixes "Invalid disk device" after recovery reset
- Recovery mode: `repair_pacman` now actually reinstalls packages with missing files instead of just warning about them
- Recovery mode: `repair_detected_issues` only runs mkinitcpio and grub-mkconfig when boot or fstab issues were actually fixed — no more mindless initramfs rebuild on every recovery
- Recovery mode: added "Fix everything (nuclear)" option alongside the surgical "Repair detected issues"
- Builder: `BASE_DIR` fallback added so "Update ArtixForge and retry" correctly calls `${BASE_DIR}/install` instead of failing with `./install: command not found`

## v8.4.0.1 (2026-06-01) — ArtixForge

### Fixed
- Generic package install: replaced `cp -a` with `rsync --keep-dirlinks` — prevents symlink collisions on merged-usr systems (`/lib64`, `/sbin`) when installing source-built packages like glibc

## v8.4.0.0 (2026-06-01) — ArtixForge

### Fixed
- Kernel recipe: `VIRTIO_BLK` changed from module to built-in across all config branches — eliminates boot panic when initramfs doesn't load the module before root mount (Volk profile, Power User mode)
- `kconfig.bash`: `VIRTIO_BLK` changed from `--module` to `--enable` in `ensure_boot_essentials()`
- `kconfig.bash`: `DEVTMPFS_MOUNT` added to `ensure_boot_essentials()` — kernel now auto-mounts devtmpfs at boot
- Kernel recipe `localmodconfig` branch now calls `ensure_boot_essentials()` after `make localmodconfig` — live ISO built-in drivers (VIRTIO_BLK, DEVTMPFS, etc.) are no longer silently omitted from the generated config
- Kernel recipe `localmodconfig` branch now applies feature flags (`nvidia-support`, `amd-support`) and resolves dependencies with `yes "" | make oldconfig`
- Kernel recipe: duplicate `scripts/config` calls removed from default config branch
- `bcachefs` added to root filesystem driver case in `localmodconfig` branch
- LUKS+LVM: `luksFormat` now runs before `pvcreate` in `partition.sh` — fixes `pvcreate` failure on missing LUKS mapper
- LUKS (no LVM): `luksFormat` and `luksOpen` added to `filesystem.sh` — plain LUKS installs no longer format the raw partition unencrypted
- LUKS (no LVM): `luksOpen` added to `mount_filesystems()` — root partition correctly mounted from LUKS mapper
- LVM: `filesystem.sh` now creates filesystems on logical volumes instead of overwriting the physical volume
- Volk quick profile: added VM disclaimer — warns users the source-built kernel omits VirtIO drivers and won't boot in virtual machines

### Added
- Recipe self-healing: `heal.bash` auto-detects newer source versions for kernel.org, GitHub releases, and generic directory listings — failed fetches can now self-repair and retry

## v8.3.1.0 (2026-05-30) — ArtixForge

### Fixed
- UKI preset: `ALL_kver` now uses kernel version string instead of file path — mkinitcpio can find modules correctly
- UKI preset: `default_uki` uses generic `artix-linux.efi` instead of hardcoded `linux-custom`
- UKI preset: `uki` hook automatically appended to `mkinitcpio.conf` HOOKS if missing
- UKI EFI boot entry: paths updated from `linux-custom.efi` to `artix-linux.efi`
- EFIStub: kernel and initramfs images detected directly from `/mnt/boot/` instead of reading unset state variables
- CachyOS kernel: mirror scrape failure now falls back to static URLs instead of hard `die`
- Desktop install: `xlibre-input-wacom` added to KDE package array instead of separate install to resolve conflict with `xf86-input-wacom` in same transaction

## v8.3.0.2 (2026-05-30) — ArtixForge

### Fixed
- Power User mode from main menu now correctly sets `POWER_USER=yes` so selecting "Power User" no longer produces a standard install (Whoops...?)
- `verify_installer_layout` updated for new modular directory structure (`scripts/recovery/`, `tui/menus/`, `poweruser/tui/menup/`)
- Custom profile loader now persists all loaded variables to state so now loaded profiles work identically to built-in ones
- Duplicate `KERNEL_CONFIG_DEPTH`, `KEEP_BINARY_KERNEL`, `COREUTILS`, and `KERNEL_IMAGE` lines removed from `handoff.sh` config export
- `gartix` dispatcher and TUI no longer attempt to source nonexistent recovery file, functions are already available

## v8.3.0.0 (2026-05-29) — ArtixForge

### Added
- Three new Quick Install profiles: Gaming, Development, Media
- Custom profile loader — source saved configurations from file
- Quick Profile auto-save to `/etc/artixforge-profile.conf` after installation
- `gartix recovery` command for checking and repairing source-built packages
- `repair_kernel` function in recovery mode — rebuilds custom kernel with latest recipe
- Kernel repair available from build failure menu and `gartix recovery`
- `gartix_recovery.bash` module for post-install package repair

### Changed
- `scripts/tui/menus/` split into 9 focused sub-files
- `poweruser/tui/menu_poweruser.sh` split into 6 sub-files under `menup/`
- `scripts/recovery/` split into `core.sh`, `detect.sh`, `repair.sh`
- `gartix` split into `gartix`, `gartix_common.bash`, `gartix_cli.bash`, `gartix_tui.bash`
- `stage_poweruser` copies all `bin/` files instead of single `gartix` binary
- Kernel config depth defaults to `localmodconfig` in Quick Profiles and "No" path
- Project structure trees updated in README.md and poweruser/README.md

### Fixed
- `stage_validate` poweruser check uses kernel file existence, not `pacman -Q`
- Build timing summary uses `tui_msg_quick` instead of broken `tui_msg`
- Audio install split to avoid KDE `jack2`/`pipewire-jack` conflict
- Kernel recipe VirtIO dependency chain complete (`BLOCK`, `BLK_DEV`, `VIRTIO`, `VIRTIO_PCI`, `VIRTIO_BLK`)

## v8.2.3.4 (2026-05-29) — ArtixForge

### Changed
- Kernel recipe default config method switched to `localmodconfig` — compiles only currently loaded modules, eliminating dependency guessing and `olddefconfig` symbol dropping
- `localmodconfig` added as recommended kernel config depth option in Power User TUI
- `USB_HID` and `VIRTIO_BLK` added as modules to kernel recipe and `kconfig.bash` for initramfs compatibility
- Fallback manual config path uses `yes "" | make oldconfig` to prevent interactive prompts hanging automated builds

### Fixed
- `BLK_DEV` symbol added to kernel recipe dependency chain — `VIRTIO_BLK` was silently dropped without it
- `VIRTIO_PCI` transport added to kernel recipe and `kconfig.bash` `ensure_boot_essentials()`
- Audio package install split — `pipewire-jack` installed separately to avoid KDE `jack2` conflict loop

## v8.2.3.3 (2026-05-28) — ArtixForge

### Fixed
- Power User kernel install bypasses `pacman -U` for `linux-custom`, copying files directly to `/mnt`
- `curl_resume` called with correct argument order in `fetch_sources()`
- SKIP checksum prompt moved outside log redirection — no more invisible prompts stuck in log files
- Broken live-watch `gum pager` removed from build stage; users directed to `tail -f` the log instead
- `POWER_USER` variable added to `state_save()` — Quick Profile Power User state now persists correctly
- `mkinitcpio` added to base package list; no longer missing from minimal installs
- `tui_select_poweruser` checks `POWER_USER` state instead of `MODE` — Quick Profile + Power User works
- Template recipe excluded from `list_recipes()` display
- Gum help text guard added to `tui_poweruser_tweak_profile` to prevent corrupted custom profiles
- `linux.sh` recipe version bumped to 7.0.10 (was 7.0.8 — kernel.org removed the old tarball)
- Recipe auto-fetch runs before Power User config menu — no more empty recipe list on first run
- `tui_poweruser_config` streamlined with Yes/No gate for detailed config vs. auto-detected defaults
- Build timing summary uses `tui_msg_quick` instead of broken `tui_msg` with literal `\n`
- `recoverable_error` function added to `scripts/common.sh` — users can update ArtixForge and retry on critical failures
- `recoverable_error` integrated into `basestrap.sh`, `bootloader.sh`, and `poweruser.sh`
- `stage_poweruser` sources `tui/core.sh` and `scripts/common.sh` for TUI function availability
- Power User kernel recipe install creates `mkinitcpio` preset for `linux-custom`
- `configure_bootloader` validates initramfs by file existence, not `mkinitcpio` exit code — warnings no longer fatal
- ArtixForge self-update available from build failure menu with `exec sudo ./install` restart
- `stage_validate` poweruser check now tests for kernel file existence instead of `pacman -Q` — resume no longer loops on direct-copy installs
- Audio package install uses `--ask=1` to auto-resolve pipewire-jack/jack2 conflicts from KDE dependencies
- Kernel recipe and `kconfig.bash` now enable full VirtIO dependency chain (`VIRTIO`, `VIRTIO_MENU`, `VIRTIO_PCI`, `VIRTIO_BLK`) to prevent `olddefconfig` from silently dropping block driver support

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