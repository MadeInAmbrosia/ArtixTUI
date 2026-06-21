# ISO Generation

Build custom Artix live ISOs from ArtixForge profiles.

## Usage

From the ArtixForge installer main menu, select **Build ISO**, then configure
the ISO using a Quick Profile, full customization, or a saved configuration file.

Optionally, build an offline-capable ISO with all packages bundled.

## Structure

| File | Purpose |
|------|---------|
| `common.sh` | Package list generation and artools profile creation |
| `build.sh` | Build orchestration – calls `buildiso` |
| `offline.sh` | Offline repository creation for disconnected installs |
| `cleanup.sh` | Workspace cleanup after build |
| `tui.sh` | TUI wizard for ISO configuration |

## Requirements

- `artools` and `iso-profiles` packages (installed automatically if missing)
- `loop` kernel module loaded
- Sufficient disk space for package downloads and ISO creation