# Rounded faces with carved ledges — active art review

The owner rejected the 09 jagged-shelf direction and the first 10 cylinder-like study. The current requirement is rounded worn rock faces with sharp ledges carved into them, composed together with broader supporting masses toward the ground. This is not approval of inflated boulders or repeated pods.

References:
- `/Users/ryko/Desktop/download-1.png`: closest previous game direction, but its two constant-height bands and insufficient lower boulder variation remain rejected.
- `/Users/ryko/Desktop/e59f1b26-5c1b-48ae-8b2c-ca7711473a8c.webp`: gold-standard shape/composition reference, reaffirmed by the owner.

The original issue register remains in ../issues.md. Other water, town, streaming and palette work remains open.

## Iterations

1. Rounded independent stacks: rejected internally. Too cylindrical and arranged like separate cakes, with smooth bare faces.
2. Shared rounded body: rejected internally. Four broad courses merely replaced the old two-band pattern; insufficient finite ledge ends.
3. Finite ledges: direction improved, but the upper boundary was jagged and lower boulders were too weak. Rendering finite windows from only their own cell also made some abrupt vertical transitions.
4. Exact continuous crest and broader lower boulder relief; finite ledges evaluate neighboring windows. Production-01 captured this intermediate geometry before later grass and depth changes. It is not the final candidate.
5. Planar cap surfaces and restrained depth. Studio front/oblique review rejected the broad smooth, draped appearance. Grass support now uses exact higher triangles and common coplanar borders instead of a convex envelope or individual mesh diagonals.
6. Short staggered horizontal fractures and finite vertical clefts break up blank stone. Small triangle boundaries remained too visible; geometry closure passed after consistent vertex welding and retaining topologically necessary collinear closure triangles.
7. Smoother stone normals preserve the sharp separate turf edge. Ledges have more varied heights and grades. Five studio views include an elevated shelf view. The current production capture is running; no art acceptance is claimed.

Code uses one shared world-coordinate profile for native chunk seams, actual triangle collision, and the same turf triangles for grass/plant support. Fern/ivy grass-colour and real crevice-root work is retained. Native ground/cliff layout is not replaced.

## Current focused evidence

- `grass-06.log`: 8/8 tests, 43 assertions. The actual grass worker plants 67 patches, with zero escaped footprint samples or buried roots. Full/split ownership buffers match. Native wall and outcrop fern contacts, closed shells, crown limits and physical seam continuity pass.
- `ledges-01.log`: 2/2 tests, 885 assertions. A 72 m control has 16 substantial finite turf components over eleven metre-height bins; lengths 1.74–8.35 m. Turf area is 63.44 m². Gray wall joins and native turf UV/material are checked on current generated meshes, with rendered vertices belonging to the physical shell.
- The former seam-depth minimum of 1 m and demand for >7 m outcrops were aesthetic thresholds for superseded geometry. They are updated to require visible supported relief and bounded irregular projection, matching the owner's later rejection of oversized masses. Closure, contact, water and complete grass-footprint checks are not relaxed.

The exact canonical studio is a diagnostic, not a claim of matching the reference composition. In particular, the native wall still has repetitive stock relief, and the new stone needs judgment under actual biome light. The reference is a shape/composition target, not permission to replace the game terrain layout with towers.

- `integration-01.log`: 11/11 tests, 469 assertions; includes actual formation water exclusions, prepared-water-domain queries and dry-field equivalence, connected neighbor bounds, short-wall rejection and 74.7% sampled wall coverage. Some retained asset-family tests exercise the historical baked library; they are collateral checks, not proof of current art.
- `cost-03.log`: caching column-constant fracture definitions retains byte-for-byte identical records across eight panels. Same-process profile generation measures 19,024 ms before / 10,194 ms after. This is a scoped CPU benchmark under concurrent capture load, not a global startup improvement. The fresh production run still has expensive feature/water planning and native integration; performance remains open.

## Current stopping point

See [result.md](result.md): studio and 21 focused tests recorded; live production capture failed to reach image saving after expensive startup and Metal waits. The headless retry is also incomplete and was stopped. Final production visual/traversal verification remains open.
