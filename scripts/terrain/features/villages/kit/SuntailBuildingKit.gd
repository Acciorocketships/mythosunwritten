class_name SuntailBuildingKit
extends RefCounted

## The Raygeas "Suntail Village" modular building pack as a `BuildingKit`.
##
## Metric measured from the pack's eight House_N prefabs: 2 m wall modules,
## 3 m storeys, a 1 m stone plinth, 1 m jetties carried on Support_2 brackets,
## and 2 m-run / 3.12 m-rise roof rows with a 1.62 m ridge-top row. Asset ids
## are the baked catalog entries from
## `tools/environment_bake/manifests/suntail_village_kit.json`.

## Stable vendor IDs are retained; the manifest now bakes red as warm wood
## and blue as weathered wood, including their bay and dormer roof surfaces.
const ROOF_COLOURS: Array[StringName] = [&"red", &"blue"]


static func create() -> BuildingKit:
	var kit := BuildingKit.new()
	kit.kit_id = &"suntail"
	kit.roof_geometry_path = "res://terrain/environment/geometry/suntail_roofs.bin"
	kit.module_width = 2.0
	kit.storey_height = 3.0
	kit.plinth_height = 1.0
	kit.roof_row_rise = 3.0
	kit.roof_top_rise = 1.62
	kit.roof_ridge_head = 0.013463
	kit.jetty_depth = 1.0
	# Frame_Wall_* outer faces stand 0.157 m proud of their pivot line.
	kit.wall_face = 0.157
	# Cornice_Cover_2 spans native z -0.0466..0.0640 before rotation.
	kit.barge_half_depth = 0.065
	# Support_3 is 0.2586 m square.
	kit.corner_post_half = 0.1293
	var r := kit.roles
	r[&"wall.timber.plain"] = [&"suntail.frame.frame_wall_2", &"suntail.frame.frame_wall_1"]
	# A complete Pure Village clerestory panel fits the same 2 m / 3 m bay.
	r[&"trim.high_window_joint"] = [&"suntail.decor.support_3"]
	kit.anchors[&"trim.high_window_joint"] = Transform3D(Basis.from_scale(Vector3(0.6,3.0,0.6)),Vector3(0,0,kit.wall_face))
	r[&"trim.high_window_head"] = [&"suntail.decor.crossbar_2"]
	r[&"wall.timber.window.high"] = [&"pure_village.wall.plaster.window_open"]
	r[&"wall.timber.window"] = [&"suntail.frame.frame_wall_1_w", &"suntail.frame.frame_wall_2_w"]
	r[&"wall.timber.door"] = [&"suntail.frame.frame_wall_1_d", &"suntail.frame.frame_wall_1_d_1"]
	r[&"wall.timber.passage"] = [&"suntail.frame.frame_wall_1_passage"]
	# Storey masonry is the pack's stone panels baked 0.2 m thicker in front
	# (`masonry_depth` in the bake manifest): windows and doors keep their
	# frames in the original plane, sunk into deep reveals, and the stone
	# storey stands proud of the timber storey above it. Retained earth uses
	# unframed Pure Village masonry, matching its native stone corbel courses.
	kit.masonry_depth = 0.2
	r[&"wall.stone.plain"] = [&"suntail.stone.stone_wall_deep"]
	r[&"wall.stone.window"] = [&"suntail.stone.stone_wall_w_deep"]
	r[&"wall.stone.door"] = [&"suntail.stone.stone_wall_d_deep", &"suntail.stone.stone_wall_d_1_deep"]
	r[&"wall.stone.passage"] = [&"suntail.stone.stone_wall_passage_deep"]
	r[&"wall.stone.retaining"] = [&"pure_village.wall.stone.plain"]
	r[&"wall.stone.retaining_half"] = [&"pure_village.stone.retaining_half"]
	# The stone top of a plinth a growing ground storey steps back from (rows of the
	# half-height course standing behind the podium face, tops level with the floor).
	r[&"plinth.cap"] = [&"pure_village.stone.retaining_half"]
	r[&"plinth.stone"] = [&"suntail.stone.stone_base"]
	# Fortification (a raised district's plinth): plain coursed stone, the
	# kit's stone wall with its timber frame baked away.
	r[&"wall.fort"] = [&"pure_village.wall.stone.plain"]
	r[&"fort.block"] = [&"pure_village.stone.block.4"]
	r[&"gate.arch"] = [&"pure_village.stone.gate_arch"]
	kit.gate_arch_size = Vector3(3.164761,2.005289,0.541562)
	kit.gate_arch_cap_lap = 0.12
	r[&"bay.spire"] = [&"pure_village.bay.spire"]
	kit.oriel_bounds = AABB(Vector3(-0.9947556,-0.67883146,-0.05),Vector3(1.9957291,5.396718,1.0600911))
	# One band of coursed stone: the flush storey masonry panel at half height.
	# (Stone_Base is a corner plinth: its taller corner pier repeated at every
	# module and jutted past run ends, a gap-toothed wall.) Courses standing on
	# the ground instead sink a full panel one band (`sunk`), keeping the
	# storeys' brick proportions.
	r[&"wall.stone.course"] = [&"suntail.stone.stone_wall"]
	kit.anchors[&"wall.stone.course"] = Transform3D(
		Basis.from_scale(Vector3(1.0, 1.5 / 3.0742, 1.0)), Vector3.ZERO)
	# Chimneys: the pack's rubble chimney block, stacked, with its hollow top.
	# Both pivot on their back face; the anchors centre them on the stack axis.
	r[&"chimney.course"] = [&"suntail.chimney.fireplace_2"]
	kit.anchors[&"chimney.course"] = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.14))
	r[&"chimney.cap"] = [&"suntail.chimney.fireplace_3"]
	kit.anchors[&"chimney.cap"] = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.14))
	r[&"gable.left"] = [&"suntail.frame.gable_l"]
	r[&"gable.right"] = [&"suntail.frame.gable_r"]
	r[&"gable.small"] = [&"suntail.frame.gable_small"]
	r[&"gable.plain"] = r[&"wall.timber.plain"]
	r[&"gable.wall"] = [&"suntail.frame.frame_wall_2_w", &"suntail.frame.frame_wall_1_w"]
	for colour: StringName in ROOF_COLOURS:
		r[StringName("roof.%s.eave" % colour)] = [StringName("suntail.roof.roof_1_cornice_%s" % colour)]
		r[StringName("roof.%s.eave_dormer" % colour)] = [StringName("suntail.roof.roof_1_cornice_w_%s" % colour)]
		r[StringName("roof.%s.slope" % colour)] = [StringName("suntail.roof.roof_1_%s" % colour)]
		# A complete straight slope starts at the wall line when the curved
		# cornice would dip into a stair's headroom.
		r[StringName("roof.%s.eave_tight" % colour)] = r[StringName("roof.%s.slope" % colour)]
		# The straight source panel still projects 0.118539 m beyond its
		# nominal foot. Slide the complete panel along its 3:2 roof plane so
		# a tight eave actually clears the wall line, without changing pitch.
		kit.anchors[StringName("roof.%s.eave_tight" % colour)] = Transform3D(
			Basis.IDENTITY, Vector3(0, 0.12 * 1.5, -0.12))
		r[StringName("roof.%s.top" % colour)] = [StringName("suntail.roof.roof_top_1_%s" % colour)]
		r[StringName("roof.%s.valley_eave" % colour)] = [StringName("suntail.roof.roof_2_cornice_%s" % colour)]
		r[StringName("roof.%s.valley" % colour)] = [StringName("suntail.roof.roof_2_%s" % colour)]
		r[StringName("roof.%s.tee" % colour)] = [StringName("suntail.roof.roof_top_2_%s" % colour)]
		r[StringName("bay.%s" % colour)] = [StringName("suntail.frame.frame_extension_%s" % colour)]
	r[&"trim.barge.eave"] = [&"suntail.decor.cornice_cover_2"]
	r[&"trim.barge.slope"] = [&"suntail.decor.cornice_cover_1"]
	r[&"trim.barge.top"] = [&"suntail.decor.cornice_cover_3"]
	r[&"trim.ridge"] = [&"suntail.decor.ridge"]
	r[&"trim.ridge_peak"] = [&"suntail.decor.decor_peaks_1"]
	r[&"trim.ridge_peak_end"] = [&"suntail.decor.decor_peaks_2"]
	r[&"trim.floor_beam"] = [&"suntail.decor.crossbar_2"]
	# Close the retracted panel's wall head with the native horizontal timber.
	# Its outer face stays inside the public wall plane (native max Z=.197263).
	r[&"trim.eave_tight"] = r[&"trim.floor_beam"]
	kit.anchors[&"trim.eave_tight"] = Transform3D(Basis.IDENTITY, Vector3(0,.15,-.2))
	# The source corner beam includes a stone block below its return. That
	# block reads as a loose cube under an upper-storey jetty; retain the
	# authored timber connection alone for suspended floor trim.
	r[&"trim.floor_beam_corner"] = [&"suntail.decor.crossbar_1_timber"]
	r[&"bracket.jetty"] = [&"suntail.decor.support_2"]
	r[&"bracket.small"] = [&"suntail.decor.support_1"]
	r[&"bracket.cantilever"] = [&"pure_village.support.cantilever"]
	r[&"post.timber"] = [&"suntail.decor.support_3"]
	r[&"post.base"] = [&"suntail.decor.support_3_base"]
	r[&"awning"] = [&"suntail.decor.wooden_canopy_1"]
	# Wooden_Canopy_1 is a free-standing four-post lean-to, 3.795 m wide
	# (x -1.875..1.919), 2.293 m deep (z -0.811..1.482) and 3.602 m tall. The
	# anchor makes it canonical: one wall module wide (minus a hairline so
	# neighbouring porches never share a post), centred, back posts on z = 0.
	kit.awning_width = 0.96
	kit.awning_depth = 2.293
	kit.awning_height = 3.602
	var canopy_x := kit.module_width * kit.awning_width / 3.794629
	kit.anchors[&"awning"] = Transform3D(Basis.from_scale(Vector3(canopy_x, 1.0, 1.0)),
		Vector3(-(-1.8753132 + 3.794629 * 0.5) * canopy_x, 0.0, 0.8112094))
	r[&"window_box"] = [&"suntail.decor.flovers_1", &"suntail.decor.flovers_2"]
	# Ivy grows from the ground: anchors seat each mesh's lowest leaves at y 0.
	# `ivy.wall` is a flat climbing patch for a blank wall; `ivy.corner` wraps
	# a convex corner at the RIGHT end of the face it is placed on (from the
	# pack's own House_3 placement: 0.08 m out, 0.12 m past the corner).
	r[&"ivy.wall"] = [&"suntail.decor.ivy_1"]
	kit.asset_anchors[&"suntail.decor.ivy_1"] = Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0))
	r[&"ivy.corner"] = [&"suntail.decor.ivy_3"]
	kit.asset_anchors[&"suntail.decor.ivy_3"] = Transform3D(Basis.IDENTITY, Vector3(0, 1.35, 0))
	r[&"stair.entry"] = [&"suntail.stair.stone_stairs"]
	r[&"stair.run_1"] = [&"suntail.stair.wooden_stairs_1"]
	r[&"stair.run_2"] = [&"suntail.stair.wooden_stairs_2"]
	r[&"deck.platform"] = [&"suntail.stair.wooden_platform"]
	r[&"deck.platform_edge"] = [&"suntail.stair.wooden_platform_cover"]
	# Complete native shallow cornice course, with authored closed end caps.
	for part: String in ["middle", "left", "right", "outer_corner", "inner_corner", "middle_half"]:
		r[StringName("wallhood."+part)] = [StringName("pure_village.wall_hood."+part)]
		# Seat the shallow roof on the retained half-storey cap; its low
		# edge clears the complete native door/window heads below.
		kit.anchors[StringName("wallhood."+part)] = Transform3D(Basis.IDENTITY,Vector3(0,0.85,0))
	for part: String in ["floor","return","return_beam"]:
		r[StringName("frontage."+part)] = [StringName("town.frontage."+part)]
	# Growing upper floors: the baked floor strips, corner squares, returns and return
	# beams at each depth the assembler asks for (KitGrowingFronts.FRONT_DEPTHS), never a
	# scaled piece.
	var front_depths: Dictionary = preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd").FRONT_DEPTHS
	for role: StringName in front_depths:
		for depth: float in front_depths[role]:
			var variant := "%s.%s" % [role, BuildingKitAssembler.lean_suffix(depth)]
			r[StringName(variant)] = [StringName("town." + variant)]
	r[&"deck.board"] = [&"suntail.floor.floor_2"]
	r[&"rail.low"] = [&"suntail.stair.wooden_railings_1"]
	r[&"rail.stair"] = [&"suntail.stair.wooden_railings_2"]
	r[&"rail.post"] = [&"suntail.stair.wooden_railings_3"]
	r[&"beam.floor"] = [&"suntail.floor.beam_1"]
	r[&"prop.pot"] = [&"suntail.prop.pot_1", &"suntail.prop.pot_2", &"suntail.prop.pot_3"]
	r[&"prop.shop"] = [&"suntail.prop.shop_1", &"suntail.prop.shop_2", &"suntail.prop.shop_3"]
	r[&"prop.lamp"] = [&"suntail.prop.lamp_1.dark_wood"]
	r[&"prop.box"] = [&"suntail.prop.box_1", &"suntail.prop.box_2"]
	r[&"prop.bucket"] = [&"suntail.prop.bucket"]
	r[&"prop.bag"] = [&"suntail.prop.bag_1", &"suntail.prop.bag_2", &"suntail.prop.bag_3"]
	r[&"prop.barrel"] = [&"suntail.prop.barrel"]
	r[&"prop.doorstep"] = [&"suntail.prop.pot_1", &"suntail.prop.bucket",
		&"suntail.prop.bag_2", &"suntail.prop.barrel", &"suntail.prop.box_2",
		&"suntail.prop.pumpkin"]
	r[&"prop.market_goods"] = [&"suntail.prop.case_and_food_1",
		&"suntail.prop.case_and_food_2", &"suntail.prop.case_and_food_3"]
	r[&"prop.well"] = [&"suntail.prop.well_1", &"suntail.prop.well_2"]
	r[&"prop.bonfire"] = [&"suntail.prop.bonfire"]
	r[&"prop.garden"] = [&"suntail.prop.pumpkin", &"suntail.prop.pot_1", &"suntail.prop.bucket"]
	return kit
