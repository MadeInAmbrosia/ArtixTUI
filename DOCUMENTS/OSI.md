# License & Open Source Status

## Is the Forge Attribution License 1.0 open source?

Yes, in the commonly understood sense of the term. The license grants
everyone the right to use, copy, modify, merge, publish, distribute,
sublicense, and sell the software. The source code is freely available,
freely modifiable, and freely redistributable.

## Is it OSI-approved?

No. The Open Source Initiative (OSI) maintains the formal Open Source
Definition — a 10-point checklist that a license must satisfy to carry
the OSI "certified open source" designation. The Forge Attribution License has
not been submitted to the OSI for review, and condition 2 (prohibiting
misrepresentation of authorship) may not align with every element of the
OSI definition.

This is a legal formality. It has no bearing on your practical freedoms
to use, modify, or share the software.

## Does OSI approval matter for this project?

Generally, no. OSI approval is relevant for:

    Inclusion in Linux distribution repositories that require OSI-approved licenses

    Corporate legal departments that mandate OSI compliance

    Formal procurement processes

ArtixForge is a modular deployment framework — it includes an installer TUI/GUI, system migration tools, an ISO builder, a source-based build system (anvil/Power User Mode), and the forge-gui Python/GTK library. While parts of it could be packaged individually (e.g., forge-gui as a PyPI module), the project as a whole is distributed as a toolkit for advanced Artix Linux deployment. The license protects what the author cares about — preventing plagiarism and protecting project names — while preserving all the freedoms users expect from open source software.

## Does condition 2 discriminate against fields of endeavor?

No. Condition 2 does not restrict how the software is used, who may use
it, or for what purpose. It solely requires that attribution be preserved
and that no one falsely claims original authorship. This is an attribution
and integrity requirement, not a field-of-use restriction. The software
may be used commercially, academically, militarily, or for any other
purpose without limitation.

## Is ArtixForge a fork of Artix Linux?

No. ArtixForge is an independent installer for Artix Linux. It does not
repackage, relicense, or redistribute Artix Linux. The installed system
is standard Artix Linux, fully compatible with all official repositories
and packages.

## Is Power User Mode a separate distribution?

No. Power User Mode builds select packages from source during installation.
The base system is installed from Artix repositories using `basestrap`. The
package manager is `pacman`. The installed system identifies as Artix Linux.
Power User Mode is a build overlay, not a distribution.

## What if the Artix Linux project objects to this project?

ArtixForge exists to serve the Artix community. It drives adoption, eases
installation, and respects the Artix ecosystem. If Artix maintainers ever
express concerns about branding, attribution, or scope, the project will
engage in good faith to address them.

## Why not use an existing OSI-approved license?

The MIT license already grants all the freedoms the author wanted — use, copy, modify, distribute, even sell. The Forge Attribution License adds exactly two conditions:

    "Don't claim you wrote it" — requires preserving original authorship credit and clearly marking modifications.

    Protection of project names and trademarks — prevents someone from taking the code, renaming it slightly, and confusing users about its origin.

These conditions matter to the author. They prevent "embrace, rename, extinguish" tactics and ensure that if someone improves ArtixForge, they share those improvements under the same terms, with credit preserved.

There is no plan to seek OSI approval or change the license. The license is stable, clear, and grants all essential freedoms.

## Could the license prevent inclusion in a distribution?

Possibly — but mostly in theory. Some distributions (Debian, Fedora, openSUSE) require OSI-approved licenses for their main repositories. The Forge Attribution License has not been submitted for OSI review, so ArtixForge would not qualify for inclusion in those repositories.

In practice, this rarely matters because:

    Arch Linux / Artix Linux / AUR: The AUR does not require OSI approval. A PKGBUILD already exists in the repo structure. Packaging is straightforward.

    Custom repositories: ArtixForge can be distributed via any custom pacman repo without OSI approval.

    ISO bundling: The project generates ISOs. Those ISOs can include ArtixForge regardless of distribution policies.

    Container / script distribution: Users clone and run directly from GitHub. No package repository involvement is required.

If a distribution wants to package ArtixForge but hits license policy issues, the author is open to discussing relicensing specific components (e.g., forge-gui as a library) under an OSI-approved dual license. The core framework (the install script, anvil, migrations) will remain under the Forge Attribution License.