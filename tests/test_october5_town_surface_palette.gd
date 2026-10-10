extends GutTest

func test_suntail_plaster_warms_without_recolouring_timber_or_mutating_source() -> void:
 var catalog := EnvironmentCatalog.load_default()
 var id := &"suntail.frame.frame_wall_1"
 var source := load(catalog.descriptor(id).visual_path) as EnvironmentVisual
 var prepared := EnvironmentRenderCache.new(catalog).visual(id)
 var checked := 0
 for i in source.pieces.size():
  for s in source.pieces[i].mesh.get_surface_count():
   var old := source.pieces[i].mesh.surface_get_material(s) as StandardMaterial3D
   var now := prepared.pieces[i].mesh.surface_get_material(s) as StandardMaterial3D
   if old.resource_name == "Wall":
    checked += 1
    assert_lt(now.albedo_color.b,old.albedo_color.b*.9,"plaster becomes warmer cream")
    assert_gt(now.albedo_color.r/now.albedo_color.b,old.albedo_color.r/old.albedo_color.b)
    assert_eq(now.albedo_texture,old.albedo_texture,"retain authored surface detail")
    assert_almost_eq(old.albedo_color.r,.97,.001,"source material stays immutable")
   else: assert_eq(now,old,"wood and other materials retain their finish")
 assert_gt(checked,0)

func test_raised_courtyard_uses_same_colour_as_terrain_below() -> void:
 var p := Vector3(311,54,1083)
 var mesh := {"vertices":PackedVector3Array([p]),"normals":PackedVector3Array([Vector3.UP]),"collision_faces":PackedVector3Array(),"terrain_ground":true}
 var actual := VillageWarrenFabricSolver._world_surface_mesh(mesh,Transform3D.IDENTITY,&"test",2697992464)
 var base := Vector2(floorf(p.x/24)*24,floorf(p.z/24)*24)
 var a := BiomeRegistry.ground_tint_at(Vector3(base.x,0,base.y),2697992464)
 var b := BiomeRegistry.ground_tint_at(Vector3(base.x+24,0,base.y),2697992464)
 var c := BiomeRegistry.ground_tint_at(Vector3(base.x,0,base.y+24),2697992464)
 var d := BiomeRegistry.ground_tint_at(Vector3(base.x+24,0,base.y+24),2697992464)
 var expected := a.lerp(b,(p.x-base.x)/24).lerp(c.lerp(d,(p.x-base.x)/24),(p.z-base.y)/24)
 assert_true((actual.colors[0] as Color).is_equal_approx(expected),"raised lawn uses the terrain's 24m colour lattice, independent of height")

func test_grass_and_raised_lawns_share_regional_lattice_across_biomes() -> void:
 var catalog := EnvironmentCatalog.load_default()
 var program := GrassProgram.compile(load("res://terrain/grass/settings.tres"),catalog,EnvironmentRenderCache.new(catalog))
 for origin: Vector2 in [Vector2.ZERO,Vector2(-24,-792),Vector2(312,1080),Vector2(4320,-5040)]:
  var fields := GrassField._bake_tile_fields(program,origin,2697992464)
  for local: Vector2 in [Vector2(1.3,2.7),Vector2(12.1,18.8),Vector2(23.9,23.1)]:
   var point := Vector3(origin.x+local.x,48,origin.y+local.y)
   var mesh := {"vertices":PackedVector3Array([point]),"normals":PackedVector3Array([Vector3.UP]),"collision_faces":PackedVector3Array(),"terrain_ground":true}
   var lawn := VillageWarrenFabricSolver._world_surface_mesh(mesh,Transform3D.IDENTITY,&"test",2697992464)
   var blades: Color = GrassField._sample_tile_fields(fields,local).tint
   assert_true(blades.is_equal_approx(lawn.colors[0]),"grass/lawn parity at %s"%point)
