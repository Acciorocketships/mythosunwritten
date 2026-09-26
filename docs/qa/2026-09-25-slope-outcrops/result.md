# Sloped rock inclusions and rolling cliff sides — September 25

Owner reference: `image-1790364668358.jpg`. Requested mid-slope clusters with
buried ends and exposed rocky sides, larger basal rocks, gentler rolling slopes,
and retirement of the crossed-out KayKit rock family throughout the world.

## Changes

- Face clusters anchor at 44–64% of each wall's height, with small per-rock
  variation. Their long axes lie in the actual two-dimensional slope tangent,
  with a small random roll. They no longer retreat downhill to bury a base.
- Two or three closely grouped rocks survive per cluster. A failed companion
  cannot leave a singleton. Basal clusters use the existing lower layered rocks,
  25% larger (capped at 6.4 m), near 8–16% of the wall height.
- The elongated Farmlands masses keep their middle relief; their buried end
  portions taper. End support samples sink both caps into the surface. Normals
  follow the taper's Jacobian, and the slope's small unions rotate with each rock.
- Envelope shoulder radii are 1.8–4.8 m, foot radius 3.6 m. Tall relief blends
  between 0.7 and 1.4 m shoulders with a 1.5 m foot: it retains rolling variation
  instead of collapsing to one fixed narrow profile. Fine noise is softer and
  broader. Flat terrace centres and compact corners remain constrained.
- Ambient and cliff-foot dressing use existing LPFV rocks in place of KayKit
  rocks. Terrace-cap KayKit rocks are removed, including their collision and
  grass obstacles. Catalog resources remain for historical fixtures, marked
  catalog-only in both descriptors and the bake manifest.

## Evidence

- Red-first alignment/end regression failed on the previous placement.
- Initial actual-mesh check found 9,390 exposed end vertices out of 32,548;
  final native control has zero. This catches the broad cap faces missed by
  testing only the long-axis endpoints.
- 34 slope tests / 13,047 assertions pass: continuity, flat terraces, slope
  descent, road cuts, shared chunk seams, rock clusters, buried basal bases,
  native caps, and catalog/dressing retirement. The expanded native-cap test
  also passes at 4, 8 and 16 m wall heights with an outer corner.
- Dressing field, ecology and collision: 17 tests / 695 assertions pass.
- Focused native control: `tests/harness/slope_outcrop_review.gd`.
- Production site: seed 2697992464, stream anchor (262,30,1045).
  Matched wide camera (292,49,1083) toward (260,25,1035); supplemental face
  camera (262,32,1045) toward (300,31,990). These are review poses, not an exact
  reconstruction of the owner's screenshot (no F3 coordinates were supplied).

## Fresh production views

`wide-before.png` and `wide-after.png` use the same camera. `face-after.png`,
`side-after.png`, `detail-after.png` and `high-after.png` are fresh production
captures with regenerated grass and ambient dressing, not hot-reload evidence.
The shorter mid-face rock sides, buried ends, grouped stones and larger basal
rocks are visible; the large blocky KayKit silhouette on the upper plateau is
replaced. The slope widens modestly and rolls between its ridges and valleys.
Hard straight grass edges on some terrace tops remain visible, especially in
the closer/high views; this is not a claim of complete terrain-art acceptance.

## Validation limits

The September 13 dressing suite passes all placement assertions, but GUT marks
one test failed because six existing KayKit terrace materials have unresolved
resource UIDs and load by path. The catalog suite similarly has 18/21 tests passing;
three are marked failed solely by existing unresolved material UIDs (including
village materials). No placement or catalog assertion failed. The full project
suite was not run. Cliff slope rocks remain visual-only, as before.
