# Roadmap

This roadmap is updated regularly based on:

- User and tester suggestions
- Upcoming features
- Critical bug fixes (security issues are patched immediately and not listed here)
- Ideas that emerge during development

*Version numbers are not strict release targets. Features may ship earlier or later depending on development pace, tester feedback, and available time. This roadmap reflects general direction, not fixed deadlines.*

## v8.2 — Filesystem & Security Hardening (Artix Forums ideas)
Target: Late May / Early June 2026

- BTRFS snapshot integration with snapper + GRUB boot menu entries ([Suggested on the Artix forums](https://forum.artixlinux.org/index.php/topic,9865.msg59194.html#msg59194))
- Replace `ufw` with something more modern.
- Categorized extras (Editors, Browsers, File Managers, Terminals, etc.)
- Real SHA256 checksums
- Lighter network connectivity check (DNS lookup)
- Screenshots added to README
- Any bug fixes needed as v8.1.1.0 is largely untested for it's current features.


# The think-tank

## Community & Ecosystem

- More Quick Install profiles (Gaming, Development, Media, etc.)
- Custom template files for quick-install with saved configuration on the target system
- Community recipe promotion workflow (COMMUNITY to OFFICIAL)
- Recipe popularity tracking

## Distribution Toolkits / Poweruser Upgrades

- Custom live ISO builder (Power User mode only)
- ARM and RISC-V architecture detection
- Full offline installation mode with bundled packages
- `gartix-tools` — ArtixTUI's own "debloated" coreutils in C (in development)

## Under Consideration

- Standalone installer ISO
- Graphical (GUI) installer variant
- Translations (German, French, Russian, Chinese, Japanese, Portuguese, Spanish)