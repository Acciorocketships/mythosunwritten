# October 3: owner correction — integrated towers and enclosed streets

Status: partial implementation, art acceptance OPEN. The owner specifically rejected
side-glued spires, apartment-like walls, houses merely beside the retaining wall,
and exposed climbing boardwalks. This supersedes the earlier acceptance of a
single-course attic turret. It does not authorize trading walking clearance for
ornament or floating construction.

## Native prefab evidence

Inspected the actual converted Pure Village `Houses/House_16c.glb` hierarchy and
rendered front, back and junction views, plus `House_11c`. Reproducible harness:
`tests/harness/suntail/pure_village_prefab_junctions.gd`. Images in
`../october3-prefab-junctions/`.

House_16c's stone shaft at x4.625,z3 joins a lower wing: support and full window
at y4.5; half-middle and reversed half-window at y7.5; full window at y10.5;
roof at y13, overlapping the final course by0.5. The taller timber house beside
it has its eave at13.5 and ridge19.5. This is a stepped wing/corner composition,
not merely an ornament on the highest gable. House_11c also uses a narrower
15x30 tower family. Those source recipes remain to be generalized fully.

Removed the production one-course corbelled fallback. Accepted towers now keep
at least two backed courses; failed shafts do not become caps glued to an attic.
This intentionally reduces tower counts (13/large still has one,43/grand four;
31/large,101/large,103/grand can have none). This is NOT a satisfactory final
frequency or proof of integrated massing. Do not claim the tower request complete.
The production test now checks full-shaft presence across its two-town sample,
not a mandatory tower on every seed. The roof audit additionally checks an
uncapped tower crown: a missing full-shaft cap need not expose a host-gable hole.

## Supported district bores

Natural tunnel selection used to forbid all platform columns and the whole
huddle around them at every height. It now protects only platform foundations
below their bearing datum. Ordinary roof-thickness/jamb/ownership tests still
prove every upper-district or surrounding bore. No seed-specific placement.

Source census:101/large0->1,103/grand3->5,31/large0->2,43/grand12->12 tunnel cells.
All four fabrics validate. Existing supported bridge proposals remain2/3/3/1.
The three raised-town regression fixtures prove surviving spans, supported
upper bores, intact foundation except explicit bounded wall tunnels, no floating
mass and no native roof intrusion into public air.

Experiment allowing flight cells through the generic bore selector was rejected:
43/grand gained four source bores, but their cover proposals lacked two bearing
jambs. It did not prove a finished enclosed stair. Flight exclusion remains.
The exposed climbing route requires joint route/room planning, still OPEN.

## Embedded frontages

Wall-room kit storeys can emit a shallow native pent-eave course beneath their
existing structural cap, with whole native end boards. They keep the real room
inside the retained mass and do not receive a detached cottage roof. Full
assemblies are refused on measured public-air conflicts; later fitting also
checks accepted tower and bay envelopes. No generated texture or primitive roof.
Native review in `../october3-wall-frontages/`: overview and wall0 inspected.
This is only a first frontage treatment; shallow projecting house fronts and
more alleys through the mass are not finished. Existing posted porches remain
visible in some views. Do not call those the requested embedded facade.

## Validation and remaining work

- Focused shafts/district spans/hoods:7/7,885 assertions,92.258s.
- Inhabited walls:4/4,289 assertions,107.321s.
- Actual player31/large:6/6 directions across open bridge, source bridge and
  underlying passage. Does not specifically walk both newly added bore cells.
- Native13/31/103 overviews, shafts, bridges and wall rooms rendered in
  `../october3-enclosed-review/`; selected overview/wall/shaft views inspected.
- Most recent quiet production timing BEFORE this correction failed8621ms
  against unchanged8000ms ceiling (148/149 assertions); prior6941ms result
  does not establish current performance. Investigate; do not relax the gate.
- Fresh production corpus completed:16/16 records validate, all measured geometry
  within declared halo1. `production-16.log/json`. The existing world3 full-floor
  post-AABB flags are not body-lane collisions (see earlier support diagnosis).
- Final hood/tower/bay arbitration smoke:1/1,122 assertions,27.039s.
  No live jobs remain at this checkpoint.

Next: source-derived stepped-wing and narrower tower recipes; protruding embedded
frontage assemblies with shed roofs; jointly supported covered climbing routes;
canopy planting along exposed streets. The raised-garden code currently fits a
whole tree crown inside the planting island, limiting useful street canopy.
Any relaxation must use the already measured per-height tree profiles and real
headroom, architecture and collision, not merely allow broad tree overlaps.
