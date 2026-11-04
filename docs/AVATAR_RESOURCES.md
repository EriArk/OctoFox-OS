# Incorporated avatar resources

The installed avatar pack and resolved-avatar disk cache use TAV1 resources.
The approved source models, rig, palette, hair choices and appearance schema are
unchanged. The installed manifest keeps its canonical Git LF bytes (the packer
normalizes Windows CRLF checkouts): saved/network wardrobe recipes keep
their existing `packRevision`. This is asset encapsulation, not a claim of secrecy,
unextractability, DRM, ownership of third-party assets or legal clearance.

## Storage and build

`trainer_avatar_pack` copies manifest/textures/notices and wraps each GLB or binary
geometry patch as `<logical-name>.tav`. It verifies decoded byte equivalence before
completing. CMake installs only this generated directory. Private source assets are
not removed or rewritten; source-only builds without the separately licensed pack
remain possible. Software staging rejects loose avatar geometry, malformed resource
lengths and missing manifest references. Whole-release signatures remain the trust
boundary; the resource MAC is not a substitute for package verification.

The envelope is `TAV1`, little-endian uint32 plaintext length, a fresh 16-byte IV,
AES-256-CBC with PKCS#7 padding, and HMAC-SHA256 over the preceding bytes. Separate
encryption/authentication keys are SHA256 of the public strings
`TrainerOS/avatar-resource/v1/encryption` and
`TrainerOS/avatar-resource/v1/authentication`. These are intentionally available in
the GPL SDK, not credentials. Readers authenticate before decrypting, reject trailing
bytes/invalid padding and cap decoded data at 64 MiB. There is no decompression step.

`sdk/qt/AvatarResource.h` is the shared C++ reader/writer (Qt Core and OpenSSL 3 Crypto).
`sdk/godot/avatar_presenter.gd` uses Godot AESContext/HMACContext and passes decoded
bytes directly to GLTFDocument. The native renderer also reads only into memory.
Texture-only renderer caches may contain PNG/JPEG; geometry caches contain `.tav`.
An invalid resource fails closed; an invalid derived cache is regenerated from the
pack. A `.tav` companion takes precedence over loose developer input even if damaged.

After a successful default-cache resolution, obsolete host-generated
`<64-hex>[-preview].glb` entries are removed from that cache only. No source pack,
custom user pack, profile, outfit recipe or rollback generation is deleted.

## SDK compatibility

Protocol 1 and descriptor schema 1 remain. `glb` and `preview` are historical field
names for resource paths, with `format: "tav1"`; `sha256` still identifies decoded
GLB bytes. Updated clients advertise `avatarFormats: ["tav1"]` in `hello` and see
`avatar.resource: 1` in capabilities. Both new clients still accept old GLB hosts.
Copy the updated presenter **and client** together. Qt clients additionally copy
`AvatarResource.h`, link OpenSSL::Crypto and register the shared AvatarScene/View3D
for portraits as well as animated views. The standalone Qt example documents that
build dependency through its CMake target.

Released clients without the opt-in retain their GLB contract on Linux: an
authenticated peer receives a private `/dev/shm` symlink ending in `.glb` to a
sealed anonymous `memfd` owned by the host. This is a deliberate in-memory legacy
export, not a second model in a permanent cache. It is bounded to two generations
per current/recipe channel and removed on peer disconnect/account revocation. Host
exit/crash closes the anonymous storage; any leftover symlink contains no geometry.
No disk-backed fallback is allowed. If Linux memfd/tmpfs is unavailable, the host
returns `avatar_consumer_update_required` or a cache error; other hosts require the
updated resource-aware consumer. Clients must clear avatars on revocation and must
not copy these resources into their own persistent installation/cache.

This preserves already released native Godot games on the supported Armada route
without modifying their gameplay packages. It does not certify every external app,
sandbox, platform or renderer; those consumers retain their own integration checks.

## Distribution boundary

Original models remain under their separate terms in `assets/avatar/README.md`.
The resource envelope addresses incorporated storage only. The CGTrader
[terms](https://www.cgtrader.com/pages/terms-and-conditions) and the other asset
licences still govern distribution/use. Public source archives exclude standalone
avatar geometry. External runtime sources/notices and public release acceptance
remain separate from this implementation.
