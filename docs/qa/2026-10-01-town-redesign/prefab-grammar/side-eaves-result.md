# Side-specific eaves and complete context review

The eave fitter previously changed an entire roof to its tight profile when
one side met public headroom. It now records a two-bit side mask. Full native
eave courses, end caps and barge trim use the same side decision; dormer fitting
also selects the corresponding complete native dormer. Explicit legacy
`tight_eave=true` with no mask still means both sides. Existing whole-verge
retraction remains where a perpendicular landing requires it. No player
headroom reduction or arbitrary new roof geometry was introduced.

Tests cover both ridge axes and both obstructed sides, preservation of complete
opposite cornices/caps, exact native triangle clearance, matching barge trim,
legacy tight roofs and idempotence. Existing Suntail expectations were changed
from demanding both sides retract to demanding only the obstructed side retract.

Owner's new screenshot also prohibits turrets on short houses. Production tower
proposal now requires overlapping vertically stacked inhabited storeys. Two
single-storey wings on different terrain heights do not qualify. Eligible tall
houses retain the original proposal probability. No source prefab is changed.

The first `--context` review was incomplete: it included other buildings but
omitted public decks, bridges, stairs and rails. It now uses the same complete
`town_payload` assembly as the town review harness. `full-context/` is the
matched native result. The hollow-looking stone tops are walked terraces with
actual decks/rails. This correction does not establish that every detail is good.

## Still open from download-2.png

- Projection hoods intersecting or poorly meeting main roofs need a general
  native connection rule; the main-gable repair resolves only one orientation.
- Stone/plaster gable seam on the green cottage still needs matching trim.
- Projecting stone block under the upper deck remains visually unresolved;
  missing review decks explained its context but did not make it attractive.
- The upper overhanging house's support appearance needs review in the whole
  structure, not just a floating-volume cell audit.
- Tall-house adjacent masonry/plaster sections need a coherent composition
  and material hierarchy, not per-section choices.
- The shed/canopy from the stone wall still has a poor return/protruding piece.
- Roofless actual houses, if any, must be distinguished from intentionally
  walked terraces by their published function and complete finished surfaces.

Full prefab reconstruction and a shared generative grammar remain unfinished.

Validation:5eave tests120assertions and2height tests6assertions pass.
Eight-town finished-kit survey builds all cases with0floating/roof-air
violations; covered quarters unchanged36,18,42,68,14,24,40,92 across
7standard,31large,13large,43grand,58large,101large,103grand,211grand.

Initial quiet production check failed its timing assertion:14228ms vs machine-
scaled11971ms ceiling;124other assertions passed. The side classifier was
checking all eave triangles even after proving a side obstructed. It now stops
checking that side immediately, and boolean clearance queries return on the
first obstruction. Focused5tests120assertions pass after this optimization.
The first performance result is retained rather than discarded.

Final production check passes all125assertions:10043ms under the test's
unchanged machine-calibrated ceiling (~10803ms, factor1.350). This is not
a claim of raw generation below8000ms; reference calibration was slower too.
