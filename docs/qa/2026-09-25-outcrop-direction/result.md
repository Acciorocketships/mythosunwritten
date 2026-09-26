# Outcrop direction — owner rejection and references

The September 25 procedural row/bed prototype is rejected. It read as repeated courses of masonry and bands. It has been removed from the active pipeline; its generator, shader and new test are removed. The prior Meadow pipeline is restored while reference research proceeds. No replacement art is accepted.

## Owner references

- `/Users/ryko/Desktop/Screenshot 2026-09-25 at 6.32.01 PM.png`: earlier broad cliff masses and usable irregular ledges, with the player for scale.
- `/Users/ryko/Desktop/Screenshot 2026-09-25 at 6.31.19 PM.png`: earlier rounded green-topped outcrops. Exact screenshot provenance not yet established; do not claim these were necessarily procedural.
- `/Users/ryko/Desktop/e59f1b26-5c1b-48ae-8b2c-ca7711473a8c.webp`: stylized tall cliffs with broad upright faces, asymmetric splits and intermittent shelves.
- `/Users/ryko/Desktop/Screenshot 2026-09-23 at 11.16.51 PM.png`: grass-topped sculpted cliff blocks; large masses first, secondary splits and chipped edges, fine texture last.

## Recovered implementation

`git log --all -- scripts/terrain/field/CliffRockCrags.gd` locates the September 22 snapshot `fa8b2e8b`, September 23 overlay `5eb17926`, and September 24 checkpoint `c3fd09b5`. The older shape implementation remains in `CliffRockCrags.gd`; the sheet style currently bypasses it with outline-only formations.

The recovered generator combines broad mass profiles, detached Nature-pack cross-sections, irregular finite terraces, rounded shoulders and actual ledge triangles. `make`, `_nature_mass_profile`, `_outcrop_profile`, `_rounded_shoulders` and `_long_terraces` are the relevant paths. It is a hybrid generator, not purely noise-based rock. See the September 23 `02-subtle-moss-terraces` chosen images and September 18 `86-cliff-oriented-stones/balanced-context/P12_reported_8.png` for saved prior evidence. The latter closely matches the first owner's amber-cliff example in form, but exact capture identity is not asserted.

## Remaining work

Reuse these larger irregular forms as localized exposures within the moss slope; restore real ledges; keep Meadow boulders upright at the foot. Preserve the shared green material. Model primary splits and chipped silhouettes, and use texture only for subordinate detail. Do not recreate repeated horizontal rows or uniformly sized bricks. Restore broad quiet faces between a few irregular fractures.

The straight dark green seams circled in `download-1.png` are still unresolved. Native aprons, lips and skirt visibility are candidates, not yet a verified diagnosis. The rejected world review was stopped, and no seam fix is claimed.

Rollback validation: restored face-placement tests pass, 2 tests / 71 assertions. The reference images were inspected directly and the historical code was read. No new art acceptance or final world acceptance is claimed.
