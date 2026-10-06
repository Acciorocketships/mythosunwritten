# October 3: stepped inhabited wings and removal of applique spires

Status: production progress retained. The overall redesign is NOT complete.
Embedded projecting wall facades, coupled tunnel/room planning, enclosed climbs
and broad tower integration/distribution still require work.

## Shape change

`KitSteppedWings.shape` lowers one end of an eligible repeated rectangular stack
by one or two storeys, seeded per building. The lower wing retains at least one
real inhabited storey and receives a native pitched roof. The taller core stays
at least two modules wide; the lower wing is two or three modules wide. All
cells remain inside the original reserved footprint. It does not thin the
entire town or replace massifs with detached buildings.

The adapter applies the rule after loggia planning and before native roof/facade
articulation. It preserves entrance cells, abutted bridge-house storeys, balcony
bearing storeys, actual walked cells and support for external construction.
Nonrectangular crowns are left to the existing L/T and loggia rules. The new
roofed shoulder is included in the compound crown packing; it is not an empty
flat terrace substituted for the requested wing.

13/large now has three stepped houses; 43/grand has two. These are observations,
not seed-specific production rules. Source route, tunnel and skywalk allocation
are unchanged by this pass.

## Rejected small spire decorator removed

The independent `bay.spire` path in `BuildingDesigner._assign_facades` remained
active after the earlier one-course FULL-tower fallback was removed. Native
renders exposed it as a small cone and window cylinder on the upper flat facade.
Automatic placement of this separate decorative assembly is now removed. Ordinary
projecting window bays remain, and full native towers still pass through
`KitTownTowers`/`KitTowerAssembly`/`KitTowerHostFit`. The library asset and its
measured-envelope check remain available; no automatic replacement is claimed.

Tradeoff explicitly OPEN: 13/large loses its former full-tower opportunity when
that host becomes stepped (one full tower before, none afterward). 43/grand
retains three full towers in the reviewed step render. The existing production
presence test across 12/large and 13/large still passes; there is no claim that
tower frequency is satisfactory. The cap-removal mutation fixture moved from
13/large to 43/grand because it needs an actual full shaft to mutate; all cap
failure criteria remain. Lower-wing/tower co-design is still needed.

## Evidence

- Initial stepped, street-loggia and retained-wall-room tests:10/10,291 assertions,
  39.828 s, before removing the old spire decorator.
- Final stepped suite:4/4,116 assertions,58.378 s. Includes real13/large,
  43/grand,31/large,41/large payloads: no floating masses and no finished roof
  triangles intruding into public air. Also proves deterministic varied choices,
  no footprint expansion and preservation of doors/walked/support cells.
- Tower/oriel suites:8/9 passed,4022/4024 assertions; the sole failed case tried
  removing the nonexistent13/large tower cap. After moving that positive mutation
  oracle to the built43/grand shafts, it passes1/1,3 assertions,24.992 s. The other
  eight cases include full-tower production presence, eave-cap removal, complete
  clearance and no independent spire decorations across standalone and real towns.
- Native whole-town renders13/large and43/grand in `after/`. Several automatic
  close cameras are occluded; do not use them as acceptance evidence.
- Added `stepped_wing_review.gd` to isolate each changed house's FINISHED town
  payload, including clipped roof meshes. `before/` uses the unchanged adapter;
  `isolated/` includes steps but still has the subsequently removed spire bay;
  `final/` is current production. Matched002/021 views inspected; final002 front
  inspected. The lower roof now breaks the continuous upper range and the small
  cylinder/cone decoration is absent. Tall faces still exist below the step.
- Isolated views omit adjacent houses, their bearing and shared faces. Open
  party faces and roof cuts visible in them already occur in the matched baseline;
  these images are shape comparisons, not proof of standalone support or holes
  in the assembled town. The whole-town support/air audits provide that scope.

No new player-route or broad full-suite acceptance is claimed. Quiet production
performance check is recorded below when terminal. No commit or PR.

Final quiet production:7,103 ms against the unchanged8,000 ms ceiling;1/1 test,149 assertions,52.332 s including world setup. All jobs terminal at this checkpoint.
