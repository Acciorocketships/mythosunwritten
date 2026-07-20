@tool
extends SceneTree

## Deterministic editor-side importer for source-pack visuals. Runtime code is
## intentionally unaware of every source path named by the manifests.
const TOOL_VERSION := 10
const DESCRIPTOR_DIR := "res://terrain/environment/catalog/descriptors"
const INDEX_PATH := "res://terrain/environment/catalog/index.tres"
const MANIFEST_DIR := "res://tools/environment_bake/manifests"
const RIGID_NATURE_TAGS: Array[String] = ["tree", "rock", "deadwood"]

var _texture_cache: Dictionary = {}
var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifests := _requested_manifests()
	if manifests.is_empty():
		_fail("Usage: --manifest <res://...json> (repeatable)")
		quit(1)
		return
	for manifest_path: String in manifests:
		_bake_manifest(manifest_path)
		if _failed:
			quit(1)
			return
	_prune_unmanifested_descriptors()
	if _failed:
		quit(1)
		return
	_refresh_index()
	if _failed:
		quit(1)
		return
	_prune_generated_orphans()
	print("Environment bake complete: %d manifest(s)" % manifests.size())
	quit(0)

func _requested_manifests() -> Array[String]:
	var out: Array[String] = []
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "--manifest" and i + 1 < args.size():
			out.append(args[i + 1])
			i += 2
			continue
		i += 1
	return out

func _bake_manifest(path: String) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_fail("Invalid bake manifest: %s" % path)
		return
	var manifest: Dictionary = parsed
	var pack := String(manifest.get("pack", ""))
	var license_label := String(manifest.get("license", ""))
	var default_scale = manifest.get("default_scale", [1.0, 1.0, 1.0])
	var entries: Array = manifest.get("assets", [])
	if pack.is_empty() or entries.is_empty():
		_fail("Manifest %s requires pack and assets" % path)
		return
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", "")))
	var provenance: Array = []
	for value in entries:
		if not value is Dictionary:
			_fail("Manifest %s contains a non-dictionary asset" % path)
			return
		var entry: Dictionary = value
		var record := _bake_asset(pack, license_label, entry, default_scale)
		if _failed:
			return
		provenance.append(record)
	var provenance_path := "res://tools/environment_bake/provenance/%s.json" % _slug(pack)
	var file := FileAccess.open(provenance_path, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write provenance: %s" % provenance_path)
		return
	file.store_string(JSON.stringify({
		"tool_version": TOOL_VERSION,
		"pack": pack,
		"license": license_label,
		"assets": provenance,
	}, "  ", true))

func _bake_asset(pack: String, license_label: String, entry: Dictionary,
		default_scale: Variant) -> Dictionary:
	var asset_id := String(entry.get("id", ""))
	var source_path := String(entry.get("source", ""))
	if asset_id.is_empty() or not source_path.begins_with("res://"):
		_fail("Bake entry requires a stable id and res:// source path")
		return {}
	_validate_collision_policy(asset_id, entry)
	if _failed:
		return {}
	var packed := load(source_path) as PackedScene
	if packed == null:
		_fail("Source is not an imported scene: %s" % source_path)
		return {}
	var root := packed.instantiate()
	var scale := _vector3(entry.get("scale", default_scale), Vector3.ONE)
	var pivot := _vector3(entry.get("pivot", [0.0, 0.0, 0.0]), Vector3.ZERO)
	var correction := Transform3D(Basis.IDENTITY.scaled(scale), -pivot)
	var supports_color := bool(entry.get("supports_instance_color", false))
	var material_tint := _color(entry.get("material_tint", [1.0, 1.0, 1.0, 1.0]))
	var green_hue := float(entry.get("green_hue", -1.0))
	if green_hue != -1.0 and (green_hue < 0.0 or green_hue > 1.0):
		_fail("green_hue must be absent or in [0,1]: %s" % asset_id)
		root.free()
		return {}
	var pieces: Array[EnvironmentVisualPiece] = []
	var bounds := AABB()
	var has_bounds := false
	var stack: Array[Node] = [root]
	var piece_index := 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local := correction * _relative_transform(mesh_instance, root)
		var baked_mesh := _bake_mesh(mesh_instance.mesh, pack, asset_id, piece_index,
			supports_color, material_tint, green_hue)
		if baked_mesh == null:
			root.free()
			return {}
		var piece := EnvironmentVisualPiece.new()
		piece.mesh = baked_mesh
		piece.local_transform = local
		pieces.append(piece)
		var piece_bounds: AABB = local * baked_mesh.get_aabb()
		bounds = piece_bounds if not has_bounds else bounds.merge(piece_bounds)
		has_bounds = true
		piece_index += 1
	root.free()
	if pieces.is_empty():
		_fail("Source contains no MeshInstance3D: %s" % source_path)
		return {}
	var collisions := _bake_collisions(pack, asset_id, entry, pieces, correction)
	if _failed:
		return {}
	var slug := _slug(asset_id)
	var visual := EnvironmentVisual.new()
	visual.pieces = pieces
	visual.collisions = collisions
	var visual_path := "res://terrain/environment/visuals/%s/%s.tres" % [_slug(pack), slug]
	_ensure_parent(visual_path)
	if ResourceSaver.save(visual, visual_path) != OK:
		_fail("Cannot save environment visual: %s" % visual_path)
		return {}
	var descriptor := EnvironmentAssetDescriptor.new()
	descriptor.id = StringName(asset_id)
	descriptor.visual_path = visual_path
	for tag_value in entry.get("tags", []):
		descriptor.tags.append(StringName(String(tag_value)))
	descriptor.tags.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	descriptor.measured_aabb = bounds
	descriptor.collision_piece_count = collisions.size()
	descriptor.tint_group = StringName(String(entry.get("tint_group", "identity")))
	descriptor.supports_instance_color = supports_color
	descriptor.provenance_id = StringName("%s:%s" % [pack, asset_id])
	var descriptor_path := "%s/%s.tres" % [DESCRIPTOR_DIR, slug]
	_ensure_parent(descriptor_path)
	if ResourceSaver.save(descriptor, descriptor_path) != OK:
		_fail("Cannot save environment descriptor: %s" % descriptor_path)
		return {}
	for output_path: String in [visual_path, descriptor_path]:
		_validate_dependencies(output_path)
	return {
		"id": asset_id,
		"source": source_path,
		"source_sha256": FileAccess.get_sha256(source_path),
		"descriptor": descriptor_path,
		"visual": visual_path,
		"pack": pack,
		"license": license_label,
		"parameters": entry.duplicate(true),
	}

func _bake_collisions(pack: String, asset_id: String, entry: Dictionary,
		visual_pieces: Array[EnvironmentVisualPiece],
		correction: Transform3D) -> Array[EnvironmentCollisionPiece]:
	var source_path := String(entry.get("collision_source", ""))
	var profile := String(entry.get("collision_profile", ""))
	if not source_path.is_empty() and not profile.is_empty():
		_fail("Asset %s cannot combine collision_source and collision_profile" % asset_id)
		return []
	if not source_path.is_empty():
		return _bake_collision_source(pack, asset_id, source_path, correction)
	match profile:
		"":
			return []
		"convex":
			return _bake_piece_convex_collisions(pack, asset_id, visual_pieces)
		"flat_rock":
			return _bake_flat_rock_collisions(pack, asset_id, entry, visual_pieces)
		"flat_box":
			return _bake_flat_box_collisions(pack, asset_id, entry, visual_pieces)
		"stump_cylinder":
			return _bake_stump_collision(pack, asset_id, visual_pieces)
		"trunk_capsule":
			return _bake_trunk_collision(pack, asset_id, entry, visual_pieces)
		"trunk_capsule_chain":
			return _bake_trunk_capsule_chain(pack, asset_id, entry, visual_pieces)
		"oriented_capsule":
			return _bake_oriented_capsule(pack, asset_id, entry, visual_pieces)
		"oriented_cylinder":
			return _bake_oriented_cylinder(pack, asset_id, entry, visual_pieces)
		_:
			_fail("Unknown collision profile %s for %s" % [profile, asset_id])
			return []

func _validate_collision_policy(asset_id: String, entry: Dictionary) -> void:
	var tags: Array = entry.get("tags", [])
	var is_rigid := false
	for tag: String in RIGID_NATURE_TAGS:
		is_rigid = is_rigid or tags.has(tag)
	var has_collision := not String(entry.get("collision_source", "")).is_empty() \
		or not String(entry.get("collision_profile", "")).is_empty()
	if is_rigid and not has_collision:
		_fail("Rigid nature asset %s requires collision_source or collision_profile" % asset_id)

func _bake_piece_convex_collisions(pack: String, asset_id: String,
		visual_pieces: Array[EnvironmentVisualPiece]) -> Array[EnvironmentCollisionPiece]:
	var out: Array[EnvironmentCollisionPiece] = []
	for piece_index in visual_pieces.size():
		var visual_piece := visual_pieces[piece_index]
		var shape := visual_piece.mesh.create_convex_shape(true, false)
		if shape == null:
			_fail("Could not derive convex collision for %s piece %d" % [asset_id, piece_index])
			return []
		var collision := EnvironmentCollisionPiece.new()
		collision.shape = _save_collision_shape(shape, pack, asset_id, piece_index)
		collision.local_transform = visual_piece.local_transform
		out.append(collision)
	return out

func _bake_flat_rock_collisions(pack: String, asset_id: String, entry: Dictionary,
		visual_pieces: Array[EnvironmentVisualPiece]) -> Array[EnvironmentCollisionPiece]:
	var component_count := maxi(1, int(entry.get("collision_component_count", 1)))
	if component_count > 1 and visual_pieces.size() != 1:
		_fail("Multi-component rock collision expects one visual piece: %s" % asset_id)
		return []
	var out: Array[EnvironmentCollisionPiece] = []
	for visual_piece: EnvironmentVisualPiece in visual_pieces:
		var rigid_meshes := _extract_primary_rigid_meshes(visual_piece.mesh, asset_id,
			component_count)
		if rigid_meshes.size() != component_count:
			_fail("Expected %d rigid rock components for %s, found %d" % [
				component_count, asset_id, rigid_meshes.size()])
			return []
		for rigid_mesh: ArrayMesh in rigid_meshes:
			var shape := rigid_mesh.create_convex_shape(true, false) as ConvexPolygonShape3D
			if shape == null:
				_fail("Could not derive rock collision for %s" % asset_id)
				return []
			_flatten_convex_top(shape,
				_collision_height_limit_local(entry, visual_piece))
			var collision := EnvironmentCollisionPiece.new()
			collision.shape = _save_collision_shape(shape, pack, asset_id, out.size())
			collision.local_transform = visual_piece.local_transform
			out.append(collision)
	return out

func _bake_flat_box_collisions(pack: String, asset_id: String, entry: Dictionary,
		visual_pieces: Array[EnvironmentVisualPiece]) -> Array[EnvironmentCollisionPiece]:
	var out: Array[EnvironmentCollisionPiece] = []
	var footprint_scale := clampf(float(entry.get("collision_footprint", 0.9)), 0.5, 1.0)
	for visual_piece: EnvironmentVisualPiece in visual_pieces:
		var rigid_mesh := _extract_primary_rigid_mesh(visual_piece.mesh, asset_id)
		if rigid_mesh == null:
			return []
		var bounds := rigid_mesh.get_aabb()
		var height := minf(bounds.size.y,
			_collision_height_limit_local(entry, visual_piece))
		var shape := BoxShape3D.new()
		shape.size = Vector3(bounds.size.x * footprint_scale, height,
			bounds.size.z * footprint_scale)
		var centre := Vector3(bounds.get_center().x,
			bounds.position.y + height * 0.5, bounds.get_center().z)
		var collision := EnvironmentCollisionPiece.new()
		collision.shape = _save_collision_shape(shape, pack, asset_id, out.size())
		collision.local_transform = visual_piece.local_transform \
			* Transform3D(Basis.IDENTITY, centre)
		out.append(collision)
	return out

func _bake_stump_collision(pack: String, asset_id: String,
		visual_pieces: Array[EnvironmentVisualPiece]) -> Array[EnvironmentCollisionPiece]:
	if visual_pieces.size() != 1:
		_fail("Stump collision expects one visual piece: %s" % asset_id)
		return []
	var visual_piece := visual_pieces[0]
	# The cut trunk is the largest connected woody component. Selecting it first
	# prevents decorative mushrooms (also brown) from raising or widening the
	# walkable cut, while the single cylinder intentionally ignores root flares.
	var rigid_mesh := _extract_primary_rigid_mesh(visual_piece.mesh, asset_id)
	if rigid_mesh == null:
		return []
	var bounds := rigid_mesh.get_aabb()
	var top_min_y := bounds.end.y - bounds.size.y * 0.28
	var top_bounds := AABB()
	var has_top := false
	for point: Vector3 in _mesh_triangle_vertices(rigid_mesh, asset_id):
		if point.y < top_min_y:
			continue
		var point_bounds := AABB(point, Vector3.ZERO)
		top_bounds = point_bounds if not has_top else top_bounds.merge(point_bounds)
		has_top = true
	if not has_top:
		_fail("Could not find stump cut for %s" % asset_id)
		return []
	var shape := CylinderShape3D.new()
	shape.height = bounds.size.y
	shape.radius = maxf(0.01, minf(top_bounds.size.x, top_bounds.size.z) * 0.5)
	var centre := Vector3(top_bounds.get_center().x, bounds.get_center().y,
		top_bounds.get_center().z)
	var collision := EnvironmentCollisionPiece.new()
	collision.shape = _save_collision_shape(shape, pack, asset_id, 0)
	collision.local_transform = visual_piece.local_transform \
		* Transform3D(Basis.IDENTITY, centre)
	return [collision]

func _bake_trunk_collision(pack: String, asset_id: String, entry: Dictionary,
		visual_pieces: Array[EnvironmentVisualPiece]) -> Array[EnvironmentCollisionPiece]:
	if visual_pieces.size() != 1:
		_fail("Trunk collision expects one visual piece: %s" % asset_id)
		return []
	var visual_piece := visual_pieces[0]
	var non_foliage := _extract_non_foliage_mesh(visual_piece.mesh, asset_id)
	if non_foliage == null:
		return []
	# A canopy branch can have more surface area than the trunk. Collision owns
	# the grounded component instead: whichever wood actually reaches the base.
	var wood_mesh := _extract_grounded_component_mesh(non_foliage, asset_id)
	if wood_mesh == null:
		return []
	var bounds := wood_mesh.get_aabb()
	var height_fraction := clampf(float(entry.get("collision_height_fraction",
		0.28)), 0.2, 0.4)
	var vertices := _mesh_triangle_vertices(wood_mesh, asset_id)
	var bottom_y := bounds.position.y
	var top_y := bounds.position.y + bounds.size.y * height_fraction
	var lower_sample := _cross_section_bounds(vertices,
		bounds.position.y + bounds.size.y * minf(0.1, height_fraction * 0.4))
	var upper_sample := _cross_section_bounds(vertices,
		bounds.position.y + bounds.size.y * maxf(0.14, height_fraction - 0.06))
	var radius := _fitted_trunk_radius(entry, visual_piece, lower_sample,
		upper_sample, top_y - bottom_y, 0.45)
	var lower_centre := Vector3(lower_sample.get_center().x, bottom_y + radius,
		lower_sample.get_center().z)
	var upper_centre := Vector3(upper_sample.get_center().x, top_y - radius,
		upper_sample.get_center().z)
	if upper_centre.y <= lower_centre.y:
		upper_centre.y = lower_centre.y + 0.01
	var axis := upper_centre - lower_centre
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = maxf(axis.length() + radius * 2.0, radius * 2.0)
	var collision := EnvironmentCollisionPiece.new()
	collision.shape = _save_collision_shape(shape, pack, asset_id, 0)
	collision.local_transform = visual_piece.local_transform \
		* Transform3D(_basis_with_y_axis(axis), (lower_centre + upper_centre) * 0.5)
	return [collision]

func _bake_trunk_capsule_chain(pack: String, asset_id: String, entry: Dictionary,
		visual_pieces: Array[EnvironmentVisualPiece]) -> Array[EnvironmentCollisionPiece]:
	if visual_pieces.size() != 1:
		_fail("Trunk capsule chain expects one visual piece: %s" % asset_id)
		return []
	var visual_piece := visual_pieces[0]
	var non_foliage := _extract_non_foliage_mesh(visual_piece.mesh, asset_id)
	if non_foliage == null:
		return []
	var wood_mesh := _extract_grounded_component_mesh(non_foliage, asset_id)
	if wood_mesh == null:
		return []
	var bounds := wood_mesh.get_aabb()
	var vertices := _mesh_triangle_vertices(wood_mesh, asset_id)
	var authored_joints: Array = entry.get("collision_joint_points_m", [])
	var authored_radii: Array = entry.get("collision_segment_radii_m", [])
	if not authored_joints.is_empty() or not authored_radii.is_empty():
		return _bake_authored_capsule_chain(pack, asset_id, visual_piece,
			authored_joints, authored_radii)
	var height_fraction := clampf(float(entry.get("collision_height_fraction",
		0.4)), 0.2, 0.6)
	var capsule_count := clampi(int(entry.get("collision_capsule_count", 3)), 2, 6)
	var radius_span_fraction := clampf(float(entry.get(
		"collision_segment_radius_fraction", 0.4)), 0.25, 0.45)
	var bottom_y := bounds.position.y
	var top_y := bounds.position.y + bounds.size.y * height_fraction
	var base_span := (top_y - bottom_y) / float(capsule_count)
	# Internal axis endpoints are shared verbatim. The outer endpoints start
	# inset from the desired bounds and are refined from their fitted radii.
	var joint_ys: Array[float] = []
	for joint_index in capsule_count + 1:
		if joint_index == 0:
			joint_ys.append(bottom_y + base_span * radius_span_fraction)
		elif joint_index == capsule_count:
			joint_ys.append(top_y - base_span * radius_span_fraction)
		else:
			joint_ys.append(bottom_y + base_span * joint_index)
	var segment_radii: Array[float] = []
	# Two bounded fitting passes place the first/last cap centres one radius
	# inside the requested trunk span while leaving every internal joint fixed.
	for unused in 2:
		var joint_samples: Array[AABB] = []
		for joint_y: float in joint_ys:
			joint_samples.append(_cross_section_bounds(vertices, joint_y))
		segment_radii.clear()
		for capsule_index in capsule_count:
			segment_radii.append(_fitted_trunk_radius(entry, visual_piece,
				joint_samples[capsule_index], joint_samples[capsule_index + 1],
				base_span, radius_span_fraction))
		joint_ys[0] = bottom_y + segment_radii[0]
		joint_ys[capsule_count] = top_y - segment_radii[capsule_count - 1]
	var joint_points: Array[Vector3] = []
	for joint_y: float in joint_ys:
		joint_points.append(_cross_section_median(vertices, joint_y))
	return _build_capsule_chain(pack, asset_id, visual_piece, joint_points,
		segment_radii)

func _bake_authored_capsule_chain(pack: String, asset_id: String,
		visual_piece: EnvironmentVisualPiece, joint_values: Array,
		radius_values: Array) -> Array[EnvironmentCollisionPiece]:
	if joint_values.size() < 3 or joint_values.size() > 7:
		_fail("Authored capsule chain for %s requires 3-7 joint points" % asset_id)
		return []
	if radius_values.size() != joint_values.size() - 1:
		_fail("Authored capsule chain for %s requires one radius per segment" % asset_id)
		return []
	var inverse_visual := visual_piece.local_transform.affine_inverse()
	var joint_points: Array[Vector3] = []
	for joint_index in joint_values.size():
		var joint_value = joint_values[joint_index]
		if not joint_value is Array or joint_value.size() != 3:
			_fail("Invalid capsule-chain joint %d for %s" % [joint_index, asset_id])
			return []
		joint_points.append(inverse_visual * _vector3(joint_value, Vector3.ZERO))
	var world_radius_scale := maxf(
		(visual_piece.local_transform.basis * Vector3.RIGHT).length(),
		(visual_piece.local_transform.basis * Vector3.BACK).length())
	var segment_radii: Array[float] = []
	for radius_index in radius_values.size():
		var world_radius := float(radius_values[radius_index])
		if world_radius <= 0.0:
			_fail("Capsule-chain radius %d for %s must be positive" % [
				radius_index, asset_id])
			return []
		segment_radii.append(world_radius / maxf(world_radius_scale, 0.0001))
	return _build_capsule_chain(pack, asset_id, visual_piece, joint_points,
		segment_radii)

func _build_capsule_chain(pack: String, asset_id: String,
		visual_piece: EnvironmentVisualPiece, joint_points: Array[Vector3],
		segment_radii: Array[float]) -> Array[EnvironmentCollisionPiece]:
	var out: Array[EnvironmentCollisionPiece] = []
	var capsule_count := segment_radii.size()
	for capsule_index in capsule_count:
		var lower_joint := joint_points[capsule_index]
		var upper_joint := joint_points[capsule_index + 1]
		var axis := upper_joint - lower_joint
		if axis.length_squared() < 0.000001:
			_fail("Capsule-chain segment %d for %s has coincident joints" % [
				capsule_index, asset_id])
			return []
		var radius := segment_radii[capsule_index]
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		shape.height = maxf(axis.length() + radius * 2.0, radius * 2.0)
		var collision := EnvironmentCollisionPiece.new()
		collision.shape = _save_collision_shape(shape, pack, asset_id,
			capsule_index)
		collision.local_transform = visual_piece.local_transform \
			* Transform3D(_basis_with_y_axis(axis),
				(lower_joint + upper_joint) * 0.5)
		out.append(collision)
	return out

func _fitted_trunk_radius(entry: Dictionary,
		visual_piece: EnvironmentVisualPiece, lower_sample: AABB,
		upper_sample: AABB, span: float, span_fraction: float) -> float:
	var radius_scale := clampf(float(entry.get("collision_radius_scale", 0.82)),
		0.5, 0.98)
	var radius := minf(_cross_section_radius(lower_sample),
		_cross_section_radius(upper_sample)) * radius_scale
	# A very sparse trunk can expose only narrow diagonal chords. Preserve a
	# usable minimum without ever inheriting canopy width.
	radius = maxf(radius, visual_piece.mesh.get_aabb().size.y * 0.012)
	var max_world_radius := float(entry.get("collision_max_radius", INF))
	if max_world_radius != INF:
		var world_radius_scale := maxf(
			(visual_piece.local_transform.basis * Vector3.RIGHT).length(),
			(visual_piece.local_transform.basis * Vector3.BACK).length())
		radius = minf(radius,
			max_world_radius / maxf(world_radius_scale, 0.0001))
	return clampf(radius, 0.01, span * span_fraction)

func _cross_section_bounds(points: PackedVector3Array, target_y: float) -> AABB:
	# Intersect the actual triangles with the requested plane. The old nearest-
	# vertex approximation jumped between sparse low-poly rings and could pull a
	# leaning trunk capsule toward a branch even though the trunk itself was
	# continuous. Exact edge intersections make the centreline stable by
	# construction, independent of vertex tessellation.
	var intersections := _cross_section_intersections(points, target_y)
	var section_bounds := AABB()
	for point_index in intersections.size():
		var point_bounds := AABB(intersections[point_index], Vector3.ZERO)
		section_bounds = point_bounds if point_index == 0 \
			else section_bounds.merge(point_bounds)
	if intersections.size() >= 3 and section_bounds.size.x > 0.0001 \
			and section_bounds.size.z > 0.0001:
		return section_bounds

	# Degenerate/coplanar source triangles still get a deterministic fallback.
	var distance_keys: Dictionary = {}
	for point: Vector3 in points:
		var distance := absf(point.y - target_y)
		distance_keys[roundi(distance * 100000.0)] = distance
	var distances: Array[float] = []
	for key: int in distance_keys:
		distances.append(float(distance_keys[key]))
	distances.sort()
	var fallback := AABB()
	for distance_limit: float in distances:
		var bounds := AABB()
		var has_bounds := false
		var unique_points: Dictionary = {}
		for point: Vector3 in points:
			if absf(point.y - target_y) > distance_limit + 0.0001:
				continue
			var point_bounds := AABB(point, Vector3.ZERO)
			bounds = point_bounds if not has_bounds else bounds.merge(point_bounds)
			has_bounds = true
			unique_points["%d:%d:%d" % [roundi(point.x * 10000.0),
				roundi(point.y * 10000.0), roundi(point.z * 10000.0)]] = true
		fallback = bounds
		if unique_points.size() >= 4 and bounds.size.x > 0.0001 \
				and bounds.size.z > 0.0001:
			return bounds
	return fallback

func _cross_section_intersections(points: PackedVector3Array,
		target_y: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var seen: Dictionary = {}
	for offset in range(0, points.size() - 2, 3):
		for edge_index in 3:
			var a := points[offset + edge_index]
			var b := points[offset + (edge_index + 1) % 3]
			var a_delta := a.y - target_y
			var b_delta := b.y - target_y
			var intersection := Vector3.ZERO
			var intersects := false
			if absf(a_delta) <= 0.00001:
				intersection = Vector3(a.x, target_y, a.z)
				intersects = true
			elif (a_delta < 0.0 and b_delta > 0.0) \
					or (a_delta > 0.0 and b_delta < 0.0):
				var weight := -a_delta / (b_delta - a_delta)
				intersection = a.lerp(b, weight)
				intersection.y = target_y
				intersects = true
			if not intersects:
				continue
			var key := "%d:%d" % [roundi(intersection.x * 10000.0),
				roundi(intersection.z * 10000.0)]
			if seen.has(key):
				continue
			seen[key] = true
			out.append(intersection)
	return out

func _cross_section_median(points: PackedVector3Array, target_y: float) -> Vector3:
	var intersections := _cross_section_intersections(points, target_y)
	if intersections.is_empty():
		var fallback := _cross_section_bounds(points, target_y).get_center()
		return Vector3(fallback.x, target_y, fallback.z)
	var xs: Array[float] = []
	var zs: Array[float] = []
	for point: Vector3 in intersections:
		xs.append(point.x)
		zs.append(point.z)
	xs.sort()
	zs.sort()
	var middle := xs.size() / 2
	var x := xs[middle]
	var z := zs[middle]
	if xs.size() % 2 == 0:
		x = (xs[middle - 1] + x) * 0.5
		z = (zs[middle - 1] + z) * 0.5
	return Vector3(x, target_y, z)

func _cross_section_radius(bounds: AABB) -> float:
	var narrow := minf(bounds.size.x, bounds.size.z) * 0.5
	var wide := maxf(bounds.size.x, bounds.size.z) * 0.5
	# Some low-poly rings expose only two coplanar vertices. The conservative
	# wide-axis fallback keeps a usable trunk without inheriting branch width.
	return maxf(narrow, wide * 0.22)

func _bake_oriented_capsule(pack: String, asset_id: String, entry: Dictionary,
		visual_pieces: Array[EnvironmentVisualPiece]) -> Array[EnvironmentCollisionPiece]:
	if visual_pieces.size() != 1:
		_fail("Capsule collision expects one visual piece: %s" % asset_id)
		return []
	var visual_piece := visual_pieces[0]
	var rigid_mesh := _extract_primary_rigid_mesh(visual_piece.mesh, asset_id)
	if rigid_mesh == null:
		return []
	var bounds := rigid_mesh.get_aabb()
	var sizes: Array[float] = [bounds.size.x, bounds.size.y, bounds.size.z]
	var longest := 0
	for axis in range(1, 3):
		if sizes[axis] > sizes[longest]:
			longest = axis
	var cross_a := sizes[(longest + 1) % 3]
	var cross_b := sizes[(longest + 2) % 3]
	var radius_fraction := clampf(float(entry.get("collision_radius_fraction", 0.45)),
		0.1, 0.5)
	var cross_radius := minf(cross_a, cross_b) * radius_fraction
	var shape := CapsuleShape3D.new()
	shape.radius = maxf(0.01, cross_radius)
	shape.height = maxf(sizes[longest], shape.radius * 2.0)
	var axis_vector := [Vector3.RIGHT, Vector3.UP, Vector3.BACK][longest] as Vector3
	var collision := EnvironmentCollisionPiece.new()
	collision.shape = _save_collision_shape(shape, pack, asset_id, 0)
	collision.local_transform = visual_piece.local_transform \
		* Transform3D(_basis_with_y_axis(axis_vector), bounds.get_center())
	return [collision]

func _bake_oriented_cylinder(pack: String, asset_id: String, entry: Dictionary,
		visual_pieces: Array[EnvironmentVisualPiece]) -> Array[EnvironmentCollisionPiece]:
	if visual_pieces.size() != 1:
		_fail("Cylinder collision expects one visual piece: %s" % asset_id)
		return []
	var visual_piece := visual_pieces[0]
	var rigid_mesh := _extract_primary_rigid_mesh(visual_piece.mesh, asset_id)
	if rigid_mesh == null:
		return []
	var bounds := rigid_mesh.get_aabb()
	var sizes: Array[float] = [bounds.size.x, bounds.size.y, bounds.size.z]
	var longest := 0
	for axis in range(1, 3):
		if sizes[axis] > sizes[longest]:
			longest = axis
	var cross_a := sizes[(longest + 1) % 3]
	var cross_b := sizes[(longest + 2) % 3]
	var radius_fraction := clampf(float(entry.get("collision_radius_fraction", 0.46)),
		0.1, 0.5)
	var shape := CylinderShape3D.new()
	shape.radius = maxf(0.01, minf(cross_a, cross_b) * radius_fraction)
	shape.height = sizes[longest]
	var axis_vector := [Vector3.RIGHT, Vector3.UP, Vector3.BACK][longest] as Vector3
	var collision := EnvironmentCollisionPiece.new()
	collision.shape = _save_collision_shape(shape, pack, asset_id, 0)
	collision.local_transform = visual_piece.local_transform \
		* Transform3D(_basis_with_y_axis(axis_vector), bounds.get_center())
	return [collision]

func _collision_height_limit_local(entry: Dictionary,
		visual_piece: EnvironmentVisualPiece) -> float:
	var max_world_height := float(entry.get("collision_max_height", INF))
	if max_world_height == INF:
		return INF
	var world_y_scale := (visual_piece.local_transform.basis * Vector3.UP).length()
	return maxf(0.01, max_world_height / maxf(world_y_scale, 0.0001))

func _flatten_convex_top(shape: ConvexPolygonShape3D,
		max_height: float = INF) -> void:
	var points := shape.points
	if points.size() < 4:
		return
	var top_y := -INF
	var bottom_y := INF
	for point: Vector3 in points:
		top_y = maxf(top_y, point.y)
		bottom_y = minf(bottom_y, point.y)
	if max_height != INF and top_y - bottom_y > max_height:
		top_y = bottom_y + max_height
		for index in points.size():
			points[index].y = minf(points[index].y, top_y)
	var band := maxf((top_y - bottom_y) * 0.12, 0.005)
	var top_indices: Array[int] = []
	while top_indices.size() < 3 and band <= (top_y - bottom_y) * 0.5 + 0.001:
		top_indices.clear()
		for index in points.size():
			if points[index].y >= top_y - band:
				top_indices.append(index)
		band *= 1.5
	for index: int in top_indices:
		points[index].y = top_y
	shape.points = points

func _basis_with_y_axis(y_axis: Vector3) -> Basis:
	var y := y_axis.normalized()
	var x := Vector3.UP.cross(y)
	if x.length_squared() < 0.001:
		x = Vector3.RIGHT
	else:
		x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)

func _extract_primary_rigid_mesh(source: ArrayMesh, asset_id: String) -> ArrayMesh:
	var meshes := _extract_primary_rigid_meshes(source, asset_id, 1)
	return meshes[0] if not meshes.is_empty() else null

func _extract_primary_rigid_meshes(source: ArrayMesh, asset_id: String,
		count: int) -> Array[ArrayMesh]:
	var non_foliage := _extract_non_foliage_mesh(source, asset_id)
	if non_foliage == null:
		return []
	return _extract_largest_component_meshes(non_foliage, asset_id, count)

func _extract_non_foliage_mesh(source: ArrayMesh, asset_id: String) -> ArrayMesh:
	var wood_vertices := PackedVector3Array()
	for surface_index in source.get_surface_count():
		if source.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			_fail("Woody collision requires triangle surfaces: %s" % asset_id)
			return null
		var arrays := source.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
			if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var texture := _material_albedo_texture(source.surface_get_material(surface_index))
		var image: Image = null
		if texture != null and uvs.size() == vertices.size():
			image = texture.get_image()
			if image != null and image.is_compressed():
				image.decompress()
		var element_count := indices.size() if not indices.is_empty() else vertices.size()
		for element_index in range(0, element_count - 2, 3):
			var triangle := PackedInt32Array([
				indices[element_index] if not indices.is_empty() else element_index,
				indices[element_index + 1] if not indices.is_empty() else element_index + 1,
				indices[element_index + 2] if not indices.is_empty() else element_index + 2,
			])
			if image != null and not image.is_empty() \
				and _triangle_is_foliage(uvs, triangle, image):
				continue
			for vertex_index: int in triangle:
				wood_vertices.append(vertices[vertex_index])
	if wood_vertices.size() < 12:
		_fail("Could not isolate enough woody geometry for %s" % asset_id)
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = wood_vertices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

func _extract_largest_component_mesh(source: ArrayMesh, asset_id: String) -> ArrayMesh:
	var meshes := _extract_largest_component_meshes(source, asset_id, 1)
	return meshes[0] if not meshes.is_empty() else null

func _extract_largest_component_meshes(source: ArrayMesh, asset_id: String,
		count: int) -> Array[ArrayMesh]:
	var records := _extract_component_records(source, asset_id)
	var out: Array[ArrayMesh] = []
	for index in mini(maxi(count, 0), records.size()):
		out.append(records[index]["mesh"] as ArrayMesh)
	return out

func _extract_grounded_component_mesh(source: ArrayMesh, asset_id: String) -> ArrayMesh:
	var records := _extract_component_records(source, asset_id)
	if records.is_empty():
		return null
	var overall_bottom := INF
	var overall_top := -INF
	for record: Dictionary in records:
		var component_bounds: AABB = record["bounds"]
		overall_bottom = minf(overall_bottom, component_bounds.position.y)
		overall_top = maxf(overall_top, component_bounds.end.y)
	var bottom_tolerance := maxf(0.001, (overall_top - overall_bottom) * 0.015)
	var best_record: Dictionary = {}
	for record: Dictionary in records:
		var component_bounds: AABB = record["bounds"]
		if component_bounds.position.y > overall_bottom + bottom_tolerance:
			continue
		if best_record.is_empty():
			best_record = record
			continue
		var best_bounds: AABB = best_record["bounds"]
		if component_bounds.end.y > best_bounds.end.y + 0.0001 \
				or (is_equal_approx(component_bounds.end.y, best_bounds.end.y) \
				and float(record["area"]) > float(best_record["area"])):
			best_record = record
	return best_record["mesh"] as ArrayMesh if not best_record.is_empty() else null

func _extract_component_records(source: ArrayMesh,
		asset_id: String) -> Array[Dictionary]:
	var triangles: Array[PackedVector3Array] = []
	var parent: Array[int] = []
	var rank: Array[int] = []
	var owner_by_point: Dictionary = {}
	var vertices := _mesh_triangle_vertices(source, asset_id)
	if vertices.is_empty():
		return []
	for offset in range(0, vertices.size(), 3):
		var triangle := PackedVector3Array([
			vertices[offset], vertices[offset + 1], vertices[offset + 2]])
		var triangle_index := triangles.size()
		triangles.append(triangle)
		parent.append(triangle_index)
		rank.append(0)
		for point: Vector3 in triangle:
			var key := "%d:%d:%d" % [roundi(point.x * 10000.0),
				roundi(point.y * 10000.0), roundi(point.z * 10000.0)]
			if owner_by_point.has(key):
				_union_components(parent, rank, triangle_index, int(owner_by_point[key]))
			else:
				owner_by_point[key] = triangle_index
	var area_by_root: Dictionary = {}
	var bounds_by_root: Dictionary = {}
	for index in triangles.size():
		var root := _find_component(parent, index)
		var triangle := triangles[index]
		var area := (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).length()
		area_by_root[root] = float(area_by_root.get(root, 0.0)) + area
		var triangle_bounds := AABB(triangle[0], Vector3.ZERO) \
			.expand(triangle[1]).expand(triangle[2])
		bounds_by_root[root] = triangle_bounds if not bounds_by_root.has(root) \
			else (bounds_by_root[root] as AABB).merge(triangle_bounds)
	var vertices_by_root: Dictionary = {}
	for index in triangles.size():
		var root := _find_component(parent, index)
		var component_vertices: PackedVector3Array = vertices_by_root.get(root,
			PackedVector3Array())
		for point: Vector3 in triangles[index]:
			component_vertices.append(point)
		vertices_by_root[root] = component_vertices
	var records: Array[Dictionary] = []
	for root: int in area_by_root:
		var component_vertices: PackedVector3Array = vertices_by_root[root]
		if component_vertices.size() < 12:
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = component_vertices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		records.append({
			"mesh": mesh,
			"area": float(area_by_root[root]),
			"bounds": bounds_by_root[root] as AABB,
		})
	if records.is_empty():
		_fail("Could not isolate rigid geometry for %s" % asset_id)
		return []
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var area_a := float(a["area"])
		var area_b := float(b["area"])
		if not is_equal_approx(area_a, area_b):
			return area_a > area_b
		var centre_a: Vector3 = (a["bounds"] as AABB).get_center()
		var centre_b: Vector3 = (b["bounds"] as AABB).get_center()
		if not is_equal_approx(centre_a.x, centre_b.x):
			return centre_a.x < centre_b.x
		if not is_equal_approx(centre_a.y, centre_b.y):
			return centre_a.y < centre_b.y
		return centre_a.z < centre_b.z)
	return records

func _mesh_triangle_vertices(source: ArrayMesh, asset_id: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	for surface_index in source.get_surface_count():
		if source.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			_fail("Rigid collision requires triangle surfaces: %s" % asset_id)
			return PackedVector3Array()
		var arrays := source.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
			if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			out.append_array(vertices)
		else:
			for index: int in indices:
				out.append(vertices[index])
	return out

func _find_component(parent: Array[int], index: int) -> int:
	var cursor := index
	while parent[cursor] != cursor:
		parent[cursor] = parent[parent[cursor]]
		cursor = parent[cursor]
	return cursor

func _union_components(parent: Array[int], rank: Array[int], a: int, b: int) -> void:
	var root_a := _find_component(parent, a)
	var root_b := _find_component(parent, b)
	if root_a == root_b:
		return
	if rank[root_a] < rank[root_b]:
		parent[root_a] = root_b
	elif rank[root_a] > rank[root_b]:
		parent[root_b] = root_a
	else:
		parent[root_b] = root_a
		rank[root_a] += 1

func _material_albedo_texture(material: Material) -> Texture2D:
	var standard := material as StandardMaterial3D
	if standard != null:
		return standard.albedo_texture
	var shader_material := material as ShaderMaterial
	if shader_material != null:
		return shader_material.get_shader_parameter("albedo_texture") as Texture2D
	return null

func _triangle_is_foliage(uvs: PackedVector2Array, triangle: PackedInt32Array,
		image: Image) -> bool:
	var uv0 := uvs[triangle[0]]
	var uv1 := _unwrap_uv_near(uvs[triangle[1]], uv0)
	var uv2 := _unwrap_uv_near(uvs[triangle[2]], uv0)
	var centroid := (uv0 + uv1 + uv2) / 3.0
	if _is_foliage_color(_sample_wrapped(image, centroid)):
		return true
	var green_vertices := 0
	for vertex_index: int in triangle:
		if _is_foliage_color(_sample_wrapped(image, uvs[vertex_index])):
			green_vertices += 1
	return green_vertices >= 2

func _unwrap_uv_near(uv: Vector2, origin: Vector2) -> Vector2:
	return origin + Vector2(uv.x - origin.x - roundf(uv.x - origin.x),
		uv.y - origin.y - roundf(uv.y - origin.y))

func _sample_wrapped(image: Image, uv: Vector2) -> Color:
	var x := clampi(int(floor(fposmod(uv.x, 1.0) * image.get_width())),
		0, image.get_width() - 1)
	var y := clampi(int(floor(fposmod(uv.y, 1.0) * image.get_height())),
		0, image.get_height() - 1)
	return image.get_pixel(x, y)

func _is_foliage_color(color: Color) -> bool:
	return color.g > color.r * 1.08 and color.g > color.b * 1.08 and color.s > 0.15

func _bake_collision_source(pack: String, asset_id: String,
		source_path: String, correction: Transform3D) -> Array[EnvironmentCollisionPiece]:
	var packed := load(source_path) as PackedScene
	if packed == null:
		_fail("Collision source is not a scene: %s" % source_path)
		return []
	var root := packed.instantiate()
	var nodes: Array[CollisionShape3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var collision := node as CollisionShape3D
		if collision != null and not collision.disabled and collision.shape != null:
			nodes.append(collision)
	nodes.sort_custom(func(a: CollisionShape3D, b: CollisionShape3D) -> bool:
		return String(root.get_path_to(a)) < String(root.get_path_to(b)))
	var out: Array[EnvironmentCollisionPiece] = []
	for piece_index in nodes.size():
		var source := nodes[piece_index]
		var piece := EnvironmentCollisionPiece.new()
		piece.shape = _save_collision_shape(source.shape.duplicate(true), pack, asset_id, piece_index)
		# Authored wrapper shapes lived under the same scaled/pivoted root as
		# their visual. Preserve that composition exactly; applying correction
		# only to the mesh makes otherwise-correct proxies miniature.
		piece.local_transform = correction * _relative_transform(source, root)
		out.append(piece)
	root.free()
	if out.is_empty():
		_fail("Collision source contains no enabled shapes: %s" % source_path)
	return out

func _save_collision_shape(shape: Shape3D, pack: String,
		asset_id: String, piece_index: int) -> Shape3D:
	var path := "res://terrain/environment/collisions/%s/%s_piece_%02d.res" % [
		_slug(pack), _slug(asset_id), piece_index]
	_ensure_parent(path)
	if ResourceSaver.save(shape, path) != OK:
		_fail("Cannot save collision shape: %s" % path)
		return null
	return ResourceLoader.load(path, "Shape3D", ResourceLoader.CACHE_MODE_REPLACE) as Shape3D

func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var out := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null and cursor != root:
		var node_3d := cursor as Node3D
		if node_3d != null:
			out = node_3d.transform * out
		cursor = cursor.get_parent()
	return out

func _bake_mesh(source: Mesh, pack: String, asset_id: String, piece_index: int,
		supports_color: bool, material_tint: Color, green_hue: float) -> ArrayMesh:
	var source_array := source as ArrayMesh
	if source_array == null:
		_fail("Only ArrayMesh source pieces are supported: %s" % asset_id)
		return null
	var mesh := _remap_mesh_green_hue(source_array, green_hue) \
		if green_hue >= 0.0 else source_array.duplicate(true) as ArrayMesh
	if mesh == null:
		_fail("Could not duplicate mesh data for %s" % asset_id)
		return null
	for surface_index in mesh.get_surface_count():
		var material := source_array.surface_get_material(surface_index)
		if material == null:
			continue
		var baked_material := _bake_material(material, pack, asset_id, piece_index,
			surface_index, supports_color, material_tint, green_hue)
		if baked_material == null:
			return null
		mesh.surface_set_material(surface_index, baked_material)
	var mesh_path := "res://terrain/environment/meshes/%s/%s_piece_%02d.res" % [
		_slug(pack), _slug(asset_id), piece_index]
	_ensure_parent(mesh_path)
	if ResourceSaver.save(mesh, mesh_path) != OK:
		_fail("Cannot save mesh: %s" % mesh_path)
		return null
	return load(mesh_path) as ArrayMesh

func _remap_mesh_green_hue(source: ArrayMesh, green_hue: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for blend_index in source.get_blend_shape_count():
		mesh.add_blend_shape(source.get_blend_shape_name(blend_index))
	mesh.blend_shape_mode = source.blend_shape_mode
	for surface_index in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface_index)
		if arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for color_index in colors.size():
				colors[color_index] = _remap_green(colors[color_index], green_hue)
			arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface_index), arrays,
			source.surface_get_blend_shape_arrays(surface_index))
		mesh.surface_set_name(surface_index, source.surface_get_name(surface_index))
	return mesh

func _bake_material(source: Material, pack: String, asset_id: String, piece_index: int,
		surface_index: int, supports_color: bool, material_tint: Color,
		green_hue: float) -> Material:
	var material := source.duplicate(true) as Material
	if supports_color:
		var standard := material as StandardMaterial3D
		if standard == null:
			_fail("Instance-colour asset %s uses unsupported material %s" % [asset_id, source.get_class()])
			return null
		standard.vertex_color_use_as_albedo = true
		standard.albedo_color *= material_tint
	for property: Dictionary in material.get_property_list():
		if int(property.get("type", TYPE_NIL)) != TYPE_OBJECT:
			continue
		var property_name := StringName(property.get("name", ""))
		var texture := material.get(property_name) as Texture2D
		if texture == null:
			continue
		# Palette variants are evaluated in the material so green foliage can
		# change hue without recolouring bark that shares the same atlas.
		var baked_texture := _bake_texture(texture, pack, -1.0)
		if baked_texture == null:
			return null
		material.set(property_name, baked_texture)
	if green_hue >= 0.0:
		var standard := material as StandardMaterial3D
		if standard == null or standard.albedo_texture == null:
			_fail("Palette variant %s requires a standard albedo texture" % asset_id)
			return null
		var variant := ShaderMaterial.new()
		variant.shader = load("res://terrain/environment/materials/palette_variant.gdshader") as Shader
		variant.set_shader_parameter("albedo_texture", standard.albedo_texture)
		variant.set_shader_parameter("green_target", Color.from_hsv(green_hue, 0.72, 1.0))
		material = variant
	var material_path := "res://terrain/environment/materials/%s/%s_piece_%02d_surface_%02d.tres" % [
		_slug(pack), _slug(asset_id), piece_index, surface_index]
	_ensure_parent(material_path)
	if ResourceSaver.save(material, material_path) != OK:
		_fail("Cannot save material: %s" % material_path)
		return null
	return load(material_path) as Material

func _bake_texture(source: Texture2D, pack: String, green_hue: float) -> Texture2D:
	var image := source.get_image()
	if image == null or image.is_empty():
		_fail("Cannot read texture pixels: %s" % source.resource_path)
		return null
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	if green_hue >= 0.0:
		for y in image.get_height():
			for x in image.get_width():
				var color := image.get_pixel(x, y)
				# Palette variants remap foliage-like greens only. Bark, rock,
				# flowers, and neutral texels retain their authored hue.
				image.set_pixel(x, y, _remap_green(color, green_hue))
	var hash: String = image.get_data().hex_encode().sha256_text()
	var key := "%s:%s:%.5f" % [pack, hash, green_hue]
	var cached := _texture_cache.get(key) as Texture2D
	if cached != null:
		return cached
	# ImageTexture is renderer-backed; saving it can retain stale GPU data
	# after an editor-side pixel transform even though get_image() reports the
	# new pixels. PortableCompressedTexture2D serializes the actual image and
	# therefore makes palette variants and source-pack-free exports reliable.
	var texture := PortableCompressedTexture2D.new()
	texture.keep_compressed_buffer = true
	texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	var texture_path := "res://terrain/environment/textures/%s/%s.res" % [_slug(pack), hash.left(20)]
	_ensure_parent(texture_path)
	if ResourceSaver.save(texture, texture_path) != OK:
		_fail("Cannot save texture: %s" % texture_path)
		return null
	var loaded := ResourceLoader.load(texture_path, "Texture2D",
		ResourceLoader.CACHE_MODE_REPLACE) as Texture2D
	_texture_cache[key] = loaded
	return loaded

func _remap_green(color: Color, green_hue: float) -> Color:
	if _is_foliage_color(color):
		return Color.from_hsv(green_hue, color.s, color.v, color.a)
	return color

func _prune_unmanifested_descriptors() -> void:
	var active_paths: Dictionary = {}
	var manifest_directory := DirAccess.open(MANIFEST_DIR)
	if manifest_directory == null:
		_fail("Cannot open environment manifest directory: %s" % MANIFEST_DIR)
		return
	manifest_directory.list_dir_begin()
	var filename := manifest_directory.get_next()
	while not filename.is_empty():
		if not manifest_directory.current_is_dir() and filename.ends_with(".json"):
			var path := MANIFEST_DIR.path_join(filename)
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not parsed is Dictionary:
				_fail("Invalid bake manifest during catalogue prune: %s" % path)
				manifest_directory.list_dir_end()
				return
			for value: Variant in (parsed as Dictionary).get("assets", []):
				if value is Dictionary:
					var asset_id := String((value as Dictionary).get("id", ""))
					if not asset_id.is_empty():
						active_paths["%s/%s.tres" % [DESCRIPTOR_DIR, _slug(asset_id)]] = true
		filename = manifest_directory.get_next()
	manifest_directory.list_dir_end()
	var descriptor_directory := DirAccess.open(DESCRIPTOR_DIR)
	if descriptor_directory == null:
		_fail("Cannot open descriptor directory during catalogue prune: %s" % DESCRIPTOR_DIR)
		return
	descriptor_directory.list_dir_begin()
	filename = descriptor_directory.get_next()
	while not filename.is_empty():
		if not descriptor_directory.current_is_dir() and filename.ends_with(".tres"):
			var path := DESCRIPTOR_DIR.path_join(filename)
			if not active_paths.has(path):
				print("Pruning unmanifested environment descriptor: ", path)
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		filename = descriptor_directory.get_next()
	descriptor_directory.list_dir_end()

func _refresh_index() -> void:
	var directory := DirAccess.open(DESCRIPTOR_DIR)
	if directory == null:
		_fail("Cannot open descriptor directory: %s" % DESCRIPTOR_DIR)
		return
	var paths: Array[String] = []
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and filename.ends_with(".tres"):
			paths.append("%s/%s" % [DESCRIPTOR_DIR, filename])
		filename = directory.get_next()
	directory.list_dir_end()
	var descriptors: Array[EnvironmentAssetDescriptor] = []
	for path: String in paths:
		var descriptor := load(path) as EnvironmentAssetDescriptor
		if descriptor == null:
			_fail("Invalid generated descriptor: %s" % path)
			return
		descriptors.append(descriptor)
	descriptors.sort_custom(func(a: EnvironmentAssetDescriptor, b: EnvironmentAssetDescriptor) -> bool:
		return String(a.id) < String(b.id))
	var index := EnvironmentCatalogIndex.new()
	index.descriptors = descriptors
	if ResourceSaver.save(index, INDEX_PATH) != OK:
		_fail("Cannot save environment catalogue index: %s" % INDEX_PATH)
		return
	_validate_dependencies(INDEX_PATH)

func _validate_dependencies(path: String) -> void:
	for dependency: String in ResourceLoader.get_dependencies(path):
		if dependency.contains("res://assets/"):
			_fail("Generated runtime resource depends on a source pack: %s -> %s" % [path, dependency])

func _prune_generated_orphans() -> void:
	var reachable: Dictionary = {}
	var pending: Array[String] = [INDEX_PATH]
	var catalog := EnvironmentCatalog.load_default()
	if catalog == null:
		_fail("Cannot prune generated resources without a valid catalogue")
		return
	for asset_id: StringName in catalog.ids():
		pending.append(catalog.descriptor(asset_id).visual_path)
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if reachable.has(path):
			continue
		reachable[path] = true
		for dependency: String in ResourceLoader.get_dependencies(path):
			var marker := dependency.find("res://")
			if marker >= 0:
				pending.append(dependency.substr(marker))
	for root: String in [
		"res://terrain/environment/visuals",
		"res://terrain/environment/meshes",
		"res://terrain/environment/collisions",
		"res://terrain/environment/materials",
		"res://terrain/environment/textures",
	]:
		_prune_generated_tree(root, reachable)

func _prune_generated_tree(root: String, reachable: Dictionary) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if directory.current_is_dir():
			if not entry.begins_with("."):
				_prune_generated_tree(path, reachable)
		elif entry.get_extension() in ["res", "tres"] and not reachable.has(path):
			print("Pruning orphaned generated environment resource: ", path)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		entry = directory.get_next()
	directory.list_dir_end()

func _vector3(value, fallback: Vector3) -> Vector3:
	if not value is Array or value.size() != 3:
		return fallback
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _color(value) -> Color:
	if not value is Array or value.size() != 4:
		return Color.WHITE
	return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))

func _slug(value: String) -> String:
	return value.to_lower().replace(".", "_").replace("-", "_").replace("/", "_").replace(" ", "_")

func _ensure_parent(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	printerr(message)
