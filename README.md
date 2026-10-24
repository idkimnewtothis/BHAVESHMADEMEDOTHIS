# ShonenX+

An independent GPL-3.0 Android app based on ShonenX. Version **2.1.0+3**, application ID **io.github.idkimnewtothis.shonenxplus**, using the ShonenX+ release signing key (same key as 2.0.0 for in-place upgrades). It installs alongside the previous Bhavesh app; it does not replace that app or automatically migrate its private data.

## Install on a phone

[Download ShonenX+ 2.1.0](https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases/tag/v2.1.0): signed ARM64 APK or verified split files. This is a prerelease; device limitations are listed below. To find it through the app updater, enable prereleases in Update Settings, or use the direct APK download.

Release delivery consists of `apk-joiner.html`, every `shonenxplus-2.1.0.part-NNN.bin`, and `shonenxplus-2.1.0.manifest.json`. The parts come from the signed ARM64 release APK. The joiner validates part sizes and SHA-256 hashes, then the assembled APK hash, offline.

1. Download apk-joiner.html, every part, and the manifest.
2. Open apk-joiner.html from Downloads in your browser.
3. Tap Select parts, choose every part and the manifest, then tap Join.
4. Tap Download APK. If Android blocks the install, allow installs from your browser. This is usually under Settings → Apps → Special app access → Install unknown apps.
5. Open the APK from Downloads and tap Install.

Use all files from the same version. A mismatched, missing, duplicate or damaged part is rejected.

## Extension setup

Open **Settings → Extensions → Repositories**. Select **Aniyomi / Anime** or **Mihon / Manga**, and add an HTTPS repository metadata URL. Review its signing certificate at the first install. Android's package installer handles installation and removal; APK signers must match repository metadata.

- Manga: `https://github.com/keiyoushi/extensions/raw/repo/index.pb` (or its `repo.json` URL)
- Anime: `https://raw.githubusercontent.com/yuzono/anime-repo/repo/index.min.json`
- Repository deep links: `aniyomi://add-repo?url=…`, `aniyomi://extension-store?url=…`, `mihon://add-repo?url=…`, and `tachiyomi://add-repo?url=…`.

Mihon manga libraries **1.4/1.6** and Aniyomi anime libraries **14/16/17** are accepted. Unknown versions are rejected with an explanation. Sources run in parent-first Android class loaders. Load errors remain visible in Sources. Keiyoushi's current `repo.json` points to `index.pb`; the old JSON index now contains “Outdated App” placeholders. No site-specific search or reader behavior is embedded in core UI.

See [upstream versions](docs/upstream-versions.md), [API maintenance](docs/upstream-maintenance.md), and [compatibility results](docs/compat-report.md). An ABI pass does not establish live source compatibility. Login, CAPTCHA, payment, and DRM requirements are unsupported.

## MovieBox UI

Open **Discover → MovieBox UI → Connect server**. Enter the HTTPS base URL of your own `moviebox-internal-api` server. The linked GitHub repository is server source code, not an endpoint. ShonenX+ does not bundle an account, upstream guest token, or a publicly hosted server.

Browse Featured, Anime, Movies and Series (the upstream Western TV category), search, load additional pages and open title details. Session cookies remain in memory; only the server URL is saved. Clear the URL to disconnect. Server errors show Retry, and stale category responses cannot replace newer results. Synthetic catalog, episode and UI tests are included. A live MovieBox deployment and video playback remain UNVERIFIED.

## Runtime updates

Mihon and Aniyomi support is bundled. The runtime panel refreshes installed extensions and links to signed app updates; there is no separate AnymeX Android runtime APK to download. The weekly Mihon API audit alerts maintainers when upstream stable changes. Compatibility updates require auditing, testing and a new signed ShonenX+ version; arbitrary future extension versions are not automatically supported.

## Reading and offline downloads

- Use the manga chapter list's scanlator selector and sort controls. “All scanlators” retains alternate releases.
- Batch Download works for manga chapters and anime episodes. The queue persists title, source, chapter/episode identity, file paths and state. Completed entries remain available.
- Open a title and enable **Offline chapters** or **Offline episodes**. This view does not require source discovery. Save titles in your Library for convenient access without searching online.
- Pause, resume/retry, cancel and delete downloads. Default concurrency is two complete jobs; failures retry with backoff. Interrupted jobs resume on the next launch. A foreground data-sync service supports active Android downloads. Downloads use app-specific storage, so uninstalling ShonenX+ removes its internal downloads.
- Failed reader pages offer **Retry page** without reopening the chapter.
- Offline reader pages preserve their order and reading position. Offline video entries retain title/episode identity and local subtitle tracks. Play/pause stays available while buffering; replay seeks to the beginning.

### 1DM integration

Enable 1DM in Download Settings. ShonenX+ persists each handoff rather than treating it as a finished download. Chapter pages use deterministic names; anime files and subtitle names are associated with their title entry.

In **Downloads**, tap **Select 1DM folder and sync** and grant access to the specific directory where 1DM writes its completed files. Android may prevent selecting the Downloads root; select 1DM's subfolder. Keep the filenames supplied by ShonenX+. The app scans on resume and every 30 seconds while running, imports stable completed files into app storage, and attaches matching subtitles to the player. It does not delete the originals. Duplicate filenames in the granted tree are rejected rather than guessed.

Use 1DM itself to pause or cancel external transfers; ShonenX+ queue controls govern its own jobs. 1DM's intents, actual completion/rename behavior, and phone permission flows need device validation. There is no verified completion callback API. Files still being written, renamed files, or files outside the granted folder cannot be reliably auto-imported. External download sync is not claimed to run while ShonenX+ is force-stopped.

## Build and signing

Use the versions in `.fvmrc` and Android Gradle files. The verified sandbox uses Flutter 3.41.9, Dart 3.11.5, JDK21, SDK/build-tools36.0.0 and NDK28.2.13676358. Initialize the public package submodules and run `flutter pub get`.

Generate a private release keystore with `keytool -genkeypair -storetype PKCS12 -keyalg RSA -keysize 4096 -validity 10000`. Keep it outside the repository. Configure ignored `android/key.properties` with `storeFile`, `storePassword`, `keyPassword`, and `keyAlias`. Back up the keystore securely: future updates of this application ID require the same key. Never commit keys or tracker credentials.

```sh
flutter analyze lib test
flutter test
flutter build apk --release --target-platform android-arm64
python3 scripts/verify_apk.py build/app/outputs/flutter-apk/app-release.apk
python3 tools/verify-extension-abi.py --host build/app/outputs/flutter-apk/app-release.apk /path/to/test-extension.apk
python3 scripts/split_apk.py build/app/outputs/flutter-apk/app-release.apk --output dist/2.1.0 --apksigner "$ANDROID_HOME/build-tools/36.0.0/apksigner"
python3 scripts/split_apk.py dist/2.1.0/shonenxplus-2.1.0.manifest.json --verify --original build/app/outputs/flutter-apk/app-release.apk --output /tmp/joined.apk
node test/delivery/joiner.test.js
python3 test/delivery/browser_joiner.py dist/2.1.0/shonenxplus-2.1.0.manifest.json --download /tmp/browser-joined.apk
python3 scripts/verify_apk.py /tmp/browser-joined.apk
python3 scripts/check_mihon_upstream.py --local-only
```

Linux tests need the package's host `librhttp.so` on `LD_LIBRARY_PATH`; the download persistence test uses the Linux Isar library from the resolved pub cache. The APK verifier's default certificate identifies this release; use `--certificate` for your own build. Preserve the current release minification/shrinking and native 16 KB linker settings. No ABI was removed to reduce size.

## Verification limits

See [release report](docs/shonenxplus-2.1-release.md) for actual checks, hashes and delivery status. No real video playback or video downloads were tested. Android UI smoothness, installation/update/uninstall, source search/details/pages, foreground service lifecycle and 1DM integration remain UNVERIFIED: software emulation installed the diagnostic APK but could not complete UI/source checks. Tests cover fake sources and local files; they do not establish that every extension or device works.

Crash diagnostics stay local. Tracker credentials are not bundled. Upstream attribution is retained in [UPSTREAM_README.md](UPSTREAM_README.md), [THIRD_PARTY.md](THIRD_PARTY.md), LICENSE and the About screen.
