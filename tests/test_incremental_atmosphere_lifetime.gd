extends GutTest
func test_attached_chunk_keeps_pending_ownership_until_its_fx_steps_finish()->void:
	var streamer:=FieldTerrainStreamer.new()
	var chunk:=Vector2i(2,3)
	var result:Dictionary={"chunk":chunk,"terrain_generation":1}
	var stale:Dictionary={"chunk":Vector2i(20,20),"terrain_generation":1}
	streamer._terrain_generation[chunk]=1
	streamer._built[chunk]=Node3D.new()
	streamer._pending_terrain.assign([result,stale])
	streamer._integrating={"result":result,"index":1}
	streamer._prune_pending_terrain(chunk)
	assert_eq(streamer._pending_index_of(result),0,"the next frame must resume the atmosphere steps")
	assert_eq(streamer._pending_terrain.size(),1)
	assert_true(is_same(streamer._drop_box[0],stale))
	streamer._built[chunk].free()
	streamer._built.clear()
	streamer._integrating={}
	streamer.free()
