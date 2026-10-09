extends SceneTree


class ReferenceSampler:
	extends WaterSampler

	func _current_fill_level_at(p: Vector2) -> float:
		return _native_fill_level_at(p)


class ReferenceGround:
	extends WaterGroundSnapshot

	func water_surface_y(x: float, z: float) -> float:
		return TerrainTileField.surface_y(self, x, z)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var results := []
	for reference: bool in [true, false, true, false]:
		var state: Dictionary = bytes_to_var(
			(
				FileAccess
				. get_file_as_bytes("res://tests/fixtures/october9/ripple-late-update.bin.gz")
				. decompress_dynamic(32 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
			)
		)
		var sim := WaterRippleSim.new()
		for row: Dictionary in state.samplers:
			var sampler: WaterSampler = ReferenceSampler.new() if reference else WaterSampler.new()
			if row._fill_ctx.has("region"):
				var snapshot: WaterGroundSnapshot = (
					ReferenceGround.new() if reference else WaterGroundSnapshot.new()
				)
				for key: String in row._fill_ctx.region:
					snapshot.set(key, row._fill_ctx.region[key])
				row._fill_ctx.region = snapshot
			for key: String in row:
				sampler.set(key, row[key])
			sim._samplers.append(sampler)
		sim._packets.assign(state.packets)
		sim._packet_n = state.packet_n
		sim._packet_timer = state.packet_timer
		sim._packet_origin = state.packet_origin
		var times := []
		var motion := HashingContext.new()
		motion.start(HashingContext.HASH_SHA256)
		for frame in 600:
			var start := Time.get_ticks_usec()
			sim._update_packets(1.0 / 60.0)
			times.append(Time.get_ticks_usec() - start)
			motion.update(var_to_bytes([sim._packets, sim._packet_n, sim._packet_timer]))
		times.sort()
		var total := 0
		for elapsed: int in times:
			total += elapsed
		var row := {
			"reference": reference,
			"mean_ms": total / 600000.0,
			"p95_ms": times[570] / 1000.0,
			"max_ms": times[-1] / 1000.0,
			"digest": motion.finish().hex_encode()
		}
		results.append(row)
		print("RIPPLE_REPLAY ", JSON.stringify(row))
		sim.free()
	assert(
		(
			results[0].digest == results[1].digest
			and results[1].digest == results[2].digest
			and results[2].digest == results[3].digest
		)
	)
	quit()
