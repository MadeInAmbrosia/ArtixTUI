# ARTIXTECTURE.md — ArtixForge Architecture

This document describes the internal architecture of ArtixForge: how the
state machine works, how the stage pipeline is structured, how the TUI
integrates with FILLY, how the major subsystems are organized, and how to
add a new configuration option. It is written for contributors who need to
understand the codebase without reverse-engineering it.

---

## 1. Overview

ArtixForge is a **declarative system deployment framework** that materializes
a complete Artix Linux installation from a central state file. All user
choices are collected through a TUI or GUI hub, stored as key-value pairs
in `/tmp/artix-installer/state.conf`, and consumed by a linear pipeline of
stage scripts. Subsystems for recovery, system migration, ISO generation,
and source-based package management (Power User) read from the same state
file, making the installer, the recovery tool, the migration engine, and
the package builder all instances of the same underlying framework.

The framework is written entirely in **Bash** (≈12,000 lines). The user
interface is provided by **FILLY**, a pure-C widget library that renders
to terminals, graphical surfaces, and headless buffers through a single
JSON protocol.

---

## 2. Entry Point (`install`)

The script `install` in the repository root is the entry point for all
modes. Its responsibilities are:

- **Self-copy to `/tmp/artix-run`**: ensures a writable working directory
  even on read-only media (ISO loopback, NFS).
- **Self-update check**: compares `VERSION` against the upstream GitHub
  release and offers to update.
- **FILLY bootstrap**: copies the `filly` binary to `/usr/local/bin`,
  deploys plugins to `~/.config/filly/plugins/`, detects graphical
  sessions, and selects the TUI or GUI backend.
- **Mode dispatch**: presents a main menu (`Automatic`, `Resume`, `Recovery`,
  `Power User`, `Build ISO`, `System Migration`) and routes to the
  appropriate pipeline function.

The `--non-interactive` flag skips the menu and reads the mode from the
state file, allowing the GUI to save a configuration and re-launch the
installer without user interaction.

---

## 3. State Management (`scripts/state.sh`)

The state file at `/tmp/artix-installer/state.conf` is the **single source
of truth** for the entire deployment. It is a flat key-value file with
single-quoted values.

### 3.1 Reading and Writing

- `state_get <key> <default>` reads a key from the state file (with
  fallback to an environment variable, then the default).
- `state_set <key> <value>` writes a key immediately, using `sed -i` for
  in-place replacement or appending a new line.
- `state_save` serializes **every known configuration key** to the state
  file atomically (write to `.tmp`, then `mv`). This ensures that
  interrupted writes do not corrupt the file.

### 3.2 Stage Tracking

Each stage of the pipeline is tracked by a sentinel file in
`/tmp/artix-installer/stages/<name>.done`. The function `stage_should_skip`
checks both the sentinel and the actual state of the environment (via
`stage_validate`). If a stage is marked complete but the environment is
invalid (e.g., `/mnt` is empty after a reboot), the stage is reset and
re-run. This enables crash-resume.

### 3.3 Adding a State Key

To add a new configuration option, you must:

1. Add a `state_get`/`state_set` call in the relevant TUI or subsystem.
2. Add the key to the `state_save` function so it persists across resume.
3. Add the key to `handoff.sh` so it is written to
   `/mnt/etc/artix-installer.conf` on the target system.

---

## 4. User Interface Layer (`scripts/tui/`)

All user interaction goes through FILLY, a C library that speaks a
JSON protocol over Unix sockets or temp files. The Bash side constructs
JSON payloads and sends them to the `filly` binary.

### 4.1 Core Dispatch (`core.sh`)

`_filly_dispatch` is the single entry point for all simple widgets
(`menu`, `yesno`, `input`, `password`, `msg`, `checklist`, `filter`,
`multiselect`). Complex widgets that require persistent daemon state
(`hub`, `install_hub`, `recovery`, `iso`, `migration_init`,
`migration_desktop`, `poweruser`) have dedicated functions that use
`filly relay` mode.

### 4.2 Daemon and Oneshot Modes

- **Oneshot mode**: spawns `filly` for one widget call, using temp files
  for input/output. Used before the main configuration loop.
- **Daemon mode**: starts a persistent `filly daemon` listening on a
  Unix socket. Bash sends JSON requests over the socket. The daemon is
  started just before the configuration hub loop in
  `tui_collect_install_config` and stopped on exit via an EXIT trap.
  This eliminates terminal flicker.

### 4.3 Hub Widget

The configuration hub is a two-pane interface: categories on the left,
editable settings on the right. The Bash function `tui_afhub` (in
`menu.sh`) builds a massive JSON object describing every category, item,
widget type, choices, and visibility conditions. FILLY renders this
object, handles all navigation and inline editing, and returns a JSON
object with the user's selections. Bash then writes them to the state
file.

The `visible_if` mechanism allows items to be shown or hidden based on
the current value of another state key (e.g., swap size only appears if
swap is enabled).

---

## 5. Stage Pipeline (`scripts/stages/`)

The installation pipeline is a linear sequence of stages, each
implemented as a separate script:

| Stage | Script | Responsibility |
|-------|--------|----------------|
| preflight | `preflight.sh` | Dependency checks, network, kernel modules |
| storage | `storage.sh` | Partitioning, filesystem creation, mounting |
| base | `base.sh` | `basestrap` base system, kernel, init |
| poweruser | `poweruser.sh` | Source-based package compilation |
| chroot | `chroot.sh` | System configuration, users, bootloader |
| init | `init.sh` | BusyBox init setup (if applicable) |
| post | `post.sh` | Desktop, drivers, audio, extras |
| finalize | `finalize.sh` | Validation, report, unmount |

Each stage script follows the same pattern:

1. Call `stage_should_skip <name>`; return 0 if already completed.
2. Perform the stage's work.
3. Call `stage_mark_done <name>`.
4. Return 0.

Stages are called sequentially by `run_install_pipeline` in `install`.
The Power User stage is only executed if `POWER_USER=yes` in the state.

---

## 6. Subsystem Architecture

### 6.1 Storage (`scripts/storage/`)

- `partition.sh` creates MBR (BIOS) or GPT (UEFI) layouts, with
  optional LVM on LUKS setup.
- `filesystem.sh` formats partitions, handles LUKS encryption, LVM
  logical volumes, and filesystem-specific options (XFS bigtime, F2FS
  compression, BTRFS).
- `mount.sh` mounts the root filesystem, creates BTRFS subvolumes,
  and mounts the EFI partition.

All three use `state_get` for configuration and support both BIOS and
UEFI paths.

### 6.2 Bootloader (`scripts/install/bootloader.sh`)

The main script `configure_bootloader` detects the root device, generates
a kernel command line via `generate_root_cmdline` (handling LUKS, LVM,
BTRFS, ZFS), runs `mkinitcpio`, and dispatches to a per-bootloader
backend. Backends live in `scripts/install/bootloaders/`:

- `grub.sh` — GRUB for UEFI and BIOS, with LUKS/LVM support.
- `refind.sh` — rEFInd configuration.
- `efistub.sh` — direct kernel boot from UEFI firmware.
- `limine.sh` — Limine bootloader with snapshot entries.
- `uboot.sh` — U-Boot for ARM boards.

### 6.3 Base System (`scripts/install/basestrap.sh`)

This is the largest function in the installer. It selects packages based
on the chosen init, kernel, filesystem, bootloader, desktop, and network
stack. It handles third-party repository setup (CachyOS, Chaotic-AUR,
ARMtix) and kernel-specific build logic (TKG, Bazzite). Kernel detection
is in `scripts/kernels.sh`.

### 6.4 Post-Install (`scripts/post/`)

Each script in `post/` is sourced inside a chroot and configures one
aspect of the installed system:

- `desktop.sh` — installs DE/WM, display manager, display stack.
- `drivers.sh` — GPU drivers, VM guest agents, Nouveau fallback.
- `audio.sh` — PipeWire or PulseAudio setup.
- `networking.sh` — NetworkManager, dhcpcd+iwd, or ConnMan.
- `extras.sh` — additional user-selected packages.
- `users.sh` — user creation, password hashing, sudo/doas setup.
- `system.sh` — hostname, locale, keymap, timezone.

### 6.5 Recovery (`scripts/recovery/`)

Recovery has two phases:

- **Detection** (`detects/`): 30+ functions that probe the target system
  and reconstruct a state file (`reconstruct_state_from_system`).
- **Repair** (`repairs/`): functions that fix detected issues (fstab,
  pacman, bootloader, kernel, seat manager, filesystem).

The TUI presents the detected state and offers repair actions. All
detection is read-only until the user confirms a repair.

### 6.6 Migration (`migrations/`)

Three migration types, all state-driven and resumable:

- **Init migration** (`inits/common.sh`): service mapping tables between
  all init pairs, with a hub-chaining model through OpenRC.
- **Desktop migration** (`des/common.sh`): generic scripts that detect
  the current DE and install the target DE.
- **ATA migration** (`ata/`): full Arch→Artix conversion with audit,
  backup, conversion, package replacement, and service migration.

All migrations use stage files (`migration-stage.conf`) for crash-resume.

### 6.7 ISO Builder (`iso/`)

A wrapper around `artools` that generates a `profile.yaml` from the state
file, runs `buildiso`, and produces a bootable ISO. Supports offline
mode, non-repo kernel builds, and ARM aarch64 targets.

### 6.8 Power User (`poweruser/`)

A complete source-based package manager implemented in Bash. Key files:

- `lib/recipe.bash` — recipe loading with dynamic feature flag parsing.
- `lib/flags.bash` — flag resolution, global defaults, conflict detection.
- `lib/deps.bash` — topological dependency sort with virtual providers.
- `lib/builder.bash` — full build lifecycle with ccache, safety checks,
  sub-packages, file inventory, and atomic staging.
- `bin/anvil` — CLI dispatcher for post-install package management.

The Power User TUI configuration is in `tui/menu_poweruser.sh`.

---

## 7. Adding a Configuration Option

To add a new user-facing option (e.g., a new kernel variant), touch these
files:

1. **State keys**: add `state_get`/`state_set` calls in the relevant
   subsystem. Add the key to `state_save` in `state.sh`.
2. **TUI hub**: add the item to the JSON in `tui_afhub` (`menu.sh`) or
   `tui_poweruser_config` (`menu_poweruser.sh`). Use `visible_if` if it
   depends on another option.
3. **Backend logic**: handle the new key in the appropriate stage script
   or subsystem library.
4. **Handoff**: add the key to the config export in `handoff.sh` so it
   is written to `/mnt/etc/artix-installer.conf`.
5. **Recovery** (if applicable): add detection in `scripts/recovery/detects/`
   and repair in `scripts/recovery/repairs/`.

---

## 8. Resilience Patterns

- **Atomic state writes**: `state_save` writes to `.tmp` then `mv`.
- **Stage validation**: `stage_should_skip` re-validates the environment,
  not just the sentinel file.
- **Retry with backoff**: `retry_command` in `common.sh` for network
  operations (3 attempts, 5/10/20s delays).
- **Pacman lock recovery**: `clean_pacman_lock` before every `pacman` call.
- **Disk space checks**: before critical stages (3 GB, 5 GB, 10 GB).
- **Debug mode**: `set -x` to fd 19, separate from TTY.
- **Self-update**: `recoverable_error` offers to update ArtixForge from
  GitHub and restart.

---

## 9. Cross-Architecture Support (ARM aarch64)

ARM support is integrated through:

- Cross-compilation profiles in `poweruser/profile/cross-aarch64*.sh`.
- Kernel config fragments in `poweruser/kernel.d/aarch64/`.
- U-Boot bootloader backend in `scripts/install/bootloaders/uboot.sh`.
- ARM kernel detection in `scripts/kernels.sh`.
- ARMtix repository configuration in `scripts/install/basestrap.sh`.
- Architecture and board selectors in `menu_poweruser.sh` and `iso/tui.sh`.

The same state machine and pipeline deploy to aarch64 without modification.

---

## 10. Conclusion

ArtixForge is a unified, state-driven system deployment framework. Every
mode—installer, recovery, migration, ISO builder, poweruser—is an instance
of the same architecture: collect state, run a pipeline, produce a bootable
Artix system. The framework is modular at the directory level, with each
subsystem (`scripts/`, `poweruser/`, `migrations/`, `iso/`) capable of
functioning as a standalone project. FILLY provides the universal UI layer
with a formal protocol, allowing the same Bash code to drive terminal,
graphical, and headless interfaces.

*This document was synthesized from CODE_INDENTS.md, the live codebase,
and the project READMEs. It is updated as the architecture evolves.*