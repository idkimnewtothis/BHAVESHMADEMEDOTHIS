# ShonenX+ 2.0.0 release report

Signed ARM64 build, **44,338,860 bytes**. App ID `io.github.idkimnewtothis.shonenxplus`, version `2.0.0+2`. A fresh RSA4096 release key was generated outside Git. It installs independently of Bhavesh; private app data is not automatically migrated. This release is marked prerelease because Android device/live-source behavior has not been verified.

APK SHA-256: `00e09cf61ad4a4b8e15573040aceb9185fe74608b9d480cccf90e861f9da1a8a`

Public signing certificate SHA-256: `1e1c683fa4cbee119b96bea3f0a2c7a04a75b38679791cc3cf8a946e6bef5124`.

## Downloads

[GitHub release](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/tag/v2.0.0)

- [Signed ARM64 APK](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/download/v2.0.0/shonenxplus-2.0.0.apk)
- [Offline HTML joiner](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/download/v2.0.0/apk-joiner.html)
- [Manifest](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/download/v2.0.0/shonenxplus-2.0.0.manifest.json)
- [Part 1 (20,000,000 bytes)](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/download/v2.0.0/shonenxplus-2.0.0.part-001.bin)
- [Part 2 (20,000,000 bytes)](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/download/v2.0.0/shonenxplus-2.0.0.part-002.bin)
- [Part 3 (4,338,860 bytes)](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/download/v2.0.0/shonenxplus-2.0.0.part-003.bin)

The direct APK and split delivery contain the same signed release. Each part is below25MB. Task Outputs also contain the parts, manifest, joiner and this report.

## Changes and root causes

Implementation: `ff42083fc39c9a9a9c4b6af14526970bf113d7ed`. Additional regression/ABI evidence: `c1003ce219d9a88c7cfc80d78f7d067360afd9c9`. All work uses the assigned branch; no separate workstream PRs/merges were created. The initially empty remote selected this branch as its default, leaving no separate base branch.

| Workstream | Changes |
| --- | --- |
| Manga runtime/store (A–D) | Latest user request intentionally supersedes anime-only restriction. Restore Mihon source-api and separate trusted manga runtime; parse current Keiyoushi protobuf instead of legacy “Outdated App” placeholders. Preserve parent-first class loading and certificate gates. Add weekly/manual upstream audit. |
| Reader/UI (I/J) | Stop current-page feedback from resetting webtoon scroll; avoid paged-controller resets on rebuild; coordinate zoom/scroll, cache reader views, debounce/serialize history writes and guard stale async results. Persist scanlator selection and retain alternate releases. |
| Downloads (H) | Retain completed tasks and title/source/chapter identity; add manga batches, bounded concurrency, retries, launch recovery and ordered local pages. Offline title toggles bypass unavailable source discovery. Foreground dataSync service, scoped storage, per-item/title deletion and storage display. |
| Player/1DM | Keep play/pause usable during buffering, replay ended media, serialize opens, discard stale switches, retain offline history/subtitles. Persist external handoffs, batch page requests, import matching files from a granted folder. Reject stale scan results after cancellation/deletion. |

Original matching/global-search work and comprehensive accessibility/immersive UI audits remain incomplete as documented in `docs/workstreams.md`. This release does not claim every requested workstream is complete or the app is bug-free.

## Upstream pins

| Component | Exact reference |
| --- | --- |
| ShonenX shell | `4d684a528ac33d5e7ab78b105903d7b0dd41712b` |
| Mihon | v0.21.2 — `9612d955db3165e1578fdf9ff19ca9b7762c4a46` |
| Keiyoushi | `6d666b4f2beba067f8aa0ca98946cc6cb7fc589d` |
| Aniyomi extensions-lib | v17 — `971ce96e76202bb35432fe71f92553e3ae40d01d` |
| Aniyomi app | v0.18.2.1 — `97414446b8a95994c72dd33c41c971a89d4d25b8` |
| yuzono/anime-repo | `ba5036afbbe9806143f0c4a3ea405421b61ba253` |

Legacy lib references:14=`f33cc241dee8f7561b97f0aa0921c58f0f8a3b8c`;v16=`a776b99df09003423eb13d9816323aaa09af7c24`. Formats, source links and pin details are in `docs/upstream-versions.md`. The18 vendored manga API hashes pass the local audit. GitHub authenticated API confirms Mihon v0.21.2; anonymous audit hit HTTP429. CI now uses its read-only token; remote CI execution is unverified.

## Compatibility

All seven real APK certificates match their repository. Static ABI passes against the final signed APK are **not live source tests**.

| Source/version | Lib | ABI references | Search/details | Lists, numbers/dates, thumbnails | Overall |
| --- | --- | --- | --- | --- | --- |
| AnimeKai16.9 |16|57 PASS|UNVERIFIED|UNVERIFIED|UNVERIFIED|
| AnimePahe16.55 |16|59 PASS|UNVERIFIED|UNVERIFIED|UNVERIFIED|
| KickAssAnime14.62 |14|47 PASS|UNVERIFIED|UNVERIFIED|UNVERIFIED|
| WCOStream14.15 |14|37 PASS|UNVERIFIED|UNVERIFIED|UNVERIFIED|
| MangaDex1.6.0 |1.6|62 PASS|UNVERIFIED|UNVERIFIED|UNVERIFIED|
| MANGA Plus1.6.67 |1.6|46 PASS|UNVERIFIED|UNVERIFIED|UNVERIFIED|
| Webtoons.com1.6.2 |1.6|42 PASS|UNVERIFIED|UNVERIFIED|UNVERIFIED|

Reason: no attached Android device; `/dev/kvm` absent. Full12-title anime matrix remains in `docs/compat-report.md`. Live tests were not replaced with fabricated fixtures. Real index fixtures and synthetic HTTP pages verify parser/queue behavior only.

## Validation

- **107 unique Flutter tests covered**: full105-test pass,30 affected tests rerun after sync fix,22 metadata checks rerun after cleanup, plus2 new offline-title integration tests. No failing assertions remain. Analyze: zero issues in lib/test and touched bridge files; new test analyzer also clean.
- Synthetic queue: concurrency2, HTTP503 retry, ordering, duplicate prevention, completed retention, Isar reopen recovery, stale external import/cancel/delete races. Reader and play/pause use widget/fake-engine tests.
- ABI:7 APKs,350 references, zero missing members. Checker regression tests:3 passed. ELF verifier regression:1 test with32/64-bit and misalignment cases passed.
- Release build passed (255.8s); original and both joined APKs pass identity/signature/16KB verification, all21 native libraries. ARM64 Flutter target; inherited dependency ABIs and shrinking settings retained.
- Joiner:15 Node checks and9 real-file Chromium156 scenarios passed: ordered/shuffled success, missing/wrong-size/flipped/duplicate/no-manifest/wrong-total-hash rejection, and pure-JS fallback. Actual download works on `file://` under the exact CSP, with zero resource requests. Browser/Python outputs match the signed APK byte-for-byte by SHA-256.
- Initial failures were corrected: native API helper signatures, protobuf field interpretation, reader image test setup, fake HTTP setup, stale external scan races and analyzer diagnostics. Browser startup required restoring the runtime-pinned Chrome executable and permissions. One overlapping build was deliberately stopped (143); final sequential build passed.
- Inherited build messages mention CupertinoIcons/CargoKit. The full test log also contains the pre-existing caught SharedPreferences binding diagnostic; no assertion failed. No phone rendering or device crash audit is claimed.

## UNVERIFIED and limitations

Android install/update/uninstall, live sources, UI smoothness/screenshots, process-kill/reboot lifecycle, actual1DM intents/file completion and subtitle rendering remain unverified. No playback or real video download tests were performed. Phone Chrome, Firefox and Samsung Internet are unverified; desktop Chromium passed.

1DM sync needs an explicit folder grant, unchanged supplied filenames, and the app running/resuming. It copies completed files without deleting originals; there is no verified completion callback or force-stopped background sync. Use1DM to control its transfers. Paused final-named files cannot always be distinguished from completed files. Optional TV layout and full cross-source matching remain outside this verified offline-title flow. No DRM/login/paywall/CAPTCHA bypass or APK-size reduction was attempted. Future upstream updates require review/ABI/device gates, not automatic unaudited code import.

## Phone steps

1. Download apk-joiner.html, every part, and the manifest.
2. Open apk-joiner.html from Downloads in your browser.
3. Tap Select parts, choose every part and the manifest, then tap Join.
4. Tap Download APK. If Android blocks the install, allow installs from your browser. This is usually under Settings → Apps → Special app access → Install unknown apps.
5. Open the APK from Downloads and tap Install.

Alternatively download the direct signed APK and follow step5. Keep the new signing key private and backed up for future updates; it is not included in release assets or Git.
