extends SceneTree
func _init() -> void:
	var phases := OS.get_cmdline_user_args()
	if phases.is_empty(): phases = PackedStringArray(["before", "after"])
	for phase: String in phases:
		var prefix := "res://artifacts/qa/2026-09-05-evening/"+phase+"/upper_facade_overlap_jitter_"
		var a := Image.load_from_file(prefix+"0.png")
		var b := Image.load_from_file(prefix+"1.png")
		var smooth := 0
		var changed := 0
		for y in range(50,550):
			for x in range(300,1550):
				var col := Vector3(a.get_pixel(x,y).r,a.get_pixel(x,y).g,a.get_pixel(x,y).b)
				var spread := 0.0
				for p: Vector2i in [Vector2i(-3,-3),Vector2i(3,-3),Vector2i(-3,3),Vector2i(3,3)]:
					var sample := a.get_pixel(x+p.x,y+p.y)
					spread=maxf(spread,col.distance_to(Vector3(sample.r,sample.g,sample.b)))
				if spread > 0.015: continue
				smooth+=1
				var next := b.get_pixel(x,y)
				changed+=int(col.distance_to(Vector3(next.r,next.g,next.b))>0.03)
		print("FLICKER ",phase," smooth=",smooth," changed=",changed," ratio=",float(changed)/maxi(1,smooth))
	quit()
