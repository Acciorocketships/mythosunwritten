extends GutTest

func test_native_lantern_batches_emit_one_warm_light_per_placement() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var queue := EnvironmentCommitQueue.new(cache,&"Visuals")
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	var ids: Array[StringName] = [&"sfv.light_pole.001",&"lpfv.fabric.prop.lantern.table.01",&"lpfv.fabric.prop.lantern.post.02"]
	for id in ids:
		for turn in 4:
			payload.add(id,Transform3D(Basis(Vector3.UP,turn*PI/2)*2.0,Vector3(turn*8,0,0)),Color.WHITE)
	queue.register_chunk(Vector2i.ZERO,1)
	queue.enqueue(Vector2i.ZERO,1,parent,payload)
	queue.drain(100)
	var lights := parent.find_children("*","OmniLight3D",true,false)
	assert_eq(lights.size(),12,"Multiple native mesh pieces must not duplicate the same lamp's light")
	for light: OmniLight3D in lights:
		assert_gte(light.omni_range,12.0,"Lanterns cast a broad pool in world metres")
		assert_gt(light.light_color.r,light.light_color.b,"The pool is warm")
		assert_false(light.shadow_enabled,"Distant decorative lights do not add shadow passes")
		assert_true(light.distance_fade_enabled)

func test_native_pane_centres_anchor_the_lights_under_scaled_rotation() -> void:
	var adapter = load("res://scripts/terrain/environment/EnvironmentLanternLights.gd")
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	for id: StringName in [&"lpfv.fabric.prop.lantern.table.01",&"lpfv.fabric.prop.lantern.post.02"]:
		var piece := cache.visual(id).pieces[0]
		var arrays := piece.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var pane_points := PackedVector3Array()
		for i in vertices.size():
			if uvs[i].x>0.34375 and uvs[i].x<0.375 and uvs[i].y>0.0 and uvs[i].y<0.03125:
				pane_points.append(piece.local_transform*vertices[i])
		assert_gt(pane_points.size(),8,"The private glass swatch must identify actual native panes")
		var bounds := AABB(pane_points[0],Vector3.ZERO)
		for point in pane_points: bounds=bounds.expand(point)
		for turn in 4:
			var parent := Node3D.new()
			var pose := Transform3D(Basis(Vector3.UP,turn*PI/2.0)*2.0,Vector3(17,3,-9))
			adapter.attach(parent,id,[pose])
			assert_lt(parent.get_child(0).position.distance_to(pose*bounds.get_center()),0.00001,"Warm light is inside the measured panes")
			parent.free()
