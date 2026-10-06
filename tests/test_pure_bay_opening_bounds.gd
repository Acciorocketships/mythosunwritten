extends GutTest
const CONTACTS := preload("res://scripts/terrain/features/villages/kit/KitFacadeRoofContacts.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")

func test_material_swapped_bays_keep_glass_and_frame_contact_checks() -> void:
	var context := CONTACTS.prepare([], SuntailBuildingKit.create(), {})
	for colour: String in ["red", "blue"]:
		var source := StringName("suntail.frame.frame_extension_" + colour)
		var variant := StringName("pure_village.bay.frame_" + colour)
		assert_true(context.openings.has(variant), "Material swaps retain measured glazing")
		assert_eq(context.frames.get(variant, []), context.frames.get(source, []),
			"The same authored window surrounds retain their bounds")
		var opening: AABB = context.openings[source]
		context.volumes = [UNION.box_volume(opening.grow(.3))]
		assert_true(CONTACTS.obstructed(variant, Transform3D.IDENTITY, context),
			"A roof through the glass blocks the material-swapped bay")
		context.volumes = []
		assert_false(CONTACTS.obstructed(variant, Transform3D.IDENTITY, context))
