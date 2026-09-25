extends GutTest
const SEED := 2697992464
const POS := Vector3(-231.7, 12.0, 422.5)

func test_native_path_keeps_earth_colour_in_the_reported_biome() -> void:
	var mesher := TerrainChunkMesher.new()
	var tint := BiomeRegistry.ground_tint_at(POS, SEED)
	var vertices: Array[Vector3] = [POS, POS+Vector3.RIGHT, POS+Vector3.FORWARD]
	var colours: Array[Color] = [tint,tint,tint]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesher._tri_tinted(st,vertices,SlopeAtlas.path_uv(),colours)
	var arrays := st.commit_to_arrays()
	assert_eq(arrays[Mesh.ARRAY_COLOR][0],Color.WHITE,"The grass multiplier must not turn native tan earth pink")
	var grass := SurfaceTool.new(); grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesher._tri_tinted(grass,vertices,CliffDressing.ground_uv(),colours)
	assert_eq(grass.commit_to_arrays()[Mesh.ARRAY_COLOR][0],tint,"Grass retains its own biome colour")
	var spots := SurfaceTool.new(); spots.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := TerrainChunkMesher.PATH_SPOT_DARKEN
	mesher._tri_tinted(spots,vertices,SlopeAtlas.path_spot_uv(),[tint*dark,tint*dark,tint*dark])
	assert_eq(spots.commit_to_arrays()[Mesh.ARRAY_COLOR][0],Color(dark,dark,dark,1),"Marks stay subtly darker without grass hue")

func test_retained_town_streets_match_native_earth_and_keep_collision() -> void:
	var vertices := PackedVector3Array([POS,POS+Vector3.RIGHT,POS+Vector3.FORWARD])
	var source := {"vertices":vertices,"normals":PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]),"collision_faces":vertices,"terrain_ground":true,"terrain_path":true}
	var street := VillageWarrenFabricSolver._world_surface_mesh(source,Transform3D.IDENTITY,&"colour-probe",SEED)
	assert_eq(street.colors[0],Color.WHITE,"Structural and native paths share the same earth tint")
	assert_eq(street.collision_faces,vertices,"Only colour changes")
	source.erase("terrain_path");source["terrain_path_spot"]=true
	var spots := VillageWarrenFabricSolver._world_surface_mesh(source,Transform3D.IDENTITY,&"colour-probe",SEED)
	var dark := TerrainChunkMesher.PATH_SPOT_DARKEN
	assert_eq(spots.colors[0],Color(dark,dark,dark,1))
	source.erase("terrain_path_spot")
	var turf := VillageWarrenFabricSolver._world_surface_mesh(source,Transform3D.IDENTITY,&"colour-probe",SEED)
	assert_eq(turf.colors[0],BiomeRegistry.ground_tint_at(POS,SEED))
