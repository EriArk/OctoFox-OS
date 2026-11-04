# ARM64 core replacement candidates

Developer tooling only. This kit does not install cores, update multiplayer
profiles, alter Setup, or certify gameplay/redistribution. The existing 76-core
release lock remains authoritative until explicit candidate promotion.

`candidates.json` pins 18 upstream inputs and retains each previous binary hash.
These commits are **not** asserted to be the source of the previous binaries.
They are selected from upstream history at the 27 September baseline period;
AppleWin explicitly uses its `libretro` branch, not the Windows `master` branch.
`sources.json` is input for `packaging/software/source_capsule.py`.

## Build

Use a new, dedicated Linux staging directory. Copy `candidates.json`,
`aarch64.cmake`, `build.py`, `probe.c`, `probe.py` and `package.py` into it.
Collect `sources.json` through `source_capsule.py`, with output in `STAGE/sources`
and a separate reusable Git cache. The builder checks capsule size/hash,
repository and full commit before extracting via Python's safe data filter.

Build the Dockerfile from this directory (the `.dockerignore` excludes artifacts).
The Ubuntu base is pinned by digest. Record the resulting image ID and
`/toolchain-packages.tsv`. APT package versions are recorded for the actual run;
the Dockerfile does not claim a future APT snapshot or bit-identical rebuild.

Run as the staging owner, with network disabled, a read-only container root,
a temporary `/tmp`, dropped capabilities and only the staging bind mount:

```sh
docker run --rm --network none --read-only --tmpfs /tmp:rw,nosuid,size=1g \
  --cap-drop ALL --security-opt no-new-privileges --user "$(id -u):$(id -g)" \
  -v "$STAGE:/work" -w /work IMAGE_ID \
  python3 /work/build.py --root /work --attempt candidate01
```

Each attempt is new. Failures and originals remain available. `--only CORE...`
limits a retry to changed/failed recipes. The builder runs at most three cores,
with two compiler jobs each. A result is accepted as `built` only if the one
expected output is an ARM64 ELF; this is not a gameplay result.

## Recipe differences and maintenance

- AppleWin: build the libretro frontend only, networking disabled as in the
  libretro-super recipe. Boost headers and `xxd` are build dependencies.
  `patches/applewin-relocatable-resources.patch` fixes an exception found on Flip:
  the optional debug/printer resource lookup canonicalized a missing build-tree
  path beside the RetroArch executable before reaching its existing fallback.
  Use the non-throwing filesystem overload and retain that fallback. Embedded
  firmware, emulation and save formats are unchanged. The patch is tied to the
  pinned upstream commit and its own SHA-256; do not create the old build path
  on an installed machine as a workaround.
- Hatari: build the `hatari_libretro` target only. The unrelated gzip manpage
  target rejects the normalized source timestamps. Explicit `-lm -ludev`
  supplies libraries omitted from the upstream module's link line. `-z defs`
  makes unresolved symbols fail at link time. No emulator source patch.
- WASM-4: explicit `-lm`; relying on the frontend's already-loaded math library
  left `powf` unresolved in a standalone `dlopen(RTLD_NOW)` check.
- Gearcoleco: pass the actual pinned commit abbreviation as `GIT_VERSION`.
  A source archive has no `.git`; otherwise it reports `undefined`.
- DOSBox Pure: `UNAMEM=aarch64` avoids detecting the x86 build host as target.
  The same-number official release asset differs from the existing binary;
  neither that asset nor this candidate is silently substituted for it.

All other recipes retain upstream builds, with explicit cross compilers and
CMake ARM64 target configuration. AppleWin is the only local source patch in
this set. For an update, pin a
new full input, collect its dependencies, use a fresh attempt, repeat affected
ABI/load and runtime checks, then prepare a new managed runtime generation.
Existing cores and saves must remain recoverable; never downgrade saves with a
binary rollback.

For patch-bearing recipes, copy the declared `patches/` files beside `build.py`.
The builder verifies their hashes before extracting/building, checks and applies
them with `git apply`, and records them with the output. The packager requires
the exact same patch list in the selected build and includes those bytes. A
patched recipe cannot retroactively claim a previously unpatched binary.

## Probe and package

Inside the same isolated image, compile `probe.c` using the ARM64 compiler and
`-ldl`; invoke `probe.py` with the artifact directory, probe executable and a new
report path. QEMU loads each library with `RTLD_NOW`, checks 25 required libretro
symbols, API version and system-info. It does **not** call `retro_init`, load a
ROM/BIOS/save, or establish controller, rendering, audio or netplay acceptance.

Choose one successful attempt explicitly for each core in `selection.json`.
Keep the corresponding attempt JSON files, source capsules/manifests, build logs,
`probes-final.json`, `toolchains.json`, package inventories and this recipe folder
under `recipes/`, including the source collector and TrainerOS license notices.
The packager refuses missing/ambiguous selections, changed artifacts/sources,
or an absent successful ABI probe for the selected bytes:

```sh
python3 package.py --root STAGE --attempts ATTEMPT... \
  --probes STAGE/probes-final.json \
  --output NEW-CANDIDATE.tar --report NEW-REPORT.json
```

The archive is independently read back, but deliberately contains no signed
`runtime-set.json`: Setup cannot mistake it for an approved runtime update.

## VirtualJaguar source repair

`jaguar-candidate.json` is a separate one-core plan for the former
`v3.6.1 f9a3c89-dirty` binary. Copy it to `STAGE/candidates.json` in a new staging
directory and use the same build/probe/package tools. It pins the exact upstream
`f9a3c89f58836cb2c45a42ad4edfac047050f30a` capsule and the previous binary hash.
This is a replacement build, not a claim to have recovered the unknown dirty diff.
`patches/virtualjaguar-source-identity.patch` supplies that revision only when
upstream build-id has no Git metadata; it does not change emulation or save code.
The ordinary Git/dirty identity remains effective in a Git checkout.

After exact native checks, `core_promotion.component(..., prior_builds=...)`
requires the previous build records for already promoted cores. The new record
set retains all unchanged identities. `media(...)` adds later candidate kits
under their SHA-256 names and preserves earlier kits, rather than overwriting
their corresponding sources. Missing or mismatched retained build records fail
before output. See the dated release evidence for installation and acceptance.
Promote only after checks in the actual private RetroArch environment and
review of affected launch/save/input and multiplayer paths. Keep source/notices
and external dependency review distinct from those runtime checks.
