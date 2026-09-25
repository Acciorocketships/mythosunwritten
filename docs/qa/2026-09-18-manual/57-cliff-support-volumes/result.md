# Cliff support-volume investigation

No production change. Pass 55 remains byte-identical. The tests below isolate several contributors to the repeated vertical forms and reject two ways of joining or bending their support. A final continuous-relief trial preserves the measured shelves but does not sufficiently improve the composition. [Native comparisons](comparison.md) retain the controls and rejected results.

## Component controls

The saved 96 m wide, 64 m high native study uses the same camera poses and Forward+/Metal lighting as pass 56. Five views each remove the Nature bodies (`no_nature/`), generic bodies (`no_mass/`) or ledge supports (`no_shoulders/`). Two further oblique views remove both body families (`no_bodies/`) or bypass the upper-envelope limit (`no_limit/`).

Vertical fluting survives each individual removal. Removing ledge supports also removes the ledges themselves; removing both body families still leaves fluted ledge supports. Thus neither one body family nor the envelope limiter alone explains the composition. Both bodies and supports retain substantial horizontal alignment through height. These ablations are diagnostic controls, not shippable alternatives; the no-limit control intentionally withdraws the required crown constraint.

## Shared support

`support-union-test.gd` first reproduces additive bearing: three aligned 2 m ledges produce a 6 m support where one produces 2 m (`red.log`, exit 1). A smooth maximum reduces the combined support to 2.136719 m and passes that proposed invariant.

The combined run nevertheless fails **two of seven tests**, with **13/15 assertions** (`union-tests.log`, exit 1). The reported cap becomes narrower than the usable-width bound at all three sections, so none of its 57 interior probes can be measured. Only two qualifying long upper ledges remain, spanning 7–30.5 m. The upper envelope retains zero excess over 302,169 samples, and 31 photo shells remain closed and nondegenerate. Five native views still show fluting and lost shelves. Reject this union: ledge projection and structural bearing cannot simply share the same maximum. The experimental test is not registered as a production requirement.

## Lateral bends

`bent.gd` displaces horizontal position according to height and depth. Five views reveal thin dark slivers and sharp folds. Its side closure also remains tied to the original straight boundary. Reject it.

`shear.gd` instead gives the entire column the same height-dependent displacement and maps its side closure consistently. Crown and foot displacement are zero. Five tall views and 17 frozen-world views complete, all native processes exiting zero. The major fold artifacts diminish, but the tall wall still looks like bent columns. Fine attachment artifacts remain in close views; the ordinary yellow cliffs retain broad blank faces. Reject it visually rather than promote a technically incomplete deformation.

The shear run reports **4/5 tests, 9/10 assertions**, but its one failure is an invalid measurement for this geometry: the channel survey searches for equal-x tread edges and finds zero columns after lateral deformation. The pointed-tip test also relies on equal-x edges, so its green result does not validate sheared tips. The independent checks retain closed/nondegenerate photo shells, 57/57 cap probes and four connected upper ledges spanning 5.5864–38.2219 m. Neither the original fixed-x upper-envelope test nor the column-correlation diagnostic was treated as valid evidence for this variant. No ownership, fresh seating, corner or gameplay acceptance is claimed.

## Continuous shallow relief

`continuous.gd` starts from production, without lateral bending. It applies restrained erosion from the existing large geological partition across both risers and treads. Unlike pass 56's quiet trial, it does not raise a protected ribbon around each ledge. Thin native attachments retain their original relief. Seventeen frozen native game views complete with exit zero.

The focused run passes **five tests / ten assertions** (`continuous-tests.log`, exit zero): the reported channels, pointed turf tips, 31 closed photo shells, 57/57 actual cap probes, and four upper ledges spanning 6.5–40.75 m. This is regression evidence, not a red-first demonstration of better composition. The replay still has broad blank faces and thin ledges, while the additional shallow divisions do not solve the recurring support shapes. It is not promoted. The earlier basal test intentionally pins upper geometry to its preceding control; this relief change was not represented as having passed that test or the full integration suite.

## Scope and next constraint

There are 32 tall-study captures and 34 frozen-world captures in this pass. These are art studies/replays, not fresh world generation: frozen context retains previous terrain, grass and collision. All native capture processes completed with exit zero. Test exits are recorded above. No new production, collision, water, grass, biome, streaming or performance acceptance is claimed.

Further geometry work needs to separate the finite projection of each ledge from the volume that bears its load, while retaining the tread's width and continuing support into the lower terrain. A single smooth-max substitute loses shelves; a global lateral warp preserves the repetitive organization and disrupts thin joins. Do not promote either merely because a silhouette metric improves. Overall cliff art and the original judging register remain open.

Verified production SHA-256:

- `CliffRockCrags.gd`: `f82eb7a70cc9f64f7f755548f33a1d217ae4d2365a52342cb8a9d6c222a67fbe`
- `CliffCornerCrags.gd`: `bd2f4d8c71a5c831721243dd8e2fc3bc30d42a5f0865f970970e3a2f337af6d6`

`source-evidence.sha256` records the fixture sources, controls, captures and reports.
