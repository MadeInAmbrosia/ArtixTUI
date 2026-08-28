# CODE_INDENTS.md — ArtixForge Hack Log

This document explains every deliberate weirdness, workaround, design quirk, and
lesson-learned-in-blood across the ArtixForge codebase.  It exists so that future
maintainers (if someone somehow picks this up) and future me don't have to reverse-engineer the same
decisions twice.

Reboots: At least 500
Hours wasted: YES

---

## Installer entry point (`install`)

### Runtime self-copy to `/tmp/artix-run`
The very first thing the installer does is copy itself to `/tmp/artix-run/` and
`exec` from there.  This guarantees a writable, disposable working directory even
if the original clone is on read-only media (ISO loopback, NFS, etc.).  The
`ARTIX_RUNTIME_DIR` env var prevents infinite re-copy loops.

### `set -Eeuo pipefail` + ERR trap
`-E` propagates the ERR trap into functions; `-e` exits on any non-zero return;
`-u` treats unset variables as errors; `pipefail` makes a pipeline fail if *any*
component fails.  Together they catch mistakes early but also mean **every
external command must be guarded** or the script dies.  The ERR trap
(`installer_error`) prints the failed line number and the last 10 lines of the
install log before exiting.

### `check_installer_version` pipefail
The version check pipes `curl` into `tr`, relying on `pipefail` to detect a
failed download.  `curl … || true` at the end would normally mask the error, but
`pipefail` makes the pipeline fail before `|| true` can swallow it.

### Debug mode `xtrace`
When the user answers **Yes** to “Enable debug mode?”, the installer opens fd 19
to `artix-debug.log` and sets `BASH_XTRACEFD=19`.  This separates the debug
trace from the TUI, which would otherwise be destroyed by `set -x` noise on
stderr.

### Non‑interactive mode
The `--non-interactive` flag is used when the GUI frontend writes a state file
and re‑launches the installer.  `scripts/noninteractive.sh` replaces every
`tui_*` function with a stub that either returns canned answers or pulls values
from the state file, allowing the same pipeline to run headless.

### GUI removal (v9.3.2.3)
The GUI backend was removed from live code.  The `DISPLAY`/`WAYLAND_DISPLAY`
detection block in `main()` was deleted, `FILLY_BACKEND=tui` is forced, and the
`--non-interactive` flag was removed entirely.  The GUI code still exists in the
FILLY submodule but is inert.  The state file remains the only interface.

### Bug report generator
`_generate_bug_report` collects install log, state file, migration debug log,
stage markers, and system info (uname, lscpu, free, lsblk, mounts) into
`/tmp/artixforge-bugreport-*.tar.gz` on failure.  Called from `installer_error`.
The bug report saves users from digging through `/tmp/artix-installer/` manually.

### Advanced features root password gate
The Advanced menu (Recovery, Power User, Migration, ISO) now requires the root
password via `_verify_root_password`.  Checks against `/etc/shadow` with
`openssl passwd -6`.  If running as root with no root password set, access is
open.  The point is to prevent a random person at the keyboard from launching
recovery or migration on someone else's machine.

---

## TUI (`scripts/tui/core.sh`, `menu.sh`)

### Hardcoded `</dev/tty`
All `gum` invocations redirect stdin from `/dev/tty` because `gum` needs a real
terminal.  When `/dev/tty` is unavailable (some dinit consoles, SSH without
`-t`), the menus fail silently.  A `_gum_tty` fallback was tested but later
reverted because it caused more problems than it solved; the real fix is to
ensure a proper TTY is available.

### Menu order sensitivity in `main_menu()`
The `case` patterns are evaluated in order.  **`Advanced*)` must appear before
`*ISO*)`** because the string `"Advanced – recovery, power user, migration, ISO"`
contains the substring “ISO”.  If the order is wrong, selecting “Advanced”
immediately launches ISO mode.  Lesson: never put a broad glob before a specific
one.

### `local mode` re-use in advanced submenu
The outer `while` loop declares `local mode` once, then the advanced submenu
re‑assigns it.  This is safe *as long as the inner `case` is checked before the
outer one*, but it’s fragile.  v9.1.1.4 uses a separate `local advanced_choice`
variable to eliminate the risk entirely.

### `tui_quick_install` state contamination
Declining a quick profile left half‑set state variables (DISK, FS_TYPE, etc.)
that would then mix with the subsequent manual selection.  The fix wipes all
quick‑profile keys before falling through to manual config.

### FILLY 0.7.0 relay protocol (v9.3.2.3)
The TUI backend was rewritten for FILLY 0.7.0.  `core.sh` no longer depends on
`fil.sh` — all widget transport is `filly relay` with JSON over a Unix socket.
`_filly_relay` sends the JSON and captures stdout.  `_start_filly_daemon` starts
the daemon with `--socket /tmp/filly.sock`; `_stop_filly_daemon` kills it.  The
old `nc -U` transport and `FILLY_DAEMON` env var are gone.  Results are bare
values on stdout, not JSON objects.  The daemon holds the alternate screen,
eliminating flicker.

### TUI rewrite (v9.2.7+ → v9.3.1.0)
The entire Bash TUI system was replaced with a Rust binary (`forge-tui`, later
merged into `FILLY`) using ratatui + crossterm. The Bash side builds JSON
payloads and pipes them to `filly` via Unix socket (daemon mode) or temp files
(oneshot mode). Only `core.sh`, `menu.sh`, and `summary.sh` remain in
`scripts/tui/` — all individual menu files were deleted. v9.3.1.0 replaced
`forge-tui` with `FILLY`, which also provides a Python GTK4 graphical backend.

### Daemon mode vs oneshot
`filly` can run in two modes. Oneshot mode spawns a new process for every
widget call. Daemon mode starts one persistent process with a Unix socket;
Bash sends JSON requests over `nc -U`. The daemon is started just before
the hub configuration loop in `tui_collect_install_config`, not globally.
Before that point, all TUI calls use oneshot mode. `fil.sh` auto-detects
daemon availability via `FILLY_DAEMON` env var.

### Hub widget
The configuration interface is a two-pane hub: categories on the left
(Disk & Storage, Bootloader, Kernel, Desktop, etc.), editable settings on the
right. FILLY handles all navigation, inline editing via dispatched
sub-widgets, F-key actions, and state management internally. Bash
builds categories as JSON with `state_get` values and passes them to
`tui_hub` (via `filly_hub` or `filly_graphical_hub`). When the user
presses F-key actions, the hub returns the current values map
back to Bash which writes them to `state.conf`.

### `visible_if` in hub
Items can specify `"visible_if":{"SWAP_ENABLED":"yes"}` in the JSON. The Rust
hub filters items based on current state values. The GUI implements the same
logic via `_visibility_rows` and `_on_state_changed` in `HubPage`.

### Theme as named presets
Theme colors are presented as human-readable names (Forge, Artix, Jet Black,
Mono, Retro) rather than raw ANSI codes. When selected, both
`GUM_TITLE_COLOR` and `GUM_ACCENT_COLOR` are set atomically to the correct
numeric values. This applies to both TUI (Rust hub) and GUI.

### `choices_from` for dynamic extras
The extras multiselect is populated at runtime by shelling out to
`pacman -Sl world galaxy`. No hardcoded package lists. The GUI does the
same by calling `pacman -Sl` during startup and caching the result in
`_package_index`.

### Filter widgets for identity fields
Timezone, locale, and keyboard layout use searchable filter widgets instead
of plain text inputs. The TUI pulls lists from `/usr/share/zoneinfo`,
`/etc/locale.gen`, and `localectl list-keymaps` via helper functions. The
GUI does the same and presents them as `Gtk.ComboBoxText` with type-to-search.

### `_load_config_preset` encrypted preset handling
`_load_config_preset` in `menu.sh` checks the first line of the chosen file for
the magic header `ARTIXFORGE_ENCRYPTED=1`.  If present, it decrypts via
`state_decrypt_preset`, writes the decrypted content to a mktemp file, loads
through `state_load_preset`, and shreds the temp.  Otherwise it validates and
loads normally.  The file picker filter accepts `.enc` files.

---

## State Management (`scripts/state.sh`)

### State file as the interface
No command-line flags configure behavior.  Everything is declared in state.
Preset inheritance via `BASE_STATE`, templating via `${KEY}` references, and
encryption via GPG are all state file features.  The installer doesn't parse
flags — it reads state.

### `lint_state` before pipeline
`lint_state` validates required keys, disk existence, and value constraints
(filesystem, init, bootloader, privilege escalation, display stack).  Called
from `run_install_pipeline` before any stage runs.  The goal: catch bad state
before it bricks a system.

### State inheritance — one level, no recursion
A preset can declare `BASE_STATE='/path/to/base.conf'`.  `state_load_preset`
loads the base first, then applies the preset's keys on top.  Relative paths
resolve against the preset's directory.  Empty values in the override mean
"use base".  Exactly one level — no recursive BASE_STATE.  If someone needs
three layers they can flatten it.  Recursion adds cycle detection and infinite
loop risk for marginal gain.

### State templating without eval
`state_resolve_templates` resolves `${KEY}` references against the loaded
state.  Uses bash `${!ref}` indirect expansion with a strict regex for
reference names.  No eval, no shell injection.  Maximum 10 iterations guards
against cycles.  Unknown references left literal — replacing with empty
silently corrupts the value.  Resolution happens only on preset load, not on
every `state_get`.  The hub sets concrete values — typed `${HOSTNAME}` in the
hub stays literal.

### Encrypted presets with magic header
Encrypted presets use `ARTIXFORGE_ENCRYPTED=1` as the first line, followed by
base64-encoded GPG binary.  `state_encrypt_preset` uses GPG AES256 with
passphrase via `--passphrase-fd 3` — never on the command line where `ps`
could catch it.  Decryption writes to temp, sources, shreds.  Live state on
tmpfs stays plaintext; encryption is for persistent presets only.  The
decrypted temp file is the weak point but the risk window is tiny.

### Migration keys in `state_save`
`MIGRATION_TYPE`, `MIGRATION_SRC`, `MIGRATION_TGT`, `MIG_ROOT`, all `DE_MIG_*`
keys, `ATA_AUR_HELPER`, `ATA_HAS_HOMED`, `POST_INSTALL_SCRIPT`, and
`POST_INSTALL_ONESHOT` are now persisted through `state_save`.  Before this,
a `state_save` call during migration would drop migration keys and a resume
would lose the user's choices.

### One-shot post-install services
`POST_INSTALL_ONESHOT` state key runs a command on first boot then
self-destructs.  `_finalize_write_oneshot_service` writes a per-init service
file (OpenRC, runit, dinit, s6) and a shared script at
`/usr/local/lib/artix-installer/oneshot.sh`.  The script removes its own
service file and symlinks on success, keeps everything on failure so the
service retries next boot.  The four init templates live in `finalize.sh`.

---

## Storage (`scripts/storage/`)

### `get_partition_name` for NVMe / MMC
NVMe and MMC block devices append `pN` for partitions (`nvme0n1p1`), while
traditional drives append just `N` (`sda1`).  `get_partition_name` detects the
device type and constructs the correct partition path.

### BIOS + `bios_grub` flag
The `bios_grub` flag is a GPT concept.  On MBR (BIOS) layouts, `parted` rejects
it with “invalid token”.  The 1 MiB gap before the first partition is sufficient
for GRUB’s core image; the flag line was removed entirely for BIOS installs.

### VFAT mount verification
`mkfs.fat` can succeed but leave a corrupted filesystem if kernel modules are
missing.  After formatting the EFI partition, the installer now performs a quick
`mount`/`umount` test to catch silent failures before they cascade into GRUB
errors.

### LVM on LUKS device chain
When both LUKS and LVM are enabled, the partition is first opened as
`/dev/mapper/cryptlvm`, then `pvcreate`/`vgcreate`/`lvcreate` operate on that
mapper device.  The root LV becomes `/dev/vg0/root`.  This double‑layer requires
the kernel command line to reference `cryptdevice=UUID=...:cryptlvm` and
`root=/dev/vg0/root`.

### `get_luks_raw_uuid` parent walking
To find the actual LUKS container UUID (not the opened mapper), the function
walks up the device tree using `lsblk -no PKNAME` until it finds a
`crypto_LUKS` partition or reaches the disk.  The fallback is scoped to the
target disk only, preventing contamination from other LUKS devices on the
system.

---

## Bootloader (`scripts/install/bootloader.sh`)

### BIOS GRUB cmdline injection
On BIOS systems, `grub-mkconfig` does not automatically add `cryptdevice=` or
`root=/dev/mapper/...` parameters.  The installer now generates the same kernel
command line used for UEFI and injects it into `/etc/default/grub` before
calling `grub-mkconfig`.

### `generate_root_cmdline` flags
The function handles four root scenarios: plain UUID, LUKS, LVM, and ZFS.  BTRFS
subvolumes add `rootflags=subvol=@`.  The `rootfstype=` flag is appended only
when explicitly requested (Limine needs it; GRUB does not).

### Limine snapshot entries
When BTRFS snapshots are detected under `.snapshots/`, the Limine config
generator creates additional boot entries for the five most recent snapshots,
each with the correct `rootflags=subvol=.snapshots/...` parameter.

### EFIStub kernel/image copying
EFIStub requires the kernel and initramfs to reside on the ESP.  The installer
copies them to `EFI/Artix/` and references them via `\EFI\Artix\...` in the
`efibootmgr` command.  Microcode is prepended as an additional initrd.

---

## Init / Services (`scripts/install/services.sh`)

### dinit `logind` vs `elogind`
The `elogind-dinit` package installs *two* service files: `elogind` (the actual
daemon) and `logind` (a `type = internal` stub that depends on `elogind`).  Many
scripts call `enable_service logind`, which symlinks the stub.  The stub does
not auto‑start `elogind` because dinit’s `internal` type doesn’t trigger
dependency resolution the same way.  The fix maps `dinit:logind` → `svc="elogind"`
inside `enable_service` and `enable_service_boot`.

### `cold_reboot` via SysRq
When swapping init systems (e.g., OpenRC → dinit), a warm reboot is not enough
— the new init must be PID 1 from the kernel’s handoff.  `cold_reboot` syncs,
remounts read‑only, and triggers a hard reset via `echo b > /proc/sysrq-trigger`.

### `cold_reboot` running-system fix (v9.3.2.3)
`cold_reboot` used `mount "${MIG_ROOT}/" -o remount,ro` — when running from
the installed system with `MIG_ROOT=""`, that became `mount / -o remount,ro`
with a stray trailing slash.  Fixed with `${MIG_ROOT:-/}`.

---

## Power User (`poweruser/`)

### Feature flag hashing
Build reproducibility is tracked by hashing the combination of CFLAGS,
CXXFLAGS, LDFLAGS, MAKEFLAGS, and enabled feature flags.  The hash is stored in
`db/local.db` alongside the package name and version.  When all inputs are
identical, the build is skipped.

### Recipe healing (`heal.bash`)
When a source fetch fails (e.g., kernel.org removes an old tarball), the heal
function scrapes the parent directory or the GitHub API for a newer version,
bumps `pkgver` and resets `pkgrel=1`, then rewrites the recipe.  Kernel.org uses
directory listing parsing; GitHub uses the releases/tags API and is subject to
rate limiting (60 req/h anonymous).

### `_major` kernel version
Some kernel recipes store the major version in `_major` (e.g., `_major=6`).
Healing re‑extracts this from the new `pkgver` so the URL pattern
`/pub/linux/kernel/v${_major}.x/` stays correct.

### `build_package` dual installation
During the installer stage, packages are installed to both the live environment
(for build dependencies) and `/mnt` (the target system).  Post‑install `anvil`
calls do not use `/mnt`; the function relies on the caller to have the target
mounted if needed.

### `validate_system` post‑build checks
After building a custom kernel, the validator checks that the target’s
filesystem driver is built‑in (`=y`, not a module), that a block device driver
exists, and that the initramfs and bootloader entries reference the custom
kernel.  Warnings are emitted but the install continues — the user can fix
things in recovery.

### TKG kernel configuration (`tkg.rs`)
The TKG kernel has a dedicated configuration sub-widget covering scheduler
(eevdf/bmq/bore/pds), build type (binary download vs source compile),
compiler (gcc/clang), optimization level, CPU target, LTO mode, preempt RT
level, tickless mode, timer frequency, CPU governor, and 8 toggleable patch
sets (glitched base, zenify, clear patches, OpenRGB, ACS override, fsync,
MGLRU, NTsync). All values are stored as `TKG_*` state keys and consumed by
`_tkg_write_config` which generates `customization.cfg` before the TKG build.

### Kernel hardware configuration (`kconfig.rs`)
The poweruser kernel configuration includes a tabbed checklist for GPU
drivers, network drivers, filesystems, sound, USB, security, virtualization,
and debugging options, plus preemption model, timer frequency, and CPU
governor. These set `KERNEL_ADV_*` state keys consumed by `kconfig.bash`
which calls `scripts/config` to modify `.config`.

### Kconfig editor
When `menuconfig` depth is selected, a native ratatui `.config` editor opens
with search, y/m/n toggle, and string value editing. On save, a sentinel file
(`/tmp/artix-kconfig-edited`) is written so the recipe's `configure()` phase
skips the ncurses `make menuconfig` and goes straight to `make olddefconfig`.

---

## ISO Builder (`iso/`)

### `buildiso` monkey‑patching
Artools’ `mount.sh` can hang on `umount` when overlayfs is busy.  The installer
patches it to retry with `umount -l` up to 5 times.  Similarly, `buildiso` is
patched to tolerate `find … -delete` failures on read‑only files.  Original
files are restored after the build.

### Stage‑based ISO resume
ISO builds save progress to `/tmp/artix-installer/iso-build-stage.conf` at each
major step (profile, offline, chroot, iso).  If interrupted, the build resumes
from the last completed stage.

### CachyOS mirror scraping
The CachyOS repository does not provide a static keyring/mirrorlist URL.  The
installer scrapes the mirror’s HTML directory listing to find the latest
package filenames, with a hardcoded fallback.  This is fragile and will break if
the mirror changes its index format.

### Offline kernel builds
When building an offline ISO with a non‑standard kernel (CachyOS, XanMod,
Bazzite), the installer creates a chroot, downloads the kernel packages, and
copies them into the ISO’s local repository.  The target system’s `pacman.conf`
is rewritten to use `[custom]` pointing to `file:///mnt/repo/`.

---

## Recovery (`scripts/recovery/`)

### `recovery_mount_all` device probing
The auto‑mount function tries LUKS containers, LVM volume groups, and plain
partitions in sequence.  It scans `/dev/mapper/*` for filesystem signatures
before falling back to raw block devices, ensuring encrypted or LVM‑wrapped
systems are found.

### `detect_seat_manager` service check
After detecting the installed package (`elogind` or `seatd`), the function also
verifies that the service is actually enabled for the current init system by
checking the appropriate symlink directory.  If missing, it appends
`seat-manager-disabled` to `BOOT_ISSUES`.

### `repair_seat_manager`
Can install the missing package, enable the service, and on dinit handles the
`logind`→`elogind` mapping.  Called automatically by `repair_boot` and
`repair_system`.

---

## Migrations (`migrations/`)

### Explicit target selection (`ensure_migration_root`)
The old live ISO detection was a single check for `/run/artix/sfs/rootfs`
that assumed `/mnt`.  It was fragile — no validation, no way to migrate a
mounted system elsewhere, and no confirmation on a running system.  The new
`ensure_migration_root` in both DE and init migrations prompts for auto-mount,
already-mounted, or custom mount point on live ISO, and running system vs
mounted install on an installed system.  Verifies the target has
`/etc/os-release`, pacman binary, and pacman DB.  Persists `MIG_ROOT` via
`state_set`.

### Init migration hub
All init migrations chain through `openrc` as the central hub.  Direct
translations exist for common pairs (OpenRC↔runit, OpenRC↔dinit, etc.), but
anything not directly mapped goes through two hops: source→openrc→target.  This
avoids an N×M explosion of migration scripts.

### Service mapping tables
Associative arrays map service names between init systems (e.g.,
`OPENRC_TO_DINIT`).  The reverse tables (`DINIT_TO_OPENRC`) are generated
automatically by iterating the forward tables, avoiding manual duplication.

### `list_enabled_services` per-init quirks (v9.3.2.3)
Dinit's `ls` output was piped through `sed 's/\.d$//'` which corrupted service
names ending in `d` (e.g., `sshd` → `ssh`).  Replaced with `find -type l`
on the boot.d directory.  Runit now filters symlinks only.  S6 was listing
all services in the database, not enabled ones — now tries
`s6-rc-db list bundle default` first.  Systemd now strips `.service` suffix
from unit names so the `SYSTEMD_TO_OPENRC` table can use bare keys.

### DE migration `remove_packages` switched to `-Rdd` (v9.3.2.3)
`pacman -Rns` removed dependencies.  For desktop package removal that's wrong
— you want to remove the DE, not cascade into shared libraries.  Switched to
`pacman -Rdd`.  Orphan removal is now a separate user-visible checklist step,
not automatic.

### DE migration dynamic source discovery (`_installed_de_packages`)
The hardcoded `DE_PACKAGES` table listed manual package names.  They rot as
packages are renamed or split.  `_installed_de_packages` queries installed
packages matching a DE pattern at migration time.  KDE removal actually
removes KDE now.  The static table is fallback, not primary.

### DE migration backup never copies `.cache` (v9.3.2.3)
The old `backup_de_config` copied `~/.config`, `~/.local`, and `~/.cache`
wholesale.  `.cache` on a KDE system can be 20-50GB.  The migration filled
the SSD before any package work, then everything downstream failed because
the disk was full.  Now only copies `.config` and `.local/share`.  Reports
backup size after completion.

### ATA backup selective (v9.3.2.3)
Same `.cache` problem, worse — `/home` copy included flatpaks, Docker volumes,
thumbnails, build caches.  `_backup_user` now uses `rsync --safe-links` with
excludes for `.cache`, flatpak/docker/container storage, thumbnails, gradle,
npm, cargo, rustup, node_modules, target, build, dist.  `/etc` backup uses
rsync with excludes for mtab, resolv.conf, pacman.d, crypttab.

### ATA desktop detection lookup table (v9.3.2.3)
The `elif` chain in `ata_detect_all` was yanderedev-tier code.  Replaced with
an associative array mapping Arch package names to DE names.  MATE is detected
but mapped to `none` with a warning since it's not supported.

### ATA user service detection per-user (v9.3.2.3)
`systemctl --user list-unit-files` ran as root, listing root's user units.
Now iterates over `/tmp/ata-users.txt` and queries each user via `su -`.

### ATA homed migration uses saved list (v9.3.2.3)
`ata_migrate_homed_users` called `homectl list` directly.  By the time
migration runs, `homectl` might be removed.  Now reads the saved
`/tmp/ata-homed.txt` from detection.

### ATA `has_homed` persisted (v9.3.2.3)
`has_homed` was set in the init stage but not persisted.  On resume, the
variable was 0 and homed migration was skipped.  Now persisted as
`ATA_HAS_HOMED` state key.

### SonicDE removed as target (v9.3.2.3)
SonicDE was nuked from install paths, migration targets, ISO choices, and
recovery repair.  Detection still recognizes SonicDE so migration can offer
to move away from it.

### xlibre removed as target (v9.3.2.3)
Xlibre was officially dropped upstream.  Removed from X_PACKAGES, TUI/ISO hub
choices, ISO common.yaml, drivers.sh GPU/VM conditionals, and sanity warnings.
Detection preserved so migration can move users to xorg.  Xorg is the only
supported display stack.

### Systemd→Artix full migration
This path replaces the entire pacman database and package set.  It temporarily
lowers `SigLevel` to `Never` to install the Artix keyring, then reinstalls every
package from Artix repositories.  `pacman -Sl system|world|galaxy | grep installed`
is used to rebuild the package list.

### `_chroot` / `_pacman` dual‑path
Migration functions use `_chroot` and `_pacman` wrappers that automatically
prepend `artix-chroot "${MIG_ROOT}"` when running from a live ISO.  This avoids
duplicating every command with an `if` branch.

### ATA (Arch to Artix) migration
The ATA module performs full system conversion from Arch Linux to Artix.
Detection extends the recovery module's system fingerprinting with
Arch-specific auditing: systemd units, timers, homed users, network
credentials, pacman hooks, PAM modules, crypttab entries, DKMS modules,
flatpaks, snaps, AppImages, Docker containers, and AUR packages.

### ATA desktop detection override
Recovery's `detect_desktop` looks for Artix package names (e.g.,
`plasma-desktop`).  On Arch the same packages have different names (e.g.,
`plasma-meta`).  ATA runs a direct `pacman -Q` query for Arch package names
after the recovery detection to correctly identify the installed desktop
environment instead of reporting `WM_DE=none`.

### ATA backup and credential security
All user data, system configs, and credentials are backed up to
`/arch-migration-backup-YYYYMMDD-HHMMSS/` with `chmod 700`.  Network
credentials (WiFi passwords, NM connections, iwd PSKs) are isolated in a
separate subdirectory with `chmod -R 700`.  The raw backup is deleted after
successful restoration to the target system with proper file permissions (600
for credential files).

### ATA package and service mapping
Rather than maintaining a static list of every possible systemd unit, ATA
dynamically maps packages by querying the Arch repos for each enabled
service's owning package, then checking Artix repos for equivalents with
init-specific suffixes (`-openrc`, `-runit`, `-dinit`, `-s6`).  Version
mismatches between Arch and Artix packages are flagged in a TUI checklist,
letting the user decide what to migrate.

### ATA `head -n1` on `pacman -Si` queries
`pacman -Si networkmanager` returns `Repository: world\nextra` when a package
exists in both Artix repos.  The original `grep Repository | awk '{print $3}'`
captured both lines, producing a newline in the version string that created
ghost `1.56.1-1 →` entries in the service checklist.  Fixed with `head -n1`.

### ATA systemd timer conversion
`OnCalendar=` timers are parsed and converted to cron expressions using a
lookup table for common patterns (daily, hourly, weekly, monthly) and a
time-parser for explicit `YYYY-MM-DD HH:MM:SS` formats.  `OnBootSec=` timers
become `@reboot sleep N && command` cron entries.  `OnUnitActiveSec=` timers
become background loop scripts launched at boot.  Monotonic timers without a
direct cron equivalent are flagged for manual review.  Case patterns are quoted
to prevent bash glob expansion at parse time (e.g., `"*-*-* 00:00:00"`).

### ATA timer conversion fetches config once (v9.3.2.3)
`systemctl cat` was called four times per timer — 200 subprocesses for 50
timers.  Now fetches once into a variable and greps the variable.

### ATA PAM and mkinitcpio conversion
`pam_systemd.so` references are replaced with `pam_elogind.so` across all
files in `/etc/pam.d/`; `pam_systemd_home.so` lines are removed entirely.
mkinitcpio hooks are rewritten: `systemd`→`udev`, `sd-encrypt`→`encrypt`,
`sd-vconsole`→`consolefont`, `sd-lvm2`→`lvm2`, and `fsck` is added after
`filesystems` if missing.  pacman hooks that call `systemctl`, `journalctl`,
or reference systemd paths are moved to `/etc/pacman.d/hooks.bak/` rather
than deleted.

### ATA `mkinitcpio` preset uncommenting
Arch's `linux.preset` uses commented-out lines that the Arch `mkinitcpio`
package uncomments during installation.  Artix's package leaves them commented,
resulting in a preset with no `default_image` or `fallback_image` — initramfs
generation fails silently.  The migration now uncomments these lines instead of
leaving the preset file fully commented-out.

### ATA `libsystemd.so.0` dependency chain
Arch compiles `util-linux`, `e2fsprogs`, `coreutils`, and `findutils` against
`libsystemd.so.0`.  When `systemd-libs` is removed, `mount`, `umount`, `fsck`,
and `findmnt` break because the shared library is missing.  The migration
force-removes `systemd-libs` with `pacman -Rdd` and reinstalls all dependent
packages from Artix repos, which compile without the systemd dependency.

### ATA DNS atomic replacement
`ata_convert_resolv_conf` writes to `/etc/resolv.conf.tmp` then `mv -f` over
the old file, eliminating the window where no resolver exists between deleting
the `systemd-resolved` stub and writing the new file.  Also stops
`systemd-resolved` before touching the file to prevent it from regenerating
the stub.  Users can choose Cloudflare, Google, Quad9, copy from backup, or
enter a custom DNS server.

### ATA `_pacman -Scc` hang
`pacman -Scc --noconfirm` doesn't suppress the `[Y/n]` prompt for cache
cleaning in some pacman versions.  The migration hung indefinitely waiting
for input that never arrived.  Fixed by using direct `rm -rf` on
`/var/cache/pacman/pkg/*` and `/var/lib/pacman/sync/*` instead of calling
`pacman -Scc`.

### ATA homed user migration
`systemd-homed` users are detected via `homectl list`.  For LUKS-encrypted
home images, the migration prompts for the user's password, unlocks the
image with `cryptsetup`, mounts it, copies data to a standard `/home/<user>`
directory, creates the user account with `useradd -u <uid>`, and cleans up
the mapper.  Non-LUKS homed users are recreated with their original UID and
shell.

### ATA user service conversion
`systemd --user` services (pipewire, wireplumber, gpg-agent, etc.) are
converted to XDG autostart `.desktop` files in `/etc/xdg/autostart/`.  Known
services have pre-defined desktop entries; unknown services are listed for
manual follow-up.

### ATA network credentials use actual interface (v9.3.2.3)
`ata_convert_network_credentials` appended to a fixed filename
`wpa_supplicant-nl80211-wlp.conf` — hardcoded interface name.  If the system
has `wlan0` or another interface, the config never loads.  Now queries
`ip link` for the actual wireless interface, falls back to `wlan0`.

### ATA resolv.conf detection checks active systemd-resolved (v9.3.2.3)
Detection only wrote `/tmp/ata-resolv-link.txt` if `/etc/resolv.conf` was a
symlink.  If systemd-resolved was running but the file was real, the check
missed it.  Now checks `systemctl is-active systemd-resolved` as well.

### ATA systemd-boot replacement
If `bootctl status` detects systemd-boot, the migration installs GRUB to the
same ESP, generates `grub.cfg`, and removes the old systemd-boot EFI entries
via `efibootmgr`.  BIOS systems get `grub-install --target=i386-pc`.

### ATA AUR batch reinstall
If the user opts in and chooses an AUR helper (paru/yay), the migration
attempts to reinstall all AUR packages in batch mode after the Artix base is
in place.  Failures are logged per-package and the full list is preserved for
manual follow-up.

### ATA resume and failure recovery
Like init and desktop migrations, ATA uses stage files to track progress
through detection, backup, conversion, package removal, installation, service
migration, and finalization.  If interrupted, the migration can be resumed
from the last completed stage or restarted fresh with both source and target
states cleaned.  Resume correctly loads `target_init`, `backup_dir`, and
`de` from the persisted state file.

### ATA minimum viable system check
After all package operations complete, ATA verifies that the kernel, init
system, session manager, coreutils, dbus, pacman, and network stack are
actually installed.  Any missing critical package is installed with the
correct init-specific suffix before the migration reports success.

---

## Known Hardware / VM Issues

### XFCE + llvmpipe crash
`xfwm4` 4.20 enables OpenGL compositing by default.  On VMs without 3D
acceleration, the software renderer (llvmpipe) fails to initialise the
compositor, `xfwm4` crashes, and the session dies.  Workaround: disable
compositing in `xfwm4.xml` or enable 3D acceleration in the VM.

### VFAT kernel module on dinit ISOs
Some Artix dinit live ISOs ship with `vfat` as a module that is not
auto‑loaded.  The preflight stage now explicitly checks for VFAT support,
attempts `modprobe vfat`, and gives a clear error if the ISO kernel lacks it.

---

## General Bash Patterns

### `state_set` and `state_save`
State is stored as `KEY=value` in `/tmp/artix-installer/state.conf`.  `state_set`
replaces a key in‑place using a `while read` loop and a temp file — this is
atomic enough for our purposes and avoids pulling in `sed -i` which behaves
differently across implementations.  Values are escaped with `printf '%q'`.

### `BASH_REMATCH` regex extraction
Version scraping (kernel.org, GitHub tags, etc.) uses `[[ $var =~ regex ]]` and
accesses capture groups via `${BASH_REMATCH[n]}`.  This is pure bash, no
external tools needed.

### `xtrace_safe` wrapper
Some commands produce enormous trace output that fills debug logs instantly.
`xtrace_safe` runs its arguments in a subshell with `BASH_XTRACEFD` unset,
suppressing trace for that command only.

### `retry_command` with exponential backoff
Network‑fragile operations (package downloads, `basestrap`) are wrapped in
`retry_command` which retries up to 3 times with delays of 5, 10, and 20
seconds.

### `pacman --root` in recovery / migrations
When operating on a mounted target system, recovery and migration code uses
`pacman --root /mnt` to query and modify the target’s package database without
entering a full chroot.  This is faster and avoids issues with `/dev`, `/proc`,
or `/sys` not being mounted inside the chroot.

### `openssl passwd -6` fd 3 for GPG passphrases
`state_encrypt_preset` passes the passphrase via `--passphrase-fd 3` with
`3<<<"${passphrase}"`.  Never on the command line where `ps` could catch it.

---

*This document grows as new hacks are added.*