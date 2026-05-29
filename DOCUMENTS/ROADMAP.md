# Roadmap

This roadmap is updated regularly based on:

- User and tester suggestions
- Upcoming features
- Critical bug fixes (security issues are patched immediately and not listed here)
- Ideas that emerge during development

*Version numbers are not strict release targets. Features may ship earlier or later depending on development pace, tester feedback, and available time. This roadmap reflects general direction, not fixed deadlines.*

## v8.3 — Power User & Recovery Hardening (DONE!)
Target: June 2026 — Completed 2026-05-29

- `gartix` modularized — split into `gartix`, `gartix_common.bash`, `gartix_cli.bash`, `gartix_tui.bash`
- `gartix recovery` command for checking and repairing source-built packages
- `repair_kernel` implemented in both recovery menu and `gartix recovery`
- Recovery scripts modularized — `scripts/recovery/` split into `core.sh`, `detect.sh`, `repair.sh`
- `scripts/tui/menus/` split into 9 focused sub-files
- `poweruser/tui/menu_poweruser.sh` split into 6 sub-files under `menup/`
- Kernel recipe defaults to `localmodconfig` for reliable module detection
- Three new Quick Install profiles: Gaming, Development, Media
- Custom profile loader and auto-save to `/etc/artixforge-profile.conf`
- Screenshots and logo added to README

## v8.4 — Community & Ecosystem
Target: TBD

- Community recipe promotion workflow (COMMUNITY to OFFICIAL)
- Recipe popularity tracking
- Recipe self-healing — auto-detect outdated source URLs and bump versions, notify maintainer

# The think-tank

## Poweruser Upgrades

- Full offline installation mode with bundled packages
- `gartix-tools` — debloated coreutils in C

## Under Consideration

- Graphical (GUI) installer variant
- Translations (German, French, Russian, Chinese, Japanese, Portuguese, Spanish)