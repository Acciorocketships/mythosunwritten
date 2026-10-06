class_name TownGroundDressing
extends RefCounted

## Seeded uses of reserved ground. All transforms are in world metres; kit
## scaling must not turn a barrel or tree into a building-sized decoration.
const TREES: Array[StringName] = [&"lpfv.tree.01", &"lpfv.tree.02"]
const BENCH := &"lpfv.fabric.prop.bench.01"
const BARREL := &"suntail.prop.barrel"
const ANVIL := &"suntail.prop.anvil"
const FIRE := &"sfbp.campfire.001"
const TENT := &"sfv.shelter.white"
const TENTS: Array[StringName] = [TENT,&"sfv.shelter.blue",&"sfv.shelter.red"]
const CAULDRON := &"alchemy.cauldron.001"
const HERBALIST := &"crafting.herbalism.table.001"
const VEGETABLE_STALL := &"market.vegetable.stall.001"
const BAKERY := &"market.bakery.stall.001"
const FORGE_ANVIL := &"forge.anvil.001"
const TAVERN_TABLE := &"tavern.adventurer.table.001"
const TAVERN_BENCH := &"tavern.bench.001"
const GARDEN_BENCH := &"interior.bench.001"
const MARGIN := 0.6
# Crowns may mingle above pedestrian space; roots and low branches may not.
const CROWN_JOIN_HEIGHT := 4.0
const TREE_PROFILES := preload("res://scripts/terrain/features/villages/TownTreeProfiles.gd").BANDS

static func asset_ids() -> Array[StringName]:
 var out := TREES.duplicate()
 out.append_array(TENTS)
 out.append_array([BENCH, BARREL, ANVIL, FIRE, CAULDRON, HERBALIST,
  VEGETABLE_STALL, BAKERY, FORGE_ANVIL, TAVERN_TABLE, TAVERN_BENCH, GARDEN_BENCH])
 return out

static func woodland(seed_value: int) -> float:
 var rng := RandomNumberGenerator.new()
 rng.seed = hash([seed_value, "town.woodland"])
 var value := rng.randf()
 return 0.0 if value < 0.2 else pow((value - 0.2) / 0.8, 0.65)

static func dress(town: VillageUrbanFabricPlan, source: WarrenMazeSourcePlan,
  bounds: Dictionary, terrain: VillageTerrainView, seed_value: int, world_seed: int = 0) -> Dictionary:
 var audit := {"woodland": woodland(seed_value), "trees": 0, "natural_pocket_trees": 0, "groups": 0, "props": 0}
 if source == null: return audit
 var spaces := _planting_spaces(source.massif)
 var allowed := {}
 for space: Dictionary in spaces: allowed.merge(space.cells)
 var clearances: Array[FeatureGroundShape] = town.clearances.duplicate()
 clearances.append_array(_native_ground_clearances(town,bounds,terrain))
 var field := FeatureGroundField.new(town.surfaces, clearances, 2.0)
 var placed: Array[FeatureGroundShape] = []
 var tree_bands := {}
 var group_anchors: Array[Vector2] = []
 var inverse := town.world_transform.affine_inverse()
 var streets: Array[Vector2] = []
 for cell: Vector3i in source.passage_kinds:
  if cell.y != source.massif.base_at(Vector2i(cell.x,cell.z)): continue
  var point := town.world_transform*Vector3(cell.x*3.0+0.75,0,cell.z*3.0+0.75)
  streets.append(Vector2(point.x,point.z))
 for space: Dictionary in spaces:
  # Independent streams keep a vendor choice from changing the next grove.
  var rng := RandomNumberGenerator.new()
  rng.seed = hash([seed_value,String(space.id),"town.green.trees"])
  var prop_rng := RandomNumberGenerator.new()
  prop_rng.seed = hash([seed_value,String(space.id),"town.green.props"])
  var columns: Array = space.cells.keys()
  columns.sort()
  # Place the purposeful cluster first so woodland density cannot displace
  # the market, seating or work area. Trees then use the remaining space.
  # The whole cluster succeeds together; a tent never loses its clearance
  # merely because its companion barrel happened to fit first.
  var blockers := _approach_blockers(town,terrain)
  var area_scale := town.world_transform.basis.x.cross(town.world_transform.basis.z).length()
  var group_budget := clampi(floori(columns.size()*9.0*area_scale/1200.0),1,4)
  if bool(space.get("plant_only",false)): group_budget = 0
  # A large green can host several distinct activities. Seeded candidate
  # order prevents every group collecting at the lexicographic west edge.
  var sites := columns.duplicate()
  for i in range(sites.size()-1,0,-1):
   var j := prop_rng.randi_range(0,i)
   var swap: Vector2i = sites[i]
   sites[i] = sites[j]
   sites[j] = swap
  for group_index in group_budget:
   var purpose: StringName = space.purpose
   if group_index>0 and purpose in [&"green",&"grove"]:
    purpose = [&"courtyard",&"market",&"green"][prop_rng.randi_range(0,2)]
   var group := _group(purpose, prop_rng)
   for column: Vector2i in sites:
    var p := town.world_transform * Vector3(column.x*3.0+0.75,0,column.y*3.0+0.75)
    var anchor := Vector2(p.x,p.z)
    var separated := true
    for other: Vector2 in group_anchors:
     if anchor.distance_squared_to(other)<16.0*16.0: separated = false
    if not separated: continue
    var facing := _street_facing(anchor,streets,NAN,blockers,12.0)
    if not is_finite(facing): continue
    if _place_group(town, group, anchor, facing, bounds,
      terrain, field, placed, allowed, inverse, "group.%s.%d" % [space.id,group_index], world_seed):
     audit.groups += 1
     audit.props += group.size()
     group_anchors.append(anchor)
     break
  for column: Vector2i in columns:
   var local := Vector3(column.x * 3.0 + 0.75, 0, column.y * 3.0 + 0.75)
   var position := town.world_transform * local
   if rng.randf() > float(audit.woodland) * 0.65: continue
   # A rejected wide crown need not leave a valid planting cell empty.
   # Try a few measured forms and positions, admitting at most one tree.
   for attempt in 4:
    var anchor := Vector2(position.x, position.z) + Vector2(rng.randf_range(-2,2),rng.randf_range(-2,2))
    var asset := TREES[rng.randi_range(0,TREES.size()-1)]
    if not bounds.has(asset): continue
    # Narrow town gardens also admit younger trees. The earlier attempts
    # retain the large canopy vocabulary; later attempts fit a smaller
    # specimen through the same measured root/crown clearance gates.
    var height := rng.randf_range(10.0,18.0) if attempt<2 else rng.randf_range(6.0,10.0)
    var scale_value := height / (bounds[asset] as AABB).size.y
    var tree_group := [{"asset": asset, "offset": Vector2.ZERO, "scale": scale_value}]
    if _place_group(town, tree_group, anchor, rng.randf()*TAU, bounds, terrain,
      field, placed, allowed, inverse, "tree.%d" % int(audit.trees), world_seed, tree_bands):
     audit.trees += 1
     if bool(space.get("plant_only",false)): audit.natural_pocket_trees += 1
     break
 return audit

static func _native_ground_clearances(town: VillageUrbanFabricPlan, bounds: Dictionary,
  terrain: VillageTerrainView) -> Array[FeatureGroundShape]:
 var out: Array[FeatureGroundShape] = []
 for entry: Dictionary in town.entries:
  if not bounds.has(entry.asset_id): continue
  var box: AABB = entry.transform * (bounds[entry.asset_id] as AABB)
  var centre := Vector2(box.get_center().x,box.get_center().z)
  var ground := terrain.surface_y(centre)
  # Finished low architecture includes non-colliding window boxes and trim.
  # High roofs are not ground obstacles; buried foundation pieces are not
  # reasons to erase planting on the usable ground above them.
  if box.end.y<=ground+0.05 or box.position.y>=ground+3.5: continue
  out.append(FeatureGroundShape.axis_rect(Rect2(Vector2(box.position.x,box.position.z),
   Vector2(box.size.x,box.size.z))))
 return out

static func _planting_spaces(massif: WarrenMassif) -> Array[Dictionary]:
 # Unbuilt pockets between lobes already have open sky. They are part of
 # the town's natural ground, even when no clearing had to excavate them.
 # Keep every whole planting cell inside the existing town convex hull;
 # this never excavates ground or changes construction topology.
 var spaces: Array[Dictionary] = massif.open_spaces.duplicate(true)
 var points := PackedVector2Array()
 for column: Vector2i in massif.columns:
  for corner: Vector2 in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:
   points.append(Vector2(column)+corner)
 if points.size()<3: return spaces
 var hull := Geometry2D.convex_hull(points)
 var extent := BuildingDesigner._bounds(massif.columns)
 var cells := {}
 for z in range(extent.position.y,extent.end.y):
  for x in range(extent.position.x,extent.end.x):
   var column := Vector2i(x,z)
   if massif.columns.has(column): continue
   var inside := true
   for corner: Vector2 in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:
    if not Geometry2D.is_point_in_polygon(Vector2(column)+corner,hull): inside=false
   if inside: cells[column]=true
 if not cells.is_empty():
  spaces.append({"id":&"natural.interstitial","cells":cells,"purpose":&"grove","plant_only":true})
 return spaces

static func _approach_blockers(town: VillageUrbanFabricPlan, terrain: VillageTerrainView) -> Array[FeatureGroundShape]:
 var out: Array[FeatureGroundShape] = []
 for volume: VillageOccupancyVolume in town.volumes:
  if volume.role not in [VillageOccupancy.Role.SOLID,VillageOccupancy.Role.WALK_GUARD]: continue
  var ground := terrain.surface_y(volume.centre)
  if volume.y_range.y <= ground+0.05 or volume.y_range.x >= ground+TraversalEnvelope.CAPSULE_HEIGHT: continue
  out.append(FeatureGroundShape.oriented_rect(volume.centre,volume.half_extents,volume.angle))
 return out

static func _street_facing(anchor: Vector2, streets: Array[Vector2], fallback: float,
  blockers: Array[FeatureGroundShape] = [], max_distance: float = INF) -> float:
 var distance := max_distance*max_distance
 var angle := fallback
 for street: Vector2 in streets:
  var delta := street-anchor
  if delta.length_squared() < distance and delta.length_squared() > 0.01:
   var approach := FeatureGroundShape.capsule(anchor,street,TraversalEnvelope.CAPSULE_RADIUS)
   var clear := true
   for blocker: FeatureGroundShape in blockers:
    if approach.intersects(blocker):
     clear = false
     break
   if not clear: continue
   distance = delta.length_squared()
   angle = atan2(delta.x,delta.y)
 return angle

static func _group(purpose: StringName, rng: RandomNumberGenerator) -> Array:
 var bench := GARDEN_BENCH if rng.randf()<0.5 else TAVERN_BENCH
 var bench_yaw := PI*0.5 if bench == TAVERN_BENCH else 0.0
 match purpose:
  &"workyard":
   if rng.randf()<0.5:
    return [{"asset":HERBALIST,"offset":Vector2.ZERO},
     {"asset":CAULDRON,"offset":Vector2(3.1,0.5)}]
   return [{"asset":FORGE_ANVIL,"offset":Vector2.ZERO},
    {"asset":BARREL,"offset":Vector2(2.0,0.8)}]
  &"market":
   # These are complete vendor assemblies, including counter and stock.
   # Their measured envelope already includes their companion props.
   return [{"asset":VEGETABLE_STALL if rng.randf()<0.5 else BAKERY,"offset":Vector2.ZERO}]
  &"courtyard":
   return [{"asset":TAVERN_TABLE,"offset":Vector2.ZERO}]
  &"grove", &"green":
   if rng.randf()<0.2:
    return [{"asset":TENTS[rng.randi_range(0,TENTS.size()-1)],"offset":Vector2.ZERO},
     {"asset":BARREL,"offset":Vector2(3.5,0)}]
   if rng.randf()<0.5:
    return [{"asset":FIRE,"offset":Vector2.ZERO},
     {"asset":bench,"offset":Vector2(0,2.6),"yaw":bench_yaw}]
   return [{"asset":TAVERN_TABLE,"offset":Vector2.ZERO}]
 return [{"asset":bench,"offset":Vector2.ZERO,"yaw":bench_yaw},
  {"asset":BARREL,"offset":Vector2(2.7,0)}]

static func _place_group(town: VillageUrbanFabricPlan, group: Array,
  anchor: Vector2, yaw: float, bounds: Dictionary, terrain: VillageTerrainView,
  field: FeatureGroundField, placed: Array[FeatureGroundShape], allowed: Dictionary,
  inverse: Transform3D, suffix: String, world_seed: int = 0,
  tree_bands: Dictionary = {}) -> bool:
 var proposals: Array[Dictionary] = []
 for item: Dictionary in group:
  var id := StringName(item.asset)
  if not bounds.has(id): return false
  var box: AABB = bounds[id]
  var scale_value := float(item.get("scale",1.0))
  var basis := Basis(Vector3.UP,yaw+float(item.get("yaw",0.0))).scaled(Vector3.ONE*scale_value)
  var offset := Vector3((item.offset as Vector2).x,0,(item.offset as Vector2).y).rotated(Vector3.UP,yaw)
  var origin := Vector3(anchor.x,0,anchor.y)+offset
  var root_box: AABB = TREE_PROFILES[id][1] if TREE_PROFILES.has(id) else box
  var flat := Transform3D(basis,origin)*root_box
  var rect := Rect2(Vector2(flat.position.x,flat.position.z),Vector2(flat.size.x,flat.size.z))
  var shape := FeatureGroundShape.oriented_rect(rect.get_center(),
   Vector2(root_box.size.x,root_box.size.z)*scale_value*0.5,
   -yaw-float(item.get("yaw",0.0)))
  if field.overlaps_clearance(shape,MARGIN,false): return false
  for path: FeatureGroundShape in town.surfaces:
   if path.surface_id != FeatureGroundField.NATURAL and shape.intersects(path,MARGIN): return false
  # Check every covered macro column, not only corners: a footprint must
  # not bridge across a hole or a narrow lane inside the reserved domain.
  var local_a := inverse*Vector3(rect.position.x,0,rect.position.y)
  var local_b := inverse*Vector3(rect.end.x,0,rect.end.y)
  var lo := Vector2i(floori((minf(local_a.x,local_b.x)+0.75)/3.0),
   floori((minf(local_a.z,local_b.z)+0.75)/3.0))
  var hi := Vector2i(floori((maxf(local_a.x,local_b.x)+0.75)/3.0),
   floori((maxf(local_a.z,local_b.z)+0.75)/3.0))
  for z in range(lo.y,hi.y+1):
   for x in range(lo.x,hi.x+1):
    if not allowed.has(Vector2i(x,z)): return false

  for other: FeatureGroundShape in placed:
   var obstacle: FeatureGroundShape = other
   if TREE_PROFILES.has(id) and tree_bands.has(other.stable_id):
    obstacle = tree_bands[other.stable_id].root
   if shape.intersects(obstacle,MARGIN): return false
  for other: Dictionary in proposals:
   if shape.intersects(other.shape,MARGIN): return false
  var low := INF
  var high := -INF
  for point: Vector2 in [rect.position, Vector2(rect.end.x,rect.position.y),
    rect.end, Vector2(rect.position.x,rect.end.y),rect.get_center()]:
   var local := inverse*Vector3(point.x,0,point.y)
   var column := Vector2i(floori((local.x+0.75)/3.0),floori((local.z+0.75)/3.0))
   if not allowed.has(column) or field.surface_at(point) != FeatureGroundField.NATURAL:
    return false
   if terrain.is_wet(point): return false
   var height := terrain.surface_y(point)
   low = minf(low,height)
   high = maxf(high,height)
  if high-low > 0.12: return false
  origin.y = (low+high)*0.5-box.position.y*scale_value
  if not TREE_PROFILES.has(id):
   # The coarse house body does not include projecting window boxes and
   # facade trim. Keep full prop envelopes back from inhabited structures.
   var prop_box: AABB = Transform3D(basis,origin)*box
   for volume: VillageOccupancyVolume in town.volumes:
    if volume.role not in [VillageOccupancy.Role.SOLID,VillageOccupancy.Role.WALK_GUARD]: continue
    if volume.y_range.y<=prop_box.position.y or volume.y_range.x>=prop_box.end.y: continue
    var wall := FeatureGroundShape.oriented_rect(volume.centre,volume.half_extents,volume.angle)
    if shape.intersects(wall,1.5): return false
  var bands: Array[VillageOccupancyVolume] = []
  if TREE_PROFILES.has(id):
   for local_box: AABB in TREE_PROFILES[id]:
    var canopy := Transform3D(basis,origin)*local_box
    var candidate := VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
     Vector2(canopy.get_center().x,canopy.get_center().z),
     Vector2(canopy.size.x,canopy.size.z)*0.5+Vector2.ONE*MARGIN,
     0,canopy.position.y,canopy.end.y,&"tree.check")
    bands.append(candidate)
    for volume: VillageOccupancyVolume in town.volumes:
     if tree_bands.has(volume.stable_id):
      var neighbour: Dictionary = tree_bands[volume.stable_id]
      var join_height := maxf(low, float(neighbour.ground)) + CROWN_JOIN_HEIGHT
      for other_band: VillageOccupancyVolume in neighbour.bands:
       if candidate.y_range.x >= join_height and other_band.y_range.x >= join_height:
        continue
       if candidate.overlaps(other_band): return false
     elif volume.role != VillageOccupancy.Role.GROUND_EXCLUSIVE and candidate.overlaps(volume):
      return false

  proposals.append({"asset_id":id,"transform":Transform3D(basis,origin),"shape":shape,"bands":bands,"ground":low})
 for index in proposals.size():
  var proposal: Dictionary = proposals[index]
  var stable := StringName("%s.dressing.%s.%d" % [town.public_walk_network_id,suffix,index])
  var tint := Color.WHITE
  if TREE_PROFILES.has(proposal.asset_id):
   tint = BiomeRegistry.blended_environment_tint(Helper.biome_weights5(
    (proposal.transform as Transform3D).origin,world_seed), &"tree")
  town.entries.append({"asset_id":proposal.asset_id,"transform":proposal.transform,
   "stable_id":stable,"color":tint,"collision_enabled":true,"visibility_owner":AABB()})
  var shape: FeatureGroundShape = proposal.shape
  shape.stable_id = stable
  var world_box: AABB = (proposal.transform as Transform3D)*(bounds[proposal.asset_id] as AABB)
  town.volumes.append(VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
   Vector2(world_box.get_center().x,world_box.get_center().z),
   Vector2(world_box.size.x,world_box.size.z)*0.5,0,
   world_box.position.y,world_box.end.y,stable,town.public_walk_network_id))
  town.clearances.append(shape)
  if TREE_PROFILES.has(proposal.asset_id):
   var crown := FeatureGroundShape.axis_rect(Rect2(
    Vector2(world_box.position.x,world_box.position.z),Vector2(world_box.size.x,world_box.size.z)))
   crown.stable_id = stable
   placed.append(crown)
   tree_bands[stable] = {"root":shape,"bands":proposal.bands,"ground":proposal.ground}
  else:
   placed.append(shape)
 return true
