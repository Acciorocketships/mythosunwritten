extends RefCounted
## Original Meadow rocks with the restored grass top-layer material.
## Placement lives in CliffSlopeField; meshes are prepared on the main thread.
## Loaded from the source packs; ground rocks collide with the catalog hulls.
const ANGRY := "res://assets/ANGRY MESH/Models/Stylized_Pack_-_Meadow_Environment/Rocks/Rocks_-_Summer/"
const PIECES := {
"angry_01": [ANGRY + "P_Rock_01_Summer.glb", Vector3(5.785935,2.9450228,5.4705315)],
"angry_02": [ANGRY + "P_Rock_02_Summer.glb", Vector3(5.3378124,2.1148965,4.9138412)],
"angry_03": [ANGRY + "P_Rock_03_Summer.glb", Vector3(4.479021,2.577344,3.7162728)],
"angry_04": [ANGRY + "P_Rock_04_Summer.glb", Vector3(3.585957,2.315596,3.0094337)],
"angry_05": [ANGRY + "P_Rock_05_Summer.glb", Vector3(2.835713,1.6161067,2.6579242)],
"angry_06": [ANGRY + "P_Rock_06_Summer.glb", Vector3(1.2350836,0.5296162,1.2317243)],
"angry_07": [ANGRY + "P_Rock_07_Summer.glb", Vector3(1.1326816,0.6913262,0.932442)],
"angry_08": [ANGRY + "P_Rock_08_Summer.glb", Vector3(0.83282745,0.3381967,0.86528623)],
"angry_09": [ANGRY + "P_Rock_09_Summer.glb", Vector3(0.85687697,0.4155087,0.81557345)],
"angry_10": [ANGRY + "P_Rock_10_Summer.glb", Vector3(0.78725004,0.3213305,0.63244516)],
"angry_11": [ANGRY + "P_Rock_11_Summer.glb", Vector3(0.53534544,0.28275135,0.5235691)],
"angry_12": [ANGRY + "P_Rock_12_Summer.glb", Vector3(0.3468631,0.38919207,0.4081958)],
"face_meadow_01": [ANGRY + "P_Rock_01_Summer.glb", Vector3(5.785935,2.9450228,5.4705315)],
"face_meadow_02": [ANGRY + "P_Rock_02_Summer.glb", Vector3(5.3378124,2.1148965,4.9138412)],
"face_meadow_03": [ANGRY + "P_Rock_03_Summer.glb", Vector3(4.479021,2.577344,3.7162728)],
"face_meadow_04": [ANGRY + "P_Rock_04_Summer.glb", Vector3(3.585957,2.315596,3.0094337)],
"face_meadow_05": [ANGRY + "P_Rock_05_Summer.glb", Vector3(2.835713,1.6161067,2.6579242)],
}
static var _pieces: Dictionary = {}
## Catalog collision of each colliding (angry_*) piece. Held here: the visual
## resource it comes from had no other owner, so every rocky chunk reloaded it
## from disk on the main thread (8-27 ms an integration step).
static var _collisions: Dictionary = {}
const STYLE = preload("res://scripts/terrain/field/CliffRockStyle.gd")


static func prepare() -> void:
	if not _pieces.is_empty():
		return
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())

	for name: String in PIECES:
		var root := (load(PIECES[name][0]) as PackedScene).instantiate()
		var instance := root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var local := Transform3D.IDENTITY
		var node: Node = instance
		while node != root:
			local = (node as Node3D).transform * local
			node = node.get_parent()
		var box: AABB = local * instance.mesh.get_aabb()
		# Pivot at the centre of the rock.
		local = Transform3D(Basis(), -box.get_center()) * local
		var material=preload("res://scripts/terrain/field/MeadowRockMaterial.gd").make(int(name.right(2)))
		material.set_shader_parameter("slope_attachment",true)
		var mesh:Mesh=instance.mesh
		if name.begins_with("face_"):
			mesh=_with_lods(_buried_ends(mesh,local,box.size));local=Transform3D.IDENTITY
		_pieces[name] = [mesh, local, material]
		if name.begins_with("angry_"):
			var visual := load("res://terrain/environment/visuals/meadow/rock_%s.res" % name.right(2)) as EnvironmentVisual
			_collisions[name] = visual.collisions.duplicate()
		root.free()


## Rocks are batched per piece AND per ROCK_TILE world square: one chunk-wide
## batch always touched the player's 3x3 chunks, so the GPU drew every rock
## of every chunk at full detail, behind the camera too (October 6: ~5 M
## triangles a frame). Small tiles let the renderer cull them and pick each
## tile's mesh LOD by distance.
const ROCK_TILE := 32.0
## Rocks no larger than this (the Meadow 06-12 pebbles) cast no shadow and fade
## out past SMALL_ROCK_RANGE.
const SMALL_ROCK_SIZE := 1.3
const SMALL_ROCK_RANGE := 70.0
const SMALL_ROCK_FADE := 10.0

## One MultiMesh per piece and tile. Each entry carries its world transform,
## the slope point and normal under it, the skirt's mound rise there, and that
## surface's rock exposure and moss grade.
static func build(entries: Dictionary, seed_value: int) -> Node3D:
	var steps := build_steps(entries, seed_value)
	for step: Callable in steps.steps:
		step.call()
	return steps.root


## build as main-thread steps: one per tile batch and one per COLLISION_STEP
## rocks of collision, so a rocky chunk spreads over frames (built in one
## step it was a 10 ms integration frame). Run in order they build build().
const COLLISION_STEP := 64

static func build_steps(entries: Dictionary, seed_value: int) -> Dictionary:
	prepare()
	var root := Node3D.new()
	root.name = "CliffSlopeRocks"
	var steps: Array[Callable] = []
	for name: String in entries:
		# Study `stamp`: face rocks live in the slope solid, not as meshes.
		if STYLE.sheet_study == "stamp" and name.begins_with("face_"):
			continue
		var tiles: Dictionary = {}
		for rock: Dictionary in entries[name]:
			var origin: Vector3 = (rock.transform as Transform3D).origin
			var key := Vector2i(floori(origin.x / ROCK_TILE), floori(origin.z / ROCK_TILE))
			if not tiles.has(key):
				tiles[key] = []
			tiles[key].append(rock)
		var keys: Array = tiles.keys()
		keys.sort()
		for key: Vector2i in keys:
			var rocks: Array = tiles[key]
			steps.append(func() -> void: root.add_child(_batch(name, rocks, seed_value)))
	_add_collision_steps(root, entries, steps)
	return {"root": root, "steps": steps}


static func _batch(name: String, rocks: Array, seed_value: int) -> MultiMeshInstance3D:
	var piece: Array = _pieces[name]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = piece[0]
	mm.instance_count = rocks.size()
	for i in rocks.size():
		var t: Transform3D = rocks[i].transform
		mm.set_instance_transform(i, t * (piece[1] as Transform3D))
		# The surface the rock is set into (meadow_rock.gdshader): its lawn
		# tint and rock exposure, its plane and moss grade. The rock's
		# base takes that surface's own colour, bare stone or lawn. The
		# tint is clamped as the sheet's and terrain's 8-bit vertex tints are.
		var tint: Color = rocks[i].tint if rocks[i].has("tint") \
			else BiomeRegistry.ground_tint_at(t.origin, seed_value).clamp()
		mm.set_instance_color(i, Color(tint.r, tint.g, tint.b, float(rocks[i].get("exposure", 0.0))))
		# The contact plane: the surface under the rock, lifted to its
		# skirt's mound top, where the rock actually meets the ground.
		var normal: Vector3 = rocks[i].normal
		var contact: float = normal.dot(rocks[i].point) + float(rocks[i].get("contact_rise", 0.0)) * normal.y
		mm.set_instance_custom_data(i, Color(normal.x, normal.z, contact, float(rocks[i].get("grade", 1.0 - normal.y))))
	var node := MultiMeshInstance3D.new()
	node.name = name
	node.multimesh = mm
	node.material_override = piece[2]
	node.add_to_group("tactical_solid_earth", true)
	var size: Vector3 = PIECES[name][1]
	if maxf(size.x, maxf(size.y, size.z)) <= SMALL_ROCK_SIZE:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = SMALL_ROCK_RANGE
		node.visibility_range_end_margin = SMALL_ROCK_FADE
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return node


## `mesh` with LODs. _buried_ends rebuilds the five largest rocks from their
## arrays, which drops the importer's LODs, so they drew full detail at any
## distance; Godot's own importer simplification restores them (the same
## meshoptimizer pass and normal merge angle as the GLB import).
static func _with_lods(mesh: ArrayMesh) -> ArrayMesh:
	var importer := ImporterMesh.new()
	for surface in mesh.get_surface_count():
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(surface), [], {},
			mesh.surface_get_material(surface))
	importer.generate_lods(60.0, 25.0, [])
	return importer.get_mesh()


## Ground rocks collide like the same Meadow rocks placed as ambient dressing
## (owner, September 27: their ground skirt collides, so must the rock). The
## catalog hull sits on the rock's base; these pieces pivot at their centre.
static func _add_collision_steps(root: Node3D, entries: Dictionary, steps: Array[Callable]) -> void:
	var colliding: Array = []   # [name, rock]
	for name: String in entries:
		if name.begins_with("angry_"):
			for rock: Dictionary in entries[name]:
				colliding.append([name, rock])
	if colliding.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "CliffSlopeRockCollision"
	steps.append(func() -> void: root.add_child(body))
	for first in range(0, colliding.size(), COLLISION_STEP):
		steps.append(func() -> void:
			for index in range(first, mini(first + COLLISION_STEP, colliding.size())):
				var name: String = colliding[index][0]
				var rock: Dictionary = colliding[index][1]
				var lift := Transform3D(Basis(), Vector3(0, -0.5 * (PIECES[name][1] as Vector3).y, 0))
				for piece: EnvironmentCollisionPiece in _collisions[name]:
					var shape := CollisionShape3D.new()
					shape.shape = piece.shape
					shape.transform = (rock.transform as Transform3D) * lift * piece.local_transform
					body.add_child(shape))

## Only the hidden end bands tuck into the backing. The visible middle keeps
## the original Meadow vertices; there is no whole-body bend or width taper.
static func _buried_ends(source:Mesh,pose:Transform3D,bounds:Vector3)->ArrayMesh:
	var result:=ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays:=source.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			var p:Vector3=pose*vertices[i];var n:Vector3=pose.basis.inverse().transposed()*normals[i]
			var u:=absf(p.y)/bounds.y
			var t:=clampf((u-.28)/.14,0.,1.)
			var derivative:=0.0 if u<=.28 or u>=.42 else 6.*t*(1.-t)/.14
			var dz:=-1.5*bounds.z*derivative*signf(p.y)/bounds.y
			p.z-=1.5*bounds.z*smoothstep(.28,.42,u)
			vertices[i]=p;normals[i]=Vector3(n.x,n.y-dz*n.z,n.z).normalized()
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result


## STUDY (September 25 rethink): front relief of a face piece in its own
## frame, rasterised from the mesh: [lo, cell, nx, ny, depths] with the
## largest z at each (x, y), -INF where the rock does not cover. Every edge
## recedes (3 local units over the outer 22%), so a stamp sinks into the
## slope all round and only its middle stands proud.
static var _depth: Dictionary = {}
static var _depth_lock := Mutex.new() # chunk tails run on several pool threads
static func depth_map(name: String) -> Array:
	_depth_lock.lock()
	var known: Variant = _depth.get(name)
	_depth_lock.unlock()
	if known != null:
		return known
	prepare()
	var piece: Array = _pieces[name]
	var mesh: Mesh = piece[0]
	var pose: Transform3D = piece[1]
	var box: AABB = pose * mesh.get_aabb()
	var nx := 72
	var ny := 44
	var lo := Vector2(box.position.x, box.position.y)
	var cell := Vector2(box.size.x / (nx - 1), box.size.y / (ny - 1))
	var depths := PackedFloat32Array()
	depths.resize(nx * ny)
	depths.fill(-INF)
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index = arrays[Mesh.ARRAY_INDEX]
		var indexed: bool = index != null and (index as PackedInt32Array).size() > 0
		var count: int = (index as PackedInt32Array).size() / 3 if indexed else v.size() / 3
		for t in count:
			var a: Vector3 = pose * v[index[3 * t] if indexed else 3 * t]
			var b: Vector3 = pose * v[index[3 * t + 1] if indexed else 3 * t + 1]
			var c: Vector3 = pose * v[index[3 * t + 2] if indexed else 3 * t + 2]
			var a2 := (Vector2(a.x, a.y) - lo) / cell
			var b2 := (Vector2(b.x, b.y) - lo) / cell
			var c2 := (Vector2(c.x, c.y) - lo) / cell
			var den := (b2.y - c2.y) * (a2.x - c2.x) + (c2.x - b2.x) * (a2.y - c2.y)
			if absf(den) < 1e-9:
				continue
			for j in range(maxi(0, ceili(minf(a2.y, minf(b2.y, c2.y)))), mini(ny - 1, floori(maxf(a2.y, maxf(b2.y, c2.y)))) + 1):
				for i in range(maxi(0, ceili(minf(a2.x, minf(b2.x, c2.x)))), mini(nx - 1, floori(maxf(a2.x, maxf(b2.x, c2.x)))) + 1):
					var l1 := ((b2.y - c2.y) * (i - c2.x) + (c2.x - b2.x) * (j - c2.y)) / den
					var l2 := ((c2.y - a2.y) * (i - c2.x) + (a2.x - c2.x) * (j - c2.y)) / den
					var l3 := 1.0 - l1 - l2
					if l1 < -1e-4 or l2 < -1e-4 or l3 < -1e-4:
						continue
					depths[j * nx + i] = maxf(depths[j * nx + i], l1 * a.z + l2 * b.z + l3 * c.z)
	for j in ny:
		for i in nx:
			var edge := minf(float(mini(i, nx - 1 - i)) / (nx * .22), float(mini(j, ny - 1 - j)) / (ny * .22))
			depths[j * nx + i] -= 3.0 * (1.0 - smoothstep(0.0, 1.0, edge))
	var map := [lo, cell, nx, ny, depths]
	_depth_lock.lock()
	_depth[name] = map
	_depth_lock.unlock()
	return map


## Bilinear relief at local (x, y); -INF off the rock.
static func depth_at(map: Array, p: Vector2) -> float:
	var g: Vector2 = (p - map[0]) / map[1]
	var nx: int = map[2]
	var i := floori(g.x)
	var j := floori(g.y)
	if i < 0 or j < 0 or i >= nx - 1 or j >= int(map[3]) - 1:
		return -INF
	var d: PackedFloat32Array = map[4]
	var a := d[j * nx + i]
	var b := d[j * nx + i + 1]
	var c := d[(j + 1) * nx + i]
	var e := d[(j + 1) * nx + i + 1]
	if is_inf(a) or is_inf(b) or is_inf(c) or is_inf(e):
		return -INF
	var f := g - Vector2(i, j)
	return lerpf(lerpf(a, b, f.x), lerpf(c, e, f.x), f.y)
