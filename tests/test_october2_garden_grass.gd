extends GutTest

func test_rotated_garden_support_preserves_holes_and_outer_boundary() -> void:
 var cells := {Vector3i(0,7,0):true,Vector3i(1,7,0):true}
 var obstacle := AABB(Vector3(-.2,12,-.2),Vector3(.4,.5,.4))
 var regions := TownGardenGrass.local_regions(cells,[obstacle])
 var frame := Transform3D(Basis(Vector3.UP,.7).scaled(Vector3(2,2,2)),Vector3(100,5,100))
 var world := TownGardenGrass.world_regions(regions,frame,&"test")
 var index := GrassSupportSurfaces.spatial_index(world)
 var p := frame*Vector3(1.5,12.005,0)
 var sample := GrassSupportSurfaces.at_index(index,Vector2(p.x,p.z))
 assert_false(sample.is_empty())
 assert_almost_eq(float(sample.y),p.y,.001)
 assert_true(sample.get("feature_garden",false),"the grass sampler can distinguish proved elevated planting from the projected lower street")
 var blocked := frame*Vector3.ZERO
 assert_true(GrassSupportSurfaces.at_index(index,Vector2(blocked.x,blocked.z)).is_empty())
 var outside := frame*Vector3(3,0,0)
 assert_true(GrassSupportSurfaces.at_index(index,Vector2(outside.x,outside.z)).is_empty())

func test_real_elevated_garden_survives_worker_detachment_and_grows_grass_over_lower_clearance() -> void:
 var catalog := EnvironmentCatalog.load_default()
 var spatial := WarrenVolumetricSolver.generate(13,{},SettlementFabricProgram.compile(catalog),WarrenVillageScaleProfile.for_id(&"grand"))
 assert_not_null(spatial)
 if spatial == null: return
 var fabric := spatial.compiled_fabric_cache()
 var local := SettlementFabricAssembler.terrace_retaining_payload(fabric)
 var payload := EnvironmentInstancePayload.new()
 var frame := Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(12,0,12))
 for mesh: Dictionary in local.surface_meshes:
  if mesh.has("garden_grass_regions"):
   payload.add_surface_mesh(VillageWarrenFabricSolver._world_surface_mesh(mesh,frame,&"garden",13))
 var coverage := Rect2(Vector2(-10,-10),Vector2(50,50))
 var clearances: Array[FeatureGroundShape] = [FeatureGroundShape.axis_rect(coverage)]
 var context := FeatureContext.new(coverage,FeatureGroundField.new([],clearances,0),payload)
 var region := HeightfieldPlan.new(4242,1.0,1,"mean").compute_region(4,4,12)
 var water := WaterFieldContext.new()
 water._ctx = {"ponds":[],"rivers":[],"buckets":{},"region":region}
 water._region = region
 water._coverage = coverage
 water._shore_limit = 20.0
 water._shore_curves_ready = true
 var sampling := GrassSamplingContext.detached(region,water,context)
 assert_false(sampling.supports.is_empty(),"the worker receives the constructed garden")
 var settings := (load("res://terrain/grass/settings.tres") as GrassSettings).duplicate(true)
 settings.coverage_by_biome = settings.coverage_by_biome.duplicate(true)
 for key in settings.coverage_by_biome: settings.coverage_by_biome[key] = 1.0
 var grass := GrassProgram.compile(settings,catalog,EnvironmentRenderCache.new(catalog))
 var grown := GrassField.compute(grass,13,Vector2i.ZERO,sampling.region,sampling.water,sampling.features,sampling.supports)
 var count := 0
 var index := GrassSupportSurfaces.spatial_index(sampling.supports)
 for batch: Dictionary in grown.batches.values():
  var buffer: PackedFloat32Array = batch.buffer
  for i in int(batch.count):
   var offset := i*GrassPayload.FLOATS_PER_INSTANCE
   var p := Vector3(buffer[offset+3],buffer[offset+7],buffer[offset+11])
   count += 1
   assert_almost_eq(p.y,24.01,.05,"projected lower construction cannot push roots onto the ground")
   assert_false(GrassSupportSurfaces.at_index(index,Vector2(p.x,p.z)).is_empty(),"grass remains inside supported planting, outside obstacles")
 assert_gt(count,0,"real courtyard garden receives streamed grass")

func test_query_support_survives_without_render_ownership_and_context_extension() -> void:
 var regions := TownGardenGrass.local_regions({Vector3i(0,7,0):true},[])
 var world := TownGardenGrass.world_regions(regions,Transform3D.IDENTITY,&"neighbour")
 var context := FeatureContext.new(Rect2(Vector2(-10,-10),Vector2(20,20)),FeatureGroundField.new([],[],0),EnvironmentInstancePayload.new())
 context.garden_support_regions = world
 var extended := context.extended([],[],EnvironmentInstancePayload.new(),Rect2())
 assert_eq(extended.garden_grass_supports(),world,"spatial garden queries do not depend on which chunk owns the town renderer")
 assert_eq(context.placements().surface_meshes.size(),0)

func test_tree_canopy_does_not_erase_grass_but_root_and_low_branches_do() -> void:
 var asset := &"lpfv.tree.01"
 var bounds := EnvironmentCatalog.load_default().descriptor(asset).measured_aabb
 var cells := {}
 for z in range(-5,6):
  for x in range(-5,6): cells[Vector3i(x,-1,z)] = true
 var obstacles := TownGardenGrass.asset_obstacles(asset,Transform3D.IDENTITY,bounds)
 var regions := TownGardenGrass.local_regions(cells,obstacles)
 var world := TownGardenGrass.world_regions(regions,Transform3D.IDENTITY,&"tree")
 var index := GrassSupportSurfaces.spatial_index(world)
 assert_true(GrassSupportSurfaces.at_index(index,Vector2.ZERO).is_empty(),"roots exclude grass")
 assert_false(GrassSupportSurfaces.at_index(index,Vector2(3,3)).is_empty(),"lawn survives under the high canopy")

class GardenPaths extends PathPlan:
 func context_for(block: Vector2i,_cancelled := Callable()) -> FeatureContext:
  return FeatureContext.new(Rect2(Vector2(block)*192,Vector2.ONE*192),FeatureGroundField.new([],[],0),EnvironmentInstancePayload.new())

class GardenFeatures extends WorldFeaturePlan:
 var records: Array[VillageRecord] = []
 func _records_affecting(coverage: Rect2) -> Array[VillageRecord]:
  var out: Array[VillageRecord] = []
  for record: VillageRecord in records:
   if record.bounds.intersects(coverage,true): out.append(record)
  return out

func test_world_feature_queries_keep_cross_chunk_gardens_through_cache_eviction() -> void:
 var catalog := EnvironmentCatalog.load_default()
 var program := FeatureProgram.compile(catalog)
 var water := WaterPlan.new(4242,1.0,1)
 var heights := HeightfieldPlan.new(4242,1.0,1,"mean")
 var fields := WorldFieldBlockCache.new(heights,water,program.query_margin,program.shore_distance_limit,program.field_cache_cap)
 var settlements := SettlementPlan.new(4242,water)
 var world := GardenFeatures.new(4242,water,fields,program,settlements)
 world._paths=GardenPaths.new(4242,water,fields,program.paths,program.query_margin,settlements)
 var regions := TownGardenGrass.local_regions({Vector3i(0,7,0):true,Vector3i(1,7,0):true},[])
 var supports := TownGardenGrass.world_regions(regions,Transform3D(Basis.IDENTITY,Vector3(192,0,20)),&"seam")
 var payload := EnvironmentInstancePayload.new()
 var mesh := preload("res://scripts/terrain/features/villages/TownStreetPaint.gd").mesh([Vector3i.ZERO])
 mesh.merge({"stable_id":&"seam-garden","anchor":Vector3(192,12,20),"visual_only":true,
  "collision_faces":PackedVector3Array(),"garden_grass_regions":supports})
 payload.add_surface_mesh(mesh)
 var record := VillageRecord.new(&"seam",Vector2(180,20),Rect2(Vector2(180,10),Vector2(30,20)),payload,[],[],[])
 world.records.append(record)
 var owner := world.context_for(Vector2i.ZERO)
 var neighbour := world.context_for(Vector2i.RIGHT)
 assert_eq(owner.garden_grass_supports(),supports)
 assert_eq(owner.placements().surface_meshes.size(),1,"the owner keeps the garden renderer")
 assert_eq(neighbour.garden_grass_supports(),supports)
 assert_eq(neighbour.placements().surface_meshes.size(),0,"neighbour queries must not duplicate the town renderer")
 for i in range(2,WorldFeaturePlan.CONTEXT_CACHE_CAP+3): world.context_for(Vector2i(i,0))
 assert_false(world._contexts.has(Vector2i.ZERO))
 var rebuilt := world.context_for(Vector2i.ZERO)
 assert_ne(rebuilt,owner)
 assert_eq(rebuilt.garden_grass_supports(),supports,"eviction/reentry preserves the elevated support")
