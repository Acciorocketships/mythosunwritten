extends CharacterBody3D

# ---------- Inspector ----------
@export var MAX_SPEED := 10.0
@export var TURN_SPEED := 14.0
@export var TURN_SPEED_AIR := 1.0
@export var ACCEL := 50.0
@export var ACCEL_AIR := 12.0
@export var FRICTION := 500.0
@export var JUMP_VELOCITY := 13.0

# Bone names you expect (only used if your attachments don't already have one)
@export var RIGHT_HAND_BONE := "handslot.r"
@export var LEFT_HAND_BONE  := "handslot.l"
@export var SPINE_BONE      := "spine"

# Pluggable controller (see below: PlayerController / AIController)
@export var controller: CharacterController

# ---------- Node Refs ----------
@onready var body_model_root: Node3D            = $Body
@onready var anim_player: AnimationPlayer       = $AnimationPlayer
@onready var anim_tree: AnimationTree           = $AnimationTree
@onready var left_hand: BoneAttachment3D        = $Hands/LeftHand
@onready var right_hand: BoneAttachment3D       = $Hands/RightHand
@onready var spine: BoneAttachment3D            = $Spine
@onready var spine_hitbox: Area3D               = $Spine/SpineHitbox

# ---------- Runtime ----------
var body: Node3D
var skeleton: Skeleton3D
var collision_shape: CollisionObject3D
var raycast: RayCast3D
var on_ground: bool = true
var was_on_ground: bool = false

func _ready() -> void:
	_setup_player_controller()
	_cache_body_and_skeleton()
	_wire_animations()
	_bind_all_attachments()

# --------------------------------------------
# Movement
# --------------------------------------------
func _physics_process(delta: float) -> void:
	assert(controller, "Assign a controller")

	# inputs (already camera-rotated by controller)
	var mv2: Vector2 = controller.get_move_vector(self, delta)
	var wants_jump := controller.wants_jump(self, delta)

	# gravity + jump
	on_ground = is_on_floor() or _get_ground_dist() < 0.2
	var started_animation: bool = !on_ground and was_on_ground
	was_on_ground = on_ground
	
	jump_animation(started_animation)
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif wants_jump: # TODO: add a mechanism to allow jump if we recently walked off a ledge (falling without having jumped, low negative vertical velocity)
		velocity += Vector3(mv2.x / 3, 1.0, mv2.y / 3).normalized() * JUMP_VELOCITY

	# desired direction & facing
	var desired_dir := Vector3(mv2.x, 0.0, mv2.y)
	var has_input := desired_dir.length() > 0.001
	if has_input:
		desired_dir = desired_dir.normalized()
		var target_yaw := atan2(desired_dir.x, desired_dir.z)
		var turn_speed: float = TURN_SPEED if on_ground else TURN_SPEED_AIR
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

	# accel/ friction on XZ
	var target_speed := MAX_SPEED * mv2.length()
	var target_vxz := desired_dir * target_speed
	var vxz := Vector2(velocity.x, velocity.z)
	var tv := Vector2(target_vxz.x, target_vxz.z)
	var changing_direction: bool = vxz.dot(tv) < 0.8
	var rate: float = ACCEL
	if !on_ground:
		rate = ACCEL_AIR
	elif !has_input or changing_direction:
		rate = FRICTION
	vxz = vxz.move_toward(tv, rate * delta)
	velocity.x = vxz.x
	velocity.z = vxz.y

	move_and_slide()
	movement_animation(target_speed)


func jump_animation(started_animation: bool):
	var vertical_vel: float = velocity.y
	var is_near_ground: bool = raycast.is_colliding()
	var state_machine = anim_tree.get("parameters/BlendTree/OneShots/playback")
	if started_animation:
		state_machine.travel("JumpStart")
		anim_tree.set("parameters/BlendTree/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if vertical_vel < 0 and is_near_ground:
		state_machine.travel("JumpLand")
		
	
func movement_animation(speed: float):
	var amount = speed / MAX_SPEED
	if anim_tree.get("parameters/BlendTree/OneShot/active") and amount > 0 and on_ground:
		anim_tree.set("parameters/BlendTree/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	anim_tree.set("parameters/BlendTree/WalkRun/blend_position", amount)
	anim_tree.set("parameters/BlendTree/RunSpeed/scale", 1 + amount)
	

# --------------------------------------------
# Wiring
# --------------------------------------------

func _setup_player_controller():
	assert(controller, "Assign a controller")
	if controller is PlayerController:
		(controller as PlayerController)._set_player(self)
	

func _cache_body_and_skeleton() -> void:
	body = _first_child_node3d(body_model_root)
	assert(body, "No model found under $Body. Put your Knight (or other) as a child of Body.")
	skeleton = body.get_node("Rig_Medium/Skeleton3D") as Skeleton3D
	assert(skeleton, "Model must contain a Skeleton3D (e.g. Rig_Medium/Skeleton3D).")
	raycast = self.get_node("CollisionShape3D/RayCast3D")


func _wire_animations() -> void:
	# Make animation track paths resolve inside the actual model instance
	anim_player.root_node = body.get_path()
	# Tie the AnimationTree to this player
	anim_tree.anim_player = anim_player.get_path()
	anim_tree.active = true

func _bind_all_attachments() -> void:
	_bind_attachment(left_hand, LEFT_HAND_BONE)
	_bind_attachment(right_hand, RIGHT_HAND_BONE)
	_bind_attachment(spine,     SPINE_BONE)

func _bind_attachment(att: BoneAttachment3D, bone_name: String) -> void:
	if att == null: return
	att.use_external_skeleton = true
	att.external_skeleton = skeleton.get_path()
	att.bone_name = bone_name

# --------------------------------------------
# Model swapping
# --------------------------------------------
func swap_model(new_model: PackedScene) -> void:
	assert(new_model, "swap_model: new_model is required")

	var old := _first_child_node3d(body_model_root)
	var xform := old.transform if old else Transform3D.IDENTITY
	if old:
		body_model_root.remove_child(old)
		old.queue_free()

	var inst := new_model.instantiate() as Node3D
	inst.transform = xform
	body_model_root.add_child(inst)

	_cache_body_and_skeleton()
	_wire_animations()
	_bind_all_attachments()

# --------------------------------------------
# Helpers
# --------------------------------------------
func _first_child_node3d(parent: Node) -> Node3D:
	for c in parent.get_children():
		if c is Node3D:
			return c
	return null
	
func _get_ground_dist() -> float:
	var is_nearby: bool = raycast.is_colliding()
	if is_nearby:
		var point: Vector3 = raycast.get_collision_point()
		var dist: float = (point - raycast.global_position).length()
		return dist
	return INF
