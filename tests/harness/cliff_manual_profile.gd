extends SceneTree
const STYLE = preload("res://scripts/terrain/field/CliffRockStyle.gd")

func _initialize() -> void:
	STYLE.apply("sheet")
	var source := FileAccess.get_file_as_string("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
	# Reconstruct original radii explicitly so the comparison stays repeatable
	# after production adopts the candidate.
	source=source.replace("Vector2(2.6,6.0)","Vector2(1.8,4.8)").replace("const FOOT:=4.5","const FOOT:=3.6")
	source=source.replace("Vector2(2.2,3.6)","Vector2(.7,1.5)").replace("(3.4*.2 if under else 6.0)","3.4*(.2 if under else 1.0)")
	for variant: String in ["before","gentler","rounder"]:
		var code := source
		if variant != "before":
			code = code.replace("Vector2(1.8,4.8)","Vector2(2.6,6.0)").replace("const FOOT:=3.6","const FOOT:=4.5")
			code = code.replace("Vector2(.7,1.5)","Vector2(1.4,2.5)").replace("3.4*(.2", "5.2*(.2")
		if variant == "rounder":
			code = code.replace("Vector2(1.4,2.5)","Vector2(2.2,3.6)").replace("5.2*(.2", "6.0*(.2")
		var script := GDScript.new()
		script.source_code = code
		assert(script.reload()==OK)
		for height: float in [4.0,8.0,12.0,20.0]:
			var env = script.build(Rect2(-12,-8,24,38),func(q:Vector2)->float:return height if q.y<0 else 0.0,Callable(),2697992464)
			var angles := PackedFloat64Array()
			for x in range(-8,9):
				for iz in range(0,100):
					var q := Vector2(x,iz*.25)
					var y: float = env.sample(q)
					if y<height*.2 or y>height*.8: continue
					var gx: float = (env.sample(q+Vector2(.25,0))-env.sample(q-Vector2(.25,0)))/.5
					var gz: float = (env.sample(q+Vector2(0,.25))-env.sample(q-Vector2(0,.25)))/.5
					angles.append(rad_to_deg(atan(sqrt(gx*gx+gz*gz))))
			angles.sort()
			print("[profile] %s height=%.0f median=%.2f p90=%.2f samples=%d"%[variant,height,angles[angles.size()/2],angles[int(angles.size()*.9)],angles.size()])
	quit()
