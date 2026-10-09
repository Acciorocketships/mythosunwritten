extends RefCounted
## Cliff dressing of one chunk: the whole-wall slope solid over every cliff
## (CliffSlopeField.solid, its render arrays and collision), the Meadow rock
## clusters at the cliff foot lines with their ground skirts, grass supports
## on the gentle slope, and the ground the slope and its rocks reserve against
## ambient dressing. The foot lines are the terrain's own walls
## (TerrainTileField.wall_segments); a chunk owns the walls, slope and rocks of
## its lattice points' dual cells. Baked resources are prepared on the main
## thread; workers consume detached arrays.
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const SLOPE_ROCKS=preload("res://scripts/terrain/field/CliffSlopeRocks.gd")
const SLOPE_FIELD=preload("res://scripts/terrain/field/CliffSlopeField.gd")
const POINTS_PER_CHUNK:=16
## Foot lines are gathered this far around the owned rectangle: a rock cluster
## or the slope it shapes can reach into the chunk from a wall beyond it.
const WALL_HALO:=24.0

static func prepare()->void:
 SLOPE_ROCKS.prepare()

## The world rectangle of the dual cells of a chunk's lattice points
## (16 k .. 16 k + 15): the half-open ownership of its walls, slope and rocks.
static func owned_rect(chunk:Vector2i)->Rect2:
 var s:=TerrainTileField.SPACING
 return Rect2(Vector2(chunk*POINTS_PER_CHUNK)*s-Vector2.ONE*s*.5,Vector2.ONE*POINTS_PER_CHUNK*s)

## `water_blocks`: see CliffSlopeField._init (the mesher shares one across
## its chunks).
static func compute(region:HeightfieldRegion,chunk:Vector2i,seed_value:int,
  features:FeatureContext=null,water:WaterFieldContext=null,
  water_blocks:WorldFieldBlockCache=null)->Dictionary:
 var owned:=owned_rect(chunk)
 var walls:=TerrainTileField.wall_segments(region,owned.grow(WALL_HALO),true)
 var slope:=SLOPE_FIELD.new(walls,seed_value,region,owned,features,water,water_blocks)
 var placements:Array[Dictionary]=slope.solid(owned)
 # Basal rocks stand in the ground, which swells to meet them: the skirt over
 # the sheet joins the sheet's own mesh.
 if not placements.is_empty():slope.add_skirts(placements[0],owned)
 var collision:=PackedVector3Array()
 for p:Dictionary in placements:
  for vertex:Vector3 in p.faces:collision.append(p.transform*vertex)
  p["render_tiles"]=CRAGS.split_tiles(CRAGS.mesh_arrays(p,region,seed_value)[0],p.transform)
 # Ambient rock and plant bases under the slope would be buried with their
 # tips poking through it; the chunk core is offset half a point from the
 # owned rectangle, so the reservation reaches past it.
 var reservations:Array[Rect2]=slope.reservations(owned.grow(16.0))
 # Every wall's own foot: the crest band and the first metres in front of it.
 # The list serves this chunk's ambient dressing (its core, the chunk square),
 # so a foot reaching that core is reserved whichever chunk owns the wall: a
 # neighbour-owned wall on the chunk border stands its foot inside this core.
 # Feet that cannot reach the core are dropped.
 var dressing_core:=Rect2(Vector2(chunk)*TerrainChunkMesher.CHUNK_WORLD,Vector2.ONE*TerrainChunkMesher.CHUNK_WORLD).grow(RESERVE_CORE_MARGIN)
 for wall:Dictionary in walls:
  var a:Vector2=wall.a;var b:Vector2=wall.b;var n:Vector2=wall.normal
  var foot:=Rect2(a-n*RESERVE_BACK,Vector2.ZERO).expand(b-n*RESERVE_BACK).expand(a+n*RESERVE_OUT).expand(b+n*RESERVE_OUT)
  if foot.intersects(dressing_core,true):reservations.append(foot)
 # Ambient rocks never land on a slope rock (owner, September 27: stacked).
 for rock:Dictionary in slope.rock_list:
  var r:=SLOPE_FIELD._base_radius(rock)
  reservations.append(Rect2(SLOPE_FIELD._base_centre(rock)-Vector2.ONE*r,Vector2.ONE*2.0*r))
 # The whole-wall slope grows the lawn's grass on its gentle ground.
 var grass_core:=Rect2(Vector2(chunk)*TerrainChunkMesher.CHUNK_WORLD,Vector2.ONE*TerrainChunkMesher.CHUNK_WORLD)
 var supports:Array[Dictionary]=[slope.grass_support(grass_core.grow(12.0))]
 var slope_rocks:Dictionary={}
 var skirted:=slope.skirts()
 for rock:Dictionary in slope.rocks(owned):
  if not slope_rocks.has(rock.piece):slope_rocks[rock.piece]=[]
  # A skirted rock grows the ground's colour up from its mound, not from the
  # buried ground under it.
  var entry:=rock.duplicate()
  if skirted.has(rock):
   entry.point=Vector3(rock.point.x,float(skirted[rock].top),rock.point.z)
  # The lawn tint is a noise field: evaluated here on the worker, not per
  # rock in the main-thread batch build (it held integration steps 30-40 ms).
  entry.tint=BiomeRegistry.ground_tint_at((rock.transform as Transform3D).origin,seed_value).clamp()
  slope_rocks[rock.piece].append(entry)
 # Every rock skirt reaching this chunk lends grass support; its owner
 # renders it (the sheet and terrain parts).
 for rock:Dictionary in skirted:
  if grass_core.grow(RockSkirt.WIDTH_MAX+8.0).has_point(SLOPE_FIELD._base_centre(rock)):
   supports.append(skirted[rock].grass_support)
 return {"placements":placements,"collision_faces":collision,"ground_reservations":reservations,
  "grass_supports":supports,"slope_rocks":slope_rocks,"rock_skirts":slope.skirt_terrain(owned),
  # The mesher withdraws the rock skirt faces this slope buries.
  "sheet_cover":slope.envelope()}

## A wall's reservation reaches this far out in front of its line and this far
## back over its crest.
const RESERVE_OUT:=4.0
const RESERVE_BACK:=.3
## An ambient base in the chunk core reaches at most this far past it.
const RESERVE_CORE_MARGIN:=16.0

static func build(data:Dictionary,seed_value:int)->Node3D:
 var steps:=build_steps(data,seed_value)
 for step:Callable in steps.steps:step.call()
 return steps.root

## build as separate main-thread steps (one per sheet placement, the slope
## rocks, the skirts), so the streamer can spread a cliff-heavy chunk over
## frames; running them in order builds exactly build()'s node.
static func build_steps(data:Dictionary,seed_value:int)->Dictionary:
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var root:=Node3D.new();root.name="CliffRockFormations"
 var steps:Array[Callable]=[]
 var labels:=PackedStringArray()  # one per step, for slow-step logs
 for p:Dictionary in data.get("placements",[]):
  # One node per sheet tile (CliffRockCrags.split_tiles), all sharing one
  # material; a step per tile keeps each frame's integration short.
  var tiles:Array=p.render_tiles if p.has("render_tiles") else [{"arrays":CRAGS.mesh_arrays(p)[0],"lods":{}}]
  var material:=[null]
  for tile:Dictionary in tiles:
   steps.append(func()->void:
    if material[0]==null:material[0]=CRAGS.shared_sheet_material()
    var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=CRAGS.mesh(p,[tile.arrays],material[0],tile.lods);mm.use_colors=true;mm.instance_count=1
    # The slope sheet carries its biome tint per vertex (as the terrain does);
    # the instance colour multiplies COLOR, so it stays white.
    mm.set_instance_transform(0,p.transform);mm.set_instance_color(0,Color.WHITE)
    var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.set_meta("cliff_asset",p.asset)
    node.add_to_group("tactical_solid_earth",true);root.add_child(node))
   labels.append("cliff_tile(%d)"%((tile.arrays as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
 if not (data.get("slope_rocks",{}) as Dictionary).is_empty():
  var rocks:=SLOPE_ROCKS.build_steps(data.slope_rocks,seed_value)
  steps.append(func()->void:root.add_child(rocks.root))
  labels.append("slope_rocks_root")
  steps.append_array(rocks.steps)
  labels.append_array(rocks.labels)
 # Terrain-covering parts of the basal rocks' ground skirts.
 var skirt_steps:=RockSkirt.commit_steps(root,data.get("rock_skirts",[]))
 steps.append_array(skirt_steps)
 for index in skirt_steps.size():labels.append("cliff_rock_skirts#%d/%d"%[index,skirt_steps.size()])
 return {"root":root,"steps":steps,"labels":labels}
