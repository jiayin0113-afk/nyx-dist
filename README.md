# nyx-dist

The Nyx distribution: **release channels**, the **package index**, and the packages themselves.

Everything here is a static file served over HTTPS from GitHub. That is the whole design — there is no
daemon, no database and no API to authenticate against, which is what makes it something a reader can
audit by opening a browser.

## What is here

| File | Read by | Purpose |
| --- | --- | --- |
| `channels.nyx-channels` | `nyx upgrade` | one line per release channel: the newest version on it and where its archive is |
| `registry.nyx-registry` | `nyx resolve`, `nyx update` | the package index: one line per published package version |
| `packages/*.tar.gz` | `nyx resolve` | the package archives the index names |
| `packages/*/` | — | the sources those archives were built from, so a change is reviewable |
| `tools/build_archives.ps1` | — | rebuilds every archive from the sources above |

Toolchain archives are attached to **GitHub Releases** rather than committed, so this repository stays
small enough to read. `channels.nyx-channels` points at them by URL.

## Release channels

| Channel | Meaning |
| --- | --- |
| **Stable** | what most people should run |
| **Preview** | published more often than Stable, expected to work |
| **Beta** | features are still moving; behaviour can change between builds |
| **Test Edition** | the bleeding edge: published from a work-in-progress branch, may not build a program at all |

A channel is a *choice*, not a property of a build. `nyx upgrade --channel=Preview` selects one and
remembers it in `nyx.channel` next to the executable; `nyx upgrade` then follows it.

Versions are compared as dotted numbers, and a `-suffix` sorts **before** its release, so
`3.14.0-beta.2` is older than `3.14.0`. That is what makes Beta usable: a beta never replaces the
release it precedes.

Publishing a channel without an archive URL is allowed and means "this version exists, there is nothing
to fetch yet" — which is the honest state of a channel whose branch is not building.

## Packages

A package is a directory of Nyx modules plus a `nyx.package` manifest. `nyx resolve` fetches it,
unpacks it into `deps/<name>/`, and treats that directory as a module search root — exactly like the
standard library's `lib/`.

The index drives **transitive** resolution: `nyx resolve` reads the manifest inside each fetched
package, and fetches what *that* declares, until nothing new appears. `Nyx.Http` above depends on
`Nyx.Json`, so fetching `Nyx.Http` brings `Nyx.Json` with it even when the project never names it.

To publish a package:

1. add its sources under `packages/<Name>/`;
2. run `tools/build_archives.ps1` to produce `packages/<Name>-<version>.tar.gz`;
3. add one line to `registry.nyx-registry`.

`official` marks a package the language project publishes. It is a label for the reader: an official
package goes through the same fetch, unpack and resolution path as any other.

## Layout of a package archive

```
Nyx.Json/
├── nyx.package                 the manifest: name, version, and this package's own dependencies
└── Nyx/Json/Parser.nyx         modules under their module path
```

The single top-level directory is what the resolver treats as the package root, so
`import Nyx.Json.Parser.parseInteger` resolves to `Nyx.Json/Nyx/Json/Parser.nyx`. A flat archive is also
accepted and unpacked as-is.
