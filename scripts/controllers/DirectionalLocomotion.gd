class_name DirectionalLocomotion
extends RefCounted
## One normalized gait cycle, aligned by the measured left/right foot-height
## signal. Offsets are NORMALIZED timeline seconds (see docs/qa/2026-09-10-tactical).
const WALK_OFFSET := 0.166666667
const BACKWARD_OFFSET := 0.75
# Median planted-foot displacement per cycle, measured on the actual model.
const RUN_STRIDE := 2.10
const STRAFE_STRIDE := 2.33
const BACKWARD_STRIDE := 0.80
const WALK_STRIDE := 0.75
const RUN_CADENCE := 2.0

static func install(tree: AnimationTree, player: AnimationPlayer) -> void:
	# Source resources are nonlooping. Loop-wrap interpolation must be enabled
	# on private copies, otherwise the last keys clamp despite node loop mode.
	var library := player.get_animation_library("CharacterAnimationLibrary").duplicate() as AnimationLibrary
	for name in ["Idle_A", "Walking_A", "Running_A", "Walking_Backwards", "Running_Strafe_Left", "Running_Strafe_Right"]:
		var animation := library.get_animation(name).duplicate() as Animation
		animation.loop_mode = Animation.LOOP_LINEAR
		library.remove_animation(name)
		library.add_animation(name, animation)
	player.remove_animation_library("CharacterAnimationLibrary")
	player.add_animation_library("CharacterAnimationLibrary", library)
	# The editor-visible graph owns source phases and the airborne state machine.
	tree.tree_root = tree.tree_root.duplicate(true)

static func blend_direction(world_velocity: Vector3, facing_basis: Basis, forward_stride: float = RUN_STRIDE) -> Vector2:
	var local := facing_basis.inverse() * world_velocity
	# Models face +Z; their right hand is -X. Weight by each clip's stride,
	# so diagonals blend to the requested travel vector without sideways slip.
	var direction := Vector2(-local.x / STRAFE_STRIDE,
		-local.z / (forward_stride if local.z >= 0.0 else BACKWARD_STRIDE))
	var sum := absf(direction.x) + absf(direction.y)
	return direction / sum if sum > 0.0001 else Vector2.ZERO

static func stride_length(world_direction: Vector3, facing_basis: Basis, forward_stride: float = RUN_STRIDE) -> float:
	var local := facing_basis.inverse() * world_direction.normalized()
	var reciprocal := absf(local.x) / STRAFE_STRIDE 		+ absf(local.z) / (forward_stride if local.z >= 0.0 else BACKWARD_STRIDE)
	return 1.0 / reciprocal if reciprocal > 0.0001 else RUN_STRIDE
