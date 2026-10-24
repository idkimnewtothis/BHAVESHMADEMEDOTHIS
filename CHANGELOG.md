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

