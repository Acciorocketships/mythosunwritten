# October 3: preserve inhabited-town skywalk landings

Retained: the previously broken43/grand exterior skywalk is traversable in
both directions. The full eight-direction player check now passes. This
repairs an existing upper route; it does not complete the broader massif,
embedded-facade or enclosed-climb redesign.

## Two mismatched construction facts

The far endpoint(6,4,-4) was a reachable construction crown,
`spatial.roof.spatial.maze_back.13.room00`, recipe`roof.flat.row`. It had no
canonical public-floor patch because the exterior bridge network is resolved
later. `KitVillageBuildings` replaced that roof unit with a pitched wing of
`kit.spatial.parcel.maze.house.002`, erasing the actual landing. The player ray
reported no floor at world(24,12,-16) and the reverse walk fell to y6.26.

The terrace-edge adapter also omitted the newly accepted bridge from its
neighboring walking surfaces. It placed a railing straight across the terminal
seam. Its native asset is named `suntail.stair.wooden_railings_1`; the asset name
initially suggested a flight guard. A trial rebuilding transition guards did
not fix the obstruction and was completely reverted. The affected rail was
the construction terrace's own edge guard.

## Production changes

- The kit designer receives the exterior network's reachable crowns as walked
  cells. These crowns cannot be replaced by pitched roof wings or removed by
  stepped-wing shaping. Their owner emits the existing native timber deck;
  the exterior terrace system retains ownership of its railings.
- The terrace-edge adapter reads the same network once. Accepted bridge walking
  lanes open the corresponding terrace seams. Structural companion lanes do
  not grant openings; exposed sides retain their guards.
- Reachable crowns also contribute to public roof-verge fitting and complete
  walking-air volumes. Native roofs, towers and optional facade details must
  respect the floor even though it is absent from the earlier public union.

No seed, coordinate or screenshot exception exists in production. The43 fixture
and diagnostic probe name the reported regression only. No new visible primitive
architecture or texture was introduced; the deck and guards use existing assets.

## Verification

- Initial landing/skywalk/inhabited-room suites:7/7,215 assertions,125.465s.
- Final landing/stepped-wing/turret suites:8/8,3,273 assertions,144.181s.
  Real-town checks cover roof public air and floating masses across43/grand,
  13/large,31/large and41/large through the relevant fixtures. The landing
  regression proves a native deck is emitted, no pitched roof occupies its
  band, the terminal terrace guard is absent, and exposed guards remain.
- Final actual player in43/grand:8/8 directions. Both exterior skywalks, the
  inhabited source bridge and the sloping underpass pass. Before this turn,
  skywalk0 failed in both directions. The restored endpoint ray reads12.255m,
  matching the native deck surface and within the player's step tolerance.
- Native final overview and matched close cameras are in`final-clearance/`.
  Reviewed the landing along the route and from above: continuous native deck,
  open entrance, side fall protection, existing enclosing rooms above/beside it.
  `floor-only-candidate/` contains the earlier incomplete repair;`final/`
  predates the shared crown-headroom extension. Neither is the final authority.
- `PublicRealmSurfacePlan.gd` matches the pre-experiment snapshot exactly.
  No transition-guard rebuild remains. All jobs completed. `git diff --check`
  passes. No fresh full-suite, production timing or world-streaming claim.

Reproduce: `tests/harness/suntail/nested_gate_walk.gd -- --seed 43 --profile
grand --skywalks --output FILE`; regression
`tests/test_october3_skywalk_landings.gd`; topology/roof diagnostic
`tests/harness/suntail/skywalk_landing_probe.gd`.
