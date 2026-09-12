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
- 3 candidates have been prepared locally for review: `Breathe`, `Get Up And
  Dance`, and `I'm Really Happy` by Hillsong Kids.
- 6 candidate URLs returned HTTP 403 when their audio was requested. They are
  not marked as ready and were not bypassed.
- 13 entries still need a source URL or an unambiguous recording identity.

The local outputs are outside the repository under
`/private/tmp/cockatiel-karaoke-gospel-assets`. They contain an MP3 instrumental,
a JSON pitch contour, and metadata with hashes and evidence statistics. They
are deliberately marked `local_review_required`.

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
asset IDs, and then updates an existing `karaoke_songs/{drill_id}` document.
It does not create an incomplete Firestore document, accept arbitrary HTTP
uploads, or print credential values. The Firestore update happens only after
both Cloudinary uploads return HTTPS URLs.

The tool intentionally refuses the current pilot output because it is marked
`local_review_required` and `observed_vocal_contour`. A reviewer must replace
those metadata values with `approved_for_publication` and
`reviewed_target_contour` only after checking the recording identity,
separation, timing, target pitches, and catalog record. This prevents an
observed singer's contour from silently becoming the scoring target.

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
to Cloudinary and Firestore and contains environment-specific paths. A future
publication step must use reviewed assets, verified URLs, a versioned import
manifest, and an explicit operator action. It must also create or update the
matching `karaoke_songs` document with the correct title, artist, duration,
vocal range, melody reference, instrumental URL, and pitch-map URL.

No raw audio is sent to Gemini or logged by this intake tool. The phone app's
pitch analysis and the published target map must remain separate: a source
recording's detected vocal contour is evidence for review, not authority for a
user's numeric score.
