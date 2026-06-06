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

No. OSI approval is relevant for:

- Inclusion in Linux distribution repositories that require OSI-approved licenses
- Corporate legal departments that mandate OSI compliance
- Formal procurement processes

ArtixForge is an installer script for personal and community use. It is not
a library, a framework, or a component of a larger distribution. The license
protects what the author cares about — preventing plagiarism — while
preserving all the freedoms users expect from open source software.

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

The MIT license already grants all the freedoms the author wanted. The
Forge Attribution License adds exactly two conditions: "don't claim you
wrote it" and protection of project names and trademarks. These conditions
are important to the author, and the chosen license reflects that priority.
There is no plan to seek OSI approval or change the license.

## Could the license prevent inclusion in a distribution?

Possibly. Some distributions (notably Debian, Fedora, and openSUSE) require
all software in their official repositories to carry an OSI-approved license.
The Volk Open License has not been submitted for OSI review. This means
ArtixForge may not be eligible for inclusion in those distributions'
official package repositories.

However, ArtixForge is an installer — it is run from a live ISO, not
installed as a package. It does not need to be in any distribution's
repositories to be useful. Users clone it from GitHub and run it directly.