extends RefCounted
## F3 readouts of the September 22 manual photos (seed 2697992464).
const SPOTS := {
	"photo1": {"town": "town-e", "feet": Vector3(295.6, 20.4, 1107.8), "aim": Vector3(294.6, 21.4, 1106.0)},
	"photo2": {"town": "town-e", "feet": Vector3(323.0, 12.0, 1107.6), "aim": Vector3(320.6, 14.6, 1105.5)},
	"photo3": {"town": "town-n02", "feet": Vector3(-228.2, 15.1, 440.7), "aim": Vector3(-228.2, 15.1, 433.2)},
	"photo4": {"town": "town-e", "feet": Vector3(339.6, 12.0, 1069.3), "aim": Vector3(338.6, 15.1, 1066.8)},
	"photo5": {"town": "town-e", "feet": Vector3(316.4, 20.5, 1108.0), "aim": Vector3(314.5, 19.4, 1102.0)},
}
const SIZE := Vector2i(1776, 996)

## Close mouse-view camera reconstructed from the F3 player/crosshair readout.
static func eye(feet: Vector3, aim: Vector3) -> Vector3:
	var pivot := feet + Vector3.UP * CameraMouseView.PIVOT_HEIGHT
	var backward := (pivot - aim).normalized()
	return ReviewCam.solve_cam(feet, aim, Vector2(backward.x, backward.z).length() * CameraMouseView.BOOM_LENGTH,
		CameraMouseView.PIVOT_HEIGHT + backward.y * CameraMouseView.BOOM_LENGTH, CameraMouseView.PIVOT_HEIGHT)

static func pivot(feet: Vector3) -> Vector3:
	return feet + Vector3.UP * CameraMouseView.PIVOT_HEIGHT

static func town_photos(town: String) -> Array:
	var names := []
	for name: String in SPOTS:
		if SPOTS[name].town == town: names.append(name)
	names.sort()
	return names

## The game's close camera: ceilings lower the pivot and collision shortens
## the boom (CameraMouseView.update_view). Returns {pivot, eye}.
static func resolved(space: PhysicsDirectSpaceState3D, feet: Vector3, aim: Vector3,
		excluded: Array[RID] = []) -> Dictionary:
	var solver := CameraObstructionSolver.new()
	var pivot := solver.resolve_ceiling(space, feet, 1.0, CameraMouseView.PIVOT_HEIGHT, excluded)
	var direction := (pivot - aim).normalized()
	var eye := solver.resolve_boom(space, pivot, pivot + direction * CameraMouseView.BOOM_LENGTH, excluded)
	return {"pivot": pivot, "eye": eye}
