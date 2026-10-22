# Aniyomi compatibility report

Test date: 2026-10-22. No playback or real video downloads were attempted.

The four real APKs came from yuzono/anime-repo commit `ba5036afbbe9806143f0c4a3ea405421b61ba253`. All four passed apksigner and match repo.json certificate fingerprint `cbec121aa82ebb02aaa73806992e0368a97d47b5451ed6524816d03084c45905`.

Static ABI comparison against the compiled host classes passed for 200 API member references (AnimeKai 57, AnimePahe 59, KickAssAnime 47, WCOStream 37). Final release-DEX results are in abi-report.json when present. The checker inspects referenced method/field descriptors and known override signatures, follows inherited members, and fails on missing members. Reflection and runtime behavior remain outside that static check. A negative mutation test verifies that removing a required method fails the gate.

## Requested live matrix

No Android device is attached (`adb devices` returned an empty list); `/dev/kvm` is absent. The Android installer/source runtime could not be exercised. Network access to GitHub succeeded; this is **not** a website-network block. No source search/details/episode responses have been fabricated or presented as fixture-backed successes.

| Source / target title | Lib | ABI (compiled host) | Search | Details | Episode count | Number/date parsing | Thumbnails | Error notes | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| AnimeKai 16.9 — One Piece | 16 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | No Android device | UNVERIFIED |
| AnimeKai — Attack on Titan / Shingeki no Kyojin | 16 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | No Android device | UNVERIFIED |
| AnimeKai — Attack on Titan Final Season Part 2 | 16 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | No Android device | UNVERIFIED |
| AnimePahe 16.55 — One Piece | 16 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | No Android device | UNVERIFIED |
| AnimePahe — Attack on Titan / Shingeki no Kyojin | 16 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | No Android device | UNVERIFIED |
| AnimePahe — Attack on Titan Final Season Part 2 | 16 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | No Android device | UNVERIFIED |
| KickAssAnime 14.62 — One Piece | 14 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | No Android device | UNVERIFIED |
| KickAssAnime — Attack on Titan / Shingeki no Kyojin | 14 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | No Android device | UNVERIFIED |
| KickAssAnime — Attack on Titan Final Season Part 2 | 14 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | No Android device | UNVERIFIED |
| WCOStream 14.15 — One Piece | 14 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | No Android device | UNVERIFIED |
| WCOStream — Attack on Titan / Shingeki no Kyojin | 14 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | No Android device | UNVERIFIED |
| WCOStream — Attack on Titan Final Season Part 2 | 14 | PASS | UNVERIFIED | UNVERIFIED | — | UNVERIFIED | UNVERIFIED | No Android device | UNVERIFIED |

The listed titles are test targets, not claims of catalog availability. No v17 extension has been run. The host recognizes 14/16/17; this does not mean every extension using those libraries works. App installation, store install/update/uninstall, source results and screenshots all require device validation.
