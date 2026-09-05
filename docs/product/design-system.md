# Cockatiel design system

This is the product visual contract for the Flutter client. It keeps the
Cockatiel bird, microphone, waveform, and dark premium character while making
the interface legible to a beginner and credible in a thesis or enterprise
demonstration.

## Principles

- **Clarity before decoration.** Every visual treatment must improve hierarchy,
  state recognition, or interaction confidence.
- **Matte layered surfaces.** Use the theme's background, surface, raised
  surface, outline, and semantic state tokens. Borders and spacing carry more
  structure than shadows.
- **Restrained accents.** Teal communicates the primary action; blue supports
  secondary navigation; semantic success, warning, info, and danger colors are
  used consistently and never as the only signal.
- **Progressive disclosure.** Beginners see plain-language guidance first;
  detailed pitch, timing, confidence, and waveform metrics remain available in
  an optional details layer.
- **Accessible by default.** Preserve contrast, 48dp interaction targets,
  visible focus, meaningful semantics, text scaling, keyboard navigation, and
  reduced-motion behavior.

## No-gradient policy

Decorative gradients, uncontrolled neon, heavy glass blur, and glow effects are
not part of the default system. They make state harder to interpret, increase
contrast risk, and create visual inconsistency across screens. A gradient may be
introduced only when it has a documented functional purpose, passes contrast and
performance review, and is covered by a stable visual test. Image artwork may
retain its own approved treatment, but text and controls must remain on a
readable opaque or sufficiently contrasted surface.

The Dribbble references supplied during review informed broad ideas—clear song
discovery, readable lyrics, strong player hierarchy, and concise metadata. No
Dribbble asset, branding, wording, or layout is copied. Decorative neon and
glass-heavy treatments were intentionally rejected in favor of comprehension,
accessibility, and maintainability.

## Tokens and components

`lib/app/theme/app_theme.dart` owns the Material color scheme, typography,
surface levels, component shapes, and interaction defaults.
`lib/app/theme/app_theme_tokens.dart` owns semantic colors that are not native
Material roles. Shared cards, badges, navigation, empty states, skeletons,
waveforms, and feedback components should consume those tokens rather than
inventing local colors.

When a screen needs a new visual role:

1. Check whether an existing Material or semantic token describes it.
2. Add a token only if the role is reused or has a distinct accessibility meaning.
3. Add the focused widget/semantics test before changing the component.
4. Verify light/dark contrast, large text, narrow width, focus, loading, error,
   and disabled states.

## Product language

Primary labels should use plain language: “Voice profile” instead of an obscure
settings label, “How accurate was your pitch?” before a raw metric, and “AI
summary (optional)” when a remote provider is involved. Terms such as vocal
range, pitch accuracy, timing, breath support, resonance, vibrato, waveform,
confidence, calibration, and practice difficulty must have helper text or a
“What does this mean?” affordance.
