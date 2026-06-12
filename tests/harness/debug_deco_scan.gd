extends SceneTree
## Headless audit for stale decorations: foliage whose host tile was replaced
## (e.g. a cliff grew over the ground tile a tree stood on) or removed.
## Reports, for every displaceable decoration piece:
##   BURIED  — a cliff tile covers the deco's footprint and its plateau top is
##             above the deco origin (the tree pokes out of the plateau).
##   ORPHAN  — no walkable tile directly under the deco origin.
##
## Run with: godot --headless --path . -s res://tests/harness/debug_deco_scan.gd

const SEEDS: Array[int] = [11, 22, 33, 44, 55, 66, 77, 88]
const DECO_TAGS: Array[String] = ["tree", "bush", "grass", "rock"]


func _init() -> void:
	_run()  # async: resumes once the tree is processing frames


func _run() -> void:
	# Nodes only enter the active tree (making global_position usable) once
	# the main loop starts — driving generation straight from _init() leaves
	# the player position stuck at the origin and silently turns every walk
	# into a no-op.
	await process_frame
	for s in SEEDS:
		await _run_seed(s)
	quit()


func _run_seed(seed_value: int) -> void:
	seed(seed_value)
	var Generator: Script = load("res://scripts/terrain/TerrainGenerator.gd")
	var gen: Variant = Generator.new()
	gen.player = Node3D.new()
	gen.terrain_parent = Node3D.new()
	root.add_child(gen.player)
	root.add_child(gen.terrain_parent)
	await process_frame
	gen._ready()

	var angle: float = 0.0
	var radius: float = 0.0
	while radius < 420.0:
		angle += 0.05
		radius += 0.55
		gen.player.global_position = Vector3(cos(angle), 0.0, sin(angle)) * radius
		for i in range(4):
			gen.load_terrain()
	# Second slow orbit at the outer band: deco sockets are deferred behind
	# structural work (DECO_PRIORITY_PENALTY), so terrain the spiral swept
	# past still holds its queued decorations — give them time to fill like
	# a player lingering in the area would.
	angle = 0.0
	while angle < TAU:
		angle += 0.02
		gen.player.global_position = Vector3(cos(angle), 0.0, sin(angle)) * 250.0
		for i in range(4):
			gen.load_terrain()

	_scan(gen, seed_value)

	root.remove_child(gen.player)
	root.remove_child(gen.terrain_parent)
	gen.player.free()
	gen.terrain_parent.free()
	gen.free()
	# Let queue_free'd piece roots actually free between seeds.
	await process_frame


func _scan(gen: Variant, seed_value: int) -> void:
	var deco_total: int = 0
	var buried: int = 0
	var orphans: int = 0
	for module in gen.terrain_index.all_modules.keys():
		if not (module is TerrainModuleInstance):
			continue
		var piece: TerrainModuleInstance = module
		var deco_tag: String = ""
		for tag in DECO_TAGS:
			if piece.def.tags.has(tag):
				deco_tag = tag
				break
		if deco_tag == "":
			continue
		deco_total += 1
		var o: Vector3 = piece.transform.origin

		# Any cliff tile whose 24x24 footprint covers this deco and whose
		# walkable top sits above the deco origin?
		var column: AABB = AABB(o + Vector3(-0.1, -1.0, -0.1), Vector3(0.2, 30.0, 0.2))
		var covering_cliff: TerrainModuleInstance = null
		var support_found: bool = false
		for hit in gen.terrain_index.query_box(column):
			if not (hit is TerrainModuleInstance) or hit == piece:
				continue
			var other: TerrainModuleInstance = hit
			var delta: Vector3 = o - other.transform.origin
			if absf(delta.x) > 12.0 or absf(delta.z) > 12.0:
				continue
			if other.def.tags.has("cliff") and other.transform.origin.y > o.y + 0.2:
				covering_cliff = other
			# Walkable support directly below (ground/level/cliff top near deco base).
			if other.transform.origin.y <= o.y + 0.2 and (
				other.def.tags.has("ground") or other.def.tags.has("level")
				or other.def.tags.has("cliff") or other.def.tags.has("hill")
			):
				support_found = true
		if covering_cliff != null:
			buried += 1
			print("[seed %d] BURIED %s at %s under cliff %s at %s" % [
				seed_value, deco_tag, str(o),
				str(covering_cliff.def.tags.tags), str(covering_cliff.transform.origin)
			])
		elif not support_found:
			orphans += 1
			print("[seed %d] ORPHAN %s at %s (no tile below)" % [seed_value, deco_tag, str(o)])
	print("[seed %d] deco_total=%d buried=%d orphans=%d" % [seed_value, deco_total, buried, orphans])

	# Distribution stats answering "does deco density depend on origin
	# distance?" and "do cliff/level tops get deco?": decorations and walkable
	# tiles bucketed by origin distance band and by supporting surface family.
	var deco_by_band: Dictionary = {}
	var tiles_by_band: Dictionary = {}
	var deco_by_family: Dictionary = {}
	var tiles_by_family: Dictionary = {}
	for module in gen.terrain_index.all_modules.keys():
		if not (module is TerrainModuleInstance):
			continue
		var piece: TerrainModuleInstance = module
		var o: Vector3 = piece.transform.origin
		var band: int = int(Vector2(o.x, o.z).length() / 100.0)
		var is_deco: bool = false
		for tag in DECO_TAGS:
			if piece.def.tags.has(tag):
				is_deco = true
				break
		if is_deco:
			deco_by_band[band] = deco_by_band.get(band, 0) + 1
			deco_by_family[_support_family(gen, piece)] = (
				deco_by_family.get(_support_family(gen, piece), 0) + 1
			)
		elif (
			piece.def.tags.has("ground-plain") or piece.def.tags.has("level")
			or piece.def.tags.has("cliff")
		):
			tiles_by_band[band] = tiles_by_band.get(band, 0) + 1
			for family in ["ground-plain", "level", "cliff"]:
				if piece.def.tags.has(family):
					tiles_by_family[family] = tiles_by_family.get(family, 0) + 1
					break
	print("[seed %d] deco_by_band=%s tiles_by_band=%s" % [
		seed_value, str(deco_by_band), str(tiles_by_band)
	])
	# Deco-capable sockets still waiting in the queue, by band: distinguishes
	# "rolls failed / never enqueued" (no queued sockets, no decos) from
	# "still pending" (queued sockets waiting for the player to come close).
	var queued_deco_by_band: Dictionary = {}
	for entry in gen.queue.heap:
		if not (entry is Dictionary):
			continue
		var item: Variant = entry.get("item", null)
		if not (item is TerrainModuleSocket):
			continue
		var queued_socket: TerrainModuleSocket = item
		if not gen._socket_can_spawn_point(queued_socket.piece, queued_socket.socket_name):
			continue
		var socket_pos: Vector3 = queued_socket.get_socket_position()
		var socket_band: int = int(Vector2(socket_pos.x, socket_pos.z).length() / 100.0)
		queued_deco_by_band[socket_band] = queued_deco_by_band.get(socket_band, 0) + 1
	print("[seed %d] queued_deco_by_band=%s" % [seed_value, str(queued_deco_by_band)])
	print("[seed %d] deco_by_support=%s tiles_by_family=%s" % [
		seed_value, str(deco_by_family), str(tiles_by_family)
	])


## Which surface family the deco stands on (by the tile directly below it).
func _support_family(gen: Variant, deco: TerrainModuleInstance) -> String:
	var o: Vector3 = deco.transform.origin
	var box: AABB = AABB(o + Vector3(-0.1, -1.5, -0.1), Vector3(0.2, 1.6, 0.2))
	var best: String = "none"
	var best_y: float = -INF
	for hit in gen.terrain_index.query_box(box):
		if not (hit is TerrainModuleInstance) or hit == deco:
			continue
		var other: TerrainModuleInstance = hit
		var delta: Vector3 = o - other.transform.origin
		if absf(delta.x) > 12.0 or absf(delta.z) > 12.0:
			continue
		if other.transform.origin.y > o.y + 0.2 or other.transform.origin.y < best_y:
			continue
		for family in ["level", "cliff", "hill", "bank", "ground-plain"]:
			if other.def.tags.has(family):
				best = family
				best_y = other.transform.origin.y
				break
	return best
