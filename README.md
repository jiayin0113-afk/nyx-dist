# nyx-dist

The Nyx distribution: **release channels**, the **package index**, and the packages themselves.

Everything here is a static file served over HTTPS from GitHub. That is the whole design — there is no
daemon, no database and no API to authenticate against, which is what makes it something a reader can
audit by opening a browser.

## Trusting this repository

The two published files — `channels.nyx-channels` and `registry.nyx-registry` — are signed by the **Nyx
Release Signing** key. The signature is a sibling file (`.sig`) holding two lines:

```
signer C86CA478EC3046CA
signature 8dc09eb4...827e4
```

The signature covers the file's bytes **exactly as published**, so it is checked against what was downloaded
rather than against a re-serialisation. That is what makes the check mean something: no part of the client's
own writing has to be canonical for the signature to hold.

The public key is in [`shield/official.pub`](shield/official.pub). Its fingerprint is

```
C86C A478 EC30 46CA
```

and the first eight bytes of the SHA-256 of the public point *are* that fingerprint, so it can be checked
rather than believed.

### Trusting it

Trust is a decision made on your machine, not a setting read from a server. Signing is enforced as soon as
the key is trusted, and refused until then:

```powershell
# 1. fetch the official public key and confirm the fingerprint above
curl -sSLo official.pub https://raw.githubusercontent.com/jiayin0113-afk/nyx-dist/main/shield/official.pub

# 2. make the decision, once
nyx shield trust C86CA478EC3046CA (Get-Content official.pub -Raw).Trim() "Nyx Release Signing"

# 3. every later `nyx upgrade` and `nyx resolve` now verifies the signature and refuses a file that fails
nyx upgrade --check
```

Until step 2, an update reports the signer and refuses:

```
error: refusing 'channels.nyx-channels': the file is signed by C86CA478EC3046CA, and that key is not
trusted here: ... Trust it with `nyx shield trust`, or import the record that vouches for it
```

That refusal is the point of the feature. A file whose signature does **not** match is refused even when the
signer is trusted — that is what catches an index with an extra line in it.

### The trust network

You do not have to decide about every key yourself. If you trust one key and that key has signed another,
the second is trusted through it:

```
nyx shield sign-key <their public key in hex> "Their Name" > their.rec
nyx shield import their.rec
nyx shield verify-trust
```

`import` stores records but grants **nothing**: a key becomes trusted because a person said so. `verify-trust`
prints every route, in full, with its length — `A -> B -> C` rather than a bare "trusted", because how many
signatures the claim rests on is the part you need in order to disagree with it.

A forged `SIGNED-BY` line creates no path: the signature is checked, so editing the file is not enough.

## What is here

| File | Read by | Purpose |
| --- | --- | --- |
| `channels.nyx-channels` | `nyx upgrade` | one line per release channel: the newest version on it and where its archive is |
| `channels.nyx-channels.sig` | `nyx upgrade` | the signature over the line above |
| `registry.nyx-registry` | `nyx resolve`, `nyx update` | the package index: one line per published package version |
| `registry.nyx-registry.sig` | `nyx resolve`, `nyx update` | the signature over the line above |
| `shield/official.pub` | `nyx shield trust` | the official public key, to be trusted once |
| `packages/*.tar.gz` | `nyx resolve` | the package archives the index names |
| `packages/*/` | — | the sources those archives were built from, so a change is reviewable |
| `tools/build_archives.ps1` | — | rebuilds every archive from the sources above |

Toolchain archives are attached to **GitHub Releases** rather than committed, so this repository stays
small enough to read. `channels.nyx-channels` points at them by URL.

**A private key is never in this repository.** `ncsPMF.NCS` and `trusted.nps` are in `.gitignore` as well as
being kept outside the working tree, so a careless `git add -A` cannot publish a signing key.

## What the signature covers, and what it does not

The signature covers the **index and the channels file**. Each package line in the index carries a SHA-256 of
its archive, and that digest is inside the signed file — so a package is covered transitively: to change what
a package contains, an attacker would have to change the index, and the index is signed.

What the digest adds on its own is detection of a **corrupted transfer**. What the signature adds is
detection of a **substituted file**. They answer different questions and neither replaces the other: a server
that can be made to send a different archive can be made to send a different digest for it.

What neither covers is the machine you are running on. A signature says the file came from the key's holder;
it says nothing about whether the key holder's own machine was trustworthy when they made it.


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
