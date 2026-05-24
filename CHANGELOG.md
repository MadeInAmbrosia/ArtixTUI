# Changelog

## v8.0.1.4 (2026-05-24)

### Fixed (Also partially from v8.0.1.1)
- Quick Install profiles now fully define all system variables instead of relying on defaults
- Quick Install profiles now ask for hostname, timezone, locale, keymap, username, and passwords
- Added "Customize" option after Quick Install confirmation to drop into full manual flow
- Desktop profile now uses xlibre (Artix default) instead of X.Org
- UKI preset now dynamically detects installed kernel instead of hardcoding `vmlinuz-linux-custom`
- Quick Install profiles now always run disk selection before proceeding
- Preflight: added `pacman -Sy` before package installation to prevent mirror sync issues
- state_get: now returns default value when stored value is empty, not just unset
- bootloader.sh: removed duplicate `fi` causing syntax error

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