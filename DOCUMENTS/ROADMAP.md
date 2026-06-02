# Roadmap

This roadmap is updated regularly based on:

- User and tester suggestions
- Upcoming features
- Critical bug fixes (security issues are patched immediately and not listed here)
- Ideas that emerge during development

*Version numbers are not strict release targets. Features may ship earlier or later depending on development pace, tester feedback, and available time. This roadmap reflects general direction, not fixed deadlines.*

## v8.5 ???
- Bug fixing?
- ????

# The think-tank

Ideas under consideration, construction or already being worked on with no real time frame or version numbering.

## Power User Upgrades

- Full offline installation mode with bundled packages
- `gartix-tools` — debloated coreutils in C (IDK)
- Renaming `gartix` to something more original (`Anvil`? `Blacksmith`?)

## ArtixForge Toolkit (v9+ territory?)

- ISO generation — build custom Artix live ISOs from a profile
- A new framework for both TUI and GUI
- Proper comments and comment blocks for all scripts (lol)
- Graphical (GUI) installer variant
- Init migration tool (convert OpenRC ↔ runit ↔ dinit ↔ s6 in‑place)
- Desktop environment migration (swap KDE ↔ XFCE ↔ Sway etc. without reinstall)
- UKI builder wizard (automated Unified Kernel Image generation with Secure Boot signing)

Might as well make my own Artix-based distribution at this point. Except that I don't have time for that.

## Community & Ecosystem

- Translations (German, French, Russian, Chinese, Japanese, Portuguese, Spanish)
- Fleet deployment (`artixforge deploy profile.conf 10.0.0.25`) — Only if I get paid by someone
- ARM and RISC‑V architecture support (*Not as critical to implement but would make ArtixForge feature-complete*)
- Community recipe promotion workflow (COMMUNITY → OFFICIAL)