extends SceneTree
## Foot outline of an outer corner: radial reach of the lowest ring by angle.
## godot --headless --path . -s res://tests/tools/corner_foot_probe.gd -- height
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var corner = load("res://scripts/terrain/field/CliffCornerCrags.gd")
	var line := ""
	for seed_value in [2697992464, 17, 91]:
		var form: Dictionary = corner.make(Transform3D(Basis.IDENTITY, Vector3(-445.5, 20, 490.5)), float(a[0]), seed_value)
		var bins := {}
		for p: Vector3 in form.faces:
			if p.y > .6: continue
			var d := Vector2(p.x + 1.5, p.z + 1.5)
			if d.x < 0 and p.x > -4.5: bins[-1] = maxf(bins.get(-1, 0.0), p.z)
			if d.y < 0 and p.z > -4.5: bins[7] = maxf(bins.get(7, 0.0), p.x)
			if d.x < 0 or d.y < 0: continue
			var angle := int(rad_to_deg(atan2(d.x, d.y)) / 15.0)
			bins[angle] = maxf(bins.get(angle, 0.0), d.length() - 1.5)
		var keys := bins.keys(); keys.sort()
		line = "seed %d:" % seed_value
		for k in keys: line += " %d°=%.2f" % [k * 15, bins[k]]
		print("FOOT ", line)
	quit()
