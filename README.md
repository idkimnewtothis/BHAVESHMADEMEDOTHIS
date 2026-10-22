# Bhavesh

Independent Android anime app derived from ShonenX, licensed under GPL-3.0.

- Application ID: `io.github.idkimnewtothis.bhavesh`
- App version: `1.0.0+1`
- Target: ARM64 Android 8.0+ (API 26)
- New private release signing key; unrelated to the upstream app's identity/key.

## Install on your phone

GitHub publishing is blocked by Git authentication, so the requested fallback assets are committed under [dist/1.0.0](dist/1.0.0/). The coding task also provides direct downloads of the joiner, three parts and manifest. No GitHub release URL is claimed.

1. Download apk-joiner.html, every part, and the manifest.
2. Open apk-joiner.html from Downloads in your browser.
3. Tap Select parts, choose every part and the manifest, then tap Join.
4. Tap Download APK. If Android blocks the install, allow installs from your browser. This is usually under Settings → Apps → Special app access → Install unknown apps.
5. Open the APK from Downloads and tap Install.

The joiner works offline, stores nothing, verifies each part and the complete APK, and refuses damaged or incomplete downloads. Keep the manifest with its corresponding parts. The download requires enough free phone storage for the parts and assembled APK.

## Extension store

Open Settings → Extensions → Manage repositories. Add the repository index URL:

```
https://raw.githubusercontent.com/yuzono/anime-repo/repo/index.min.json
```

Both `aniyomi://add-repo?url=...` and `aniyomi://extension-store?url=...` are handled. Approve the repository signing fingerprint on first installation, then confirm installation in Android and refresh the store. A certificate mismatch is blocked. Android may require permission to install apps from Bhavesh.

Only Aniyomi **anime** APKs are accepted. Lib versions 14, 16 and 17 have host entry points; other versions are rejected with a reason. Static checks of the four selected extensions are documented in [the compatibility report](docs/compat-report.md). Static ABI checks do not prove source website compatibility. Manga reader/library code remains in the shell, with **No manga sources in this build**.

## Current limitations

This is an experimental build, not a claim that all original workstreams are complete. See [workstream status](docs/workstreams.md) and [compatibility](docs/compat-report.md).

- Android installation, source calls, title/episode matrix, restart/reboot behavior and app screenshots are UNVERIFIED: no connected device or accelerated emulator is available.
- Multi-source streaming search, per-source retry/cancellation, confirmed-match persistence/overrides, full source-switch identity handling, foreground download service and comprehensive accessibility/reduced-motion work remain incomplete.
- Android downloads use app-specific storage. Arbitrary filesystem directories are not offered on Android; no broad storage permission is requested.
- Login, payment and challenge responses are unsupported. No challenge bypass is implemented. No playback or real-video download checks were performed.
- Tracker credentials are not bundled; register your own tracker application using `bhavesh://callback` and use the custom credentials settings.
- Upstream announcement configuration is disconnected by default. Optional `BHAVESH_CONFIG_URL` is a build-time setting. Crash logging remains local; no telemetry service was added.

## Build and signing

Use Flutter **3.41.9**, JDK **21**, Android SDK/build tools **36**, and Flutter's NDK **28.2.13676358**. The initial dependency build also needs Rust (rhttp), CMake and NDK 27 for plugin builds. The shell's original release shrinking/minification is retained. QuickJS is linked with 16 KB page flags.

Initialize the public package submodules individually, then resolve dependencies:

```sh
git submodule update --init packages/byte_me packages/commentum_client packages/flutter_web_auth
flutter pub get
```

The unused, inaccessible upstream `shonenx-sources` gitlink and stale `byte_me_ecosystem` mapping were removed. The Android anime bridge is vendored.

Generate a separate keystore outside the checkout. Keytool prompts for passwords:

```sh
keytool -genkeypair -keystore /private/path/bhavesh-release.jks \
  -alias bhavesh-release -keyalg RSA -keysize 4096 -validity 10000
```

Create ignored `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. Back up the private key/password securely: app updates require the same key. Never commit or upload signing files to a release. The delivered build's public certificate fingerprint is recorded in the release report.

```sh
flutter analyze lib test
flutter test
flutter build apk --release --target-platform android-arm64
python3 scripts/verify_apk.py build/app/outputs/flutter-apk/app-release.apk
python3 tools/verify-extension-abi.py --host build/app/outputs/flutter-apk/app-release.apk /path/to/test-extensions/*.apk
python3 scripts/split_apk.py build/app/outputs/flutter-apk/app-release.apk --output dist/1.0.0
python3 scripts/split_apk.py dist/1.0.0/bhavesh-1.0.0.manifest.json --verify \
  --original build/app/outputs/flutter-apk/app-release.apk --output /tmp/joined.apk
python3 scripts/verify_apk.py /tmp/joined.apk
node test/delivery/joiner.test.js
python3 test/delivery/abi_checker_test.py
python3 test/delivery/browser_joiner.py dist/1.0.0/bhavesh-1.0.0.manifest.json --download /tmp/browser-joined.apk
python3 scripts/verify_apk.py /tmp/browser-joined.apk
```

The verifier defaults to the published app’s public signing-certificate fingerprint. For a separately generated developer key, pass its verified fingerprint with `--certificate`; never substitute a different key for a published app update.

Expose `apksigner` on PATH (or pass `--apksigner`) and set `ANDROID_HOME`. Host Flutter tests using rhttp require its Linux `librhttp.so` on `LD_LIBRARY_PATH`; build it with `RUSTFLAGS='--cfg reqwest_unstable' cargo build --locked` in the resolved rhttp `rust/` directory. On an 8 GB builder, use a 3 GB Gradle heap, two workers and in-process Kotlin compilation to avoid an OOM kill.

## Credits

[Upstream source/version audit](docs/upstream-versions.md), [original README](UPSTREAM_README.md), [third-party credits](THIRD_PARTY.md), and [GPL-3.0 license](LICENSE). Credits are also available in About.
