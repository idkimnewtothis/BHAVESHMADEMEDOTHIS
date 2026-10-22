# Bhavesh 1.0.0 release report

## Delivered build

- Name **Bhavesh**; application ID `io.github.idkimnewtothis.bhavesh`; version `1.0.0+1`.
- Signed release APK: **44,290,088 bytes**, ARM64 Flutter target. All **21** packaged native libraries pass 16 KB ELF alignment (dependencies retain their additional ABIs).
- APK SHA-256: `4532881cfb9519afc4be668e680f6b42133750f1a044df891ef91dbfe39bf53c`.
- Fresh RSA4096 release key, outside Git. Public certificate SHA-256: `9810883286bbefb30a6899b2c24da116273b383ee4a22db613303647a8929b0c`.
- GitHub publishing **BLOCKED**: Git fetch returned `Invalid username or token. Password authentication is not supported for Git operations.` The authenticated release API then returned `HTTP 422: Release.target_commitish is invalid` because the empty remote has no published task branch. No release URL or pushed commit is claimed.
- Requested fallback: joiner, manifest and three parts in `dist/1.0.0/`, also available in task Outputs under `release/1.0.0/`. Part sizes: 20,000,000; 20,000,000; 4,290,088 bytes.

## Commits and workstreams

| Commit | Work |
| --- | --- |
| `9d84758feb534297b6e5238f73614b1a42d4295e` | Sanitized ShonenX import; upstream signing key excluded from new history |
| `57aa9f96aebc2de4dfd01ce78d6100d646c8ef19` | Independent identity; A anime boundary; B runtime/ABI gate; C/D store/trust/parser; E detail transport/error fixes; F matcher; H scoped storage; I store states; J analyzer/build fixes; signed split/join tooling |

These are local commits. A–J are **not all complete**. G streaming search, F match persistence/picker, H foreground service/reboot tests and I comprehensive accessibility work remain outstanding. One PR per workstream was not delivered; the remote is empty and Git authentication failed. Details: [workstreams](workstreams.md).

## Verification

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub lib test` | PASS, zero issues |
| Flutter tests | PASS, 93 unique tests: full suite 92 plus updated metadata suite 14 (13 overlap); includes 60 title-pair fixtures, Unicode/alias/part guards |
| Four real extension APK signatures | PASS, match pinned repository fingerprint |
| Final release DEX ABI | PASS: AnimeKai 57, AnimePahe 59, KickAssAnime 47, WCOStream 37 API references; 200 total |
| Python checker regressions | PASS, 3 ABI tests and 1 ELF test covering both 32/64-bit formats |
| Release build | PASS, `flutter build apk --release --target-platform android-arm64 --no-pub`, 372.2s after dependency preparation |
| APK signature, app identity and native alignment | PASS on release, Python-joined and browser-downloaded APKs |
| Python split `--verify` | PASS, byte-identical SHA-256 |
| Node joiner suite | PASS, 15 synthetic algorithm/failure checks; reused unchanged joiner code |
| Chromium offline joiner | PASS, all 8 requested scenarios plus real signed-APK pure-JS fallback; CSP download works; zero resource requests |

Browser cases: ordered happy path, random order, missing part, wrong size, flipped byte, duplicate part, no manifest and incorrect total hash. Both assembled APKs have the release hash above.

Repaired failures: missing host rhttp library, JDK proxy CA, Kotlin API/compiler errors, Gradle memory kill, QuickJS 4 KB alignment, analyzer diagnostics, and checker false positives for static methods/32-bit ELF. `git diff --cached --check` reported inherited trailing whitespace in vendored upstream/reference files; no analyzer/compiler error remains. No checks are reported as live successes based on fixtures.

## Compatibility and upstream pins

| Source | Lib | APK signature / static ABI | Live search/details/episodes |
| --- | --- | --- | --- |
| AnimeKai (Unoriginal) 16.9 | 16 | PASS / PASS | UNVERIFIED |
| AnimePahe 16.55 | 16 | PASS / PASS | UNVERIFIED |
| KickAssAnime 14.62 | 14 | PASS / PASS | UNVERIFIED |
| WCOStream 14.15 | 14 | PASS / PASS | UNVERIFIED |

The [12-title matrix](compat-report.md) records unrun counts/date/thumbnail checks. No connected device; `/dev/kvm` absent. Static checks do not prove source functionality.

- ShonenX: `4d684a528ac33d5e7ab78b105903d7b0dd41712b`.
- extensions-lib v17: `971ce96e76202bb35432fe71f92553e3ae40d01d`; v16 `a776b99df09003423eb13d9816323aaa09af7c24`; 14 `f33cc241dee8f7561b97f0aa0921c58f0f8a3b8c`.
- Aniyomi v0.18.2.1: `97414446b8a95994c72dd33c41c971a89d4d25b8`.
- Mihon v0.21.2: `9612d955db3165e1578fdf9ff19ca9b7762c4a46`.
- yuzono/anime-repo: `ba5036afbbe9806143f0c4a3ea405421b61ba253`.

## UNVERIFIED / limitations

Android installation and UI/screenshots; live source matrix; store install/update/uninstall roundtrip; lib17 device compatibility; queue kill/reboot persistence; Firefox/Samsung Internet and phone-browser behavior. No Android emulator was booted. No playback or real video downloads were attempted. No DRM/login/paywall/CAPTCHA bypass, telemetry, or APK-size optimization was added. Remaining feature work is explicitly listed in workstreams.md.

## Phone installation

1. Download apk-joiner.html, every part, and the manifest.
2. Open apk-joiner.html from Downloads in your browser.
3. Tap Select parts, choose every part and the manifest, then tap Join.
4. Tap Download APK. If Android blocks the install, allow installs from your browser. This is usually under Settings → Apps → Special app access → Install unknown apps.
5. Open the APK from Downloads and tap Install.
