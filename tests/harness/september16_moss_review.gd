extends "res://tests/harness/september16_manual_qa.gd"
# Material ownership replay: identical final vertices, collision and poses.
func _capture_views(world: Node3D) -> void:
	if "--original-materials" in OS.get_cmdline_user_args() or "--current-geometry" in OS.get_cmdline_user_args():
		await super._capture_views(world)
		return
	var rocks = preload("res://scripts/terrain/field/CliffRockDressing.gd")
	rocks.prepare()
	var replaced := 0
	for node: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
		var source := node.multimesh.mesh
		for asset: StringName in rocks._visuals:
			if asset in rocks.PLANTS: continue
			for piece: EnvironmentVisualPiece in rocks._visuals[asset].pieces:
				if not source.get_aabb().is_equal_approx(piece.mesh.get_aabb()) or source.get_faces().size() != piece.mesh.get_faces().size(): continue
				# The asset family includes quarter-turn variants: compare the
				# complete vertex multiset rather than just counts and bounds.
				var old_points := Array(source.get_faces()); old_points.sort()
				var new_points := Array(piece.mesh.get_faces()); new_points.sort()
				if old_points != new_points: continue
				node.multimesh.mesh = piece.mesh
				replaced += 1
	print("MOSS_REPLAY batches=",replaced)
	assert(replaced > 0)
	await super._capture_views(world)
