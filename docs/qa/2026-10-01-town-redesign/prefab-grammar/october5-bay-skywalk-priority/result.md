# Optional bays consume late enclosed crossings

The ordinary-house height experiment is rejected and `WarrenPlotPlanner.gd` restored byte-for-byte to the accepted raised-district version. No previously accepted architecture, route or court changes were reverted.

## Experiment and result

Tested a three-storey maximum for an ordinary house’s optional roll while retaining required street/room height authority and the existing neighboring passage overhead-room budget. Wholly raised houses retained their accepted massif-crown rule. This differs from the earlier global field cap, which could lower ground houses to one storey.

Four finished towns: 103 and 63 retain every covered sample; 53 loses two distant nine-band ceilings; **31 loses six four-band ceilings**, covering two independent low bridge-houses. Floating and public-air audits remain zero. Native 53 and 103 overviews were inspected. 103’s tall mixed-level shaft remains because the nearby route budget raises its optional crown again. The broader rule is not accepted as a solution to that shaft.

Only one source plot in 31 changes: house.006, floor 0, top 10→8. Its endpoint room at (-3,4,2) and the far room at (2,4,2) remain complete and retain the same room identities.

## Root cause established by sealed occupancy

The new generic `tests/harness/suntail/skywalk_refusal_probe.gd` takes a seed/profile and a requested cell/axis/gap. It reproduces the late skywalk selector’s room, public-floor, structural, retained-crown and planted-volume inputs, and reports endpoint identities, exact occupied cells, gap admission, site admission and complete enclosure admission.

At 31/large, crossing (-3,4,2), +X, gap 4:

- Accepted baseline/restored: identical endpoint room identities; gap 4; site true; enclosure true; no occupied cells in the tested span envelope.
- Height trial: gap -1; site false; enclosure false. `spatial.feature.facade-bay.02.component.00` occupies (-2,4,2), (-2,5,2), (-2,4,3), (-2,5,3). The first two are directly in the span’s first bay; the others occupy its lateral shell.

Thus the earlier roof hypothesis is disproved. Optional decoration moves down into a real potential crossing when the host shortens. The late bridge pass correctly rejects occupied space. Relaxing collision checks or restoring arbitrary house height would conceal the ordering problem.

`WarrenSpatialFeatureSolver` reserves optional facade bays after its explicitly preplanned skywalks, but `SettlementFabricAssembler` discovers additional private bridge-houses later. The comment that bays cannot consume a required skywalk does not cover these late candidates.

## Next action

Give supported enclosed street-crossing prospects priority before optional bay reservation, using shared room/clearance facts and verifying final native geometry. Do not reserve every vaguely opposing facade or disable the late safety checks: prospective crossings must meet endpoint, complete-bay, street-headroom and shell-clearance rules. After that arbitration is proven, re-evaluate ordinary-house silhouettes. The diagnostic and evidence are retained; the failed height trial is archived outside production.
