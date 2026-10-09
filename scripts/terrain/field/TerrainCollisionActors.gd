extends RefCounted

var _tree: SceneTree
var _actors: Dictionary = {}
var _held: Dictionary = {}

func start(tree: SceneTree) -> void:
	_tree = tree
	_tree.node_added.connect(_added)
	for node: Node in tree.root.find_children("*","PhysicsBody3D",true,false): _added(node)

func _added(node: Node) -> void:
	if node is CharacterBody3D or node is RigidBody3D:
		_actors[node.get_instance_id()] = weakref(node)

func interests() -> PackedVector3Array:
	var points := PackedVector3Array()
	for id: int in _actors.keys():
		var actor := (_actors[id] as WeakRef).get_ref() as PhysicsBody3D
		if actor == null or not actor.is_inside_tree():
			_actors.erase(id)
			continue
		points.append(actor.global_position)
		var velocity: Vector3 = actor.velocity if actor is CharacterBody3D else actor.linear_velocity
		points.append(actor.global_position+(velocity*30.0).limit_length(192.0))
	return points

func guard_except(player: Node, ready: Callable) -> void:
	for id: int in _actors.keys():
		var actor := (_actors[id] as WeakRef).get_ref() as PhysicsBody3D
		if actor == null or not actor.is_inside_tree() or actor == player: continue
		if ready.call(actor.global_position):
			_release(id)
		elif not _held.has(id):
			var record := {"node":weakref(actor),"mode":actor.process_mode}
			if actor is RigidBody3D:
				record["freeze"] = actor.freeze
				actor.freeze = true
			_held[id] = record
			actor.process_mode = Node.PROCESS_MODE_DISABLED
	for id: int in _held.keys():
		var node := (_held[id].node as WeakRef).get_ref() as Node
		if node == null or not node.is_inside_tree(): _release(id)

func _release(id: int) -> void:
	if not _held.has(id): return
	var record: Dictionary = _held[id]
	var actor := (record.node as WeakRef).get_ref() as PhysicsBody3D
	if actor != null:
		actor.process_mode = record.mode
		if actor is RigidBody3D: actor.freeze = record.freeze
	_held.erase(id)

func stop() -> void:
	if _tree != null and _tree.node_added.is_connected(_added): _tree.node_added.disconnect(_added)
	for id: int in _held.keys(): _release(id)
	_actors.clear()
	_tree = null
