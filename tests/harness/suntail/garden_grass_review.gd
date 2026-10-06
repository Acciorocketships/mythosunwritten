extends RefCounted
## Uses production grass sampling, assets and material on the native town's
## declared elevated gardens. The surrounding study plane is deliberately bare;
## this is a garden rendering check, not a streamed-world replacement.
static func draw(payload: EnvironmentInstancePayload, frame: Transform3D,
  catalog: EnvironmentCatalog, cache: EnvironmentRenderCache, seed_value: int) -> Dictionary:
 var world := EnvironmentInstancePayload.new()
 var coverage := Rect2()
 for mesh: Dictionary in payload.surface_meshes:
  if not mesh.has("garden_grass_regions"): continue
  var transformed := VillageWarrenFabricSolver._world_surface_mesh(mesh,frame,&"grass-review",seed_value)
  world.add_surface_mesh(transformed)
  for support: Dictionary in transformed.garden_grass_regions:
   coverage=coverage.merge(support.bounds) if coverage.has_area() else support.bounds
 var node := Node3D.new()
 var report := {"node":node,"instances":0,"tiles":0}
 if not coverage.has_area(): return report
 coverage=coverage.grow(8.0)
 var clearances: Array[FeatureGroundShape] = [FeatureGroundShape.axis_rect(coverage.grow(24))]
 var context := FeatureContext.new(coverage,FeatureGroundField.new([],clearances,0),world)
 var centre := Vector2i(roundi(coverage.get_center().x/HeightfieldPlan.CELL),roundi(coverage.get_center().y/HeightfieldPlan.CELL))
 var region := HeightfieldPlan.new(seed_value,1.0,1,"mean").compute_region(centre.x,centre.y,12)
 var water := WaterFieldContext.new()
 water._ctx={"ponds":[],"rivers":[],"buckets":{},"region":region}
 water._region=region
 water._coverage=coverage.grow(48.0)
 water._shore_limit=20.0
 water._shore_curves_ready=true
 var sampling := GrassSamplingContext.detached(region,water,context)
 var settings := load("res://terrain/grass/settings.tres") as GrassSettings
 var program := GrassProgram.compile(settings,catalog,cache)
 var renderer := GrassStreamer.new(program,cache)
 node.set_meta(&"grass_renderer",renderer)
 for z in range(floori(coverage.position.y/24),floori(coverage.end.y/24)+1):
  for x in range(floori(coverage.position.x/24),floori(coverage.end.x/24)+1):
   var grass := GrassField.compute(program,seed_value,Vector2i(x,z),sampling.region,sampling.water,sampling.features,sampling.supports)
   for asset: StringName in grass.asset_ids(): renderer._add_batch(node,asset,grass.batches[asset])
   report.instances+=grass.instance_count
   report.tiles+=1
 return report
