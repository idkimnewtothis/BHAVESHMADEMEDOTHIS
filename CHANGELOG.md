# 2.1.0 — 2026-10-24

- Repair exact Keiyoushi protobuf and Yuzono JSON repository URLs, HTTPS redirects, download streaming, and repository diagnostics.
- Fix the Android manifest collision that removed the extension installer FileProvider authority. Add an APK-level verification gate.
- Await Android install/removal confirmations; preserve trust checks for grouped installs and updates, refresh actual installed sources, and avoid duplicate package operations.
- Validate and stream app-update APKs with isolated temporary files, bounded timeouts, size checks and disposal safety.
- Expose bundled Mihon/Aniyomi runtime status instead of a nonfunctional separate Android runtime download.
- Implement source preferences with extension defaults and change listeners; refresh source maps atomically.
- Add retry and readable errors for failed offline/online reader pages. Guard delayed subtitle results when switching sources.
- Add configurable MovieBox UI catalogs, search, pagination and source integration using an independently implemented HTTP client.
- Add repository-to-installer regression tests, MovieBox contract tests, reader retry coverage, and synthetic download endurance validation.

# ShonenX+ 2.0.0 — 2026-10-24

- New application identity and private signing key; independent installation.
- Restore manga execution using Mihon v0.21.2 source-api and Keiyoushi protobuf repositories; retain certificate trust checks and Aniyomi anime runtime.
- Repair reader scroll reset/zoom conflicts and debounce ordered history writes.
- Retain completed downloads, title/source/episode identity and ordered chapter page paths. Add chapter batches, persistent queue recovery and offline title toggle.
- Route 1DM batches through persistent tasks; add folder-granted import and subtitle association.
- Keep pause accessible during buffering, serialize native opens, discard stale episode/server requests, and retain offline history context.
- Add pinned upstream audit, real repository fixtures, queue/reader/playback-control regressions, and signed split/join delivery.

Device behavior and live sources remain unverified; see docs/shonenxplus-release.md. No claim of universal extension support or zero remaining bugs.

# Bhavesh changelog

## 1.0.0 — 2026-10-22 (experimental)

- Separate application identity and fresh release key.
- Bundled anime-only Aniyomi runtime, explicit version rejection and certificate trust gate.
- Strict legacy/modern metadata parsing and both Aniyomi deep-link forms.
- NFKD season-aware title comparison with 60 fixture pairs.
- Preserve metadata status/episode URLs and expose source failures.
- App-specific Android download storage; remove broad storage permissions.
- Signed APK verification, 20 MB split parts and offline SHA-256 joiner.
- Live Android/source validation and remaining feature work are listed in docs/workstreams.md.

## Upstream history

