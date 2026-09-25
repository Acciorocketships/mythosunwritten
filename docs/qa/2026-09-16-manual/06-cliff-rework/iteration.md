# Cliff rework — owner rejection, September 16

Status: active; no candidate accepted.

The prior widened Ultimate Nature mounds were a poor response to the report. They retained independent summits, overlaps between detached lower and upper shapes, and spread turf across steep faces. Earlier QA counts do not constitute visual acceptance. C01–C03 are reopened explicitly by the owner.

The revised construction is an original closed terraced buttress: highest rear ridge buried within the unchanged native cliff, gray contact shoulder, connected lower terraces within the same mesh, native turf only on flatter exposed ledges. This replaces the six outcrop assets through the ordinary catalogue baker; visual triangles remain the collision source. Water/public exclusions and canonical ownership remain active.

Rejected iterations:

- First export: winding inverted, caught by six signed-volume assertions. Corrected before judging.
- Study 01: joined geometry but regular concentric outlines look like stacked platforms. Rejected despite closed-mesh pass (36 assertions).
- Study 02: bevels improve the rock faces, but two continuous green bands still repeat across every formation. Gray junction tests also fail at lateral ledge ends; one small green area is too steep. Rejected.
- Study 03: asymmetric one/two-ledge silhouettes remove the duplicated bands, but one variant loses most usable turf. That ledge was widened rather than relaxing the flatness/contact test.
- Study 04: full smooth normals look clay-like and erase the stone planes. Rejected; final candidate retains 72% of face normals and 28% shared smoothing.
- Short wall spans: two depth/width failures caught in the arrangement fixture. Outward depth now bounds to 58% of available wall width.

Early focused verification: 17 tests / 579 assertions passed (`tests-06.log`). Later geometry and support changes supersede this result; see the latest runs below. This is technical evidence, not art acceptance.

Study scenes use actual catalogue meshes, native wall/lip modules and fixed light. They isolate shape; they do not establish production rooting, wet/public exclusions, biome rendering or player traversal. Fresh production review is required after the study is convincing.


Production 01 judgment (three reported poses inspected at full resolution):

- P20: gray wall/outcrop color relationship and buried shoulder improve; no independent rounded summit. The ledge still reads as a narrow band and needs scrutiny in wider context.
- P17: gray roots connect, but a short-span formation retains an excessively deep nose. Rejected; the depth/width correction applies to the next fresh world.
- P12: an isolated turf patch on the upper shoulder is visually poor. Rejected; usable bench rings are now level so material admission no longer fragments them through slope variation. Original player feet also intersect new rock; subsequent review uses native ray-supported stances and records them.

Production 02/03 judgments:

- Production 02's P12 and P17 cameras changed pitch when only the supported feet were adjusted. These are diagnostic views, not valid matched art acceptance. Production 03 translates the crosshair by the same vertical offset and records it.
- Production 03 P20 retains a blocky central riser and a narrow turf ribbon. P17 has better gray junctions but insufficient usable ledge width. Rejected.
- Highland 03 confirms the same bare, mechanical ledges under a second biome. Rejected.
- The thin foreground fin in P11 survives both width and rear-taper changes. Actual visual triangle rays (`fin-probe/probe.json`) identify `kaykit_rock_03_00`, an ambient rock at approximately (-587.585,16,-761.396), rather than a cliff outcrop. Earlier statements attributing this fin to the outcrop rear were incorrect. The rear-width and short-span constraints still protect outcrop junctions but do not resolve this separate ambient silhouette.
- The first walk harness incorrectly required a live parent name that snapshots flatten. Its zero walks are an invalid harness result. After using persisted asset metadata, 10 of 12 real walks passed, but two on a small upper ledge stopped. These failures are retained in `walks-03b`; no traversal acceptance is claimed for that candidate.

Production 04 candidate broadens the usable benches, varies their elevations, breaks the large riser planes, and adds ordinary grass on actual turf triangles. Higher rock cross-sections exclude whole grass patches from risers/overlaps. Complete native collision remains unchanged in principle: the actual final rock triangles supply it.

`tests-13.log`: 22/23 tests pass, 691/692 assertions. The sole failing test is the historical native-terrace fixture's six stale material UID warnings; all 20 current outcrop/grass tests pass. The actual grass worker produces 496 elevated roots, with zero escaped patch-edge samples and zero roots inside rock. Full/split chunk owners produce identical grass buffers. No global performance claim follows from these tests.

The water-margin diagnostic exposed an outdated test window: the fixture used native cell bounds [-12,180], whereas `WorldFieldBlockCache` and grass tiles use [0,192]. Its margin remains 26 m and now matches the actual production window. No production water domain or hydraulic rule was changed.

Fresh Production 04 and P11 wide captures run concurrently. Their startup times cannot support comparative performance claims. Visual acceptance remains pending.

Remaining visual gates before any scoped acceptance:

1. Gray shoulders actually emerge from the native wall at close and oblique angles; no independent summit, exposed rear sheet or separate lower mound.
2. Lower ledges belong to the same connected rock; no doubled overlap seam used as a substitute for shaping the terrace.
3. Broad flatter benches have coherent turf. Steep faces and wall junctions remain stone, with no giant green side face or isolated postage-stamp patch.
4. Whole-wall composition avoids equally spaced ornaments, identical stacked-platform silhouettes and monotonous green ribbons. Native cliff relief remains part of the composition.
5. Reported positions, useful neighboring angles, wide terrain, and a second biome must be judged with actual game materials. Invalid/occluded views cannot count as passes.


### Final verification and evidence audit

Fresh Highland-final has no extra fern population; all three final angles were inspected. The ordinary ledge-grass support now declares planting ownership so the existing rounded shrub pass remains the only outcrop plant allocator. The grass follow-up passes 3 tests / 8 assertions.

The initial P12 side inspection was inside terrain and is excluded. An exterior replacement provides limited oblique context; P12_front remains the useful attachment view. The initial tree-obscured P20 inspection is also excluded. Context-verified/context-original retain the final five-camera sets. Seventeen before/after camera pairs have equal FOVs and maximum saved-transform component error 0.000001. See evidence-manifest.json and review.html.

Production04 repairs the reported independent-mound form, gray/green junction and connected lower ledges at the inspected sites. Twelve actual ledge walks pass. No owner approval, general performance improvement, full-suite acceptance, or perfection of the broader repetitive terrain system is implied.
