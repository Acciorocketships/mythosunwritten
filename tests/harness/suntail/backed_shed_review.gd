extends "res://tests/harness/pure_village_lineup.gd"
const AUDIT = preload("res://tests/fixtures/kit_roof_audit.gd")
func _run() -> void:
	root.size=Vector2i(1200,900)
	for kit in [SuntailBuildingKit.create(),preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()]:
		for before in [true,false]:
			var stage:=Node3D.new()
			root.add_child(stage)
			_light(stage)
			var mass=load("res://tests/test_backed_shed_roofs.gd").mass_at_step()
			var designer=load("res://docs/qa/2026-10-01-town-redesign/prefab-grammar/october5-backed-shed-study/before_designer.gd").new(kit) if before else BuildingDesigner.new(kit)
			designer.forbidden=func(cell:Vector2i,_band:int)->bool:return not Rect2i(0,0,2,3).has_point(cell)
			designer._assign_roofs(mass,designer._rng(8),&"red")
			var built:=AUDIT.assemble([mass],kit)
			var payload:=EnvironmentInstancePayload.new()
			AUDIT.UNION.append(built.placements,built.roofs,built.walls,kit,Transform3D.IDENTITY,payload)
			var cache:=EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
			assert(cache.prepare(payload.asset_ids()))
			var queue:=FeatureCommitQueue.new(cache)
			queue.enqueue(Vector2i.ZERO,1,stage,payload)
			while queue.pending_count()>0:
				queue.drain(100000,100000,100000)
				await process_frame
			var label="%s_%s" %[kit.kit_id,"before" if before else "after"]
			await _shoot(stage,Vector3(13,9,15),Vector3(2,4,3),label+"_front")
			await _shoot(stage,Vector3(-10,6,11),Vector3(2,4,3),label+"_side")
			stage.queue_free()
			await process_frame
	quit()
