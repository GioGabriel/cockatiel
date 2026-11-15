# Cockatiel client visual system

The client references supplied on 2026-11-14 replace the earlier matte/teal direction.
The product keeps its Cockatiel name and singing workflows while using the references'
midnight backgrounds, violet/rose accents, large voice artwork, rounded cards and pill controls.

## Reusable visual roles

- Background: deep midnight (`#070419`), with a restrained violet/rose wash on entry and studio surfaces.
- Surface: `#120C2B`; raised surface: `#21143C`; borders: `#332446`.
- Primary: lavender (`#C4A7FF`) with dark text; secondary: rose (`#F2A7D5`).
- Typography: bundled Inter for reading and Outfit for headings. Both include their OFL licenses and work offline.
- Voice artwork: bundled 3D microphone art tinted violet, with a vector microphone fallback. The supplied reference screenshots are design references, not application assets or branding.
- Cards and primary controls: rounded, readable surfaces. Gradient artwork never replaces recording/error/success labels.

`AppTheme`, `VoiceStageBackground`, `StudioCard` and `VoiceHero` own this shared styling.
Keep controls at least 48dp, permit text scaling, and use scrollable content on narrow screens.
The focused training surface reserves at least half of its viewport for the training visual.
Results show the score and next step first; the full breakdown is available through “Read full feedback”.

## Language and flow

- Home → Voice studio → exercise briefing → optional warm-up → focused live take → review.
- Home → Song Practice → church-song catalog → song briefing → sing with lyrics and backing when available → feedback.
- “Song Practice” is the user-facing name; existing `karaoke` API and persistence identifiers remain compatible.
- Voice range is a selectable practice preference. Optional gender suggestions never remove voice-range choices.
- Technical measurement details belong in expandable feedback, not the main singing view.

Visual checks render onboarding, live practice and feedback at 320px and 390px widths with bundled fonts.
Behavior tests also exercise large text and review retry paths.
