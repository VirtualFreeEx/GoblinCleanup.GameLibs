<!-- SPDX-License-Identifier: MIT -->
# Game libraries for Goblin Cleanup.

This repository contains tooling to build a `GoblingCleanup.GameLibs` package
on a Unix-like system. WSL might work, but has not been tested. I run
Linux, so this is why the tooling has been made with all the bullshit
it has. pleasebepatientimautistic.

## Versioning

The package is versioned in the following way:
`$GAME_VERSION+$MANIFEST_REVISION`. Game version is the officially given
version revision. For example, as of writing this the last version is patch 8.
Therefore, the game version would be `8.0.0`. Manifest revision is the version
of the manifest for the depot of the game on steam at the time of building
the package.

## Building

To build the package, simply run `just build $VERSION $GAMEPATH`, where
`VERSION` is the version picked by you as described in the Versioning
section, and the game path is the path to your local copy of the game. A
NuGet package will appear in your working directory.
