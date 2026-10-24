# ShonenX+ 2.1.0 repair report

Version 2.1.0+3, `io.github.idkimnewtothis.shonenxplus`. Uses the same private release key as 2.0.0 so Android can upgrade in place. No signing secrets are committed.

## Changes and root causes

- **Repositories and APKs:** GitHub `/raw/` URLs were converted incorrectly. Shared URL/HTTP transport now reads both exact user URLs, metadata/index redirects, current Keiyoushi protobuf and Yuzono JSON; APKs stream to temporary files and reject HTTP/HTML/truncated responses. Duplicate packages from multiple repositories no longer overwrite selected metadata silently.
- **Installation and updates:** The app manifest merged away the bridge FileProvider authority; a distinct `ExtensionApkProvider` and APK-level regression gate now prevent that collision. Android installs previously returned before the installer completed; grouped operations skipped the shared trust flow, and refresh did not reload installed packages. Installation/removal now waits for Android confirmation, verifies package/version/certificate, persists trust after success, and refreshes actual installed sources. Grouped operations deduplicate packages.
- **Mihon/Aniyomi runtime:** Android uses the bundled implementation rather than a separate AnymeX host download. Preferences now map defaults, nested groups, switches, lists, multiselect and text through native Android preference APIs and extension change listeners. Source map refresh is atomic. Runtime updates are delivered as audited, signed app updates, with a weekly Mihon upstream audit.
- **App updater:** Release APK downloads use the shared streamed transport, validate HTTP responses and advertised size, isolate temporary files, throttle progress updates, close network clients, and avoid opening the installer after the screen is disposed.
- **Reader/player:** Failed online/offline pages now have Retry. The existing webtoon position and RTL zoom tests remain passing. Delayed subtitle discovery captures source/load identity and expires after 15 seconds, preventing obsolete results from replacing the current selection. No video was played.
- **MovieBox:** Added **Discover → MovieBox UI**, configurable HTTPS server, Featured/Anime/Movies/Series catalogs, search, pagination, title/episode mapping, clear errors and stale-response protection. The linked repository is server software; no public server endpoint was supplied. No upstream implementation or embedded credentials were copied.

## Commits

- `4d49133`: repository transport, verified installation/removal, FileProvider fix, preferences and runtime status.
- `ca38eda`: MovieBox source and discovery integration.
- `2622956`: reader Retry and stale subtitle protection.
- `1e5d720`: streamed app-update downloads with response/size checks and disposal safety.

## Upstream and validation

Exact commits and contracts are in [upstream versions](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/blob/v2.1.0/docs/upstream-versions.md). Mihon v0.21.2; Aniyomi host libraries 14/16/17 and Mihon 1.4/1.6. MovieBox contract commit `e1dfbe5b2bf8c9559fa7631cb8a35172d651fe85`.

- Flutter: 129 tests pass (124 full suite plus 2 MovieBox UI checks, 1 mixed-catalog search check and 2 app-updater checks).
- Native Android preference/provider JVM tests: 4 pass, 0 failures/skips, using Robolectric Android 28. This is not device testing.
- Analyzer: no issues in app/tests, diagnostic entry, touched AniYomi bridge module and extension manager.
- Live repository transport: Keiyoushi 1,426 entries, Yuzono 250 entries; 7 extension APK downloads succeeded and all 7 signatures match their repository fingerprints. Source website execution is separate from APK download verification.
- Signed ARM64 release build passed; version 2.1.0/code 3, release certificate, merged installer provider and all 21 shipped native libraries passed 16 KB alignment checks. Existing dependency ABIs and release shrinking settings were preserved.
- All 7 real extension APKs pass the final host static ABI check: 350 references, zero missing members.
- Delivery: Python split/rejoin passed; 9 shared Chromium scenarios passed (ordered/random selection, missing/wrong-size/corrupt/duplicate parts, no manifest, wrong total hash and pure-JavaScript fallback). The actual file:// download worked under the required CSP, with zero resource requests. Browser output and Python output match the signed original and both pass verify_apk.py. The 15 unchanged Node joiner logic checks are reused from the earlier validated implementation.
- Endurance: PASS, 59 minutes 36 seconds; 120 synthetic chapters / 240 ordered page files, HTTP 503 retry, two batches across a database close/reopen, zero failed jobs and peak concurrency 2. This adds one test to the 129 normal Flutter checks (130 total). It does not establish Android reboot/force-stop behavior.
- Recovered setup failures: missing host native test dependency was repaired; two debug-build attempts exhausted sandbox memory before bounded Gradle/Rust builds succeeded. Device inspection failures remain listed below; no live/device check is counted as passed.

### Exact upstream references

| Component | Reference |
| --- | --- |
| Mihon v0.21.2 | `9612d955db3165e1578fdf9ff19ca9b7762c4a46` |
| Aniyomi extensions-lib v17 | `971ce96e76202bb35432fe71f92553e3ae40d01d` |
| Aniyomi v0.18.2.1 | `97414446b8a95994c72dd33c41c971a89d4d25b8` |
| Keiyoushi repo | `6d666b4f2beba067f8aa0ca98946cc6cb7fc589d` |
| Yuzono repo | `d79665e2915347faf7af9db47d11d3001c33fd06` |
| MovieBox contract | `e1dfbe5b2bf8c9559fa7631cb8a35172d651fe85` |

### Current compatibility

| Source | Lib | Live index/APK/certificate | Static ABI | Live details/episodes |
| --- | --- | --- | --- | --- |
| MangaDex 1.6.0 | 1.6 | PASS | PASS | UNVERIFIED |
| MANGA Plus 1.6.67 | 1.6 | PASS | PASS | UNVERIFIED |
| Webtoons 1.6.2 | 1.6 | PASS | PASS | UNVERIFIED |
| AnimeKai (Unoriginal) 16.9 | 16 | PASS | PASS | UNVERIFIED |
| AnimePahe 16.55 | 16 | PASS | PASS | UNVERIFIED |
| KickAssAnime 14.62 | 14 | PASS | PASS | UNVERIFIED |
| WCOStream 14.15 | 14 | PASS | PASS | UNVERIFIED |

The [title-by-title matrix](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/blob/v2.1.0/docs/compat-report.md) retains unverified search, episode/date and thumbnail results. No fixture result is labeled a live source pass.

## Limitations

An Android 30 software emulator booted and accepted the diagnostic app APK. Earlier attempts crashed with QEMU CPU/main-loop hangs; extended retries timed out on the inspection helper (30 seconds); a later 55-second screenshot attempt returned only a blank launch surface. No source diagnostic results appeared after software-rendering relaunch. App thread inspection showed Flutter/Dart native frames; system ANR traces belonged to Android telephony. These traces do not establish a working app or a specific application defect. Extension install/update/removal, live source search/details/episodes, foreground lifecycle/reboot, UI performance, 1DM behavior and phone-browser behavior remain UNVERIFIED. No real video download or playback checks were performed. MovieBox live catalogs require a configured HTTPS server; synthetic HTTP/UI checks are not live compatibility claims. Custom source login/action preferences, login/CAPTCHA/paywall/DRM flows are unsupported. Future upstream versions require review and a signed app update; no automatic executable runtime replacement is provided. Real APK samples cover anime libraries 14/16 and manga 1.6; live runtime compatibility for every declared library version is not established. The assigned branch is also the remote default and has no separate main/base branch; no workstream PRs or merges are claimed.

## Signed download files

APK: 44355200 bytes. SHA-256: `0bfa4871c88dc4d3b9de4aa968289889630c385e37960d0547f45dcbae0a371d`.

- [shonenxplus-2.1.0.apk](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/download/v2.1.0/shonenxplus-2.1.0.apk)
- [apk-joiner.html](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/download/v2.1.0/apk-joiner.html)
- [shonenxplus-2.1.0.manifest.json](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/download/v2.1.0/shonenxplus-2.1.0.manifest.json)
- [shonenxplus-2.1.0.part-001.bin](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/download/v2.1.0/shonenxplus-2.1.0.part-001.bin)
- [shonenxplus-2.1.0.part-002.bin](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/download/v2.1.0/shonenxplus-2.1.0.part-002.bin)
- [shonenxplus-2.1.0.part-003.bin](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/download/v2.1.0/shonenxplus-2.1.0.part-003.bin)

## Phone installation

1. Download apk-joiner.html, every part, and the manifest.
2. Open apk-joiner.html from Downloads in your browser.
3. Tap Select parts, choose every part and the manifest, then tap Join.
4. Tap Download APK. If Android blocks the install, allow installs from your browser. This is usually under Settings → Apps → Special app access → Install unknown apps.
5. Open the APK from Downloads and tap Install.
