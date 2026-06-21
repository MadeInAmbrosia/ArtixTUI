# Power User Mode

<p align="center">
  <img src="https://img.shields.io/badge/Power_User-v1.5.5.2-blue?style=flat-square" alt="Power User Version">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&logo=gnu-bash" alt="Bash">
  <img src="https://img.shields.io/badge/Build_Engine-makepkg-FFB6C1?style=flat-square" alt="makepkg">
</p>

Power User Mode is ArtixForge's source-based package compilation subsystem.

It provides source-based package management and fine-grained build control for Artix Linux — build kernels, drivers, init systems, coreutils, and userspace packages from source with custom compilation flags and feature toggles.

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

The `anvil` tool is installed to `/usr/local/bin/anvil`.

Use it to manage recipes, source-built packages, kernel configuration, recovery operations, and community repositories.

---

## Commands

```bash
anvil list                 # List installed source packages
anvil list-recipes         # List available recipes
anvil info <pkg>           # Show build details
anvil rebuild <pkg>        # Rebuild a specific package
anvil new <name>           # Create a new recipe
anvil edit <name>          # Edit recipe
anvil lint <name>          # Validate recipe
anvil config               # Edit running kernel config
anvil menuconfig           # Launch make menuconfig
anvil fetch-source <pkg>   # Prepare package sources for manual build workflow
anvil fetch-recipe <name>  # Download a single recipe from the community repo
anvil fetch-all            # Download all recipe sources for offline builds
anvil upgrade              # Backup recipes, update repository, report changes
anvil cache-clean          # Remove obsolete cached packages
anvil sync                 # Update recipe index and refresh enabled recipes
anvil recovery             # Check and repair source-built packages
anvil checksum <recipe>    # Download sources and print SHA256 checksums
anvil sections             # Manage enabled recipe sections
anvil --tui                # Launch interactive TUI
```

Theme selection is inherited from installation and stored in `/etc/anvil-theme.conf` (legacy: `/etc/gartix-theme.conf` also supported). It is loaded automatically on startup.

---

## Recovery

`anvil recovery` audits and repairs source-built packages, checking for missing recipes, missing kernel artifacts, and potentially broken installations.

```bash
anvil recovery             # Full system audit and optional repair
anvil recovery linux       # Rebuild a specific package
```

---

## Recipes

Recipes are Bash-based build definitions stored in the ArtixForge-recipes repository.

The local `poweruser/recipes/` directory ships only `template.sh`. All other recipes are fetched during installation or via `anvil fetch-recipe`.

Each recipe defines:

* Sources
* Dependencies
* Feature flags
* Build phases

New recipes can be created with:

```bash
anvil new <name>
```

---

## Recipe Sections

Recipes are grouped into sections:

* OFFICIAL/Base — core maintained recipes
* OFFICIAL/Other — extended tested recipes
* COMMUNITY/Base — community submissions under review
* COMMUNITY/Other — experimental community recipes

Manage enabled sections with:

```bash
anvil sections
```

Only enabled sections are used by fetch, sync, and source operations.

---

## Profiles

Compilation profiles are stored in:

```text
poweruser/profile/
```

Built-in profiles:

* default
* safe
* performance
* hardened

Profiles can be customized during installation and are persisted automatically.

---

## Build Cache

Built artifacts are stored in:

```text
poweruser/build/artifacts/
```

or

```text
/var/cache/artix-poweruser/artifacts/
```

Package database location:

```text
poweruser/db/local.db
```

or

```text
/usr/share/artix-poweruser/db/local.db
```

depending on installation mode.

Tracked metadata includes:

* Installed packages
* Build flags
* Package versions
* Build history

---

## Offline Builds

```bash
anvil fetch-all
```

Downloads all required source archives for enabled recipes, allowing fully offline builds once cached.

---

## Requirements

* Artix Linux live environment
* Internet connection for source downloads
* ~5 GB temporary disk space for kernel builds
* `gum` for TUI (auto-installed if missing)
* Build system supports retries, resume on interruption, and lock recovery
