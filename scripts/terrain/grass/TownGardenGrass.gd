class_name TownGardenGrass
extends RefCounted

## Trees use measured vertical bands so a canopy cannot erase its ground cover.
## The support builder below clips these to grass height on each garden floor.
static func asset_obstacles(asset: StringName, pose: Transform3D, bounds: AABB) -> Array[AABB]:
 var out: Array[AABB] = []
 var profiles := preload("res://scripts/terrain/features/villages/TownTreeProfiles.gd").BANDS
 if profiles.has(asset):
  for band: AABB in profiles[asset]: out.append(pose*band)
 else:
  out.append(pose*bounds)
 return out

## Only declared planting cells own this support, never the surrounding walk.
static func local_regions(cells: Dictionary, obstacles: Array[AABB]) -> Array[Dictionary]:
 var layers := {}
 for cell: Vector3i in cells:
  if not layers.has(cell.y): layers[cell.y] = {}
  layers[cell.y][cell] = true
 var out: Array[Dictionary] = []
 for band: int in layers:
  var layer: Dictionary = layers[band]
  var triangles := PackedVector2Array()
  var border := PackedVector2Array()
  var bounds := Rect2()
  for cell: Vector3i in layer:
   var centre := Vector2(cell.x,cell.z)*FabricRecipe.CELL_SIZE
   var corners := [centre+Vector2(-.75,-.75),centre+Vector2(.75,-.75),centre+Vector2(.75,.75),centre+Vector2(-.75,.75)]
   for i in [0,1,2,0,2,3]: triangles.append(corners[i])
   var rect := Rect2(corners[0],Vector2.ONE*1.5)
   bounds = bounds.merge(rect) if bounds.has_area() else rect
   var steps := [Vector3i.FORWARD,Vector3i.RIGHT,Vector3i.BACK,Vector3i.LEFT]
   for side in 4:
    if not layer.has(cell+steps[side]):
     border.append(corners[side]);border.append(corners[(side+1)%4])
  var height := float(band+1)*FabricRecipe.CELL_SIZE+SettlementFabricAssembler.GREEN_CAP_LIFT
  var holes: Array[Rect2] = []
  for box: AABB in obstacles:
   if box.end.y <= height+.01 or box.position.y >= height+1.5: continue
   holes.append(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)))
  out.append({"id":"town-garden/%d"%band,"height":height,"bounds":bounds,
   "triangles":triangles,"border":border,"obstacles":holes,"feature_garden":true})
 return out

static func world_regions(regions: Array, frame: Transform3D, owner: StringName) -> Array[Dictionary]:
 var out: Array[Dictionary] = []
 for source: Dictionary in regions:
  var region := source.duplicate(true)
  region.id = "%s/%s"%[owner,source.id]
  region.height = (frame*Vector3(0,source.height,0)).y
  for key: String in ["triangles","border"]:
   var points := PackedVector2Array()
   for p: Vector2 in source[key]:
    var q := frame*Vector3(p.x,source.height,p.y)
    points.append(Vector2(q.x,q.z))
   region[key] = points
  region.bounds = Rect2(region.triangles[0],Vector2.ZERO)
  for p: Vector2 in region.triangles: region.bounds = region.bounds.expand(p)
  region.obstacles = []
  region.polygon_obstacles = []
  for hole: Rect2 in source.obstacles:
   var polygon := PackedVector2Array()
   for p: Vector2 in [hole.position,Vector2(hole.end.x,hole.position.y),hole.end,Vector2(hole.position.x,hole.end.y)]:
    var q := frame*Vector3(p.x,source.height,p.y)
    polygon.append(Vector2(q.x,q.z))
   region.polygon_obstacles.append(polygon)
  out.append(region)
 return out
