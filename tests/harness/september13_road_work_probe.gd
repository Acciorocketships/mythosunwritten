extends SceneTree
const Nodes = preload("res://tests/test_path_plan_nodes.gd")
class Measured extends PathPlan:
	func _compute_route(a:Dictionary,b:Dictionary,key:String)->Dictionary:
		var started := Time.get_ticks_msec()
		print("ROUTE_BEGIN ",a.cell," -> ",b.cell)
		var result := super._compute_route(a,b,key)
		print("ROUTE_END ",key," ms=",Time.get_ticks_msec()-started)
		return result
func _init()->void:
	var fixture := Nodes.new()
	var source := fixture._plan()
	fixture.free()
	var paths := Measured.new(4242,source._water_plan,source._fields,source._program,source._program.query_margin,source._settlements)
	var started := Time.get_ticks_msec()
	var context := paths.context_for(Vector2i.ZERO)
	print("CONTEXT_END ms=",Time.get_ticks_msec()-started," masks=",context.connection_masks.size()," stats=",paths.stats())
	quit()
