# City roof junctions and bored passages — September 26

Implemented in the separate `codex/town-shapes-wood` worktree, based on
`c82f40b6`. No screenshot coordinates, city seeds, or building IDs are special
cases in production. Fixed seeds below are review fixtures only.

## Architecture

- `KitRoofJunctions` reconciles all house/bridge roof wings before assembly.
  Matching cross-sections share one continuous roof, including a one-module
  gap where the sealed grid permits the complete roof volume. Compatible
  perpendicular branches extend into their host; buried gables and valley
  dormers are withdrawn. Joined wings share a wood finish.
- `KitRoofMeshUnion` subtracts intersecting roof volumes, higher walls, and
  declared walking headroom from authored roof/gable/trim triangles. It keeps
  UVs, smooth normals, materials, and UV tangents for the wood normal maps.
  Collision is the same final triangle set. Pieces needing no cut remain
  ordinary instances. Worker data is reproducibly baked from the kit by
  `tests/harness/suntail/bake_roof_geometry.gd`; its binary is under the existing
  `terrain/environment/**` export include filter.
- Boring retains short, level ground passages in seeded daylight intervals,
  with complete headroom and continuous side-wall bearing. Paired lanes use
  their actual outer jambs. Elevated crossings use the existing occupied
  bridge-house support proof. Each scale allows two additional bridge-house
  opportunities; an unsupported candidate still fails admission.
- Natural tunnel ceilings are reserved before room composition. Their kit
  closure survives the legacy flat-roof/retained-terrain classification and
  receives timber soffits and rim framing.

## Validation

- Red-first roof join test: two independent roofs / wrong extent before;
  one continuous roof after. Supported-bore fixture: zero ordinary covered
  cells before, preserved short tunnels after without reducing headroom.
- **50 focused tests / 13,795 assertions pass**, covering roof junctions,
  existing architecture, native kit replica, hamlets, tunnel arches, and bake
  geometry. Native overlapping triangles reproduce the defect as a control;
  no resulting triangle centroid is buried in the other roof. Every generated
  collision face matches its rendered triangle; tangents are unit length and
  perpendicular to normals.
- **3,658 native roof rays** across cross-gable and unequal-depth parallel
  junction fixtures find no open seam. Samples are offset from exact native
  triangle/instance boundaries, where the Godot ray kernel gave ambiguous
  misses in the initial exact-grid control.
- **48/48 cities compile** (seeds 1–12, compact/standard/large/grand) with valid
  final kit payloads. The corpus retains **15 additional ground passage cells**.
  Accepted source bridge-house opportunities increase **122 → 148**; these are
  source compounds, not a claim that every span renders as an isolated bridge.
- **135/135 actual-player capsule probes pass** across all 15 new passage
  cells in the corpus, with native ceiling hits above every passage. Floor
  height is measured from the real committed surface before placing the body.
- Legacy carver/plot suites have **the same nine failing tests / 18 failed
  assertions** on unchanged main and this change. Names are recorded in
  `legacy-failures.json`; baseline and candidate logs are retained. They are
  not counted as passing validation.

## Native review

Matched overview/reverse views for compact seed 1 and standard seeds 2 and 7
are saved beside this report, with pixel differences. The seed-1 overview
reproduces the supplied town composition. Camera formulas and payload extents
are unchanged for these paired captures. Reviewed all four orbital directions
for each, plus street-level ceilings; no claim of a screenshot-exact original
player camera is made because this attachment has no player pose readout.

The early passage view was rejected: source retention alone let later stages
remove the ceiling. `7_standard_tunnel_rejected.png` and
`7_standard_tunnel_after.png` show the same camera before/after the structural
closure fix. Occluded skywalk-side cameras were excluded from visual evidence.

This is native flat-town/physics validation, not a fresh streamed terrain-world
startup benchmark or proof of every possible seed. Different roof datums and
incompatible cross-sections remain separate; open streets remain between
short covered runs. Broader city art remains iterative.
