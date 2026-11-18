# System verification — November 15–16, 2026

## Verified result

The available local verification pass is complete: **374 backend tests, 24 content-tool tests and 304 Flutter tests pass (702 total)**. All **29 HTTP operations** have observed successful responses in integration tests. Backend statement coverage is **86%**, not 100%. Python lint/compilation, Dart formatting and Flutter analysis pass. The final Python wheel and Flutter web release build succeed.

These results verify the local revision and its deterministic test scenarios. They do not establish that every possible input, device or deployment behavior is correct. Audit fixes remain local and uncommitted; they have not been pushed, deployed or shipped in a new APK.

## Completed coverage

- Route-derived authentication matrix: every private operation rejects missing, malformed, empty and rejected credentials. Guest catalogs reject invalid supplied credentials.
- Cross-user session isolation: detail, feedback, metrics, attempts, finalization and audio read/write return 404 without altering the owner's session. Session lists isolate users.
- Every JSON-body operation rejects malformed JSON and incorrect top-level shapes with safe 422 errors. Error responses omit submitted marker text and include request IDs. Nonfinite voice measurements are rejected.
- Existing backend suites exercise production configuration, provider/storage failures, quotas, concurrent finalization, queue behavior, analytics, retention, scoring evidence and API contracts. This is local concurrency testing, not production capacity testing.
- All 45 Flutter test files ran, including pitch estimation, scoring, state, API contracts, parsing, lyrics, calibration, widgets and interactions.
- Fifteen screen layouts passed five configurations each: 320×844, 390×844, 320×568 at 200% text, 844×390 at 130% text and 768×1024. Populated analytics charts/metrics are included. Fifteen final 390×844 screenshots were captured and visually reviewed.
- Interaction regressions cover sign-in validation, sign-up password mismatch, password visibility labels, song-search recovery/navigation, analytics filtering, out-of-order responses, failed-period retry, sign-out cancellation/confirmation and mezzo profile selection.
- All 35 available catalog records validate: 29 saved Firestore documents plus six reconstructed from verified publication inputs and the saved publication ledger. This is a saved-data check, not a fresh read of production.
- Nineteen local MP3 files decoded in full without decoder errors. Original/publication input hashes match metadata; pitch times are monotonic, finite and within recording duration. Fourteen bundled/web images, JSON and video assets parse/decode successfully. This does not certify musical accuracy or lyric alignment.
- Limited tracked-source secret-pattern checks previously found no private-key blocks, GitHub token patterns or service-account private-key IDs. Full Git history and credential rotation were not verified.

## Corrections and regressions

| Defect | Corrected behavior |
| --- | --- |
| Production users could self-grant premium through the demo upgrade | Production/staging returns 403 until verified entitlements exist; development demo remains available |
| Early rhythm errors described as near the beat | Large negative delay says ahead; positive delay says behind |
| Firestore audio could exceed document size after base64 expansion | Reject raw audio above 750,000 bytes before writing |
| Audio deletion failures falsely counted as successful retention cleanup | Propagate the failure and retain metadata for retry |
| API response body could stall after the header timeout ended | One deadline covers headers and body; failed response subscriptions are cancelled |
| Sign-in links, feedback scores, history and song cards overflowed with enlarged text | Wrapping, scrolling and responsive dimensions; reduced motion respected |
| Mezzo range absent and misclassified as soprano | All six ranges available; exact normalized matching preserves mezzo |
| Password controls lacked labels; period controls lacked keyboard button semantics | Labelled visibility controls and focusable period buttons |
| Older analytics response could overwrite a newer period | Request identities discard stale responses, including background refresh conflicts |
| Analytics errors silently ignored | Visible error and working retry; empty periods have an explanation |
| Populated analytics labels overflowed at 200% text | Chart headings, dates and metric values wrap |
| Positive infinity accepted in four evidence fields | Segment and aggregate voice evidence require finite numeric values |
| Dependency manifests permitted reviewed vulnerable parser versions | Both manifests require tested FastAPI ≥0.135.1, Starlette ≥1.9.0,<2 and python-multipart ≥0.0.32,<0.1 |

Tests were added before each new behavior fix. The analytics and nonfinite-input logs preserve failing regressions before correction.

## Execution details

Backend tests used Python 3.13.6; deployment configuration specifies Python 3.11.9. Flutter SDK was 3.47.2. Exact backend test versions are preserved in the evidence bundle. Dependencies were installed offline from locally cached distributions; cached parser wheels were checked against their RECORD hashes before installation. A complete fresh deployment dependency installation was not possible with network access blocked.

The standard `flutter test` launcher requires a loopback socket unavailable inside this sandbox. All tests instead ran through Flutter's standalone test compatibility runner: build a debug bundle targeting a generated importer of every test file, then run `flutter_tester --disable-vm-service` with `FLUTTER_TEST=true`. The runner's process exit code alone is insufficient: the recorded final output is `+306: All tests passed!` (304 tests plus two suite hooks), with no failed-test marker. The importer and complete log are retained. Ordinary CI can use the repository's `flutter test --coverage` gate. A fresh Flutter coverage percentage is not claimed.

The final web build succeeds. It emits an existing warning about the Cupertino icon font family; source inspection found no explicit CupertinoIcons usage. Wasm dry-run success is a compiler check, not a browser runtime test. The Python wheel builds successfully; production uses source installation via Render rather than this wheel.

## Environment-blocked verification

| Check | Observed blocker | Evidence needed to close it |
| --- | --- | --- |
| Android release build | Gradle FileLockContentionHandler cannot open its required socket: Operation not permitted | Successful release build in an unrestricted trusted runner |
| Escalated execution / GitHub write operations | Approval service fails before execution with HTTP 503 / bridge cooldown | Functioning approval service, then run remaining build/release steps |
| Fresh live health/catalog and authenticated production flows | Shell cannot resolve the backend hostname; web connector also reports the URLs inaccessible | Reachable service and an authorized test account |
| Full current dependency-advisory scan | Network access and a complete scanner/database unavailable | Online scan of the resolved production dependency set |
| Real audio-device behavior | No connected representative test device available | Microphone/permission, Bluetooth, interruption, latency and singer testing |

Neither a blocked launcher nor a passing local suite proves live production health. No production load or destructive restore exercise was attempted.

## Production findings that testing does not implement

- Android uses debug signing and a `com.example` application ID; the original V10 signing key is unavailable. No store-ready release is claimed.
- Rotation of the Cloudinary root secret exposed earlier in a screenshot remains unverified.
- Premium purchasing/verified entitlement integration is absent. The new guard prevents self-grants after deployment, but does not implement billing or audit existing grants.
- Optional AI queues and finalization locks remain process-local. Distributed durability and multi-replica guarantees require implementation and deployment tests.
- Application rate limiting, request budgets, bounded telemetry/pagination and cost protections need explicit production limits and validation.
- Dependency security floors are tightened, but a full reproducible production lock and full vulnerability scan remain outstanding. Targeted vendor advisory review is not a vulnerability-free certification.
- Backup restoration, production alerting/SLOs, capacity and Firebase rules require operational verification.
- Layout and selected interaction tests do not exhaust every screen-reader, keyboard, OS or authenticated end-to-end path. Reference-image styling is an adaptation, not a pixel-identical reproduction or client acceptance.

## Reviewed dependency advisories

- [python-multipart header parsing denial of service](https://github.com/Kludex/python-multipart/security/advisories/GHSA-pp6c-gr5w-3c5g)
- [python-multipart parameter smuggling](https://github.com/Kludex/python-multipart/security/advisories/GHSA-vffw-93wf-4j4q)
- [Starlette URL-encoded form limits](https://github.com/Kludex/starlette/security/advisories/GHSA-82w8-qh3p-5jfq)

## Endpoint evidence

Observed local integration responses; counts are requests across the full backend suite, not production traffic or performance measurements.

| Operation | Observed statuses | Requests |
| --- | --- | --- |
| `GET /v1/auth/me` | 200, 401, 503 | 22 |
| `GET /v1/profile` | 200, 401 | 15 |
| `PUT /v1/profile/preferences` | 200, 401, 422 | 18 |
| `POST /v1/profile/tier/upgrade` | 200, 401, 403 | 10 |
| `GET /v1/ai/health` | 200, 401 | 6 |
| `GET /v1/ai/jobs` | 200, 401 | 6 |
| `GET /v1/ai/jobs/{job_id}` | 200, 401 | 5 |
| `POST /v1/sessions` | 201, 400, 401, 422 | 48 |
| `GET /v1/sessions` | 200, 401 | 6 |
| `GET /v1/sessions/{session_id}` | 200, 401, 404 | 27 |
| `POST /v1/sessions/{session_id}/finalize` | 200, 401, 404, 409 | 35 |
| `POST /v1/sessions/{session_id}/attempts` | 201, 401, 404, 409, 422 | 29 |
| `POST /v1/sessions/{session_id}/metrics` | 202, 400, 401, 404, 422 | 18 |
| `GET /v1/sessions/{session_id}/feedback` | 200, 401, 404 | 7 |
| `GET /v1/analytics/dashboard` | 200, 401 | 8 |
| `GET /v1/analytics/trends` | 200, 401 | 6 |
| `POST /v1/sessions/{session_id}/audio-snippets` | 201, 400, 401, 404, 422 | 13 |
| `GET /v1/sessions/{session_id}/audio-snippets` | 200, 401, 404 | 7 |
| `POST /v1/audio-snippets/cleanup` | 200, 401 | 5 |
| `GET /v1/training/catalog` | 200, 401 | 5 |
| `GET /v1/training/progress` | 200, 401 | 6 |
| `GET /v1/training/recommendations` | 200, 401 | 5 |
| `GET /v1/karaoke/catalog` | 200, 401 | 10 |
| `GET /v1/karaoke/catalog/preview` | 200, 401 | 6 |
| `GET /v1/karaoke/catalog/{drill_id}` | 200, 401, 404 | 7 |
| `GET /v1/karaoke/progress` | 200, 401 | 5 |
| `POST /v1/karaoke/evaluate-tone` | 200, 401, 413, 415 | 9 |
| `GET /health` | 200 | 1 |
| `GET /metrics` | 200, 404 | 2 |

## November 18 publication verification

Before publication, backend lint/compilation, all 374 backend tests, all 24 content-tool tests, and the Python wheel build were rerun successfully. The Flutter studio redesign, distinct three-step onboarding artwork, recovery states and reduced-motion changes pass 469 tests, including 216 responsive matrix cases; Dart formatting, analysis and production web build pass. Gallery renders use fixtures, not live microphone or authenticated production sessions.

The earlier statements about local/uncommitted changes and approval-service outages describe the November 15–16 snapshot. GitHub publication is now authorized; live Render deployment and its resulting health must be verified separately. Render serves the API; publishing Flutter source does not distribute a new mobile release.
