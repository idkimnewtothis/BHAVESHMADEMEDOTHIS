# Baseline before workstreams A–J

Imported ShonenX `4d684a528ac33d5e7ab78b105903d7b0dd41712b` into the originally empty connected checkout on the assigned task branch. No application code has been changed. App identity placeholders and PR branch strategy await user input. No release, signing key, commit, or PR has been created by this task.

## Environment

Ubuntu 26.04.1, x86_64. Installed the repository-pinned Flutter 3.41.9 (Dart 3.11.5), JDK 21, Android platform 36, build tools 36.0.0, platform tools 37.0.1, and NDK 28.2.13676358. `flutter pub get` passed without a lockfile change.

The full submodule checkout failed at `lib/source_engine/inbuilt_sources` with `fatal: could not read Username for https://github.com: terminal prompts disabled`. The existing providers return empty lists and do not import that submodule. Upstream CI initializes only `packages/anymex_extension_bridge`, `packages/byte_me`, `packages/commentum_client`, and `packages/flutter_web_auth`; those package checkouts were restored successfully.

## Original checks

| Check | Result |
| --- | --- |
| `flutter analyze lib test` | Exit 1: 0 errors, 0 warnings, 5 infos |
| `flutter test` | Exit 1: setup failed loading `librhttp.so`; 0 tests passed |
| Bridge `flutter test --no-pub` | Exit 1: `Test directory "test" not found.` |
| Android device verification | UNVERIFIED; `/dev/kvm` absent, no emulator boot attempted |

Analyzer findings:

- `lib/features/tracking/presentation/widgets/tracker_bio_renderer.dart:62,74,81`: deprecated `withOpacity`.
- `lib/features/tracking/providers/shonenx_metrics_provider.dart:26,29`: String compared with MediaType enum; flagged as unrelated type equality.

The native HTTP dependency was compiled using its package build wrapper’s required `RUSTFLAGS='--cfg reqwest_unstable'` setting. With `LD_LIBRARY_PATH=/home/vercel-sandbox/runtime/rhttp-target/debug`, `flutter test --no-pub` then passed **12 tests**, exit 0. The original failed result is retained above. The successful run still logs a caught SharedPreferences ServicesBinding initialization error at `session_manager.dart:83/313`; retain this for the bug sweep. Missing extension tests must be supplied during the implementation; desktop plugin template tests are not source compatibility tests.

## Implementation and release status

Workstreams A–J, runtime ABI checks, source calls, matching fixtures, persistence tests, UI verification, signed APK build, 16 KB checks, split/join testing and publishing are **not yet completed**. No playback checks were performed. An upstream index fetch does not establish source compatibility; see `upstream-versions.md` for exact source references and observed schema differences.


## Continuation

This file records the original import baseline. Current identity is Bhavesh (`io.github.idkimnewtothis.bhavesh`, `1.0.0+1`). Baseline analyzer findings were fixed and the native rhttp test dependency was built. Current validation/delivery results are in release-report.md; workstream completion is tracked separately in workstreams.md.
