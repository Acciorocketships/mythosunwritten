extends GutTest

func test_long_shared_walk_has_supported_lamps_before_random_planting() -> void:
	var garden: Dictionary = {}
	var walked: Dictionary = {}
	for x in 12:
		for z in 2: garden[Vector3i(x,0,z)]=true
		walked[Vector3i(x,1,-1)]=true
	var sites := SettlementFabricAssembler.maze_garden_planting_sites(garden,{}, {},{}, {},{},[] as Array[AABB],walked)
	var lamps: Array[Dictionary] = []
	for site in sites:
		if site.asset==SettlementFabricProgram.TERRACE_LANTERN_POST:lamps.append(site)
	assert_gte(lamps.size(),2,"A long public walk must have deliberate lighting stations")
	assert_lte(lamps.size(),4,"Each town has a bounded additional lamp count")
	for i in lamps.size():
		var site := lamps[i]
		assert_true(garden.has(site.cell) and garden.has(site.cell+site.step))
		assert_false(walked.has(site.cell+Vector3i.UP))
		for j in i: assert_gte((site.origin as Vector3).distance_to(lamps[j].origin),6.0)

func test_lights_cannot_consume_a_public_square_or_occupied_air() -> void:
	var garden: Dictionary = {}
	var walked: Dictionary = {}
	for x in 4:
		for z in 4:
			garden[Vector3i(x,0,z)]=true
			walked[Vector3i(x,1,z)]=true
	var sites := SettlementFabricAssembler.maze_garden_planting_sites(garden,garden,{}, {},{}, {},[] as Array[AABB],walked)
	assert_true(sites.is_empty())
	walked.clear()
	for x in 4:walked[Vector3i(x,1,-1)]=true
	var blocked: Array[AABB] = [AABB(Vector3(-2,1,-2),Vector3(10,8,10))]
	sites=SettlementFabricAssembler.maze_garden_planting_sites(garden,{}, {},{}, {},{},blocked,walked)
	for site in sites: assert_ne(site.asset,SettlementFabricProgram.TERRACE_LANTERN_POST)

func test_every_realized_closed_door_has_one_contained_native_wall_lamp() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	for label in ["east","offset","thin-turf"]:
		var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september9-%s-source.txt"%label),program)
		var fabric := spatial.compiled_fabric_cache()
		var panels: Dictionary = {}
		var lamps: Dictionary = {}
		for entry in fabric.expanded_placements():
			var id:=String(entry.asset_id)
			if id.begins_with("sfv.fabric.wall.wood.door.closed.001") or id.begins_with("sfv.fabric.wall.rock.door.closed.005"):
				panels[entry.stable_id]=entry
			if entry.has("attachment_owner"):
				assert_false(lamps.has(entry.attachment_owner))
				lamps[entry.attachment_owner]=entry
		assert_gt(panels.size(),0)
		assert_eq(lamps.size(),panels.size(),label+" lights each remaining real doorway")
		for owner in lamps:
			assert_true(panels.has(owner),"A suppressed wall cannot leave a floating lamp")
			assert_true((panels[owner].bounds as AABB).grow(0.00001).encloses(lamps[owner].bounds),"Lamp stays in the existing panel envelope")
			var panel: Dictionary = panels[owner]
			var pose: Transform3D = lamps[owner].transform
			var mount := pose*Vector3(0,0.45,-0.20547369)
			var normal: Vector3 = pose.basis.z.normalized()
			var visual := load(EnvironmentCatalog.load_default().descriptor(panel.asset_id).visual_path) as EnvironmentVisual
			var nearest := INF
			for piece in visual.pieces:
				var faces := piece.mesh.get_faces()
				var wall_pose: Transform3D = panel.transform*piece.local_transform
				for i in range(0,faces.size(),3):
					var hit=Geometry3D.ray_intersects_triangle(mount+normal*0.1,-normal,
						wall_pose*faces[i],wall_pose*faces[i+1],wall_pose*faces[i+2])
					if hit!=null:nearest=minf(nearest,(hit as Vector3).distance_to(mount))
			assert_lt(nearest,0.003,"The bracket contacts the real realized panel, including its miter and return choices")

