# Native inward canopy connection — October 4

Implemented for two accepted, same-height frontages meeting at a concave
vertex. The native Pure Village inward valley reserves 1.5 m on each face;
each two-metre end bay therefore retains an unscaled half-metre strip.
All three replacement pieces must pass the existing clearance callback.

The first native render exposed an upright fin in the source asset itself.
`Roof_Bottom_InCorner_5x5_1` includes a separate `RoofTransition_1` surface
standing above its valley. The baked variant excludes that surface only;
source files are unchanged. Tests compare every retained tile/timber vertex
and index with the source. The corrected close-up shows a closed tiled valley
without the fin. Both native context views of 7/standard were inspected.

Validation: eight frontage tests / 125 assertions pass, including four
rotations, native scale, reserved join lengths, source geometry preservation,
and every emitted hood against public air in generated 13/large.

Limits: blocked or missing adjoining runs still fall back to independent
closed caps. That fallback and short/unequal runs need further work; the
reported town still has an awkward canopy termination on its right side.
The broad upper overhang also remains visually unresolved. This is a verified
connection rule, not acceptance of the complete building generator.

An initial finish bake ran before asset registration and failed; it was
terminated and rerun sequentially after the main bake completed. Final bakes,
tests and native renders exited successfully.
