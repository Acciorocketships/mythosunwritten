# Doorway side panels — P37

Accepted September 14, 2026 for the reported native doorway housing.

Seed 2697992464; player `(997.5, 26.1, -412.7)`, crosshair `(993.2, 27.2, -415.0)`. ReviewCam reconstructs the rounded screenshot overlay, with ±8° controls. The circled room is `spatial.parcel.maze.house.015.part00.room00`.

## Change

The closed doorway's side housing previously compressed diagonal native M001 wall stock to 0.12 m depth. It produced thin protruding diagonal panels unlike the adjoining facade. The general asset recipe now uses horizontal native M005 stock at its full 0.4686609 m relief. Baker 37 mirrors the left return about the stock's actual centre, preserving winding and placing both complete timber jambs toward the front. The new optional manifest field defaults off for other assets. All ten closed-door variants are rebaked, including mirrored, mitered and floor-owned alternatives. Source FBXs are unchanged.

The actual leaf, hinges and arch remain intact; replacing the housing legitimately replaces its outer framing. The original doorway envelope and room transforms remain fixed. The older central-preservation test formerly included the side framing out to X=1.3; it now checks the authored leaf/arch region inside X=0.85 (actual arch under 0.80).

## Falsification and visual evidence

The original depth test failed all 72 samples (`red.txt`). Final depth/framing checks cover 96 native rays over both hands and four variants. An additional 2,715 interior-to-exterior sightlines verify no new openings through the assembled room around either corner.

Several alternatives were rejected: reversing the whole door faced the wrong way; overlapping the uncut original housing exposed a white strip; full-depth diagonal stock retained the wrong pattern; unhanded horizontal stock left one front corner without its native post. The first rectangular silhouette probe reported 26 grazing rays at X=±1.49. Those lie outside the native recessed profile; the replacement room test checks actual enclosure instead. This distinction is recorded rather than treating the grazing results as verified holes. The unhanded candidate is superseded; `controls/pairs.jpg` is that earlier comparison.

Reviewed final pairs:

- [Three native photo-angle pairs and differences](native-reproduction/P37/pairs-final.jpg).
- [Three matched game pairs/differences and three fresh game views](game-pairs-final.jpg).
- [Five neutral-lit complete-room controls](controls/pairs-final.jpg), including both front corners and both rear returns.

The game differences are localized to the modified native housing. Final fresh startup is 367.264 s; this is not a performance acceptance. The existing snapshot helper reports its editor-only packing warning.

## Validation

- Two new tests pass, including complete room enclosure. The 32 distinct focused/closure tests total 1,896/1,898 assertions; 30 pass. Both failures reproduce with the original assets: the older photographed frontage owner (`frontage-baseline.txt`) and September 8 retaining-remnant treatment key (`cap-baseline.txt`). No historical assertion is changed to pass.
- Actual original/final collision gives identical results at all 164 local stances and 235 crossings (`clearance-final.txt`, `clearance.json`).
- All 48 seed/scale towns seal and retain 11,868 clear public stances and 17,035 clear crossings, with zero blocked centres/crossings. The existing 25 off-centre AABB contacts remain. See `corpus-final.json` / `corpus-final.txt`.
- Composition passes 95/95 (`gate-final.txt`).
- Payload batches and box collision are identical. Of 56 generated surfaces, six existing visual doorway floor caps add four triangles each; their collision remains identical. The native door collision follows the new native mesh. See `surface-differences.json`.

No full-suite, global streaming, renderer, or startup-speed claim is made. Other photographed facade, roof and village composition issues remain separate.
