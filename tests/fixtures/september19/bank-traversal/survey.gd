extends SceneTree
const OUT := "res://docs/qa/2026-09-19-manual/130-bank-traversal"
const BANKS := "res://docs/qa/2026-09-19-manual/129-bank-corridor/validated-banks.bin"
var space: PhysicsDirectSpaceState3D
var field: WaterFieldContext
var capsule: CapsuleShape3D

func _init() -> void: run.call_deferred()

func run() -> void:
	var stage: Node3D = load("res://docs/qa/2026-09-19-manual/119-small-town/world.scn").instantiate()
	root.add_child(stage)
	var forms: Array = FileAccess.open(BANKS, FileAccess.READ).get_var()
	for form: Dictionary in forms:
		var body := StaticBody3D.new()
		body.collision_layer = 64
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var mesh := ConcavePolygonShape3D.new()
		mesh.set_faces(form.faces)
		shape.shape = mesh
		body.add_child(shape)
		root.add_child(body)
		body.transform = form.transform
	var water := TerrainWorldTuning.make_water(2697992464)
	var fields := WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,water),water,26,0,8)
	var region := fields.region(Vector2i(-3,1))
	field = fields.water(Vector2i(-3,1))
	print("BANK_TRAVERSAL fields ready")
	var actor: CharacterBody3D = preload("res://characters/character.tscn").instantiate()
	capsule = actor.get_node("CollisionShape3D").shape
	actor.free()
	await physics_frame
	await physics_frame
	space = root.world_3d.direct_space_state
	var rows: Array = []
	for rect: Rect2 in [Rect2(-542,304,28,24),Rect2(-488,288,28,28)]:
		var cells: Array = []
		for z in range(int(rect.position.y),int(rect.end.y)+1):
			for x in range(int(rect.position.x),int(rect.end.x)+1):
				var p := Vector2(x,z)
				var level := field.level_at(p)
				if not is_finite(level): continue
				var before := clear(p,level,1)
				var after := clear(p,level,65)
				cells.append({"x":x,"z":z,"level":level,"before":before,"after":after})
		rows.append({"rect":str(rect),"cells":cells})
	FileAccess.open(OUT.path_join("clearance.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	# Keep the real production sampler and trigger payload for repeatable actor
	# traversals. No synthetic water box or constant-height sampler is substituted.
	var skin := WaterSurfaceBuilder.new().compute_chunk(water,Vector2i(-3,1),region,field)
	var values: Dictionary = {}
	var sampler: WaterSampler = skin.sampler
	for property: Dictionary in sampler.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: values[property.name] = sampler.get(property.name)
	FileAccess.open(OUT.path_join("water.bin"),FileAccess.WRITE).store_var({"sampler":values,"triggers":skin.triggers,"arrays":skin.arrays})
	print("BANK_TRAVERSAL surveyed ",rows.size()," bends; froze production water")
	quit()

func clear(p: Vector2, level: float, mask: int) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = mask
	# Production buoyancy settles near 75% of the 1.4 m body span below water.
	query.transform.origin = Vector3(p.x,level-1.05+1.122,p.y)
	query.margin = .02
	return space.intersect_shape(query,1).is_empty()
