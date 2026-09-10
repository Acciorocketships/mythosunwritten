extends GutTest

func test_startup_has_ground_for_the_first_chunk_of_travel_in_any_direction()->void:
	for spawn:Vector3 in [Vector3(287.4,5,-1238),Vector3(0.5,0,0.5),Vector3(-192.01,0,191.99)]:
		var chunks:=FieldTerrainStreamer.support_chunks_at(spawn)
		for direction:Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(-1,1).normalized()]:
			for metres:float in [0.0,96.0,191.0]:
				var point:=spawn+Vector3(direction.x,0,direction.y)*metres
				assert_true(chunks.has(FieldTerrainStreamer.chunk_of(point)),
					"startup must cover the first %.0f m from %s toward %s" % [metres,spawn,direction])
