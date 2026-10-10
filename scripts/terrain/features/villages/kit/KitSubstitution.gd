class_name KitSubstitution
extends RefCounted

## Cross-pack substitution by measured bounds.
##
## Public-realm pieces that the planner still places from the legacy vocabulary
## (guard rails, deck posts, plank tiles, retaining walls, braces) are redrawn
## with the equivalent kit ROLE: the kit asset is fitted into the legacy
## asset's measured box, so every lattice contact the planner proved (rail
## height, post reach, tile extent) is kept while the art becomes the kit's.
## Rigid free-standing legacy props instead keep their own art and receive the
## frame's rigid compensation.
##
## The table is compiled on the main thread from catalog descriptors
## (`prepare`) and read by workers as plain transforms.

## legacy asset id -> kit role.
const ROLE_FOR_LEGACY := {
	&"sfv.deck.railing.s.001": &"rail.low",
	&"sfv.deck.railing.m.001": &"rail.low",
	&"sfv.deck.pillar.001": &"post.timber",
	&"sfv.deck.floor.s.001": &"deck.board",
	&"sfv.fabric.floor.l.001": &"deck.board",
	&"sfv.fabric.gallery.floor.m.001": &"deck.board",
	# Public retaining courses share the native masonry of massif and citadel
	# walls. House plinths have their own family and do not own public stone.
	&"sfv.fabric.wall.rock.plain.001": &"wall.stone.retaining_half",
	&"sfv.fabric.wall.rock.retaining.001": &"wall.stone.retaining_half",
	&"sfv.fabric.wall.wood.s.001": &"wall.timber.plain",
	&"sfv.fabric.wall.wood.s.002": &"wall.timber.plain",
	&"sfv.fabric.wall.wood.window.s.002": &"wall.timber.window",
	&"sfv.fabric.wall.wood.window.s.004": &"wall.timber.window",
	&"sfv.fabric.brace.wood.002": &"bracket.jetty",
}
## legacy id PREFIX -> kit role for free-standing props: fitted uniformly
## (proportions kept, base aligned, centred) and rigidly compensated. A kit
## prop replaces one complete legacy object: a family prefix also names that
## object's parts (a stall's attachments, supports, chimney, hanging string),
## and those must never be fitted with a whole miniature copy (`_prop_role`
## admits only descriptors carrying WHOLE_TAG and none of PART_TAGS).
const PROP_ROLE_FOR_PREFIX := {
	"sfm.stall.": &"prop.shop",
	"lpfv.fabric.prop.lantern.post.": &"prop.lamp",
	"lpfv.fabric.prop.crate.": &"prop.box",
	"lpfv.fabric.prop.bucket.": &"prop.bucket",
	"lpfv.fabric.prop.bag.": &"prop.bag",
	"lpfv.fabric.prop.barrel.": &"prop.barrel",
	"lpfv.mushroom.": &"prop.garden",
	"farm.toadstool.": &"prop.garden",
	"sfv.well.": &"prop.well",
	"sfv.fabric.awning.": &"prop.shop",
	"sfm.table.": &"prop.market_goods",
	"sfbp.campfire.": &"prop.bonfire",
}
const WHOLE_TAG := {"sfm.stall.": &"stall"}
const PART_TAGS: Array[StringName] = [&"support"]
## Legacy dressing that hangs from a legacy canopy the kit redraws: the kit
## stall has no canopy at the legacy station, so the dressing is withdrawn
## with its canopy instead of floating in front of the kit piece.
const DRESSING_OF_REDRAWN: Array[StringName] = [&"sfm.stall.veg_string.001"]
const RIGID_PREFIXES: Array[String] = ["lpfv.fabric.prop.", "lpfv.flower.",
	"lpfv.mushroom.", "meadow.flower.", "farm.toadstool.", "sfm.", "sfv.fabric.planter.", "lpfv.nature.",
	"sfv.prop.", "lpfv.prop."]
## Rigid props sized for the player (see VillageWorldScale.HUMAN_PROP_*):
## they keep their pre-upscale world size instead of growing with the town.
const HUMAN_PREFIXES: Array[String] = ["lpfv.fabric.prop.", "lpfv.flower.",
	"lpfv.mushroom.", "lpfv.prop.", "meadow.flower.", "farm.toadstool."]

static var _fits: Dictionary = {}
## Props placed directly in world space (hamlet squares): uniform fit only.
static var _world_fits: Dictionary = {}
static var _prepared := false
## The kit's public timber: deck boards lend their material to the generated
## walking surfaces, rail and post pieces redraw the generated flight guards.
static var _public_timber: Dictionary = {}

## Generated public surfaces (flights, ramps, landings and the structural deck
## skin) carry lattice-metre UVs / 3. The kit deck board maps its 2 m native
## tile onto 0.745 of its plank texture, and public decks fit that tile to
## the 3 m lattice board (`sfv.fabric.floor.l.001`), so 0.745 texture per UV
## unit keeps the generated boards the width of the deck boards beside them.
const DECK_TEXTURE_PER_UV := 0.745
## Legacy landing railing whose measured span/depth the flight rails share.
const LANDING_RAILING := &"sfv.deck.railing.s.001"


## Main thread: resolves every substitution against measured bounds.
static func prepare(catalog: EnvironmentCatalog, kit: BuildingKit) -> void:
	var fits: Dictionary = {}
	for legacy: StringName in ROLE_FOR_LEGACY:
		var target := kit.asset(ROLE_FOR_LEGACY[legacy])
		if target.is_empty() or not catalog.has(legacy) or not catalog.has(target):
			continue
		var source_box := catalog.descriptor(legacy).measured_aabb
		var target_box := catalog.descriptor(target).measured_aabb
		if not source_box.has_volume() or not target_box.has_volume():
			continue
		if ROLE_FOR_LEGACY[legacy] == &"post.timber":
			# Keep the house kit's square post section instead of stretching
			# it across the legacy pillar's broad rectangular base. One member
			# spans the complete support height, inside the proved envelope.
			var width_scale := minf(
				VillageWorldScale.KIT_WORLD_SCALE / VillageWorldScale.HORIZONTAL_SCALE,
				minf(source_box.size.x / target_box.size.x,
					source_box.size.z / target_box.size.z))
			var post_scale := Vector3(width_scale,
				source_box.size.y / target_box.size.y, width_scale)
			var source_foot := Vector3(source_box.get_center().x,
				source_box.position.y, source_box.get_center().z)
			var target_foot := Vector3(target_box.get_center().x,
				target_box.position.y, target_box.get_center().z)
			fits[legacy] = {"asset_id": target, "tiles": [Transform3D(
				Basis.from_scale(post_scale), source_foot - target_foot * post_scale)]}
			continue
		# Tile along length and height at near-native size; only the depth
		# stretches, so masonry courses and rail spans keep their proportions.
		var nx := maxi(1, roundi(source_box.size.x / target_box.size.x))
		var ny := maxi(1, roundi(source_box.size.y / target_box.size.y))
		var scale := Vector3(source_box.size.x / float(nx) / target_box.size.x,
			source_box.size.y / float(ny) / target_box.size.y,
			source_box.size.z / target_box.size.z)
		var tiles: Array[Transform3D] = []
		for iy in ny:
			for ix in nx:
				var corner := source_box.position + Vector3(
					float(ix) * source_box.size.x / float(nx),
					float(iy) * source_box.size.y / float(ny), 0.0)
				tiles.append(Transform3D(Basis.from_scale(scale),
					corner - target_box.position * scale))
		fits[legacy] = {"asset_id": target, "tiles": tiles}
	var rigid := Transform3D(VillageWorldScale.rigid_compensation(), Vector3.ZERO)
	var world_fits: Dictionary = {}
	for legacy: StringName in catalog.ids():
		var role := _prop_role(legacy, catalog.descriptor(legacy).tags)
		if role.is_empty():
			continue
		var target := kit.asset(role, absi(hash(legacy)))
		if target.is_empty() or not catalog.has(target):
			continue
		var source_box := catalog.descriptor(legacy).measured_aabb
		var target_box := catalog.descriptor(target).measured_aabb
		if not source_box.has_volume() or not target_box.has_volume():
			continue
		# Props keep near-native size: shrink to fit, never blow up past 1.25x.
		var ratio := minf(1.25, minf(minf(source_box.size.x / target_box.size.x,
			source_box.size.z / target_box.size.z),
			source_box.size.y / target_box.size.y))
		var source_base := Vector3(source_box.get_center().x, source_box.position.y,
			source_box.get_center().z)
		var target_base := Vector3(target_box.get_center().x, target_box.position.y,
			target_box.get_center().z) * ratio
		var fit := Transform3D(Basis.from_scale(Vector3.ONE * ratio),
			source_base - target_base)
		var compensation := Transform3D(VillageWorldScale.human_prop_compensation(),
			Vector3.ZERO) if is_human_prop(legacy) else rigid
		fits[legacy] = {"asset_id": target, "tiles": [compensation * fit]}
		world_fits[legacy] = {"asset_id": target, "fit": fit}
	_fits = fits
	_world_fits = world_fits
	_public_timber = {}
	var deck := kit.asset(&"deck.board")
	var rail := kit.asset(&"rail.low")
	var post := kit.asset(&"rail.post")
	if catalog.has(deck) and catalog.has(rail) and catalog.has(post) \
			and catalog.has(LANDING_RAILING):
		_public_timber = {"deck": deck, "rail": rail, "post": post,
			"rail_box": catalog.descriptor(rail).measured_aabb,
			"post_box": catalog.descriptor(post).measured_aabb,
			"landing": catalog.descriptor(LANDING_RAILING).measured_aabb}
	var beam := kit.asset(&"beam.floor")
	if not _public_timber.is_empty() and catalog.has(beam):
		_public_timber["beam"] = beam
		_public_timber["beam_box"] = catalog.descriptor(beam).measured_aabb
		# Authored Wooden_Railings_1 cross members occupy y=.471..533 and
		# .799..862; the taller .938 post head is not the upper rail line.
		# Preserve those source joints when composing a short return.
		if rail == &"suntail.stair.wooden_railings_1":
			_public_timber["member_y"] = Vector2(.502,.8305)
			_public_timber["member_height"] = .064

	_prepared = true


## A world-space prop entry redrawn with its kit equivalent (or unchanged).
static func swap_world_entry(entry: Dictionary) -> Dictionary:
	var fit: Dictionary = _world_fits.get(StringName(entry.get("asset_id", "")), {})
	if fit.is_empty():
		return entry
	var out := entry.duplicate()
	out.asset_id = fit.asset_id
	out.transform = (entry.transform as Transform3D) * (fit.fit as Transform3D)
	return out


static func is_prepared() -> bool:
	return _prepared


static func _prop_role(asset_id: StringName, tags: Array[StringName]) -> StringName:
	var id := String(asset_id)
	for prefix: String in PROP_ROLE_FOR_PREFIX:
		if not id.begins_with(prefix):
			continue
		if WHOLE_TAG.has(prefix) and not tags.has(WHOLE_TAG[prefix]):
			return &""
		for tag: StringName in PART_TAGS:
			if tags.has(tag):
				return &""
		return PROP_ROLE_FOR_PREFIX[prefix]
	return &""


static func is_human_prop(asset_id: StringName) -> bool:
	var id := String(asset_id)
	for prefix: String in HUMAN_PREFIXES:
		if id.begins_with(prefix):
			return true
	return false


static func is_rigid_prop(asset_id: StringName) -> bool:
	var id := String(asset_id)
	for prefix: String in RIGID_PREFIXES:
		if id.begins_with(prefix):
			return true
	return false


## Rewrites `source` (authored lattice frame): substituted pieces become kit
## assets, rigid props gain the frame's rigid compensation, everything else
## passes through unchanged.
static func apply(source: EnvironmentInstancePayload) -> EnvironmentInstancePayload:
	var out := EnvironmentInstancePayload.new()
	var rigid := VillageWorldScale.rigid_compensation()
	var human := VillageWorldScale.human_prop_compensation()
	for asset_id: StringName in source.asset_ids():
		if DRESSING_OF_REDRAWN.has(asset_id):
			continue
		var batch: Dictionary = source.batches[asset_id]
		var fit: Dictionary = _fits.get(asset_id, {})
		var flags: Array = batch.get("collision_enabled", [])
		var owners: Array = batch.get("visibility_owners", [])
		var prop := is_rigid_prop(asset_id)
		for index in batch.transforms.size():
			var transform := batch.transforms[index] as Transform3D
			var id := StringName(batch.ids[index]) if not batch.ids.is_empty() \
				else StringName("anonymous/%s/%d" % [asset_id, index])
			var collide := flags.is_empty() or bool(flags[index])
			var owner: AABB = owners[index] if index < owners.size() else AABB()
			if not fit.is_empty():
				var tiles: Array = fit.tiles
				for t in tiles.size():
					out.add(fit.asset_id, transform * (tiles[t] as Transform3D),
						batch.colors[index],
						id if t == 0 else StringName("%s/tile%d" % [id, t]),
						collide, owner)
				continue
			if prop:
				transform.basis = transform.basis * (human if is_human_prop(asset_id) else rigid)
			out.add(asset_id, transform, batch.colors[index], id, collide, owner)
	for mesh: Dictionary in source.surface_meshes:
		var drawn := redraw_public_surface(mesh)
		out.add_surface_mesh(drawn.mesh)
		for rail: Dictionary in drawn.rails:
			out.add(rail.asset_id, rail.transform, Color.WHITE, rail.stable_id, false)
	for box: Dictionary in source.collision_boxes:
		out.add_collision_box(box.transform, box.size,
			StringName(box.get("stable_id", &"")))
	return out


## A generated public walking surface drawn in the kit's timber. The mesh keeps
## its exact vertices and collision (the traversal authority); it takes the kit
## deck board's material, with boards laid across a flight, and a flight's
## guard members leave the render (their collision stays) for kit railings on
## the same foot line, returned as `rails` (asset_id, transform, stable_id; no
## collision). Other surfaces pass through unchanged.
static func redraw_public_surface(mesh: Dictionary) -> Dictionary:
	var transition := bool(mesh.get("is_transition", false))
	if _public_timber.is_empty() or mesh.has("material_asset_id") \
			or not (transition or bool(mesh.get("structural_plank", false))):
		return {"mesh": mesh, "rails": []}
	var out := mesh.duplicate()
	var uvs := PackedVector2Array()
	for uv: Vector2 in mesh.uvs as PackedVector2Array:
		# Flight UVs run u across and v along the run; the board texture's
		# planks follow v, so a flight swaps them to lay boards across.
		uvs.append((Vector2(uv.y, uv.x) if transition else uv) * DECK_TEXTURE_PER_UV)
	out["uvs"] = uvs
	if transition:
		var indices := PackedInt32Array()
		var source := mesh.indices as PackedInt32Array
		var guard := PackedByteArray()
		guard.resize(source.size())
		for range_value: Variant in mesh.get("guard_index_ranges", []):
			var span := range_value as Vector2i
			for index in range(span.x, span.y):
				guard[index] = 1
		for index in source.size():
			if guard[index] == 0:
				indices.append(source[index])
		out["indices"] = indices
	out["material_asset_id"] = _public_timber.deck
	out["material_piece"] = 0
	out["material_surface"] = 0
	out["tangents"] = uv_tangents(out.vertices, out.normals, uvs, out.indices)
	var rails: Array[Dictionary] = []
	if transition:
		var index := 0
		for span: Dictionary in mesh.get("guard_spans", []):
			for rail: Dictionary in _flight_railing(span):
				rail["stable_id"] = StringName("%s/rail%d" % [
					String(mesh.get("stable_id", "")), index])
				rails.append(rail)
				index += 1
	return {"mesh": out, "rails": rails}


## Kit railing tiles along one exposed guard span, sheared onto its slope:
## posts stay plumb, rails follow the flight, and the top meets the guard's
## collision height. One post closes the far end.
static func _flight_railing(span: Dictionary) -> Array[Dictionary]:
	if bool(span.get("landing_return",false)) and _public_timber.has("beam"):
		return _landing_return(span)
	var out: Array[Dictionary] = []
	var foot_a := span.foot_a as Vector3
	var foot_b := span.foot_b as Vector3
	var height_a := (span.top_a as Vector3).y - foot_a.y
	var height_b := (span.top_b as Vector3).y - foot_b.y
	var run := foot_b - foot_a
	var horizontal := Vector3(run.x, 0.0, run.z)
	if horizontal.length() < 0.001:
		return out
	var along := horizontal.normalized()
	var across := along.cross(Vector3.UP)
	var rail_box := _public_timber.rail_box as AABB
	var post_box := _public_timber.post_box as AABB
	var landing := _public_timber.landing as AABB
	var tiles := maxi(1, roundi(horizontal.length() / landing.size.x))
	var depth := landing.size.z / rail_box.size.z
	var last := Transform3D()
	for tile in tiles:
		var t0 := float(tile) / float(tiles)
		var t1 := float(tile + 1) / float(tiles)
		var a := foot_a.lerp(foot_b, t0)
		var b := foot_a.lerp(foot_b, t1)
		var height := lerpf(height_a, height_b, (t0 + t1) * 0.5)
		var basis := Basis((b - a) / rail_box.size.x,
			Vector3.UP * height / rail_box.size.y, across * depth)
		last = Transform3D(basis, a - basis * Vector3(rail_box.position.x,
			rail_box.position.y, rail_box.get_center().z))
		out.append({"asset_id": _public_timber.rail, "transform": last})
	# The closing post, on the last tile's own frame at its far end.
	out.append({"asset_id": _public_timber.post, "transform": last * Transform3D(
		Basis.IDENTITY, Vector3(rail_box.end.x - post_box.end.x, 0.0, 0.0))})
	return out


## A short landing shoulder joins an existing flight post. Compressing a whole
## railing here also compresses its posts and duplicates the attachment post.
## Two stock timber members and one ordinary-width end post close the return.
static func _landing_return(span: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var a: Vector3 = span.foot_a
	var b: Vector3 = span.foot_b
	var run := b-a
	if run.length() < 0.001: return out
	var along := run.normalized()
	var across := along.cross(Vector3.UP).normalized()
	var box: AABB = _public_timber.beam_box
	var rail: AABB = _public_timber.rail_box
	var height := (span.top_b as Vector3).y-b.y
	var member_y: Vector2 = _public_timber.get("member_y",
		Vector2(rail.position.y+rail.size.y*.52,rail.end.y))
	var beam_height := float(_public_timber.get("member_height",
		PublicRealmSurfacePlan.GUARD_BEAM))*height/rail.size.y
	var basis := Basis(run/box.size.x,Vector3.UP*beam_height/box.size.y,
		across*PublicRealmSurfacePlan.GUARD_BEAM/box.size.z)
	for native_y: float in [member_y.x,member_y.y]:
		var level := (native_y-rail.position.y)*height/rail.size.y
		var centre := (a+b)*.5+Vector3.UP*level
		var pose := Transform3D(basis,centre-basis*box.get_center())
		out.append({"asset_id":_public_timber.beam,"transform":pose})
	var post: AABB = _public_timber.post_box
	var landing: AABB = _public_timber.landing
	var post_basis := Basis(along*landing.size.x/rail.size.x,
		Vector3.UP*height/rail.size.y,across*landing.size.z/rail.size.z)
	var foot := Vector3(post.get_center().x,post.position.y,post.get_center().z)
	out.append({"asset_id":_public_timber.post,
		"transform":Transform3D(post_basis,b-post_basis*foot)})
	return out


## Per-vertex tangents (Godot layout: xyz + binormal sign) from UV gradients.
static func uv_tangents(vertices: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, indices: PackedInt32Array) -> PackedFloat32Array:
	var tangent_sum := PackedVector3Array()
	var binormal_sum := PackedVector3Array()
	tangent_sum.resize(vertices.size())
	binormal_sum.resize(vertices.size())
	for i in range(0, indices.size() - 2, 3):
		var ia := indices[i]
		var ib := indices[i + 1]
		var ic := indices[i + 2]
		var e1 := vertices[ib] - vertices[ia]
		var e2 := vertices[ic] - vertices[ia]
		var d1 := uvs[ib] - uvs[ia]
		var d2 := uvs[ic] - uvs[ia]
		var det := d1.x * d2.y - d2.x * d1.y
		if absf(det) < 0.0000001:
			continue
		var tangent := (e1 * d2.y - e2 * d1.y) / det
		var binormal := (e2 * d1.x - e1 * d2.x) / det
		for vertex: int in [ia, ib, ic]:
			tangent_sum[vertex] += tangent
			binormal_sum[vertex] += binormal
	var out := PackedFloat32Array()
	out.resize(vertices.size() * 4)
	for v in vertices.size():
		var normal := normals[v]
		var tangent := tangent_sum[v] - normal * normal.dot(tangent_sum[v])
		if tangent.length_squared() < 0.0000001:
			tangent = normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT)
		tangent = tangent.normalized()
		out[v * 4] = tangent.x
		out[v * 4 + 1] = tangent.y
		out[v * 4 + 2] = tangent.z
		out[v * 4 + 3] = -1.0 if normal.cross(tangent).dot(binormal_sum[v]) < 0.0 else 1.0
	return out
