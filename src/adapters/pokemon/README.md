# Pokemon experience

`PokemonExperience::manifest()` owns the compatibility alternatives and asset
family profiles. `PokemonExperienceViews.qml` owns presentation; the controllers,
persona and local navigation in this directory own game-specific UI behavior.
Protected save readers/writers and runtime mechanisms remain reusable services.

Current alternative routes:

- Local TrainerOS catalogue identity plus platform, from the existing catalogue.
- ScreenScraper game ID plus GBA platform: Emerald 84406, FireRed 84408, LeafGreen
  84409. Verified on 9 October 2026 against the provider's
  [Emerald](https://www.screenscraper.fr/gameinfos.php?gameid=84406&plateforme=12),
  [FireRed](https://screenscraper.fr/gameinfos.php?gameid=84408&plateforme=12) and
  [LeafGreen](https://www.screenscraper.fr/gameinfos.php?gameid=84409&plateforme=12)
  records. Other provider IDs require explicit reviewed rules; no fuzzy lookup.
- Raw GBA header codes BPEE/BPRE/BPGE/AXVE/AXPE, with fixed-byte/header-checksum
  validation. This works with arbitrary filenames and no scraper credentials.
  Codes may survive ROM hacks, so this is family presentation only.
- Stored `pokemon` domain as a weaker legacy migration fallback. Existing games
  do not require rescraping. Historic domain classification is not exact identity.

The existing exact-ROM Gen III providers still validate their own content/save
revisions and checksums before exposing semantic progress or protected changes.
A catalogued game or plausible header does not bypass those checks. No standalone
save identification or ROM-art extraction is claimed by this increment.

Asset family `art` uses the existing `ClassicArt` version-1 bootstrap index and
entity/form mapping; `sprites` uses `SpriteArt` version-1 sprite index, checked
assets/credits and exact-form targets. Their new default roots are
`<state>/adapters/pokemon/packs/art/` and `.../sprites/`. Existing
`artwork/bootstrap` / `artwork/sprites` roots remain compatible when the scoped
family has not been installed. No files are copied, removed or publicly bundled.
The directory arguments (including `--art-dir` / `--sprite-dir`) no longer activate
imported art: both providers default to `ArtSource::Original`. The internal
`Imported` mode retains validation for future explicit selection and import tests;
production does not select it. Graphics switches remain owner-deferred.

Cuboid v1 is now the default on every presentation surface: exact-key
recipes cover the offline catalogue; unknown keys use a neutral symbolic cube.
ClassicArt supplies original illustrations; SpriteArt supplies all clips and
portraits even when legacy packs are installed. The original renderer shares one canvas
across actions and uses the existing asynchronous image provider/cache. It is
not an installed pack and grants no save capability. [Contract and delivery](../../../docs/CUBOID_CREATURES.md).

Both families declare no extraction sources yet. Pack Studio, installable external
packs/adapters, and ROM-native extraction/cache/migration keep their #59/#92/#95–97
acceptance; changing the manifest is not an implementation of a decoder.

## Sticker home (14 November 2026)

The host now presents all nine declared screens as large sticker buttons, using
new original generated art owned by this adapter. L2/R2 cycle screens after entry;
Back returns to the home once local interactions close. The provider still owns
Party/Boxes/Guide/Care/Shop/Playroom/persona/history behavior and protected save
operations. [Current navigation contract](../../../docs/ADAPTER_HOME.md).

## Workspace categories (2 November 2026, superseded navigation)

The descriptor owns Team (Party/Boxes), Field Guide, Center (Care Center/Shops/
Playroom), and Trainer (Trainer Card/Journey/Hall of Fame). The shared host keeps
per-category screen history, with no game-specific routing branches. Select can
open this registered workspace without launching the game. Exact save admission
and installed private pack precedence are unchanged. [Evidence and unfinished
cuboid fallback #161](../../../docs/evidence/2026-11-02-emerald-workspace/README.md).
