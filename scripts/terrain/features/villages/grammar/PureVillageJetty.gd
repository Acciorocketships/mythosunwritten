extends RefCounted
## Native StreetHouse_1 projecting room interface: 3 m wide, 1 m outward.
## Local origin is the lower wall face at the upper floor, outward +Z.
## Host must provide a connected room behind z=0 and roof/ceiling at y=3.
## This component is not independently closed and must not be scattered as decor.
const Roof = preload("res://scripts/terrain/features/villages/grammar/PureVillageNativeRoof.gd")
const WIDTH := 3.0
const DEPTH := 1.0
const HEIGHT := 3.0
# Source assembly fit, not an arbitrary stretch to cover a larger projection.
const SUPPORT_SCALE := 1.2331678867340088
const FLOOR_SEAT := Vector3(0, .0084929466, .0239944458)


static func derive(host_owned_returns: Array[int] = []) -> Dictionary:
	var parts: Array[Dictionary] = []
	Roof._emit(parts, "Window_3_1", Vector3(0, 0, DEPTH), 0)
	for half: String in ["Start", "End"]:
		Roof._emit(parts, "Floor_Down_%s_15x10_2" % half, FLOOR_SEAT, 0)
	for side: int in [-1, 1]:
		Roof._emit(parts, "Support_4", Vector3(side * WIDTH * .5, -.125, 0), 0)
		parts.back().transform.basis = Basis.from_scale(Vector3.ONE * SUPPORT_SCALE)
		if side in host_owned_returns:
			continue
		Roof._emit(parts, "Wall_End_10x30_1", Vector3(side * WIDTH * .5, 0, 0), side * PI * .5)
		# Return panel's local span is +X. Opposite return needs the same
		# outward span with mirrored handedness, as in native timber assemblies.
		if side == 1:
			parts.back().transform.basis = (
				parts.back().transform.basis * Basis.from_scale(Vector3(-1, 1, 1))
			)
	return {
		"parts": parts,
		"room": AABB(Vector3(-WIDTH * .5, 0, 0), Vector3(WIDTH, HEIGHT, DEPTH)),
		"host_connection": Rect2(Vector2(-WIDTH * .5, 0), Vector2(WIDTH, HEIGHT)),
		"roof_seat": HEIGHT,
		"requires_host": true,
		"requires_roof": true,
		"host_owned_returns": host_owned_returns.duplicate()
	}


static func instantiate(
	at: Transform3D = Transform3D.IDENTITY, host_owned_returns: Array[int] = []
) -> Node3D:
	var root := Node3D.new()
	root.transform = at
	for part: Dictionary in derive(host_owned_returns).parts:
		var module: Node3D = (
			(load(Roof.MODULE_ROOT + part.module + ".glb") as PackedScene).instantiate()
		)
		module.set_meta("native_module", part.module)
		root.add_child(module)
		module.transform = part.transform
	return root
