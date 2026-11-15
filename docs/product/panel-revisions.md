# Panel and client revisions — 2026-11-14

Source: `Revisions-List-Cocketiel with Recos.docx` and the two client design references.
The form's panel requests are treated as requirements. The later developer/researcher
notes supply recommendations; their medical and timing claims are not treated as validated standards.

| Request | Implementation / evidence |
| --- | --- |
| Six selectable vocal ranges | Soprano, mezzo-soprano, alto, tenor, baritone and bass remain available. Shared display/detection bounds use the requested practical ranges; they are guidance rather than a formal voice classification. |
| Gender option | Optional gender persists through the API and profile. Common groups are explained while all six ranges remain selectable. Unit and endpoint tests cover persistence, invalid input and a range outside the suggested group. |
| Rename karaoke; church songs with backing and lyrics | User-facing name is Song Practice. The initial revision retained the existing catalog; the user authorized expansion on 2026-11-15 (see rollout update below). Optional lyrics and media have bounded loads and visible availability states. |
| Feedback after singing | The finalization response is opened directly when it contains feedback. Saved takes survive a failed review request; retries do not resave a successfully saved take. Queued reviews open automatically when ready, with bounded polling and access to saved reviews. |
| Organized, friendly flow | Home exposes Voice studio, Song Practice and a practice-rhythm guide. Briefing → warm-up → live practice → review is explicit. |
| Maximize training visuals | A focused live screen devotes at least half the viewport to the visual and keeps one cue, timer and stop action. An interrupted training take is not saved as a completed full-duration attempt. |
| Less result text; visualization; read more | Score ring and metric bars with a short next step. Full coaching/measurement details are collapsed under “Read full feedback”. |
| More reliable song practice | Timestamp maps are sorted and validated, invalid neighboring frames do not discard valid data, and lyrics support multiple timestamps and offsets. Progress outages do not hide the song catalog. Request, response and session metadata accept song takes up to the catalog limit of 600 seconds. Very short or unusable takes offer a fresh recording. |
| Client design | Shared midnight/violet/rose theme, rounded controls, bundled microphone artwork, bundled Inter/Outfit fonts, and responsive studio cards. |
| Practice recommendations | An optional routine explains warm-up, one technical focus, song application, cooldown, rest and basic music concepts. It avoids guarantees of improvement or diagnostic claims. |

## Scope and rollout

- This source revision does not change the live catalog or publish new music. The user selected “Keep the current catalog for this revision”.
- The updated backend auto-deployed after PR #1 merged. Its live OpenAPI contract was verified to include optional gender and a 600-second attempt limit on 2026-11-15.
- Automated tests and builds verify source behavior. Microphone accuracy, audio routing, synchronization against each actual recording and usability still require a representative Android device and singer review.
- The deployed guest catalog preview initially timed out, then responded after warming up on 2026-11-15. See the rollout update for verified counts.

## Verification and review build

- Flutter: 229 tests passed, analyzer clean, formatting applied.
- Python backend and tools: 235 tests passed; backend coverage was 85%. Ruff and Python compilation passed.
- Web and Android release builds succeeded. `git diff --check` passed.
- Android review artifact: `mobile/vocal_coach_app/build/app/outputs/flutter-apk/app-release.apk`, version 5.1.0, build 7.
- The review APK and the supplied V10 APK use different Android debug signing certificates. This artifact cannot update that existing installation in place. Preserve the existing installation and its data; an upgrade-compatible artifact requires the original signing key. Production distribution also requires release signing.
- Screen previews were captured at narrow phone widths and reviewed for overflow. Physical-device microphone, audio and recording synchronization checks remain outstanding.
- App changes were committed, pushed and merged through PR #1; the publication audit was merged through PR #2. The backend auto-deployed and was verified through its live contract. The catalog remains unchanged because audio uploads failed.

## Rollout update — 2026-11-15

The user subsequently authorized autonomous song extraction, Cloudinary upload,
catalog expansion and the remaining release work. This supersedes the earlier
instruction to keep the catalog unchanged.

- Direct Firestore inspection found 29 existing songs, including nine gospel recordings.
- All 58 existing Cloudinary audio/pitch-map URLs returned HTTP 200; all 29 pitch-map responses contained points.
- Six additional recordings have distributor-provided source metadata recorded in the manifest. Performer names are distinguished from original catalog composer labels.
- The signed-in Render workspace contains unrelated services and does not expose the existing Cockatiel service. Deployment cannot be confirmed from that account.
- No Android device was attached when checked. Real microphone, routing and singer acceptance checks remain unavailable.
- The original V10 signing key is not present in the supplied project; the review APK remains signed with this machine's debug certificate.

- Follow-up verification: 229 Flutter tests and 235 backend/tool tests passed locally; analysis, lint, compilation and web/APK release builds passed. CI now pins Java 17 because the runner's default Java 25 is incompatible with Gradle 8.14. Content tooling tests are included in CI.
- Recording-duration matching prevents lyric selection from silently choosing a shorter edit; untimed lyrics have a clearly labelled manual-scroll view.
- Before deployment, the live OpenAPI contract still had a 300-second attempt limit and no gender field. A successful GitHub merge alone must not be reported as verified deployment.

- Audio publication is blocked by repeated transfer timeouts, including 60/180-second signed uploads, a second multipart transport, native HTTP/2 and a 1 MiB chunked transfer. One unlinked pitch-map asset was uploaded successfully; zero new catalog documents were created. All six complete local packages are preserved under the workspace's `karaoke-expansion-2026-11-15/` directory.
- The versioned `song-expansion-2026-11-15.json` report records source identities, hashes, lyric availability, sparse-contour evidence and publication attempts. The public catalog remains at 29 total songs / nine gospel songs until audio upload succeeds.

## Final delivery status — 2026-11-15

- PR #1 (`4812ea9`) merged after both GitHub quality jobs passed on final app code. PR #2 records operational evidence; no runtime code changed in that report.
- Live deployment verified: the profile contract includes gender and training attempts accept up to 600 seconds. No direct Render dashboard deployment was necessary.
- The review APK is preserved as `../Cockatiel-5.1.0-build7-review.apk`. SHA-256: `84e123040e2f4565354a0bda2468f70e6cb56a6a3e69e01886fa3eae77f83ffc`.
- A GitHub prerelease draft was prepared. Its small checksum asset uploaded, but APK transfer exceeded 150 seconds; the draft was not published without its APK.
- The repository has no existing Actions secrets for remote content publishing. No credentials were added to GitHub or exposed in source to work around the local transfer failures.
- Outstanding: Cloudinary audio transfer, original V10 signing key, real-device audio checks and client/panel acceptance. Six verified local song packages are ready for the supported publisher once the transfer path works.

- Final transfer diagnostic: a 64 KiB chunk reached Cloudinary and returned HTTP 400 because non-final chunks must exceed 5 MB. Smaller chunks therefore cannot work around the stalled larger transfers on this connection. Final public preview still confirms 29 songs / nine gospel entries.
