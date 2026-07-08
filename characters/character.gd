extends CharacterBody3D

# ---------- Inspector ----------
@export var MAX_SPEED := 10.0
@export var TURN_SPEED := 14.0
@export var TURN_SPEED_AIR := 1.0
@export var ACCEL := 50.0
@export var ACCEL_AIR := 12.0
@export var FRICTION := 500.0
@export var JUMP_VELOCITY := 13.0
@export var MAX_STEP_HEIGHT := 0.5

# ---------- Swimming ----------
# Water tiles expose an Area3D volume on WATER_LAYER. While the character's
# probe point is inside one it swims with force-based control: buoyancy
# proportional to the submerged fraction of the body counteracts gravity
# (slightly losing when fully submerged, so idling sinks slowly), holding
# jump adds a constant upward kick. The body rising out of the water loses
# buoyancy and falls back in, so bobbing emerges naturally. Pressing toward
# a nearby bank wall with jump launches the character out of the water.
const WATER_LAYER_MASK: int = 1 << 7
# Fallback surface for legacy water volumes that carry no surface_y meta
# (the old flat-sheet water). Field-terrain volumes always set the meta.
const WATER_SURFACE_Y: float = -1.5
var water_surface_y: float = WATER_SURFACE_Y
# CPU mirror of the water shader's swell so the floating body RIDES the waves
# (buoyancy tracks the displaced surface — rocking, like a boat). Keep in sync
# with water_wave_h in terrain/water/water_common.gdshaderinc and the
# wave_height/wave_speed uniform defaults in water_unified.gdshader (the noise
# drift term is omitted — the travelling sines carry most of the swell).
# Mirrors water_unified.gdshader's wave_height / wave_speed — keep in sync.
const SWELL_HEIGHT: float = 1.15
const SWELL_SPEED: float = 0.26
@export var SWIM_SPEED_FACTOR := 0.45
@export var SWIM_ACCEL := 6.0  # sluggish, momentum-y direction changes
@export var BODY_HEIGHT := 1.4  # submersion span used for buoyancy
@export var BUOYANCY := 17.0  # < gravity (18) fully submerged: idle = slow sink
@export var SWIM_THRUST := 8.0  # extra upward force while holding jump
@export var WATER_LINEAR_DRAG := 1.4
@export var MAX_SWIM_RISE := 2.5
@export var MAX_SWIM_SINK := 4.0
@export var WATER_EXIT_PROBE := 1.3  # how far ahead a bank wall triggers the leap

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
var step_visual_offset_y: float = 0.0
var body_model_base_pos: Vector3 = Vector3.ZERO
var prev_body_global_y: float = 0.0
var in_water: bool = false

func _ready() -> void:
	_setup_player_controller()
	_cache_body_and_skeleton()
	_wire_animations()
	_bind_all_attachments()
	body_model_base_pos = body_model_root.position
	prev_body_global_y = global_position.y

# --------------------------------------------
# Movement
# --------------------------------------------
func _physics_process(delta: float) -> void:
	assert(controller, "Assign a controller")

	# inputs (already camera-rotated by controller)
	var mv2: Vector2 = controller.get_move_vector(self, delta)
	var wants_jump := controller.wants_jump(self, delta)

	_update_in_water()

	# gravity + jump (or buoyancy while swimming)
	on_ground = is_on_floor() or _get_ground_dist() < 0.2
	var started_animation: bool = !on_ground and was_on_ground and not in_water
	was_on_ground = on_ground
	
	jump_animation(started_animation)
	if in_water:
		_swim_vertical(delta, wants_jump)
	elif not is_on_floor():
		velocity += get_gravity() * delta
	elif wants_jump: # TODO: add a mechanism to allow jump if we recently walked off a ledge (falling without having jumped, low negative vertical velocity)
		velocity += Vector3(mv2.x / 3, 1.0, mv2.y / 3).normalized() * JUMP_VELOCITY

	# desired direction & facing
	var desired_dir := Vector3(mv2.x, 0.0, mv2.y)
	var has_input := desired_dir.length() > 0.001
	if has_input:
		desired_dir = desired_dir.normalized()
		var target_yaw := atan2(desired_dir.x, desired_dir.z)
		var turn_speed: float = TURN_SPEED if (on_ground or in_water) else TURN_SPEED_AIR
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

	# accel/ friction on XZ
	var max_speed: float = MAX_SPEED * SWIM_SPEED_FACTOR if in_water else MAX_SPEED
	var target_speed := max_speed * mv2.length()
	var target_vxz := desired_dir * target_speed
	var vxz := Vector2(velocity.x, velocity.z)
	var tv := Vector2(target_vxz.x, target_vxz.z)
	var changing_direction: bool = vxz.dot(tv) < 0.8
	var rate: float = ACCEL
	if in_water:
		rate = SWIM_ACCEL
	elif !on_ground:
		rate = ACCEL_AIR
	elif !has_input or changing_direction:
		rate = FRICTION
	vxz = vxz.move_toward(tv, rate * delta)
	velocity.x = vxz.x
	velocity.z = vxz.y

	var did_step: bool = _try_step_up(delta)
	if not did_step:
		move_and_slide()
	_update_step_visual_smoothing(delta)
	movement_animation(target_speed)


# Swimming verticals, force based: gravity always pulls; buoyancy pushes up
# in proportion to how much of the body is under the surface; holding jump
# adds a constant kick. As the body rises out it loses buoyancy and drops
# back in — the bobbing falls out of the physics. Drag keeps speeds low and
# damps the splash-in plunge.
func _swim_vertical(delta: float, wants_jump: bool) -> void:
	if _try_water_exit(wants_jump, delta):
		return
	var submerged: float = clampf(
		(water_surface_y - global_position.y) / BODY_HEIGHT, 0.0, 1.0
	)
	var lift: float = BUOYANCY * submerged
	if controller.jump_held(self, delta):
		lift += SWIM_THRUST
	velocity.y += (get_gravity().y + lift) * delta
	velocity.y -= velocity.y * WATER_LINEAR_DRAG * delta
	velocity.y = clampf(velocity.y, -MAX_SWIM_SINK, MAX_SWIM_RISE)


# Mirrors _try_step_up's forward probe: while swimming near the surface and
# pressing jump (held or fresh), probe ahead along the facing direction. If a
# bank wall blocks within WATER_EXIT_PROBE, launch out of the water like a
# jump — no need to be touching the wall.
func _try_water_exit(wants_jump: bool, delta: float) -> bool:
	if not (wants_jump or controller.jump_held(self, delta)):
		return false
	if global_position.y < water_surface_y - BODY_HEIGHT:
		return false
	var facing: Vector3 = global_transform.basis.z
	facing.y = 0.0
	if facing.length() < 0.001:
		return false
	var probe: Vector3 = facing.normalized() * WATER_EXIT_PROBE
	if not test_move(global_transform, probe):
		return false
	velocity.y = JUMP_VELOCITY * 0.85
	return true


# The probe sits at knee height: standing on a dry bank keeps it above the
# water volume, while floating at the surface keeps it inside. The overlapped
# volume's surface_y meta (per-body water level) drives buoyancy.
func _update_in_water() -> void:
	var params := PhysicsPointQueryParameters3D.new()
	params.position = global_position + Vector3(0.0, 0.3, 0.0)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = WATER_LAYER_MASK
	var hits: Array = get_world_3d().direct_space_state.intersect_point(params, 4)
	in_water = not hits.is_empty()
	if in_water:
		var best: float = -INF
		for h in hits:
			var collider: Object = h.get("collider")
			if collider != null and collider.has_meta("surface_y"):
				best = maxf(best, float(collider.get_meta("surface_y")))
		water_surface_y = (best if best > -INF else WATER_SURFACE_Y) + _swell_offset()


# The water surface the buoyancy chases, displaced by the shader's travelling
# swells at the character's position — floating bodies rock in the waves.
func _swell_offset() -> float:
	var p: Vector2 = Vector2(global_position.x, global_position.z)
	var t: float = float(Time.get_ticks_msec()) / 1000.0 * SWELL_SPEED
	var h: float = 1.0 * sin(p.dot(Vector2(0.042, 0.016)) - t * 0.33)
	h += 0.7 * sin(p.dot(Vector2(-0.023, 0.037)) - t * 0.26 + 1.7)
	h += 0.35 * sin(p.dot(Vector2(0.032, -0.076)) - t * 0.36 + 4.0)
	h += 0.5 * sin(p.dot(Vector2(-0.036, -0.014)) - t * 0.31 + 2.6)
	return h * 0.5 * SWELL_HEIGHT


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

func _try_step_up(delta: float) -> bool:
	var step_clearance: float = 0.05
	var step_down_extra: float = 0.1
	var forward_probe_extra: float = 0.45
	var step_height_epsilon: float = 0.01
	var min_step_height: float = 0.005
	var horizontal_motion: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * delta
	var current_tf: Transform3D = global_transform
	var has_motion: bool = horizontal_motion.length() >= 0.001
	var on_floor_now: bool = on_ground
	var moving_down_or_flat: bool = velocity.y <= 0.0
	var probe_motion: Vector3 = horizontal_motion
	if has_motion:
		probe_motion = horizontal_motion + horizontal_motion.normalized() * forward_probe_extra

	var blocked_short: bool = false
	var blocked_long: bool = false
	if on_floor_now and moving_down_or_flat and has_motion:
		blocked_short = test_move(current_tf, horizontal_motion)
		blocked_long = test_move(current_tf, probe_motion)

	var raise_amount: float = MAX_STEP_HEIGHT + step_clearance
	var raised_tf: Transform3D = current_tf.translated(Vector3.UP * raise_amount)
	var can_step: bool = (
		on_floor_now
		and moving_down_or_flat
		and has_motion
		and (blocked_short or blocked_long)
	)
	if not can_step:
		return false

	if test_move(raised_tf, probe_motion):
		return false

	var raised_forward_tf: Transform3D = raised_tf.translated(probe_motion)
	var downward_motion: Vector3 = Vector3.DOWN * (raise_amount + step_down_extra)
	var down_collision: KinematicCollision3D = KinematicCollision3D.new()
	if not test_move(raised_forward_tf, downward_motion, down_collision):
		return false

	var floor_angle: float = down_collision.get_normal().angle_to(Vector3.UP)
	if floor_angle > floor_max_angle:
		return false

	var probe_origin: Vector3 = raised_forward_tf.origin + down_collision.get_travel()
	var new_origin: Vector3 = current_tf.origin + horizontal_motion
	new_origin.y = probe_origin.y
	var climbed_height: float = new_origin.y - current_tf.origin.y
	if climbed_height < min_step_height:
		return false
	if climbed_height <= 0.0 or climbed_height > MAX_STEP_HEIGHT + step_height_epsilon:
		return false

	global_position = new_origin
	velocity.y = 0.0
	apply_floor_snap()
	return true

func _update_step_visual_smoothing(delta: float) -> void:
	var visual_comp_threshold: float = 0.2
	var smooth_speed: float = 8.0
	var body_delta_y: float = global_position.y - prev_body_global_y
	if body_delta_y > visual_comp_threshold:
		step_visual_offset_y -= body_delta_y * 0.35
		step_visual_offset_y = max(step_visual_offset_y, -MAX_STEP_HEIGHT * 0.16)
	prev_body_global_y = global_position.y
	step_visual_offset_y = lerp(step_visual_offset_y, 0.0, clamp(smooth_speed * delta, 0.0, 1.0))
	body_model_root.position = body_model_base_pos + Vector3(0.0, step_visual_offset_y, 0.0)
