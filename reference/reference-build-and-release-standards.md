---
title: Build and release house standard
type: reference
scope: [build, release, versioning, distribution]
last_reviewed: 2026-09-16
authors:
  - "Carlos Boeing"
  - "Muse Spark (Muse Code)"
related:
  - reference/reference-oss-standards.md
---

# Build and release house standard

Checklist for any `carlosboeing/*` repository that ships a binary. Derived from `quotacap` (npm/Bun) and `crossrev` (Go) (2026-09-16). One source, not per-repo folklore. The two standards cross-link through `related:`; the OSS standard covers governance, this one covers the build.

## How to use

- **New repo**: follow the checklist below, copying the shape from whichever reference implementation matches the toolchain.
- **Existing repo**: rename to the entry points in section 2, centralise on one build script per section 3, and wire the agreement gate in section 5. The version strings in section 1 fall out of the marking, not the other way round.

## 1. Version strings

| String | Meaning |
|---|---|
| `X.Y.Z` | It came from a release. Nothing else prints this. |
| `X.Y.Z-<short-sha>` | Somebody built it, from a clean tree at that commit. |
| `X.Y.Z-<short-sha>-dirty` | Somebody built it from a modified tree. |

Every local build is marked, not only a dirty one. A clean build past the tag is the case the convention exists for: it is what you get after merging several pull requests without cutting a release, and it is indistinguishable from the release without the suffix.

The mechanism differs by language and should. Node records no build provenance, so QuotaCap computes the string at build time from `git rev-parse` and `git status`. Go stamps `vcs.revision` and `vcs.modified` automatically, so CrossRev composes the same string at runtime and only the local-build bit comes from the installer. Same convention, read identically by a person.

## 2. Install entry points

| Path | Job |
|---|---|
| `install.sh` at the repository root | Downloads a release and installs it. This is the curl-pipe target. |
| `scripts/install-local.<ext>` | Builds from the checkout and installs that. |

Exactly one install entry point at the root, and it means the same thing in every repository: download, not build.

## 3. One build script

`scripts/build-binary.<ext>` compiles the binary, parameterised by target. CI and the local installer call the same script; their builds differ only by the environment in section 4.

A workflow that compiles with its own inline command is the defect this rule exists to prevent: the version-agreement gate then verifies an artifact nobody ships.

## 4. Environment variables

Identical either side of the project prefix:

| Variable | Meaning |
|---|---|
| `<PROJECT>_DEV_BUILD=1` | Marks a local build. Set by the local installer, never by CI. |
| `<PROJECT>_VERSION_OVERRIDE` | Replaces the whole version string. |
| `<PROJECT>_BIN_DIR` | Chooses the install directory. |

## 5. The agreement gate

A release verifies that the version file, the package manifest, the built binary and the tag all agree before publishing. The binary the gate checks is built through the same script as the binaries the release publishes — section 3 is what makes the gate meaningful.

## 6. The convention by language

| Rule | npm / Bun | Go |
|---|---|---|
| Version format | computed at build time from `git rev-parse` and `git status` | composed at runtime from the VCS stamp plus the `-ldflags` mark |
| Root entry point | `install.sh` downloads the release | `install.sh` downloads the release |
| Local installer | `scripts/install-local.mjs` | `scripts/install-local.sh` |
| Build script | `scripts/build-binary.mjs <target>…` | `scripts/build-binary.sh <target> <output>` |
| Dev mark | `QUOTACAP_DEV_BUILD=1` | `CROSSREV_DEV_BUILD=1` |
| Version override | `QUOTACAP_VERSION_OVERRIDE` | `CROSSREV_VERSION_OVERRIDE` |
| Bin dir | `QUOTACAP_BIN_DIR` | `CROSSREV_BIN_DIR` |

## 7. How to verify

```bash
test -f install.sh && grep -q build-binary scripts/install-local.* .github/workflows/release.yml
```

Build once with `<PROJECT>_DEV_BUILD=1` and confirm the version carries `-<short-sha>`; build without it and confirm plain `X.Y.Z`, equal to the version file.

Reference implementation: `quotacap` (npm/Bun), `crossrev` (Go) after 2026-09-16.
