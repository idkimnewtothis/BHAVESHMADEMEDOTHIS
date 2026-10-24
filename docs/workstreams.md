> Historical Bhavesh 1.0.0 workstream status. ShonenX+ 2.0.0 intentionally restores manga support and changes the download/reader/player paths; see [current release report](shonenxplus-release.md) and [compatibility report](compat-report.md). Unfinished matching/global-search and comprehensive accessibility work below remains outstanding unless the current report explicitly supersedes it.

# Implementation record

## A — Anime-only extension boundary

Root cause: the bridge registered manga, JavaScript, novel, CloudStream and Kotatsu managers, and accepted a downloadable runtime host capable of loading manga APKs. The shell also exposed manga source adapters.

Changes: only Aniyomi is registered; manga providers return an explicit empty state; manga source adapter removed; repository and installation entry points reject non-anime sources; native method channel rejects manga operations; external runtime-host APK loading removed. The reader and local manga library remain in the shell. Removed the unused inaccessible inbuilt-source gitlink and stale byte_me_ecosystem submodule mapping; the three actual public package submodules remain. Removed the unused RuntimeBridges, kotatsu_ext and proxy-method native host trees after extracting the anime runtime. Removed unused prebuilt torrent binaries (none were part of the Android source set or APK inventory). Upstream references remain available at the recorded bridge commit. No native runtime library existed in the plugin’s source set solely for manga; future APK verification inventories the actual packaged libraries.

Identity: Bhavesh / io.github.idkimnewtothis.bhavesh / 1.0.0+1. The upstream tracked signing key and generated local files were removed before creating this app’s new root commit. Upstream source provenance is retained in THIRD_PARTY.md and UPSTREAM_README.md.

## B — Runtime and API checks (partial)

Bundled parent-first Android class loader, certificate gate, explicit 14/16/17 acceptance and separate details dispatch for v17. Pinned v17 stub artifact is checksum-verified during the Android build. Compiled host preserves legacy members; directly comparing older extensions to the v17 stub demonstrates missing old signatures, while the compatibility host passes the four chosen APKs. A DEX checker and missing-member/override regression tests are included. It is a static build gate, not an on-device preflight of every future downloaded APK. Device execution and complete v17 coverage remain UNVERIFIED.

## C/D — Store and metadata (partial)

One metadata model; legacy JSON, modern embedded/external JSON and Aniyomi protobuf parser, strict malformed-input handling, optional-field diagnostic hook, manga exclusion, duplicate package rejection. Both deep links route to the anime store. Repository trust prompt, native certificate mismatch rejection and Android install/uninstall intents are implemented. Uninstall does not depend on repository availability. Failures and retry are visible. Android installer roundtrip, NSFW filtering behavior, Mihon protobuf display-only handling and all store edge cases still require further work/verification.

## E — Details and episodes (partial)

Input URL is preserved through details/episode calls. Details preserve source status. Adapter failures throw source-named errors instead of empty lists. Transport fixture verifies URL, cover, genre, status, fractional episode number, date and thumbnail preservation. The live 12-title matrix is UNVERIFIED; see compat-report.md.

## F — Matching (partial)

Unicode NFKD normalization, CJK/Korean preservation, season/part guards, token and edit-distance comparison, metadata score adjustments and reasons. Sixty title-pair fixtures plus focused alias/Unicode/part tests pass. Confirmed match persistence, override/unmatch UI, top-k picker integration and full multi-season identity work remain incomplete.

## G — Unified search (outstanding)

The inherited search screen compiles. Streaming per-source results, per-source retry/cancellation, robust pagination, duplicate grouping and identity-preserving source switching are not complete. Existing aggregation still waits for its source futures and can hide errors at that layer. Do not interpret adapter error fixes as completion of global search.

## H — Downloads (partial)

Inherited Isar queue/default concurrency 2 retained. Removed broad storage permissions and switched Android default/reset storage to app-specific paths. Arbitrary Android filesystem-path selection is disabled pending a document-tree implementation. Foreground-service integration, retry/backoff tests, fake HTTP queue tests and reboot/kill persistence verification remain outstanding. No real video downloaded.

## I — UI (partial)

Preserved Eclipse/theme engine and shell. Anime-only store choices, explicit manga empty state, source load error/retry display and About attribution added. Existing library/player/reader compile. Comprehensive inset, hero, navigation, TalkBack, contrast, font-scale and reduced-motion work is not finished. Android screenshots UNVERIFIED (no device).

## J — Build and bug sweep (partial)

Fixed baseline analyzer diagnostics, metadata error swallowing, incorrect repository deep-link receiver registration, uninstall requiring trust, missing detail status and QuickJS 4 KB native alignment. Current lib/test analyzer and unit checks are recorded in the release report. No device crash reports were available. This is not a completed zero-crash or lifecycle audit.

## Delivery

New app ID/version and private RSA4096 key. Signed ARM64 release, per-part and whole-file SHA-256 validation, offline HTML joiner with WebCrypto and pure-JS fallback, Python reassembly, and browser failure-case harness. Release artifact checks are recorded separately from app feature completeness.

The task is using the single assigned branch. Separate per-workstream PRs/merges have not been created; no workstream is represented as merged or fully complete.
