# Roadmap

This roadmap is updated regularly based on:

- User and tester suggestions
- Upcoming features
- Critical bug fixes (security issues are patched immediately and not listed here)
- Ideas that emerge during development

*Version numbers are not strict release targets. Features may ship earlier or later depending on development pace, tester feedback, and available time. This roadmap reflects general direction, not fixed deadlines.*

## v8.2 — Filesystem & Security Hardening (DONE!)

- BTRFS snapshot integration with snapper + GRUB boot menu entries ([Suggested on the Artix forums](https://forum.artixlinux.org/index.php/topic,9865.msg59194.html#msg59194))
- Replaced `ufw` with `firewalld`
- Categorized extras (System Tools, Editors, Browsers, File Managers, Terminals, Shell & Prompt, Monitoring, Media)
- Real SHA256 checksum tooling (`gartix checksum`) with SKIP warnings during build
- Lighter network connectivity check (DNS lookup via dig/nslookup)
- Recovery mode overhaul: detects LVM, ZFS, UKI, coreutils, Power User state, boot health, fstab health, pacman integrity
- Recovery repair system: automatic fstab regen, pacman lock removal, base reinstall, kernel reinstall, initramfs rebuild, GRUB repair
- Rootkit scanning via rkhunter in Recovery mode
- vxwm window manager support (dwm fork, compiled from source)
- Volk's Personal Quick Profile (dinit, KDE minimal, LightDM, source-built kernel)
- LightDM support for KDE Plasma with automatic SDDM replacement
- Kernel recipe switched to `localmodconfig` — reliable module detection, no more dependency guessing
- Project renamed to ArtixForge
- Community recipes repository renamed to ArtixForge-recipes

## v8.2.x? — Community & Polish
Target: June 2026

- Screenshots added to README
- Re-adding a new image / logo to the README
- More Quick Install profiles (Gaming, Development, Media)
- Custom template files for quick-install with saved configuration on the target system
- Community recipe promotion workflow (COMMUNITY to OFFICIAL)
- Recipe popularity tracking
- Recovery mode: `repair_kernel` function to rebuild custom kernel with updated config
- Any bug fixes from v8.2 testing

# The think-tank

## Distribution Toolkits / Poweruser Upgrades

- Custom live ISO builder (Power User mode only)
- ARM and RISC-V architecture detection
- Full offline installation mode with bundled packages
- `gartix-tools` — ArtixForge's own "debloated" coreutils in C (in development)

## Under Consideration

- Standalone installer ISO
- Graphical (GUI) installer variant
- Translations (German, French, Russian, Chinese, Japanese, Portuguese, Spanish)