# Pack-agnostic building kits: Suntail village migration

Date: 2026-09-24. Branch `suntail-towns`, worktree `/Users/ryko/story-suntail`.

## Intent (owner's words, condensed)

Replace the town's basic building art with the Raygeas **Suntail Village** modular
pack (`assets/Raygeas`, already converted to glTF). Keep the macroscopic
village planner; change what buildings are made of. Where possible decouple
building generation from any one asset pack so packs can be switched or
combined later. Buildings must be stitchable into any planned shape, biased
toward the pack's reference look (interesting roofs with dormers, jetties and
other overhangs, stone ground storeys under timber-frame uppers, window bays,
awnings, planters, ivy), and still compose into the dense connected warren with
skywalks. Iterate with falsification screenshots until it is professional.

Assumptions (mine): the warren macro planner (massif, maze, parcels, room
composition, public realm) is kept unchanged in lattice units; the old SFV/LPFV
building vocabulary remains inside the planner as an *envelope reservation*
model for now, but no longer draws buildings.

## What the kit teaches (measured from the eight House_N prefabs)

Native metric: wall module 2 m wide x 3 m tall; storey 3 m; stone plinth 1 m
(`Stone_Base`) under a 3 m stone ground storey; timber (`Frame_Wall_*`) uppers.
Walls are centred on a cell edge midpoint facing outward (+Z), with a 0.16 m
corner post on local -X. Jetty = upper footprint 1 m (half module) larger per
side, `Support_2` brackets under every upper wall joint and paired at corners.
Roof over depth `2n` m: per side, one eave row `Roof_1_Cornice` (dormer variant
`Roof_1_Cornice_W`) then `Roof_1` rows, each 2 m run / 3.12 m rise; odd module
depth adds a central `Roof_Top_1` (1.62 m) and gable `Gable_Small`. Gable ends
stack `Gable_L`/`Gable_R` triangle halves plus full frame walls; barge boards
`Cornice_Cover_1..3`; ridge caps `Ridge` + `Decor_Peaks`. Inner L corners use
`Roof_2_Cornice`/`Roof_2`, T tops `Roof_Top_2`. Bays: `Frame_Extension` replaces
one upper wall slot. Awnings `Wooden_Canopy_1`; external stairs
`Wooden_Stairs_1/2`, `Wooden_Platform`, `Wooden_Railings_1..3`; `Stone_Stairs`
at doors; window boxes `Flovers_1/2`; ivy `Ivy_1..5`. Red and blue roof sets.

## Architecture

```
planner (unchanged, lattice units)
  WarrenSpatialPlan.buildings / features / construction faces
        |
  BuildingMassAdapter  (plan -> pack-agnostic BuildingMass list)
        |
  BuildingDesigner     (articulation: jetty, stone/timber, dormers, bays,
        |               awnings, cross gables, dressing; deterministic, biased
        |               toward the reference look, clearance-checked)
  BuildingKitAssembler (BuildingMass + BuildingKit -> EnvironmentInstancePayload)
        |
  VillageWarrenFabricSolver._materialize (world frame) -> VillageRecord
```

1. **`BuildingKit`** (resource-free descriptor, one per pack): native module
   width, storey height, plinth height, kit-to-world scale, and a role table
   (`wall.timber.plain|window|door`, `wall.stone.*`, `plinth`, `gable.left|right|small`,
   `roof.<colour>.eave|eave_dormer|slope|top|valley_eave|valley|tee`,
   `bracket.jetty`, `bay`, `awning`, `stair.*`, `rail.*`, `decor.*`) mapping to
   baked catalog asset ids plus the role's canonical anchor convention. The
   Suntail kit is the first implementation; any pack that can express these
   roles plugs in. Roles a kit lacks simply make the designer skip that feature.
2. **`BuildingMass`** (pack-agnostic IR, pure data, in *module cells*): per
   storey a rectilinear footprint (set of cells), floor level, material, per-edge
   wall kind (plain/window/door/bay/party/open) and optional ground inset (the
   jetty); a roof made of gable *wings* (rectangle + ridge axis + colour) with
   dormer slots; attachments (awning, balcony, external stair, window box, ivy).
3. **`BuildingKitAssembler`**: pure, worker-safe; expands a mass into kit
   placements (walls, corner handling, plinth, brackets, gable stacks, roof rows,
   valleys, trims, dressing). Never decides architecture, only realizes it.
4. **`BuildingDesigner`**: pure deterministic articulation from a seed plus
   constraints (cells that must stay clear: public air, other owners, reserved
   roof envelopes). Biases toward the reference houses: stone ground storey on
   most terrain-borne buildings, jettied timber uppers, dormer rhythm, bays on
   gable/end walls, awnings over street-facing ground doors, window boxes under
   upper windows, ivy on sparse corners, red/blue roof districts.
5. **`BuildingMassAdapter`**: turns each `WarrenBuildingVolume` (private cells
   per band, thresholds, room records) into a mass: storeys = band pairs,
   footprints = floorplates, doors from thresholds, party walls where another
   owner's private cell abuts, roof wings from exposed crowns; skywalk and
   balcony features become attachments/bridge masses.

### World metric from the kit

The planner lattice is 1.5 m authored (fine cell and band). Suntail storey:
module is 3:2, the lattice is 1:1 per band pair, so no uniform scale fits both.
The frame therefore becomes kit-derived and anisotropic: horizontal x2
(3 m fine cell = one Suntail module at 1.5x), vertical x1.5 (2.25 m band,
4.5 m storey = one Suntail storey at 1.5x). Kit placements carry the inverse
axis compensation so every kit mesh renders at uniform 1.5x; legacy rigid
catalog assets are compensated to keep their previous uniform 2x look.
Generated lattice geometry (streets, stairs, planks, turf) follows the frame.
`VillageWorldScale` owns both factors; every former `scale_of` caller uses the
axis it means.

### Interception

`VillageWarrenFabricSolver._materialize` replaces building-unit placements from
`SettlementFabricAssembler.payload(fabric)` (units owned by buildings/roofs and
building features) and the building-like parts of `terrace_retaining_payload`
(maze-stone storeys, masonry joints, plinths, outcrops, skywalk shells) with the
kit payload. Public surfaces, guards, stairs, turf, frontage dressing pass
through. Occupancy, collision boxes and terrain grade stay plan-derived.

## Testing and review

- Unit tests: kit descriptor integrity (every role resolves to a catalog id),
  assembler geometry (wall count per perimeter, no duplicate slots, roof rows
  per depth, jetty brackets at joints, determinism), designer determinism and
  clearance (no placement bounds enter forbidden cells).
- `tests/harness/suntail/building_gallery.gd`: renders many designed buildings
  (random masses: rectangles, L, T, stacks, skywalk pairs) from several angles
  in seconds. First place beauty is iterated.
- In-village: frozen-town payload loop (`tests/fixtures/september22/payload.gd`
  + `native.gd`) and live multi-town captures; each image gets a falsification
  disposition.

## Out of scope for this pass

Interiors, animated doors, replacing the planner's recipe envelope model with
kit-measured envelopes (follow-up: let the kit publish envelopes to the
planner), chimney smoke FX.
