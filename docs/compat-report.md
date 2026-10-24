# Extension compatibility report

Original anime audit: 2026-10-22; ShonenX+ refresh: 2026-10-24. No playback or real video downloads were attempted.

The four real APKs came from yuzono/anime-repo commit `ba5036afbbe9806143f0c4a3ea405421b61ba253`. All four passed apksigner and match repo.json certificate fingerprint `cbec121aa82ebb02aaa73806992e0368a97d47b5451ed6524816d03084c45905`.

Static ABI comparison against the compiled host classes passed for 200 API member references (AnimeKai 57, AnimePahe 59, KickAssAnime 47, WCOStream 37). Final release-DEX results are in abi-report.json when present. The checker inspects referenced method/field descriptors and known override signatures, follows inherited members, and fails on missing members. Reflection and runtime behavior remain outside that static check. A negative mutation test verifies that removing a required method fails the gate.

## Requested live matrix

Device source run incomplete is attached (`adb devices` returned an empty list); `/dev/kvm` is absent. The Android installer/source runtime could not be exercised. Network access to GitHub succeeded; this is **not** a website-network block. No source search/details/episode responses have been fabricated or presented as fixture-backed successes.

| Source / target title | Lib | ABI (compiled host) | Search | Details | Episode count | Number/date parsing | Thumbnails | Error notes | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| AnimeKai 16.9 — One Piece | 16 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |
| AnimeKai — Attack on Titan / Shingeki no Kyojin | 16 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |
| AnimeKai — Attack on Titan Final Season Part 2 | 16 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |
| AnimePahe 16.55 — One Piece | 16 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |
| AnimePahe — Attack on Titan / Shingeki no Kyojin | 16 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |
| AnimePahe — Attack on Titan Final Season Part 2 | 16 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |
| KickAssAnime 14.62 — One Piece | 14 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |
| KickAssAnime — Attack on Titan / Shingeki no Kyojin | 14 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |
| KickAssAnime — Attack on Titan Final Season Part 2 | 14 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |
| WCOStream 14.15 — One Piece | 14 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |
| WCOStream — Attack on Titan / Shingeki no Kyojin | 14 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |
| WCOStream — Attack on Titan Final Season Part 2 | 14 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |

The listed titles are test targets, not claims of catalog availability. No v17 extension has been run. The host recognizes 14/16/17; this does not mean every extension using those libraries works. App installation, store install/update/uninstall, source results and screenshots all require device validation.

## ShonenX+ 2.0.0 manga audit

Mihon source-api v0.21.2 (commit `9612d955db3165e1578fdf9ff19ca9b7762c4a46`) supplies manga libraries 1.4/1.6. Keiyoushi fixtures and APK downloads use repository commit `6d666b4f2beba067f8aa0ca98946cc6cb7fc589d`. All three manga APK signatures match repo.json (`9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2`). The real protobuf fixture parses 1,426 entries. This verifies repository metadata, not source website execution.

| Source | Lib | Static ABI references | Search | Details | Chapters/pages | Number/date parsing | Thumbnails | Error notes | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| MangaDex 1.6.0 | 1.6 | 62, PASS | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |
| MANGA Plus 1.6.67 | 1.6 | 46, PASS | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |
| Webtoons.com 1.6.2 | 1.6 | 42, PASS | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED | Device source run incomplete | UNVERIFIED |

Synthetic loopback chapter downloads verify ordered page files, bounded batch concurrency, retry after HTTP503, duplicate prevention, completed retention and database reopen recovery. Reader widgets verify webtoon scroll preservation and RTL zoom behavior. Fake player-engine tests verify controls without starting video. None of these are substituted for live source/device results. Manga support intentionally supersedes the original anime-only requirement in response to the user's latest instructions.

## ShonenX+ 2.1.0 current-repository transport audit

Both exact user URLs were fetched through the production transport. Current APKs:

| Extension | Version / lib | Live index/APK download | APK certificate | Live search/details/episodes |
| --- | --- | --- | --- | --- |
| MangaDex |1.6.0 /1.6|PASS|PASS|UNVERIFIED|
| MANGA Plus by SHUEISHA |1.6.67 /1.6|PASS|PASS|UNVERIFIED|
| Webtoons.com |1.6.2 /1.6|PASS|PASS|UNVERIFIED|
| AnimeKai (Unoriginal) |16.9 /16|PASS|PASS|UNVERIFIED|
| AnimePahe |16.55 /16|PASS|PASS|UNVERIFIED|
| KickAssAnime |14.62 /14|PASS|PASS|UNVERIFIED|
| WCOStream |14.15 /14|PASS|PASS|UNVERIFIED|

Software Android 30 emulation booted and installed the diagnostic app. Earlier QEMU attempts crashed; extended attempts failed UI inspection (5-second adb and later 30-second helper-install timeouts). A 55-second screenshot eventually returned a blank launch surface, with no source diagnostic results after software-rendering relaunch. Extension installation and source execution remain UNVERIFIED. Source status is not promoted to PASS based on repository transport, signature validation, static ABI or fixtures. MovieBox HTTP contract and UI are fixture tested; a live deployment URL was not supplied. Final artifact/static ABI and any later device outcomes appear in the 2.1 release report.
