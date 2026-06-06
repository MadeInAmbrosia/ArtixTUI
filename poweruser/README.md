# Power User Mode

<p align="center">
  <img src="https://img.shields.io/badge/Power_User-v1.5.5.2-blue?style=flat-square" alt="Power User Version">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash" alt="Bash">
  <img src="https://img.shields.io/badge/Build_Engine-makepkg-FFB6C1?style=flat-square" alt="makepkg">
</p>

Power User Mode is ArtixForge's source-based package compilation subsystem.

It brings Gentoo-style control to Artix Linux — build kernels, drivers, init systems, coreutils, and userspace packages from source with custom compilation flags and feature toggles.

---

## How It Works

During installation, select **Power User** from the main menu.

After the base system is installed, you'll configure:

1. Compilation profile — safe, performance, hardened, or custom flags
2. Package selection — choose which packages to build from source
3. Feature flags — toggle per-package options (e.g. NVIDIA/AMD support)
4. Kernel configuration:

   * `localmodconfig` — compile only currently loaded modules (recommended)
   * Hardware auto-detection
   * Manual checklist configuration
   * `make menuconfig`
5. Coreutils selection:

   * GNU coreutils
   * BusyBox
   * uutils (Rust)
   * ArtixForge minimal coreutils
   * Custom recipe
6. Init configuration:

   * OpenRC
   * runit
   * dinit
   * s6
   * BusyBox init

The build engine then:

* Fetches sources
* Resolves dependencies
* Compiles packages
* Installs them into the target system
* Optionally downloads all recipe sources ahead of time for offline builds

---

## After Installation

The `anvil` tool is installed to:

```text
/usr/local/bin/anvil
```

Use it to manage your source-built packages.

### Commands

```bash
anvil list                 # List installed source packages
anvil list-recipes         # List all available recipes
anvil info <pkg>           # Show build details
anvil rebuild <pkg>        # Rebuild package with current flags
anvil new <name>           # Create a new recipe
anvil edit <name>          # Edit recipe
anvil lint <name>          # Validate recipe
anvil config               # Edit running kernel config
anvil menuconfig           # Launch make menuconfig
anvil fetch-all            # Download all recipe sources for offline builds
anvil upgrade              # Backup recipes and update from remote
anvil cache-clean          # Remove obsolete cached packages
anvil sync                 # Update recipes from remote
anvil recovery             # Check and repair source-built packages
anvil checksum <recipe>    # Download sources and print SHA256 checksums
anvil fetch-recipe <name>  # Download a single recipe from the community repo
anvil sections             # Manage which recipe sections are enabled
anvil --tui                # Launch interactive TUI
```

`anvil` automatically inherits the colour theme you chose during installation. Your theme choice is saved to `/etc/anvil-theme.conf` (legacy: `/etc/gartix-theme.conf` also works) and loaded on every run.

---

## Recovery

`anvil recovery` checks all source-built packages for missing files or recipes, and can rebuild them with the current profile and flags.

```bash
anvil recovery             # Check all packages and prompt for repair
anvil recovery linux       # Rebuild a specific package
```

---

## Recipes

Recipes are simple Bash files stored in the ArtixForge-recipes community repository.

The local `poweruser/recipes/` directory ships with only `template.sh` — all other recipes are fetched from the repository during installation or via `anvil fetch-recipe`.

Each recipe defines:

* Sources
* Dependencies
* Feature flags
* Build phases

Use `recipes/template.sh` as a starting point or generate one interactively with:

```bash
anvil new <name>
```

---

## Profiles

Compilation profiles are stored in:

```text
poweruser/profile/
```

Built-in profiles:

* `default`
* `safe`
* `performance`
* `hardened`

During installation you can tweak flags inline, and custom profiles are saved automatically.

---

## Build Cache

Built packages are cached in:

```text
poweruser/build/artifacts/
```

or

```text
/var/cache/artix-poweruser/artifacts/
```

The package database is stored at:

```text
poweruser/db/local.db
```

or

```text
/usr/share/artix-poweruser/db/local.db
```

Depending if you're installing or in the installed system.

This tracks:

* Installed packages
* Build flags
* Package versions
* Build metadata

---

## Requirements

* Artix Linux live environment
* Internet connection for source downloads
* Sufficient disk space (~5 GB temporary space for kernel builds)
* `gum` for TUI (installed automatically if missing)
* The build engine includes automatic retry for failed downloads, mid-build resume for interrupted compilations, and pacman lock recovery
