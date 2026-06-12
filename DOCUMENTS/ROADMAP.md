# Roadmap

This roadmap is updated regularly based on:

- User and tester suggestions
- Upcoming features
- Critical bug fixes (security issues are patched immediately and not listed here)
- Ideas that emerge during development

*Version numbers are not strict release targets. Features may ship earlier or later depending on development pace, tester feedback, and available time. This roadmap reflects general direction, not fixed deadlines.*

## v8.6 (current — `v9-merger` branch)
- ~~Init migration tool~~ (**Done**)
- ~~Desktop environment migration~~ (**Done**)
- ~~UKI builder wizard~~ (**Done — v8.4.x**)
- ~~ISO generation~~ (**Done**)
- ~~Full offline installation mode with bundled packages~~ (**Done**)
- ~~Graphical (GUI) installer variant~~ (**Done — GTK persistent config window, progress viewer**)
- ~~Renaming `gartix` to something more original (`Anvil`? `Blacksmith`?)~~ (**Renamed to Anvil to fit the Forge/Blacksmithing theme of the project naming**)
- Bug fixing and stabilisation
- ~~Adding sonicDE support(?)~~ (**Done**)

## v9.0 (planned)
- Merge `v9-merger` → `main`
- Volk's Forge Framework (VFF) integration
- ~~New shared TUI library~~ (**Abandoned – Building a TUI library is a pain in the ass**)
- Proper comments and comment blocks for all scripts

# The think-tank

Ideas under consideration, construction or already being worked on with no real time frame or version numbering.

## Power User Upgrades

- `gartix-tools` — debloated coreutils in C

## Community & Ecosystem

- Translations (German, French, Russian, Chinese, Japanese, Portuguese, Spanish)
- Fleet deployment (`artixforge deploy profile.conf 10.0.0.25`) — Only if I get paid by someone
- ARM and RISC‑V architecture support
- Community recipe promotion workflow (COMMUNITY → OFFICIAL)