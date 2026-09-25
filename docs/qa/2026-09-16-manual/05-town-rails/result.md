# September 16 town railing review — doorway repair

T07 is repaired at P04, seed 2697992464, player (-1992, 28.1, 1783.1), crosshair (-1995.1, 29.6, 1783.2). T08 remains open. This change follows the cliff work recorded in [12-cliff-transition](../12-cliff-transition/result.md).

## Cause and change

The public landing guards were sealed before the exterior bridge network selected its connections. Two terminal rails therefore remained across accepted bridge mouths, including the photographed enclosed doorway. The compiler now passes the accepted walking lanes back to the public surface plan before the complete fabric is finalized. The surface owner rebuilds its guard geometry and collision with exactly those terminal boundaries open. Companion structure and lateral fall edges do not gain openings.

The previous test incorrectly used exact 3D midpoint equality. Guards are lifted 0.025 local metres above the floor; this made the test silently overlook both blocking rails. The corrected horizontal-boundary/storey test reproduces both failures in [actual-red.log](actual-red.log), then passes with the repair. The earlier `red.log` was not a valid reproduction.

## Matched views

Before:

![P04 before](/Users/ryko/story/docs/qa/2026-09-16-manual/05-town-rails/game/before/P04/P04_0.png)

After:

![P04 after](/Users/ryko/story/docs/qa/2026-09-16-manual/05-town-rails/game/after/P04/P04_0.png)

Six native payload pairs and six saved-game pairs cover P04/P15 at the reported ReviewCam reconstruction and ±8 degrees. P04's doorway and landing lose the transverse rails; the diagonal stair rail, doorway frame, flooring and neighboring mass remain. P15 remains a collateral control: its isolated cap and awkward roof-side termination are still visible, so T08 is not accepted.

The native harness commits complete before/after production payloads. The saved-game replay applies the exactly verified two-instance removal to the frozen world; terrain, environment, camera transforms and collision remain frozen in that art replay. Native physical checks below use the actual changed payload. Neither replay is a fresh streamed world or a claim about loading performance.

## Verification

- [Focused run](focused.log): **9 tests / 498 assertions pass**, 67.471 seconds, including bridge-neighborhood and integration controls. Four-orientation guard tests retain lateral guards, rebuild collision, and restore guards when a bridge is withdrawn.
- [Payload comparison](payload-comparison.json): only `public-guard/-3:4:8:0:-1` and `public-guard/-4:4:8:0:-1` are removed. No added or changed native instances. All 101 generated surface meshes and generated collision boxes are identical. Native railing colliders disappear with their owning instances.
- [Native collision survey](clearance-final.log), [data](clearance.json): all **312 existing public stances and 444 existing neighboring crossings** retain their exact previous results. This means unchanged results, not that every existing sample is unobstructed.
- The photographed doorway mouth changes from blocked to center-clear. All **six capsule sweeps** across it (three lateral offsets, both directions) change from a 0.197 safe fraction to 1.0. These are native collision sweeps, not animated character walks.
- A stronger initial assertion that both adjacent bridge mouths become passable failed. The narrow open bridge beside the doorway is independently blocked by the enclosed bridge's generated side-wall collider (`maze-skywalk/-4/4/5/1/barrier/00/-1`). Its guard is removed, but that separate collision remains. This is recorded as T09; no full bridge-network traversal acceptance is claimed.
- Native runs retain the three existing stale village material UID warnings, falling back to the correct text paths. Headless runs also emit the known macOS certificate lookup error. Final runs exit successfully.

## Reproduction

- `tests/harness/september16_rails_payload.gd` recompiles the frozen photographed source and asserts the exact two-instance delta.
- `tests/harness/september16_rails_native.gd` renders complete native payload pairs at saved ReviewCam poses.
- `tests/harness/september16_rails_clearance.gd` commits actual native colliders, compares public clearance and sweeps the repaired doorway.
- `tests/harness/september16_rails_game.tscn -- --frozen --snapshot res://docs/qa/2026-09-16-manual/05-town-rails/baseline/world.scn --spot P04 --camera-poses-root res://docs/qa/2026-09-16-manual/05-town-rails/baseline --output res://docs/qa/2026-09-16-manual/05-town-rails/game` reproduces the saved-game art comparison.

The remaining manual water, town, streaming and biome issues stay open in [the register](../issues.md). No full-suite or global performance acceptance is claimed.
