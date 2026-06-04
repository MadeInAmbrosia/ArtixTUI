# Roadmap

This roadmap is updated regularly based on:

- User and tester suggestions
- Upcoming features
- Critical bug fixes (security issues are patched immediately and not listed here)
- Ideas that emerge during development

*Version numbers are not strict release targets. Features may ship earlier or later depending on development pace, tester feedback, and available time. This roadmap reflects general direction, not fixed deadlines.*

## v8.5 (current — `v9-merger` branch)
- ~~Init migration tool~~ (**Done**)
- ~~Desktop environment migration~~ (**Done**)
- ~~UKI builder wizard~~ (**Done — v8.4.x**)
- Bug fixing and stabilization
- ISO generation — build custom Artix live ISOs from a profile
- Full offline installation mode with bundled packages

## v9.0 (planned)
- Merge `v9-merger` → `main`
- Volk's Forge Framework (VFF) integration
- New shared TUI library (extracted from VFF, used by both AF and VFF)
- Graphical (GUI) installer variant (sourced from VFF)
- Proper comments and comment blocks for all scripts

# The think-tank

Ideas under consideration, construction or already being worked on with no real time frame or version numbering.

## Power User Upgrades

- `gartix-tools` — debloated coreutils in C
- Renaming `gartix` to something more original (`Anvil`? `Blacksmith`?)

## Community & Ecosystem

- Translations (German, French, Russian, Chinese, Japanese, Portuguese, Spanish)
- Fleet deployment (`artixforge deploy profile.conf 10.0.0.25`) — Only if I get paid by someone
- ARM and RISC‑V architecture support
- Community recipe promotion workflow (COMMUNITY → OFFICIAL)