extends RefCounted
## Pure Village facade family on the common 2 x 3 m construction grid.
## The bake trims blank margins from 3 m opening panels without scaling
## the openings. Roofs, decks and structural timber use Suntail join rules.
## Kept explicit so a pack's source pivots never leak into the planner.
static func create(style_seed: int = 0) -> BuildingKit:
	var kit := SuntailBuildingKit.create()
	kit.kit_id = &"pure_village"
	# The shared projecting bay must use this house's native plaster, not
	# Suntail's lighter infill. Geometry, glass and roof remain authored.
	for colour: String in ["red","blue"]:
		var id := StringName("pure_village.bay.frame_"+colour)
		kit.roles[StringName("bay."+colour)] = [id]
		kit.geometry_aliases[id] = StringName("suntail.frame.frame_extension_"+colour)
	kit.roles[&"trim.panel_joint"] = [&"suntail.decor.support_3"]
	kit.anchors[&"trim.panel_joint"] = Transform3D(
		Basis.from_scale(Vector3(0.6, 3.0, 0.6)), Vector3(0, 0, kit.wall_face))
	kit.roles[&"trim.panel_head"] = [&"suntail.decor.crossbar_2"]
	for kind: String in ["plain", "window", "door", "passage"]:
		var plaster := StringName("wall.timber." + kind)
		var stone := StringName("wall.stone." + kind)
		kit.roles[plaster] = [StringName("pure_village.wall.plaster." + kind)]
		kit.roles[stone] = [StringName("pure_village.wall.stone." + kind)]
		# Plaster stock has its front at +0.125; align to the common wall face.
		kit.anchors[plaster] = Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.032))
		# Retain native stone relief; align the backing courses, not the sill.
		kit.anchors[stone] = Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.17))
	# Odd-height inhabited foundations use the pack's actual half course.
	# Inheriting Suntail's compressed panel introduced a blue masonry stripe
	# and different brick proportions underneath otherwise native stone.
	kit.roles[&"wall.stone.course"] = [&"pure_village.stone.retaining_half"]
	kit.anchors[&"wall.stone.course"] = kit.anchors[&"wall.stone.plain"]
	kit.roles[&"plinth.stone"] = [&"pure_village.stone.plinth"]
	kit.anchors[&"plinth.stone"] = kit.anchors[&"wall.stone.plain"]
	var opening := &"pure_village.wall.plaster.window_open" if posmod(style_seed, 3) != 0 \
		else &"pure_village.wall.plaster.window_arch"
	kit.roles[&"wall.timber.window"] = [opening, opening, opening,
		&"pure_village.wall.plaster.window"]
	return kit

## Complete native roof adapter, also used by the isolated grammar gallery.
static func roof_study(style_seed: int = 0) -> BuildingKit:
	var kit := create(style_seed)
	kit.roof_edge_caps = true
	kit.tight_eave_joint_clip = true
	# Suntail's straight panel has a projecting foot; Pure's native slope
	# needs its own measured seat and deeper fascia below.
	kit.roles.erase(&"trim.eave_tight")
	kit.anchors.erase(&"trim.eave_tight")
	for colour: StringName in SuntailBuildingKit.ROOF_COLOURS:
		kit.anchors.erase(StringName("roof.%s.eave_tight" % colour))
	# Measured native X extents. Closed end pieces move as complete assets
	# when a public passage or attached tower shortens the roof's verge.
	kit.roof_cap_x_bounds = {
		&"pure_village.roof.eave.start": Vector2(-0.6554712, 0.679289),
		&"pure_village.roof.eave.end": Vector2(-0.68729, 0.7462137),
		&"pure_village.roof.slope.start": Vector2(-0.6554712, 0.679289),
		&"pure_village.roof.slope.end": Vector2(-0.6748535, 0.7229675),
		&"pure_village.roof.top.start": Vector2(-0.7192212, 0.68729),
		&"pure_village.roof.top.end": Vector2(-0.68729, 0.7192212),
	}
	kit.ridge_cap_reach = Vector2(0.8,0.79499024)
	kit.roof_top_rise = 1.5
	# The half-height top course ends below the full course's ridge seat.
	# Keep the ridge skirt seated against its tile face, including oblique views.
	kit.roof_ridge_lift = Vector2(0.3,0.24)
	kit.roof_ridge_head = 0.469060
	kit.roof_geometry_path = "res://terrain/environment/geometry/pure_village_roofs.bin"
	for colour: StringName in SuntailBuildingKit.ROOF_COLOURS:
		for role: String in ["eave", "slope", "top"]:
			kit.roles[StringName("roof.%s.%s" % [colour,role])] = [StringName("pure_village.roof." + role)]
		kit.roles[StringName("roof.%s.eave_dormer" % colour)] = [&"pure_village.roof.dormer"]
		kit.roles[StringName("roof.%s.eave_tight" % colour)] = [&"pure_village.roof.slope"]
		kit.roles[StringName("roof.%s.eave_tight_dormer" % colour)] = [&"pure_village.roof.dormer_tight"]
		# The native straight panel still reaches 0.298138 m beyond its foot.
		# Seat the complete tight course up its 3:2 plane, including end caps.
		for suffix: String in ["", ".start", ".end", "_dormer"]:
			kit.anchors[StringName("roof.%s.eave_tight%s" % [colour,suffix])] = Transform3D(
				Basis.IDENTITY, Vector3(0,0.45,-0.3))
	kit.roles[&"trim.eave_tight"] = kit.roles[&"trim.floor_beam"]
	kit.anchors[&"trim.eave_tight"] = Transform3D(
		Basis.from_scale(Vector3(1,2,1)), Vector3(0,0.21,-0.2))
	for role: String in ["left", "right", "small"]:
		kit.roles[StringName("gable." + role)] = [StringName("pure_village.gable." + role)]
		kit.anchors[StringName("gable." + role)] = Transform3D(Basis.IDENTITY,Vector3(0,0,0.032))
	# Full-height interior gable bays use the same measured opening grammar
	# as the facade. Roof/floor contact arbitration can still close an obscured
	# opening with the complete plain panel; sloping end panels stay native.
	# The open-casement facade variant exposes its room. An attic uses a
	# closed native window instead, so it never reveals the roof interior.
	kit.roles[&"gable.wall"] = [&"pure_village.wall.plaster.window_arch"] if posmod(style_seed,3)==0 else [&"pure_village.wall.plaster.window"]
	kit.roles[&"gable.plain"] = [&"pure_village.wall.plaster.plain"]
	kit.anchors[&"gable.wall"] = Transform3D(Basis.IDENTITY,Vector3(0,0,0.032))
	kit.anchors[&"gable.plain"] = kit.anchors[&"gable.wall"]
	kit.roles[&"trim.ridge"] = [&"pure_village.roof.ridge"]
	for side: String in ["start", "end"]:
		for colour: StringName in SuntailBuildingKit.ROOF_COLOURS:
			for role: String in ["eave", "slope", "top"]:
				kit.roles[StringName("roof.%s.%s.%s" % [colour,role,side])] = [StringName("pure_village.roof.%s.%s" % [role,side])]
			kit.roles[StringName("roof.%s.eave_dormer.%s" % [colour,side])] = [StringName("pure_village.roof.eave." + side)]
			kit.roles[StringName("roof.%s.eave_tight.%s" % [colour,side])] = [StringName("pure_village.roof.slope." + side)]
		kit.roles[StringName("trim.ridge." + side)] = [StringName("pure_village.roof.ridge." + side)]
	for role: StringName in [&"trim.barge.eave", &"trim.barge.slope", &"trim.barge.top"]:
		kit.roles.erase(role)
	kit.roles.erase(&"trim.ridge_peak")
	kit.roles.erase(&"trim.ridge_peak_end")
	return kit
