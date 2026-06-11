extends MeshInstance3D
## Single world-space water sheet. All visible water shares this one surface,
## so there are no per-tile mesh seams (per-tile planes used to overlap with
## mismatched vertex lattices, and their displaced surfaces interpenetrated
## along tile borders). The shader's waves and UVs are pure functions of world
## position, so the sheet can follow the active camera; its position is
## snapped to the vertex grid so the sampling lattice never slides relative to
## the world (which would make the wave surface shimmer).
##
## The sheet sits below ground level: land tiles (slabs from y=0 down to
## -0.5) occlude it everywhere except inside water basins, whose bank walls
## drop past it to the water floor.

## Must equal PlaneMesh size / (subdivisions + 1).
const CELL_SIZE: float = 3.0
## Water surface height for tiles on the ground grid (WaterTile origin y=0).
const SURFACE_Y: float = -1.5


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	global_position = Vector3(
		snappedf(camera.global_position.x, CELL_SIZE),
		SURFACE_Y,
		snappedf(camera.global_position.z, CELL_SIZE)
	)
