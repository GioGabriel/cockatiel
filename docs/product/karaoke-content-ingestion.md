# Karaoke content intake

This is the controlled intake path for the gospel-song candidates transcribed
from the supplied karaoke catalog screenshots. The client has confirmed that
Cockatiel has permission to use and redistribute the recordings. That
confirmation is recorded in the local manifest; it does not make an arbitrary
online recording the correct version of a catalog entry.

## Current intake status — 2026-11-15

- The 22-entry manifest now contains 15 source URLs. Six new recording identities were checked against distributor-provided title, performer, album and duration metadata; original catalog labels are retained separately.
- Direct Firestore and public API checks confirmed 29 existing catalog songs, including nine gospel recordings. All 58 audio/pitch-map URLs returned HTTP 200 and all 29 pitch maps contained points.
- Six additional recordings were extracted using the supported pipeline: `Jesus Generation`, `A Broken Spirit`, `A Heart Like Mine`, `A Man After Your Own Heart`, `A Place at Your Altar`, and `A Pure Heart`.
- Each new package passed hash, duration, timestamp, frequency-bound and catalog-schema checks. These checks establish technical integrity, not melody accuracy. The observed contours remain provisional and contain gaps; they have not received expert melody or singer review.
- All six new recordings have matching-duration lyric results. Five offer synchronized lyrics. `A Place at Your Altar` offers readable plain lyrics; the app labels these as untimed and allows manual scrolling. Lyric selection rejects results more than two seconds away from the catalog duration, avoiding shorter edits with the same title and artist.
- Seven entries remain unresolved. Generic duplicate labels and incomplete titles are not treated as distinct recordings without evidence.

Publication succeeded on retry: all six recordings are linked, and the public preview confirms 35 songs / 15 gospel entries. The retry used full-duration optimized practice copies and small transport writes; stereo upgrades are recorded per song in the publication ledger. Original stereo masters remain preserved locally. See `song-expansion-2026-11-15.json` for the source, delivery encoding and verification evidence. Never infer successful publication merely from local files or a completed media process.

## What the local pipeline does

`tools/karaoke_pipeline.py` validates the manifest, downloads one explicitly
selected source with `yt-dlp`, separates vocals and accompaniment with Demucs,
estimates the vocal fundamental with pYIN, and encodes the accompaniment to
128-kbps MP3. It never uploads, updates Firestore, or writes to Cloudinary.

The generated `pitch_map.json` is an observed vocal fundamental-frequency
contour. It is not a verified lead melody, key map, lyric alignment, or
copyright/licence record. Recording identity and technical integrity must be checked before publication.
Expert review of separation, timing and the target melody is still required before
calling an observed contour an authoritative scoring reference.

## Controlled publication

`tools/karaoke_publisher.py` is the only supported publication path. It is a
one-shot operator tool, not an API route: it reads the three Cloudinary
variables from the execution environment, uploads deterministic audio and JSON
asset IDs, then safely creates a missing `karaoke_songs/{drill_id}` document or
updates a matching existing document. It does not accept arbitrary HTTP
uploads or print credential values. Firestore writes happen only after both
Cloudinary uploads return HTTPS URLs, and existing records are identity-checked
before update.

Publication authorization and pitch-map validity are separate. Recovery
metadata labels the available contours `observed_vocal_contour`; their current
publication state and musical accuracy have not been independently verified.
Do not describe these maps as expert-reviewed. Before using any map as an
authoritative scoring reference, review recording identity, vocal separation,
timing, and target pitches, then record that review in versioned metadata.

The Render variables alone do not make local files available to a local
process. Run the publisher only from a controlled environment that has both
the reviewed asset directory and these variables:

```text
python3 tools/karaoke_publisher.py plan \
  --manifest scratch/karaoke_gospel_manifest.json \
  --assets /path/to/reviewed-assets

python3 tools/karaoke_publisher.py publish \
  --manifest scratch/karaoke_gospel_manifest.json \
  --assets /path/to/reviewed-assets \
  --drill-id gospel_breathe_hillsong_kids \
  --execute
```

Use `--overwrite` only when intentionally replacing the same deterministic
Cloudinary asset. Firebase Admin must also have its normal application-default
credentials. Do not paste the secret into chat, commit a `.env` file, or run
the old `scratch/upload_and_publish.py`.

Example commands:

```text
python3 tools/karaoke_pipeline.py validate --manifest scratch/karaoke_gospel_manifest.json
python3 tools/karaoke_pipeline.py process --manifest scratch/karaoke_gospel_manifest.json --output /private/tmp/cockatiel-karaoke-gospel-assets
```

The second command is plan-only unless `--execute-download` is supplied. Use
the isolated media environment for the pYIN step when processing assets:

```text
PYTHONPATH=. /private/tmp/cockatiel-media-venv/bin/python tools/karaoke_pipeline.py process --manifest scratch/karaoke_gospel_manifest.json --output /private/tmp/cockatiel-karaoke-gospel-assets --execute-download
```

## Lyrics and version matching

The app uses LRCLIB only for optional synchronized lyrics. Search results are
ranked by exact normalized title and artist; a clearly labeled variant such as
`Live` is a fallback, never a replacement for an exact match. This keeps a
lyric result for a different recording from silently appearing to be correct.
See the [LRCLIB documentation](https://lrclib.net/docs) for the search and
lookup fields. Album, duration, and final recording identity still require
content-review data before publication.

## Publication gate

Do not run the old `scratch/upload_and_publish.py` as part of intake. It writes
to Cloudinary and Firestore and contains environment-specific paths. Before
publishing or replacing any listed recording, first read its current remote
record, verify the source and assets, and compare against a versioned manifest.
For each remaining candidate, use the supported publisher with verified
assets, explicit operator action, and identity-checked Firestore create/update.
Do not publish any candidate until its source identity and review status are
resolved.

No raw audio is sent to Gemini or logged by this intake tool. The phone app's
pitch analysis and a source-derived pitch contour are different signals. The
published maps are observed vocal contours, not independently verified lead
melody annotations; file/hash/schema validation is not a musical accuracy
test. Treat karaoke pitch comparisons as provisional until each map has been
reviewed against the correct recording and target melody. Do not describe the
result as a validated singing assessment.
