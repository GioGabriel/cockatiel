# Karaoke content intake

This is the controlled intake path for the gospel-song candidates transcribed
from the supplied karaoke catalog screenshots. The client has confirmed that
Cockatiel has permission to use and redistribute the recordings. That
confirmation is recorded in the local manifest; it does not make an arbitrary
online recording the correct version of a catalog entry.

## Current intake status

- 22 visible catalog entries are recorded in
  `scratch/karaoke_gospel_manifest.json`.
- 9 entries have candidate YouTube source URLs.
- A prior recovery note reports that six recordings were published:
  `Glorify Your Name`, `Glory`, `All For Love`, `Hosanna`,
  `Lead Me to the Cross`, and `Oceans (Where Feet May Fail)`. This checkout
  does not include a Firestore export or publication ledger, so their current
  Cloudinary and Firestore state has not been independently verified.
- The same recovery note reported a guest catalog preview with 9 Gospel drills.
  That deployed preview has not been re-queried; the remaining three records
  have not been individually audited here.
- The manifest includes three Hillsong Kids candidates: `Breathe`,
  `Get Up And Dance`, and `I'm Really Happy`. Their current publication and
  local review-package status is unverified.
- 13 entries still need a source URL or an unambiguous recording identity.

The six recording names and deployed counts above are recovery notes, not live
service evidence. Local artifacts outside this repository are not a complete
publication record: some song folders lack metadata or a final instrumental.
File presence and schema tests cannot prove that remote assets exist, that
Firestore currently serves them, or that an extracted contour is musically
correct. Recheck the live catalog and asset inventory before an operational
decision. The `Oceans` instrumental was reported as encoded at 96-kbps
stereo/44.1-kHz to meet the service's asset-size limit; that deployed asset was
not inspected during this source recovery.

## What the local pipeline does

`tools/karaoke_pipeline.py` validates the manifest, downloads one explicitly
selected source with `yt-dlp`, separates vocals and accompaniment with Demucs,
estimates the vocal fundamental with pYIN, and encodes the accompaniment to
128-kbps MP3. It never uploads, updates Firestore, or writes to Cloudinary.

The generated `pitch_map.json` is an observed vocal fundamental-frequency
contour. It is not a verified lead melody, key map, lyric alignment, or
copyright/licence record. Human review must confirm the recording identity,
whether the separation is clean enough, the timing, and the target contour
before publication.

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
