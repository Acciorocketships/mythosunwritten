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
	# Low retaining walls are plinth courses, not storey walls squashed flat.
	&"sfv.fabric.wall.rock.plain.001": &"plinth.stone",
	&"sfv.fabric.wall.rock.retaining.001": &"plinth.stone",
	&"sfv.fabric.wall.wood.s.001": &"wall.timber.plain",
	&"sfv.fabric.wall.wood.s.002": &"wall.timber.plain",
	&"sfv.fabric.wall.wood.window.s.002": &"wall.timber.window",
	&"sfv.fabric.wall.wood.window.s.004": &"wall.timber.window",
	&"sfv.fabric.brace.wood.002": &"bracket.jetty",
}
## legacy id PREFIX -> kit role for free-standing props: fitted uniformly
## (proportions kept, base aligned, centred) and rigidly compensated.
const PROP_ROLE_FOR_PREFIX := {
	"sfm.stall.": &"prop.shop",
	"lpfv.fabric.prop.lantern.post.": &"prop.lamp",
	"lpfv.fabric.prop.crate.": &"prop.box",
	"lpfv.fabric.prop.bucket.": &"prop.bucket",
	"lpfv.fabric.prop.bag.": &"prop.bag",
	"lpfv.fabric.prop.barrel.": &"prop.barrel",
	"lpfv.mushroom.": &"prop.garden",
	"sfv.well.": &"prop.well",
	"sfv.fabric.awning.": &"prop.shop",
	"sfm.table.": &"prop.market_goods",
	"sfbp.campfire.": &"prop.bonfire",
}
const RIGID_PREFIXES: Array[String] = ["lpfv.fabric.prop.", "lpfv.flower.",
	"lpfv.mushroom.", "sfm.", "sfv.fabric.planter.", "lpfv.nature.",
	"sfv.prop.", "lpfv.prop."]

static var _fits: Dictionary = {}
## Props placed directly in world space (hamlet squares): uniform fit only.
static var _world_fits: Dictionary = {}
static var _prepared := false


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
		var role := _prop_role(legacy)
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
		fits[legacy] = {"asset_id": target, "tiles": [rigid * fit]}
		world_fits[legacy] = {"asset_id": target, "fit": fit}
	_fits = fits
	_world_fits = world_fits
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


static func _prop_role(asset_id: StringName) -> StringName:
	var id := String(asset_id)
	for prefix: String in PROP_ROLE_FOR_PREFIX:
		if id.begins_with(prefix):
			return PROP_ROLE_FOR_PREFIX[prefix]
	return &""


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
	for asset_id: StringName in source.asset_ids():
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
				transform.basis = transform.basis * rigid
			out.add(asset_id, transform, batch.colors[index], id, collide, owner)
	for mesh: Dictionary in source.surface_meshes:
		out.add_surface_mesh(mesh)
	for box: Dictionary in source.collision_boxes:
		out.add_collision_box(box.transform, box.size,
			StringName(box.get("stable_id", &"")))
	return out
