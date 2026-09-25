extends GutTest
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const OLD=preload("res://tests/fixtures/september19/cliff-commit/baseline_crags.gd")
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")

func test_worker_prepares_exact_render_arrays_without_changing_the_formation() -> void:
	var generator:GDScript=CRAGS
	assert_true(generator.has_method("mesh_arrays"),"Normal preparation must leave the main-thread commit")
	if not generator.has_method("mesh_arrays"):return
	ROCKS.prepare();OLD.prepare()
	var entries:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
	var forms:Array[Dictionary]=[]
	for index in [0,4]:
		var e:Array=entries[index]
		forms.append(CRAGS.make(e[0],e[1],e[2],2697992464,null,e[3],e[4])[0])
	forms.append(CORNER.make(Transform3D(Basis.IDENTITY,Vector3(-445.5,32,-253.5)),8,2697992464))
	for rock:Dictionary in forms:
		var before:=var_to_bytes(rock)
		var old_mesh:ArrayMesh=OLD.mesh(rock)
		var worker:=Thread.new()
		assert_eq(worker.start(func()->Array:return generator.call("mesh_arrays",rock)),OK)
		var prepared:Array=worker.wait_to_finish()
		assert_eq(var_to_bytes(rock),before,"Worker preparation must not reshape collision or mutate source data")
		rock["render_arrays"]=prepared
		var new_mesh:ArrayMesh=CRAGS.mesh(rock)
		assert_eq(new_mesh.get_surface_count(),old_mesh.get_surface_count())
		for surface in old_mesh.get_surface_count():
			# September 23: rock surfaces add a UV2 moss-height channel; every
			# array the baseline had must still be byte-identical.
			var fresh:Array=new_mesh.surface_get_arrays(surface)
			if surface==0:fresh[Mesh.ARRAY_TEX_UV2]=null
			assert_eq(var_to_bytes(fresh),var_to_bytes(old_mesh.surface_get_arrays(surface)),"Native rendered vertices, normals, colour and UVs must be byte-identical")

func test_ordinary_chunk_payload_already_contains_cliff_render_arrays() -> void:
	var plan:=HeightfieldPlan.new(7,56.0,12,"mean",4)
	plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 24.0 if cx<=3 else 0.0)
	var mesher:=TerrainChunkMesher.new();mesher.prepare_resources()
	var payload:=mesher.compute_chunk(Vector2i.ZERO,plan.compute_region(4,4,8))
	var prepared:=0;var missing:=0
	for rock:Dictionary in payload.cliff_terraces.placements:
		if not rock.get("native_crag",false):continue
		prepared+=1
		if not rock.has("render_arrays"):missing+=1
	assert_gt(prepared,0,"Exercise actual generated cliff solids")
	assert_eq(missing,0,"Ordinary publication must never rebuild cliff normals in commit")
