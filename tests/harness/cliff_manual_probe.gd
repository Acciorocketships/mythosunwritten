extends SceneTree
## Detached geometry diagnostic at the owner's photo 11. This deliberately
## omits feature grading/water cuts: it distinguishes envelope/mesh defects
## from production exclusion defects and is not full-site acceptance.
const FIELD = preload("res://scripts/terrain/field/CliffSlopeField.gd")
const STYLE = preload("res://scripts/terrain/field/CliffRockStyle.gd")
const SEED := 2697992464

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	STYLE.apply("sheet_bedrock")
	var area := Rect2(296,768,8,8)
	var field
	if OS.get_cmdline_user_args().has("--full"):
		area=Rect2(270,748,60,55)
		var water:=TerrainWorldTuning.make_water(SEED)
		var region:=TerrainWorldTuning.make_heightfield(SEED,water).compute_region(12,32,6)
		field=FIELD.new([],SEED,region,area)
	else:
		var saved:Dictionary=FileAccess.open("res://tests/fixtures/september26-cliffs/photo11-envelope.var",FileAccess.READ).get_var()
		var env=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd").new()
		for key:String in saved:env.set(key,saved[key])
		field=FIELD.new([],SEED,null,area)
		field._env=env
	_measure(field,area,"current")
	quit()

func _measure(field, area: Rect2, variant: String) -> void:
	var surface: Array = field.solid(area)
	var faces: PackedVector3Array = surface[0].faces
	var edges := {}
	var downward := 0
	for i in range(0, faces.size(), 3):
		var n := (faces[i+2]-faces[i]).cross(faces[i+1]-faces[i])
		if n.y < -.00001:
			downward += 1
		for k in 3:
			var a := faces[i+k]
			var b := faces[i+(k+1)%3]
			var key := [a,b] if a < b else [b,a]
			edges[key] = int(edges.get(key, 0)) + 1
	var open := []
	for edge: Array in edges:
		if edges[edge] != 1:
			continue
		var mid: Vector3 = (edge[0] + edge[1]) * .5
		var q := Vector2(mid.x,mid.z)
		if area.grow(-1).has_point(q) and mid.y > field.envelope().ground_node(q) + .1:
			open.append(edge)
	var out := "res://docs/qa/2026-09-26-manual-cliffs/probe-%s.var" % variant
	var file := FileAccess.open(out,FileAccess.WRITE)
	file.store_var({"area":area,"faces":faces,"open":open,"downward":downward})
	print("[cliff_manual_probe] %s triangles=%d open=%d downward=%d" % [variant,faces.size()/3,open.size(),downward])
	for i in mini(12,open.size()): print("  open ",open[i])
