# Cliff formation sampling and physical tread repair

Production retains one scoped geometry repair. C01/C02/C03 and the owner's
request for more interesting physical formations remain open. No water, town,
streaming or biome issue is closed. The larger formation studies are rejected.

## Retained physical repair

The generator computed the vertical drop of a curved ledge before projecting
its vertices into the final cliff envelope. That later step can shorten the
ledge horizontally. Keeping the old drop then turns a gentle tread into a
steep channel and can exclude it from the upward-facing turf surface.

The final width now scales the original tread drop when a tread shrinks. Its
root stays fixed. Expanding treads do not lower their fronts into the next
riser. This is a vertex-position change in the common rendered/collision mesh;
there is no shader, normal-map, or color-texture change. Production carries no
study audit arrays. Positive-width treads are corrected; this does not claim a
repair for every possible inverted or vanished tread.

The red-first regression measures actual physical cap endpoints for 48 m wide,
8 m and 32 m high walls, seed 2697992464, pose (-13.5, 0, 10.5). Before the repair,
181 of 461 measured caps exceed their intended grade by more than 0.02; maximum
excess is 1.609527. Afterward, all 461 endpoints exist in the physical shell,
zero caps exceed the bound, and maximum excess is 0.000789 (mesh quantization).
The separate pre-triangulation diagnostic reaches the same 181-to-zero result.

The retained production run passes **23 tests / 72 assertions**. It includes
31 closed photo shells with zero bad edges or degenerates, 57/57 covered cap
probes, native corner closure/admission/ownership, crown/lip bounds, and the
actual grass worker: **332 supported patches, zero escaped or buried roots**.
A Godot physics probe builds actual ConcavePolygonShape3D collision from the
new shell and checks **333 visible turf contacts**: zero missing/wrong bodies,
maximum contact error 0.000006914 m. This is physical ray verification, not a
new character traversal or a fresh full-world regeneration.

## Visual review and limitations

Matched 32 m oblique and overhead views compare `before-tall/` with
`tread-tall/`. The overhead view shows restored shallow cap surfaces and some
thin turf boundaries; it also still shows the inherited long upright supports.
The scoped repair is retained for its physical correctness and preserved joins,
not as acceptance of that cliff composition. Seventeen frozen production-world
views are saved; P12 side, P17 front and P20 oblique were inspected. These
rebuild the cliff and its plants on frozen terrain, and do not regenerate the
world's grass, hydraulic admission, or collision. The independent worker and
physical tests above cover only their stated fixtures.

The upper cliff is still too plain, while some lower regions are organized
into smooth upright supports. Thin/angular turf ends remain in places. The
owner's request for actual interesting bumps, outcrops and random formations
is **not yet satisfied** by this repair.

## Rejected formation experiments

- Finite Nature-rock additions from pass 73 had a steep contact ramp: an added
  depth jump around 0.87 m over 0.20 m. Using contact distance in metres removes
  the major fins. The red contact invariant has 430 directed edge occurrences;
  the corrected study has zero. The unrestricted maximum added edge gradient
  falls from 5.878 to 2.010 (the last edge has a small absolute depth jump).
  Despite that improvement, `contact-world/` and `contact-tall/` still read as
  embossed/smooth patches. Rejected, not production.
- `shape-preserving.gd` avoids the pointwise depth clip, but loses readable
  ledges and retains plain faces. Rejected.
- `broad-contacts.gd` widens and reduces the number of sampled additions. The
  game and tall images retain blunt forms and narrow marks. Rejected.
- `primary-bodies.gd` replaces the old primary body with finite rock fronts.
  It exposes a large plain upper face and loses ledge coverage. Applying the
  tread repair in `primary-treads.gd` helps the tread but not that composition.
  Both are rejected.
- `shoulder-forms.gd` tests irregular polygonal rounded shoulders with wider
  feet and independent slopes. The amber image still looks too smooth and
  does not demonstrate the required rocky shape improvement. Rejected.

The native diagnostic also includes shadow/SSAO/shading controls. The faceted
view confirms that some strips are actual mesh geometry rather than only a
material effect. No rejected study is used by production. Contact studies are
pinned to the exact pass-69 generator (`before.gd`, verified SHA-256), so the
retained production repair cannot silently change their baseline.

## Reproduction

- `tests/test_september18_cliff_tread_projection.gd`: actual-mesh regression;
  optional `STORY_COLUMN_GENERATOR` selects the candidate. The intended grades
  come from the immutable pre-repair construction in `tread-before.gd`.
- `test_tread_grade.gd`: internal construction diagnostic, study only.
- `test_contacts.gd`: red contact-shape control; set `STORY_COLUMN_GENERATOR`
  to the local `contact.gd` for the corrected study.
- `physics-probe.gd`: headless Godot collision contact survey.
- `production.patch`: minimal retained production edit relative to pass 69.
- `source-hashes.json`: source and evidence provenance.

No general startup/performance, fresh-world traversal, full-suite, or full
cliff-art acceptance is claimed.
