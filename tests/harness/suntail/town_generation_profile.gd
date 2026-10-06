extends SceneTree
## Identical CPU-stage measurement usable in current and baseline checkouts.
## Run this file by absolute path with either checkout's --path. Native kit
## resources are loaded from that checkout; no rendering or terrain is timed.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[args.find("--output")+1] if args.has("--output") else "/tmp/town-generation-profile.json"
	var begin := Time.get_ticks_msec()
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var setup := Time.get_ticks_msec()-begin
	var rows: Array = []
	for job: Array in [[1260018864828801968,&"compact"],[3,&"standard"],[34,&"large"],[13,&"grand"]]:
		begin = Time.get_ticks_msec()
		var source := WarrenMazeSitePlanner.plan(job[0],{},WarrenVillageScaleProfile.for_id(job[1]),&"",false)
		assert(source != null)
		var planned := Time.get_ticks_msec()
		var spatial := preload("res://tests/fixtures/frozen_maze_source.gd").spatial(source,program)
		assert(spatial != null)
		var composed := Time.get_ticks_msec()
		var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create())
		var finished := Time.get_ticks_msec()
		var triangles := 0
		for mesh: Dictionary in built.payload.surface_meshes:
			triangles += (mesh.get("indices",PackedInt32Array()) as PackedInt32Array).size()/3
		var row := {"seed":str(job[0]),"profile":job[1],"plan_ms":planned-begin,
			"compose_ms":composed-planned,"kit_ms":finished-composed,"total_ms":finished-begin,
			"instances":built.payload.instance_count,"procedural_triangles":triangles,
			"houses":built.masses.size(),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}
		rows.append(row)
		print("TOWN_PROFILE ",JSON.stringify(row))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"setup_ms":setup,"towns":rows},"  "))
	quit()
