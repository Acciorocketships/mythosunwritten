extends SceneTree

const Terraces = preload("res://scripts/terrain/field/CliffTerraces.gd")
const Controller = preload("res://tests/harness/september13_terrace_jump.gd").JumpController

func _init() -> void: _run.call_deferred()

func _run() -> void:
	Terraces.prepare()
	var plan := HeightfieldPlan.new(17,128,32,"mean",4)
	plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 32.0 if cx<=3 else 0.0)
	var region := plan.compute_region(4,4,12)
	var actor := (load("res://characters/character.tscn") as PackedScene).instantiate()
	root.add_child(actor)
	actor.set_physics_process(false)
	var control := Controller.new()
	actor.controller = control
	var rows := []
	for seed_value in [99,19]:
		var data := Terraces.compute(region,0,0,8,seed_value)
		var selected: Dictionary = {}
		for p: Dictionary in data.placements:
			if p.get("layers",[]).size()==2:
				selected=p
				break
		assert(not selected.is_empty())
		var anchor: Vector2 = Vector2(selected.transform.origin.x,selected.transform.origin.z)-selected.outward*.5
		var outward: Vector2 = selected.outward
		var tangent := Vector2(-outward.y,outward.x)
		var columns: Array = [selected]+selected.layers
		for turn in 4:
			var stage := Node3D.new()
			root.add_child(stage)
			var faces := PackedVector3Array()
			for column: Dictionary in columns: Terraces._append_collision_faces(faces,column.asset,column.transform)
			for i in faces.size(): faces[i]-=Vector3(anchor.x,0,anchor.y)
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var mesh := ConcavePolygonShape3D.new()
			mesh.set_faces(faces)
			shape.shape=mesh
			body.add_child(shape)
			stage.add_child(body)
			# The same high-side terrain bearing and lower flat ground as the
			# production step fixture; native stock collision remains untouched.
			for high in [false,true]:
				var solid := StaticBody3D.new()
				var collider := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size=Vector3(80,32 if high else 2,80)
				collider.shape=box
				collider.position=Vector3(-40 if high else 0,16 if high else -1,0)
				solid.add_child(collider)
				stage.add_child(solid)
			stage.rotation.y=turn*PI*.5
			for level in 3:
				var target: Dictionary=columns[level]
				var position := outward*(4.3 if level==0 else 2.7)
				var direction := -outward
				if level==1:position+=tangent*3.0
				if level==2:
					position=outward*.6+tangent*3.2
					direction=-tangent
				var pose := Vector3(position.x,float(target.base)+.03,position.y).rotated(Vector3.UP,stage.rotation.y)
				var move := Vector3(direction.x,0,direction.y).rotated(Vector3.UP,stage.rotation.y)
				actor.global_position=pose
				actor.velocity=Vector3.ZERO
				control.direction=Vector2(move.x,move.z)
				control.jumping=false
				for tick in 40:
					await physics_frame
					actor._physics_process(1.0/60)
				var start: Vector3=actor.global_position
				var highest:=start.y
				var ceiling:=0
				var reached:=false
				for tick in 100:
					control.jumping=tick==0
					var current: Vector3=stage.to_local(actor.global_position)
					var travel_axis: Vector2=tangent if level==2 else outward
					if Vector2(current.x,current.z).dot(travel_axis)<(.6 if level==2 else (.7 if level==1 else 2.5)):
						control.direction=Vector2.ZERO
					await physics_frame
					actor._physics_process(1.0/60)
					highest=maxf(highest,actor.global_position.y)
					for c in actor.get_slide_collision_count():
						if actor.get_slide_collision(c).get_normal().y<-.05:ceiling+=1
					if actor.is_on_floor() and actor.global_position.y>=target.top-.1:
						reached=true
						break
				var row:={"seed":seed_value,"turn":turn,"level":level,"asset":target.asset,"rise":target.top-target.base,"start":str(start),"end":str(actor.global_position),"highest":highest,"reached":reached,"ceiling_contacts":ceiling}
				rows.append(row)
				print("STACK_JUMP ",JSON.stringify(row))
			stage.free()
			await physics_frame
	var output:="res://docs/qa/2026-09-13-manual/25-cliff-hierarchy/stack-jumps.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
