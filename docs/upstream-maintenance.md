# Mihon compatibility maintenance

ShonenX+ 2.0.0 intentionally restores manga APK execution, replacing 1.0.0's anime-only restriction at the user's request. Manga libraries 1.4 and 1.6 follow Mihon v0.21.2's loader contract. Anime libraries remain 14, 16, 17. Future versions are rejected until audited.

`docs/mihon-api-pin.json` pins the upstream commit and hashes every vendored manga API file. The public source API comes from Mihon's `source-api` module. Host adaptations use the existing coroutine bridge, provide a public wrapper for image requests, and support range requests in the network helper. No website behavior is built into core search, reader, or matching.

The weekly/manual CI audit checks the local hashes and upstream stable release. A changed upstream release fails the audit; it does not silently load new executable code. Maintainers must:

1. Compare the new `source-api` and extension loader contracts against the pin.
2. Review changes in `NetworkExtensionStore` protobuf fields and repository metadata.
3. Port the API and required helpers; update pinned hashes and this report.
4. Download representative signed APKs from the current Keiyoushi index and run `tools/verify-extension-abi.py` against the built release.
5. Run repository/reader/download tests and analysis, then source search/details/pages and installer/update tests on Android.
6. Sign and deliver a versioned release. Never replace the signing key for routine updates.

The audit workflow is present locally; remote execution is not claimed until it is pushed. Compatibility with every extension is not guaranteed by an ABI check: reflection, source-specific preferences, authentication, and device behavior require separate tests. Login, payment, and CAPTCHA challenges are unsupported.

Keiyoushi's legacy `index.min.json` now advertises “Outdated App.” Use `https://raw.githubusercontent.com/keiyoushi/extensions/repo/repo.json`; follow `index_v2` to the current protobuf index. The manga source field is 8, compared with Aniyomi's field 9. Repository fingerprints describe the APK signer, not a separate metadata API.
