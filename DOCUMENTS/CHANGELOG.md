# Changelog

## v8.8.3.2 (2026-06-18) — ArtixForge

### Fixed
- ISO: live ISO state and offline target system state now separated — target config no longer overwrites live environment's kernel/DE selection
- ISO: offline package bundle generated from target system config while live ISO uses its own lightweight config
- ISO: live ISO kernel selection locked to standard Artix kernels (linux, zen, lts, hardened) — no AUR/external kernel builds in the live environment

## v8.8.3.1 (2026-06-18) — ArtixForge

### Fixed
- ISO: offline package download now uses live system's pacman database instead of blank db — packages actually download (hopefully)
- ISO: buildbot signing key now fetched from keyserver before local signing — eliminates spurious key trust warning

## v8.8.3.0 (2026-06-18) — ArtixForge

### Changed
- ISO: builder no longer asks for disk, partitions, users, or passwords — live ISO configuration is now lightweight (DE, init, kernel, network, audio, extras only)
- ISO: bootloader, filesystem-specific, and UKI packages removed from live ISO — leaner image, faster builds
- ISO: user can now choose output directory for the final ISO
- ISO: offline mode target system configuration separated from live ISO config — asks for system packages without disk selection

## v8.8.2.7 (2026-06-18) — ArtixForge

### Fixed
- CachyOS: Intel 12th gen+ CPUs (Alder Lake and newer) now correctly downgraded from v4 to v3 — AVX-512 is fused off on these chips despite being reported as supported (Special thanks to https://github.com/HappyAmper for pointing it out)

## v8.8.2.6 (2026-06-18) — ArtixForge

### Fixed
- TKG: `CONFIG_DM_CRYPT` and `CONFIG_DM_INTEGRITY` enabled after `make defconfig` — LUKS-encrypted root now unlocks correctly with TKG-custom kernels
- mkinitcpio: `lvm2`, `encrypt`, `bcachefs`, and `zfs` hooks now check for existing entry before appending — no more duplicate hook accumulation on resume or re-run

## v8.8.2.5 (2026-06-18) — ArtixForge

### Fixed
- TKG: kernel renamed using modification-time detection — newest `vmlinuz*` always becomes `vmlinuz-artixforge-tkg`, eliminating `vmlinuz.old` edge case
- Limine: kernel glob widened from `vmlinuz-*` to `vmlinuz*` with `nullglob` — no longer dies on non-standard kernel names
- mkinitcpio: `lvm2`, `encrypt`, `bcachefs`, and `zfs` hooks now check for existing entry before appending — no more duplicate hook accumulation on resume or re-run

## v8.8.2.4 (2026-06-18) — ArtixForge

### Fixed
- TKG: mkinitcpio preset uses actual kernel path from `make install` — matches `vmlinuz` without version suffix
- TKG: success check matches `vmlinuz*` without requiring version suffix

## v8.8.2.3 (2026-06-18) — ArtixForge

### Fixed
- TKG: mkinitcpio preset now created after kernel build — `mkinitcpio -P` finds the preset and generates initramfs

## v8.8.2.2 (2026-06-18) — ArtixForge

### Fixed
- Bootloader: `generate_root_cmdline()` now includes `rootflags=subvol=@` for btrfs — fixes "init does not exist" on btrfs installs with Limine
- TKG: failed patches now restore ALL files they touched, not just files with `.rej` — fixes `debug.c`/`sched.h` mismatch from partial PRJC patch application

## v8.8.2.1 (2026-06-18) — ArtixForge

### Changed
- TKG: kernel now compiled inside target chroot instead of live ISO (Another oopsie)

### Fixed
- TKG: failed scheduler patches now restore corrupted files and continue build — kernel compiles with remaining patches
- TKG: user warned which patches failed to apply after successful build

## v8.8.2.0 (2026-06-18) — ArtixForge

### Added
- GUI: non‑interactive backend now supports Recovery, Migration, ISO, and Power User modes — GUI config flows drive the full pipeline
- GUI: password confirmation enforced — mismatched passwords block navigation with warning dialog

### Changed
- GUI: filesystem list updated — exFAT and ZFS removed to match TUI
- GUI: `save_state()` no longer uses `sudo` — installer already runs as root
- Non‑interactive: `tui_password_confirm` reads passwords from state — GUI‑saved credentials used correctly
- Non‑interactive: `tui_password` handles LUKS prompts from saved state

### Fixed
- Non‑interactive: recovery mode reads `RECOVERY_ACTION` from state and executes the correct repair
- Non‑interactive: migration mode reads `MIGRATION_SRC`/`MIGRATION_TGT` from state and runs the correct migration
- Non‑interactive: ISO mode reads profile/init/kernel from state and builds with `build_artix_iso`
- Power User: interactive `tui_poweruser_config` skipped when `GUI_MODE=yes` — GUI config used instead

## v8.8.1.8 (2026-06-18) — ArtixForge

### Fixed
- Basestrap: `/sbin/init` symlink verified after installation — kernel panic from missing init no longer possible
- Recovery: `detect_boot_health` now checks for `/sbin/init` — missing init symlink detected and repairable
- Recovery: `repair_boot` can recreate `/sbin/init` symlink from detected init system

## v8.8.1.7 (2026-06-18) — ArtixForge

### Fixed
- Basestrap: gnupg permissions corrected on target system — `pacman-key --init` no longer required after installing CachyOS/XanMod kernels (Special thanks to https://github.com/etrigan63 for pointing this out)

## v8.8.1.6 (2026-06-18) — ArtixForge

### Fixed
- Extras: `zram-tools` installs `zramen`/`zramen-${init}`, services use `zramen` and `bluetoothd` — correct Artix package names (Special thanks to https://github.com/etrigan63 for pointing this out)
- Limine: kernel and initramfs copied to ESP — `boot():/` paths now resolve correctly, fixes kernel panic on boot

## v8.8.1.5 (2026-06-18) — ArtixForge

### Fixed
- Migrations: `known_services` exclusion list expanded with `logind`, `lightdm`, and all standard openrc boot services — no more false custom service detection

## v8.8.1.4 (2026-06-18) — ArtixForge

### Fixed
- Migrations: `list_enabled_services()` returns empty string when init not installed — no more ANSI escape codes crashing service enumeration
- Migrations: `_install_target_init_fallback()` removes conflicting `cryptsetup-scripts` before installing openrc
- Installer: `installer_error()` now displays last 10 lines of install log and migration debug log — users see actual errors instead of line numbers

## v8.8.1.3 (2026-06-18) — ArtixForge

### Fixed
- Migrations: `detect_custom_services()` excludes known system services — NetworkManager, agetty, bootmisc, and other standard services no longer misdetected as custom scripts
- Migrations: `migrated=$((migrated + 1))` replaces `((migrated++))` — avoids post-increment `set -e` crash in init service migration loop
- Migrations: service-specific init packages installed before service migration — `NetworkManager-runit`, `dhcpcd-runit`, etc. now present when `enable_service` runs

## v8.8.1.2 (2026-06-18) — ArtixForge

### Fixed
- Migrations: `detect_custom_services()` excludes known system services — NetworkManager no longer misdetected as custom script
- Migrations: `((migrated++))` and `((skipped++))` replaced with `migrated=$((migrated + 1))` — avoids post-increment `set -e` issues in init service migration loop

## v8.8.1.1 (2026-06-17) — ArtixForge

### Added
- Migrations: `_repair_pacman_db()` runs at start of `run_de_migration` — detects and repairs broken package database entries before detection
- Migrations: `_cleanup_target_repo()` removes SonicDE repository after migration — `SigLevel = Never` not left permanent ( ͠° ͟ʖ ͡°)

### Fixed
- Migrations: `ROOT` variable conflict resolved — recovery detection now correctly queries target system packages

## v8.8.1.0 (2026-06-17) — ArtixForge

### Changed
- Migrations: `migrations/inits/common.sh` now supports live ISO via `MIG_ROOT` — all system operations route through chroot
- Migrations: init detection uses recovery's `detect_init` instead of manual selection
- Migrations: `_enable_service()` wrapper shared between DE and init migrations
- Migrations: detection functions in `des/common.sh` replaced with wrappers that call recovery's existing `detect_desktop`, `detect_display_manager`, `detect_xstack`, `detect_audio_stack`, `detect_network_stack` (That moment when you forget your own codebase)

## v8.8.0.10 (2026-06-17) — ArtixForge

### Changed
- Migrations: all detection functions refactored to use associative arrays with loops — adding new DEs/DMs/inits is one line
- Migrations: `_prepare_target_repo()` handles external repository setup (SonicDE, Chaotic-AUR) for migrations
- Migrations: live ISO detection uses `-d` instead of `-f` for `/run/artix/sfs/rootfs` directory check

### Fixed
- Migrations: pacman -Qtdq orphan check now guarded with || true — no longer fatal when no orphans exist
- Migrations: tui_de_migration_menu uses tui_msg_quick instead of tui_msg for current DE detection display

## v8.8.0.9 (2026-06-17) — ArtixForge

### Changed
- Migrations: `migrations/des/common.sh` now detects live ISO and routes all system operations through chroot to `/mnt` — migrations work from both live ISO and installed system
- Migrations: `_chroot()` and `_pacman_Q()` helpers added for transparent root path routing
- Migrations: `_enable_service()` wrapper runs service enablement inside target chroot with correct `INIT` exported
- Migrations: `recovery_mount_all()` offered interactively when target not mounted on live ISO

## v8.8.0.8 (2026-06-17) — ArtixForge

### Fixed
- Migrations: `apply_migration_choices` now exports `INIT` before calling `enable_service` — services enabled for correct init system
- Migrations: `mkinitcpio` now runs inside `artix-chroot /mnt` — no longer rebuilds live ISO kernel (FUCK)
- Recovery: `detect_iso_health` skips when not running from live ISO — no more false `missing-artixforge`
- Recovery: menu loop allows multiple repairs, added "Return to main menu" and "Exit" options

## v8.8.0.7 (2026-06-17) — ArtixForge

### Fixed
- Migrations: `enable_service` calls in `apply_migration_choices` now guarded with `|| log_warn` — no longer fatal when service is missing or something else happens for any reason

## v8.8.0.6 (2026-06-17) — ArtixForge

### Fixed
- Migrations: `run_de_migration` now auto-selects target DE's default display manager when migrating from `none` — e.g. lightdm correctly installed for xfce
- Migrations: `tui_de_migration_menu` no longer warns on missing pair scripts — generic `run_de_migration` handles all combos silently

## v8.8.0.5 (2026-06-17) — ArtixForge

### Fixed
- Drivers: CachyOS kernel header detection simplified — removed nonexistent `linux-cachy-headers` fallback

## v8.8.0.4 (2026-06-17) — ArtixForge

### Fixed
- Drivers: VM detection now case-insensitive, adds `vbox` pattern — VirtualBox no longer misdetected as KVM
- Drivers: `enable_service qemu-guest-agent` guarded with `|| log_warn` — no longer fatal when service is missing

## v8.8.0.3 (2026-06-17) — ArtixForge

### Fixed
- Drivers: CachyOS kernel header detection fixed — `linux-cachy*` pattern now matches all variants

## v8.8.0.2 (2026-06-17) — ArtixForge

### Fixed
- Post-install: removed stale `source ./scripts/post/kernel.sh` — file no longer exists, stage no longer fails

## v8.8.0.1 (2026-06-16) — ArtixForge

### Fixed
- CachyOS: `Architecture = x86_64 x86_64_v4` now set globally under `[options]` instead of per-repo — pacman accepts v4 packages

## v8.8.0.0 (2026-06-16) — ArtixForge

The next few patches will include GUI upgrades.

### Added
- ISO: artix-keyring refreshed before `buildiso` call

### Changed
- System: keyboard layout now applied to X11 sessions via `localectl set-x11-keymap` — non-US layouts work in graphical environments
- Post-install: package list deduplicated with `sort -u` before `pacman -S`
- Installer: self-update copies to `/tmp/artix-run` before replacing files
- Filesystems: exFAT removed as root option — no Unix permissions or symlink support
- Kernel: `find_kernel_image()` and `find_initramfs_image()` match `KERNEL_CHOICE` explicitly
- Bootloader: `generate_root_cmdline()` unified across all five bootloaders
- Bootloader: Secure Boot signing paths use chroot-relative paths
- Audio: `setup_audio()` detects and removes conflicting stacks, skips already-installed packages
- Desktop: SonicDE and MangoWM isolated into dedicated functions with trap cleanup
- Drivers: PCI ID validated as hex, VM detection uses CPUID hypervisor bit, Nouveau fallback cleans DKMS
- Networking: detects conflicting stacks, skips already-installed packages
- Recovery: `detect_init` uses binary detection — no more state/runtime mismatch
- Recovery: kernel detection uses tiered priority
- Recovery: `detect_coreutils` verifies BusyBox symlinks before assuming implementation
- Power User: `validate_system()` uses `sort -V` for kernel module directory ordering
- ZFS: service files support all four init systems, mkinitcpio hook appends instead of replacing
- Migrations: DM/network normalisation uses explicit case mapping, init package transformation fixed
- ISO: `BASE_DIR` and installer functions sourced if missing, chroot detection uses multiple fallbacks
- Partitioning: removed unnecessary `dd` wipe, LVM volume group name configurable

### Fixed
- CachyOS: `Architecture = x86_64_v4` added to v4 repo sections
- Recovery: `pacman_root_has` guarded against empty input
- Recovery: `repair_pacman` batch arithmetic fixed
- Recovery: filesystem repair unmounts BTRFS recursively, verifies FS before remount
- Recovery: `/dev/mapper/control` filtered, already-open mappers skipped
- ZFS: preflight installs `zfs-dkms` from archzfs with repo prefix
- ZFS: removed unbound `zfs_pkg` variable in modprobe check
- TKG: `make modules_install INSTALL_MOD_PATH=/mnt` and `make install INSTALL_PATH=/mnt/boot`
- bcachefs: mkinitcpio hook appends instead of replacing
- Bootloader: `find_kernel_image` matches `KERNEL_CHOICE` instead of alphabetical `head -n1`
- Limine: snapshot loop uses `while read` with proper quoting
- Storage: duplicate block-device validation removed
- Storage: LUKS reopen cleans up stale mappers
- Storage: EFIStub mount detection fixed
- Desktop: dead `elif` in KDE profile logic removed
- Desktop: MangoWM AUR build uses trap for cleanup
- Drivers: PCI ID validated, VM detection improved, Nouveau fallback cleans DKMS
- Networking: service enable failures logged
- Migrations: orphan removal checks list first, extras loop builds clean list
- ISO: offline mode skips target configuration for installer ISOs
- ISO: `cleanup.sh` uses explicit `output_dir` fallback
- Power User: kernel module sort fixed

## v8.7.0.8 (2026-06-16) — ArtixForge

### Fixed
- CachyOS: `Architecture = x86_64_v4` added to v4 repo sections — fixes "package architecture is not valid" on v4-capable CPUs

## v8.7.0.7 (2026-06-15) — ArtixForge

### Fixed
- ISO: artix-keyring refreshed before `buildiso` call — prevents "Signature from Artix Buildbot is invalid" error

## v8.7.0.6 (2026-06-15) — ArtixForge

### Fixed
- CachyOS: v3/v4 mirrorlist now downloaded before repo sections added to `pacman.conf` — fixes broken config when mirrorlist package fails (oops...)

## v8.7.0.5 (2026-06-15) — ArtixForge

### Changed
- Filesystems: ZFS temporarily disabled — ZFS max supported kernel is 6.15 (live ISOs ship 6.19 and above!)
- Filesystems: selecting ZFS now shows an "Unavailable" message and returns to selection

## v8.7.0.4 (2026-06-15) — ArtixForge

### Fixed
- ZFS: preflight now installs `zfs-dkms` from archzfs with repo prefix — live ISO kernel rarely matches prebuilt ABI and may ship outdated ZFS
- ZFS: preflight forces `archzfs/zfs-dkms` to override outdated live ISO packages
- ZFS: removed unbound `zfs_pkg` variable in modprobe check — now reports DKMS status on failure

## v8.7.0.3 (2026-06-15) — ArtixForge

### Fixed
- Recovery: `recovery_mount_all()` now detects plain partitions (ext4/btrfs/xfs/f2fs) — no longer requires LUKS or LVM to auto-mount (I FORGOT)
- Recovery: auto-mount falls back to `lsblk` scan when no LUKS/LVM volumes found
- Recovery: `detect_uki` syntax error fixed — missing `; then` after grep condition causing exit 127
- Recovery: UKI missing file no longer flagged as a boot issue — system boots via bootloader
- TUI: kernel sub-menu case patterns fixed — `"linux-* (standard)"` and `"linux-cachyos-*"` now match menu display
- TUI: `tui_filter()` no longer redirects stdin to `/dev/tty` — `gum filter` correctly receives piped package list (oops)
- Extras: `EXTRAS_SAFETY_FILTER` regex fixed — `*` changed to `.*` to silence grep warnings
- ZFS: preflight now installs ZFS module for live kernel instead of target kernel — fixes install failure when target kernel differs from live ISO
- ZFS: removed spurious die when live and target kernels differ — target gets its own ZFS package during basestrap

## v8.7.0.2 (2026-06-15) — ArtixForge

### Added
- Extras: "Search for packages..." — live fuzzy search over Artix `world` and `galaxy` repositories
- Extras: `tui_search_extras()` using `tui_filter` (wraps `gum filter`) for real-time package filtering
- Extras: `EXTRAS_SAFETY_FILTER` excludes DEs, kernels, bootloaders, init services, and system packages from search results
- TUI: `tui_filter()` wrapper added to `scripts/tui/core.sh`

### Changed
- Post-install: `install_extras()` refactored — `SIMPLE` array loop replaces repetitive `[[ ]]` checks; init-specific packages remain explicit
- Post-install: searched packages install as plain `pacman` packages, curated list unchanged

## v8.7.0.1 (2026-06-14) — ArtixForge

### Changed
- Main menu: Recovery, Power User, Migration, and ISO modes moved under "Advanced" sub-menu
- Each advanced mode now shows a clear warning explaining what it does and its risks before proceeding

## v8.7.0.0 (2026-06-14) — ArtixForge

### Added
- Kernels: sub-menu grouping — standard kernels (linux, zen, lts, hardened) under "linux-*" and CachyOS variants under "linux-cachyos-*"
- CachyOS: full variant support — all 9 CachyOS kernels (cachyos, bore, eevdf, bmq, rt-bore, hardened, lts, server, deckify)
- CachyOS: architecture-specific repository tiers — v3 (AVX2) and v4 (AVX512) optimized repos configured based on CPU detection
- Bazzite: kernel now compiled from AUR during basestrap instead of post-install

### Changed
- `basestrap.sh`: atomized — kernel packages, target repos, custom kernel builds, and ZFS config extracted to `scripts/install/basestraps/`
- `bootloader.sh`: atomized — GRUB, Limine, rEFInd, and EFIStub each in `scripts/install/bootloaders/`
- `detect.sh`: atomized — detection functions grouped into `scripts/recovery/detects/{system,desktop,network_audio,packages,hardware,health}.sh`
- `repair.sh`: atomized — repair functions grouped into `scripts/recovery/repairs/{system,packages,advanced,migration_iso}.sh`
- `kernel.sh`: removed unused `install_kernel_bazzite` (now in `basestraps/kernel_build.sh`)
- `stages/post.sh`: removed dead bazzite build call
- Recovery: `detect_kernel` refactored to single loop over all known kernels
- Recovery: `detect_extras` refactored to single loop with special case for zram-tools
- Recovery: `detect_desktop` refactored to associative array lookup
- TUI: kernel menu uses `-*` suffix notation to indicate sub-menu choices

### Fixed
- Limine: kernel panic on boot — config now creates an entry for every installed kernel with exact filenames and matching initramfs
- Limine: missing kernel path error replaced with clear failure during install if no kernels found

## v8.6.4.7 (2026-06-14) — ArtixForge

### Fixed
- Limine: kernel panic on boot — config now creates an entry for every installed kernel with exact filenames and matching initramfs
- Limine: missing kernel path error replaced with clear failure during install if no kernels found

## v8.6.4.6 (2026-06-13) — ArtixForge

### Added
- SonicDE: user warning before installation — notifies that signature verification is disabled due to upstream key infrastructure issues
- SonicDE: user can cancel and return to desktop selection if they decline unsigned installation

### Fixed
- SonicDE: removed old repository URLs before adding new one to prevent key conflicts
- SonicDE: `SigLevel = Never` at repo level to work around missing upstream signing key (70B4B1EF0FF2A94E)???

## v8.6.4.5 (2026-06-13) — ArtixForge

### Changed
- TKG: completely rewritten build process — no longer depends on TKG's interactive scripts (they suck)
- TKG: clones Artix's current kernel version from kernel.org, applies TKG patches directly
- TKG: uses `make defconfig` for a clean baseline (no LiveISO kernel dependency)
- TKG: GRUB configuration regenerated after kernel install

## v8.6.4.4 (2026-06-13) — ArtixForge

### Added
- Extras: "Wayland Extras" category with swaybg, swaylock, waybar, wofi, fuzzel, foot, hyprpaper
- Wayland compositors now show a recommendation message during extras selection

### Fixed
- MangoWM: complete AUR dependency chain now built in order (wlroots0.19-hidpi-xprop → scenefx0.4 → mangowm-git)
- MangoWM: temporary passwordless sudo configured during AUR builds, cleaned up automatically
- MangoWM: build user added to `seat` group so compositor can launch without root
- MangoWM: Arch repositories now enforced when MangoWM is selected

### Changed
- MangoWM: AUR build now uses `makepkg -si --noconfirm` to automatically resolve all dependencies

## v8.6.4.3 (2026-06-13) — ArtixForge

### Fixed
- MangoWM: pacman keyring initialization now sets `GNUPGHOME` before Chaotic-AUR key import
- MangoWM: AUR build dependencies (`cjson`, `scenefx0.4`, `xorg-xwayland`) installed before compilation
- SonicDE: `sonic-login-manager-${init}` init-specific package restored in desktop installation
- XanMod: pacman keyring initialization now sets `GNUPGHOME` before Chaotic-AUR key import

## v8.6.4.2 (2026-06-12) — ArtixForge

### Changed
- TKG: kernel now compiled automatically during installation instead of requiring manual post‑install build
- TKG: uses TKG's own `_tkg_srcprep` + `make` with a non‑interactive customization.cfg (BORE scheduler, running‑kernel config, GCC)
- TKG: built kernel and modules copied to `/mnt` automatically; target initramfs regenerated

## v8.6.4.1 (2026-06-12) — ArtixForge

### Added
- SonicDE: full desktop environment support — repository setup, package installation, and Sonic Login Manager integration
- SonicDE: migration support — DE_PACKAGES, DE_DISPLAY_MANAGER, and DM_PACKAGES entries for sonicde ↔ any DE
- SonicDE: recovery detection — `detect_desktop()` and `detect_display_manager()` recognize sonicde-meta and sonic-login-manager
- SonicDE: GUI support — desktop combo boxes in `base.py` and `iso.py` include sonicde

## v8.6.4.0 (2026-06-12) — ArtixForge

### Added
- ZFS: full wiki-compliant ZFS-on-root support with dual-pool setup (bpool + rpool)
- ZFS: optional native encryption on root pool (aes-256-gcm) with passphrase confirmation
- ZFS: container and filesystem datasets with data separation (home, root, srv, usr/local, var/log, var/spool, var/tmp)
- ZFS: dedicated boot pool partition (BE00) and root pool partition (BF00) in GPT layout
- ZFS: `archzfs` repository configuration on target system
- ZFS: `zfs-mount` init script for automatic dataset mounting at boot
- ZFS: `zpool.cache` generation for initramfs embedding
- ZFS: GRUB compatibility workarounds (`ZPOOL_VDEV_NAME_PATH`, pool name detection in `10_linux`, `--removable` install)
- ZFS: manual fstab entries for boot pool and EFI partition (replaces fstabgen)
- LUKS: PBKDF2 key derivation added to all `luksFormat` calls for GRUB compatibility
- LUKS/LVM: init-specific service packages (`cryptsetup-${init}`, `lvm2-${init}`) installed on target
- LUKS/LVM: `dmcrypt`, `device-mapper`, and `lvm` services enabled at boot via `enable_service_boot()`
- Services: `enable_service_boot()` function added for boot-runlevel service activation across all four inits
- README: installation instructions for `pacman -S artixforge` package
- README: [galaxy] soonTM badge added
- PKGBUILD: ready for Artix [galaxy] submission? (pending v9 merger)

### Changed
- Migration: `install_target_init` now queries installed init packages via `pacman -Qsq` instead of hardcoded lists
- Migration: `cache_target_init_packages` downloads new init packages before removing old ones (network-safe)
- Migration: `remove_source_init` uses `pacman -Qsq` to find and remove all init-specific packages
- Migration: `cold_reboot()` function for SysRq-based reboot after init swap (prevents broken symlink hangs)
- Partition: ZFS layout now creates 1GB EFI + 4GB boot pool + root pool partitions
- ISO: `build.sh` now uses wiki method for non-repo packages (`buildiso -x` → chroot → `-sc` → `-zc`)
- SECURITY.md: supported versions table updated (v9.x future, v8.6.x best effort)
- OSI.md: corrected license name reference
- GUIDE.md: `gartix` references updated to `anvil`

## v8.6.3.0 (2026-06-12) — ArtixForge

### Added
- Migration: full Arch→Artix migration path following the official Artix wiki — replaces pacman.conf/mirrorlist, installs Artix keyring, removes systemd, reinstalls all packages from Artix repos
- Migration: LVM service enablement for all init systems after migration
- Migration: systemd junk cleanup (accounts, directories)
- Migration: bootloader update (mkinitcpio + GRUB reinstall) after migration
- Migration: pacman cache cleanup and security level toggle for keyring installation

### Changed
- Migration: `run_init_migration` now handles systemd→Artix as a complete system replacement (wiki parity)
- Migration: `install_target_init` now includes elogind and init-system packages for all inits
- Migration: `remove_source_init` replaces manual package removal with batched init-specific cleanup
- Migration: init migration now always updates bootloader and enables LVM services post-migration
- `services.sh`: relaxed sourcing — no longer dies when `/etc/artix-installer.conf` is missing (supports migration/recovery contexts)

## v8.6.2.0 (2026-06-10) — ArtixForge

### Added
- Recovery: migration health detection — detects multiple init systems, init mismatches, orphaned service symlinks
- Recovery: ISO health detection — detects missing pacman, broken package database, missing kernel, incomplete base
- Recovery: migration repair — reinstalls correct init system, cleans up conflicting init directories
- Recovery: ISO repair — reinstalls missing base packages and kernel when salvageable
- Recovery: extended detection prompt — migration and ISO checks are opt-in, keeping standard recovery fast

### Fixed
- Recovery: `esp_disk` and `esp_part` undefined variables in `repair_boot` Limine EFI entry repair
- Recovery: `_kernel_pkg` incorrectly listed `linux-bazzite-bin-headers` as a repo package (AUR, same as TKG)

## v8.6.1.0 (2026-06-10) — ArtixForge

### Fixed
- GUI: `extras_checkboxes` string corruption bug — state collection now reads directly from widget tree
- GUI: `state.conf` not saving — `save_state()` now writes via sudo with temp file shredding
- GUI: installer not launching from GUI — fixed path resolution for `install` script
- GUI: `state_load` never called in non‑interactive mode — installer now loads state before pipeline
- GUI: `&&`/`||` logic error in non‑interactive auto/manual causing false `power user stage failed` — replaced with `|| true`
- GUI: `GUI_MODE` flag not set — `collect_state_common()` now sets `GUI_MODE="yes"`
- GUI: `MODE` key not set — all modes now set `MODE` in state
- GUI: mode selection dialog added at startup
- GUI: LUKS and BTRFS sub‑boxes now properly hidden using `set_no_show_all(True)`
- GUI: `poweruser_box` visibility fixed with `show_all()`/`hide()` toggles
- GUI: `ResumeWindow` missing `start_installation()` override
- GUI: ANSI escape codes stripped from progress log output
- GUI: main config window hidden during installation to prevent accidental closure
- GUI: proper cancel/success/failure dialogs after installation
- GUI: CSS extracted to single `get_global_css()` function in `theme.py` — eliminates 200+ lines of duplication
- ISO: `buildiso` `useradd` error fixed — profile.conf now includes `username` and `password`
- ISO: `blank_db` variable typo fixed (`blankdb` → `blank_db`)
- ISO: `buildiso` flag corrected from `-o` to `-t` for output directory
- ISO: `ISO_DIR` properly defined in `build_artix_iso()` so script works when called directly

### Changed
- GUI: all mode windows now follow same pattern: `collect_state()` → `save_state()` → `./install --non-interactive`
- ISO: `offline.sh` now reads package list from `packages.x86_64` generated by user config instead of hardcoded array
- ISO: `build.sh` adds first‑boot setup script for non‑repo packages (MangoWM, vxwm, bazzite, tkg)
- ISO: `tui.sh` extra packages checklist fixed — removed broken `"off"` state strings, uses `tr '\n' ' '`
- ISO: offline mode now calls `tui_collect_install_config` to let user configure target system packages for bundling

### Removed
- ISO: hardcoded package list in `offline.sh` — replaced with state‑driven `packages.x86_64`
- GUI: custom Bash command construction in `recovery.py`, `iso.py`, `migration.py`

## v8.6.0.0 (2026-06-06) — ArtixForge

### Added
- GUI installer: persistent GTK configuration window (`forge-gui --mode config`) with 12 pages covering all installation options
- GUI installer: theme preview (Gentoo, Artix, Jet Black, Mono, Retro) with live CSS colour updating
- GUI installer: LUKS passphrase entry with confirmation and conditional visibility
- GUI installer: BTRFS layout selector (standard/flat/snapshot) shown only when btrfs filesystem selected
- GUI installer: Power User mode sub‑page with coreutils selection, fallback kernel toggle, and package checklist
- GUI installer: Arch repositories and offline mode toggles
- GUI installer: user and root password fields with visibility hiding
- GUI installer: summary page with sanity warnings for dangerous combinations (ZFS, glibc source, EFIStub+LUKS)
- GUI installer: all configuration saved to `/tmp/artix-installer/state.conf` in the same format as the TUI
- GUI integration: automatic detection of `DISPLAY`/`WAYLAND_DISPLAY` and `forge-gui` presence
- GUI integration: user prompt at startup to choose GUI over TUI when graphical session detected
- GUI integration: non‑interactive installer mode (`scripts/noninteractive.sh`) overriding all `tui_*` functions when GUI config is saved
- GUI integration: full installation pipeline reuses existing stages without UI prompts
- GUI integration: `forge-gui` added as a git submodule in `forge-gui/`
- `forge-gui` now installs `jsonschema` and `pygobject` as Python dependencies
- `preflight.sh` installs GTK3 and system Python bindings when GUI mode is enabled
- `install` script now supports `--non-interactive` flag (used by GUI after config save)
- GUI installer: categorized extras page with tabs for System Tools, Editors, Browsers, File Managers, Terminals, Shell & Prompt, Monitoring, and Media – includes "Select All" per category
- GUI installer: optional black or white background (user‑selectable on Theme page)

### Changed
- `gartix` package manager renamed to `anvil` – binary, internal scripts, and documentation updated accordingly
- `forge-gui` repository stripped of all Textual TUI code – now pure GTK3 GUI only
- `cli.py` extended with `--mode config` to launch persistent configuration window (replaces single‑widget mode for install flow)
- `tui_yesno` override in `noninteractive.sh` now checks `SIGN_UKI` state variable to answer Secure Boot prompts correctly
- `state.sh` now includes `GUI_MODE` variable to persist GUI selection across stages
- `install` script now runs non‑interactive pipeline directly after GUI config saves, without returning to TUI
- Changelog restructured to separate v8.5 (ISO + migrations) from v8.6 (GUI + integration)

### Fixed
- `bootloader.sh` Secure Boot prompt no longer blocks non‑interactive installation – reads `SIGN_UKI` from state instead
- `forge-gui` no longer attempts to run `sudo ./install` on its own – saves config and exits cleanly
- `forge-gui` theme preview now updates correctly when switching theme options

### Documentation
- `README.md` updated to describe GUI installer alongside TUI
- `GUIDE.md` added GUI installation section
- `forge-gui/README.md` rewritten for pure GTK frontend
- `poweruser/README.md` updated: all `gartix` references changed to `anvil`
- `DOCUMENTS/ROADMAP.md` updated: GUI integration moved from think‑tank to v8.6

## v8.5.0.0 (2026-06-05) — ArtixForge

### Added
- System Migration: init system conversion between all 16 combinations (openrc, runit, dinit, s6, systemd)
- System Migration: automatic service mapping with hub-chaining through OpenRC for non-direct pairs
- System Migration: custom service detection and backup to `/root/init-backup-*/`
- System Migration: desktop environment migration for all 13 supported DEs/WMs with network stack and extras support
- System Migration: interactive prompts for display manager, display stack, audio stack, and network stack during DE migration
- System Migration: user config backup (~/.config, ~/.local, ~/.cache) during DE migration
- System Migration: init-specific package handling (sddm-dinit, lightdm-openrc, etc.)
- New `migrations/` module structure: `inits/` and `des/` with shared `common.sh` libraries
- System Migration entry in main installer menu
- ISO generation: build custom Artix live ISOs from any Quick Profile or full custom configuration
- ISO generation: Live Desktop mode (full graphical environment) and Installer mode (boots directly into ArtixForge)
- ISO generation: installer auto-launch overlays for OpenRC, dinit, and runit
- ISO generation: offline-capable ISOs with bundled package repository that carries over to installed system
- ISO generation: offline mode auto-detection in `require_internet` when local repo is present
- ISO generation: init-specific live service overlays for OpenRC, dinit, runit
- ISO generation: full ArtixForge installer included on every ISO at `/root/ArtixForge/`
- ISO generation: user-requested extra packages support via `ISO_EXTRA_PACKAGES`
- ISO generation: build logs saved alongside ISO output
- New `iso/` module at repo root: `build.sh`, `common.sh`, `offline.sh`, `cleanup.sh`, `tui.sh`
- "Build ISO" entry in main installer menu

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