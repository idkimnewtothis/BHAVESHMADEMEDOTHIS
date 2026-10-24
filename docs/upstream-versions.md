# Upstream source audit

Inspected 2026-10-22. These are source findings, **not runtime compatibility results**.

| Component | Pinned reference | Commit |
| --- | --- | --- |
| ShonenX shell | main at inspection | `4d684a528ac33d5e7ab78b105903d7b0dd41712b` |
| Aniyomi extensions-lib, latest non-prerelease tag | v17 | `971ce96e76202bb35432fe71f92553e3ae40d01d` |
| Aniyomi extensions-lib compatibility reference | 14 | `f33cc241dee8f7561b97f0aa0921c58f0f8a3b8c` |
| Aniyomi extensions-lib comparison | v16 | `a776b99df09003423eb13d9816323aaa09af7c24` |
| Aniyomi app, latest stable release | v0.18.2.1 | `97414446b8a95994c72dd33c41c971a89d4d25b8` |
| Mihon schema reference, latest stable release | v0.21.2 | `9612d955db3165e1578fdf9ff19ca9b7762c4a46` |
| yuzono/anime-repo (GitHub redirects to mojuru/anime-repo) | repository HEAD at inspection | `ba5036afbbe9806143f0c4a3ea405421b61ba253` |

The extensions-lib repository has no GitHub Releases entries. `v17` is its latest stable **tag**, not a GitHub release. The Android bridge pins `com.github.aniyomiorg:extensions-lib:v17` as an isolated reference configuration, verified by SHA-256 before every Android build; stub bodies are not packaged or placed on the host compile classpath. Its Kotlin 2.4 metadata is newer than the host Kotlin 2.2 compiler. Artifact SHA-256: `6912054943d9c88f9885c8bb579d17a7c4b71cedf437b95986ebb13fdd180de2`. Bundled runtime methods are checked separately against compiled extension references.

## Runtime contract

[AnimeExtensionLoader.kt](https://github.com/aniyomiorg/aniyomi/blob/97414446b8a95994c72dd33c41c971a89d4d25b8/app/src/main/java/eu/kanade/tachiyomi/extension/anime/util/AnimeExtensionLoader.kt) explicitly supports **14, 16, 17**. It reads the extension-lib manifest metadata, falling back to the version name without its final component. A numeric range would incorrectly accept unsupported versions.

[Library v17 source](https://github.com/aniyomiorg/extensions-lib/tree/971ce96e76202bb35432fe71f92553e3ae40d01d/library/src/main/java) is a compile-time stub API: many bodies throw `Stub!`. It cannot itself implement a host runtime. Comparing v16 and v17 shows v17 combined `getAnimeEpisodeUpdate` and `getAnimeSeasonUpdate`, related-anime APIs, and episode `memo`. Legacy details/episode methods remain deprecated. Adapters and runtime implementations require verification against compiled APKs. The tag 14 → v16 diff removes legacy Rx `fetchAnimeDetails` / `fetchEpisodeList` APIs from the stub, adds seasons and hosters, and adds episode `fillermark`, `summary`, and `preview_url`. This proves that the interfaces differ; compatibility depends on host adapters and the actual members each APK uses. No blanket claim that lib 16 breaks extensions is supported by this audit. Playback API changes were inspected only as source; no streams were requested.

## Store schemas

- [Aniyomi index.proto](https://github.com/aniyomiorg/extensions-lib/blob/971ce96e76202bb35432fe71f92553e3ae40d01d/index/index.proto) defines protobuf and equivalent JSON, optionally gzip compressed. Store fields: name=1, badgeLabel=2, signingKey=3, contact=4, embedded extensionList=101 or extensionListUrl=102.
- Anime extension fields: name=1, packageName=2, resources=3, extensionLib=4, versionCode=5, versionName=6, contentWarning=7, isTorrent=8, sources=9. Source IDs are signed 64-bit values and must not pass through JavaScript floating-point conversion.
- [Mihon NetworkExtensionStore](https://github.com/mihonapp/mihon/blob/9612d955db3165e1578fdf9ff19ca9b7762c4a46/data/src/main/java/mihon/data/extension/model/NetworkExtensionStore.kt) uses **sources=8**, with source message=7. Aniyomi uses sources=9 and source message=6. The formats must not be decoded interchangeably or treated as executable manga sources.
- Legacy `index.min.json` is an array with `name`, `pkg`, `apk`, `lang`, `code`, `version`, `nsfw`, and optional `sources` (`id`, `lang`, `name`, `baseUrl`). Legacy APK URLs resolve under `apk/`. Library version is the version prefix before the last dot.
- [Legacy metadata](https://github.com/aniyomiorg/aniyomi/blob/97414446b8a95994c72dd33c41c971a89d4d25b8/data/src/main/java/mihon/data/extension/anime/model/NetworkLegacyAnimeExtensionRepo.kt) reads `repo.json`: `meta.name`, optional `meta.shortName`, `meta.website`, `meta.signingKeyFingerprint`, and optional `index_v2` redirect. There is no separate metadata API identified; extension metadata comes from the index.
- [Store service](https://github.com/aniyomiorg/aniyomi/blob/97414446b8a95994c72dd33c41c971a89d4d25b8/data/src/main/java/mihon/data/extension/anime/service/AnimeExtensionStoreService.kt) follows `index_v2`, accepts JSON/protobuf/gzip and external extension lists. An index need not literally be named `index.pb`.
- Aniyomi accepts `aniyomi://add-repo?url=...` and `aniyomi://extension-store?url=...` (MainActivity.isAddAnimeExtensionStoreIntent).
- The loader computes SHA-256 over signing certificate bytes. A repository fingerprint is not an APK file hash.

## Test repository observations

Fetched real pinned `repo.json` and `index.min.json` successfully. The metadata fingerprint is `cbec121aa82ebb02aaa73806992e0368a97d47b5451ed6524816d03084c45905`. The index lists AnimeKai (Unoriginal), package `eu.kanade.tachiyomi.animeextension.en.kotokai`, version 16.9, and AnimePahe version 16.55. These are index observations only; APK installation, ABI and source calls remain UNVERIFIED.

## Baseline setup

ShonenX pins Flutter 3.41.9 in `.fvmrc`; Android requires JDK 21 and Flutter compile SDK 36 / NDK 28.2.13676358. Release minification and shrinking are enabled and have not been changed.

Full recursive submodule initialization fails for `lib/source_engine/inbuilt_sources`: `fatal: could not read Username for https://github.com: terminal prompts disabled`. Its providers are empty and current CI initializes only the four package submodules. Those four were checked out at the recorded gitlink commits. No access workaround was used.

## ShonenX+ manga restoration — 2026-10-24

- Mihon latest stable rechecked through GitHub: **v0.21.2**, commit **9612d955db3165e1578fdf9ff19ca9b7762c4a46**. Loader explicitly supports **1.4 and 1.6** (`ExtensionLoader.kt`); host now vendors the corresponding source-api.
- Keiyoushi repository branch, `git ls-remote`: **6d666b4f2beba067f8aa0ca98946cc6cb7fc589d**. Saved live repo.json/index.pb/legacy JSON in test/fixtures/keiyoushi. Index parses 1,426 manga entries; legacy JSON contains Outdated App placeholders.
- APK signer from repo.json: **9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2**.
- Exact host source hashes and update gates: mihon-api-pin.json and upstream-maintenance.md.
- Direct GitHub commits API returned HTTP403; the repository commit was verified using Git transport instead.


## ShonenX+ 2.1 repair audit — 2026-10-24

- Mihon stable `v0.21.2`, commit `9612d955db3165e1578fdf9ff19ca9b7762c4a46`; inspected `SourcePreferencesScreen.kt` and the public source API. Android preferences now use the same `source_<id>` storage namespace, extension defaults, and change listeners.
- Keiyoushi repo branch `6d666b4f2beba067f8aa0ca98946cc6cb7fc589d`; current protobuf index contains 1,426 entries. The exact GitHub `/raw/repo/index.pb` URL is supported. Manga source field remains8; APK fingerprint comes from embedded protobuf or repo.json.
- Yuzono repo branch `d79665e2915347faf7af9db47d11d3001c33fd06`; live index contains 250 entries. AnimeKai16.9, AnimePahe16.55, KickAssAnime14.62 and WCOStream14.15 were downloaded via the production transport and certificate checked.
- Aniyomi/extensions-lib pins remain as recorded above (v17 reference artifact checksum verified by Gradle); supported host versions remain14,16,17. Manga host supports1.4,1.6.
- MovieBox HTTP contract: `solo12345689/moviebox-internal-api` commit `e1dfbe5b2bf8c9559fa7631cb8a35172d651fe85`, `moviebox_api_server.py`, dashboard API client and category documentation. Independent client implementation; no upstream server implementation, embedded credentials, or signing material copied. No license file was found in the referenced repository. Series category 19 follows its documented Western TV mapping; category 3 is education/kids and is not used for series.

The MovieBox GitHub URL is a server code repository, not a hosted API endpoint. Configure a user-operated HTTPS server through MovieBox UI. Catalog parsing is tested with synthetic responses; live server compatibility requires a reachable configured endpoint.
