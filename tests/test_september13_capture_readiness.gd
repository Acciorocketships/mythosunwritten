extends GutTest

func test_capture_waits_until_the_last_native_wall_and_generated_surface_exist() -> void:
	var capture := preload("res://tests/harness/village_reported_qa.gd").new()
	var streamer := FieldTerrainStreamer.new()
	capture._streamer = streamer
	streamer._feature_program = FeatureProgram.new()
	streamer._feature_program.geometry_halo = 0
	streamer._startup_completion_emitted = true
	streamer._built[Vector2i.ZERO] = true
	streamer._feature_generation[Vector2i.ZERO] = 1
	var queue := FeatureCommitQueue.new(EnvironmentRenderCache.new(EnvironmentCatalog.load_default()))
	streamer._feature_queue = queue
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	for asset: StringName in [&"sfv.fabric.wall.wood.window.001", &"sfv.fabric.wall.wood.window.040"]:
		payload.add(asset,Transform3D.IDENTITY,Color.WHITE,asset)
	payload.add_surface_mesh(TerrainChunkMesher.flat_ground_surface({Vector3i.ZERO:true},1.5,0,&"capture-floor"))
	queue.enqueue(Vector2i.ZERO,1,parent,payload)
	var events := []
	for tick in 10:
		events = queue.drain(4,100,0)
		if not events.is_empty(): break
	assert_eq(events.size(),1)
	streamer._feature_ready[Vector2i.ZERO] = 1
	assert_true(streamer._feature_square_ready(Vector2i.ZERO),"Collision readiness is intentionally earlier than visual completion")
	assert_false(capture._capture_ready([Vector2i.ZERO],false),"Do not freeze a world with all its visual batches still queued")
	queue.drain(0,0,2)
	assert_eq(parent.find_children("*","MeshInstance3D",true,false).size(),1)
	assert_eq(parent.find_children("*","MultiMeshInstance3D",true,false).size(),1)
	assert_false(capture._capture_ready([Vector2i.ZERO],false),"The final native window panel still has to commit")
	queue.drain(0,0,2)
	assert_eq(parent.find_children("*","MultiMeshInstance3D",true,false).size(),2)
	assert_true(capture._capture_ready([Vector2i.ZERO],false),"A complete rendered site may be captured")
	assert_false(capture._capture_ready([Vector2i.ZERO],true),"Worker activity still vetoes capture")
	streamer._built.clear()
	streamer.free()
	capture.free()
