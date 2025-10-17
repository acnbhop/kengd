# Copyright Grant Abernathy & Kendalynn Kohler. All rights reserved.

extends CharacterBody3D

## This group controls movement settings.
@export_group("Movement")
## Movement speed of the character.
@export_range(0.0, 20.0, 0.1) var f_movement_speed: float = 5.0
## The force applied when the character jumps.
@export_range(0.0, 20.0, 0.1) var f_jump_force: float = 4.0
## Movement speed when crouching
@export_range(0.0, 20.0, 0.1) var f_crouch_speed: float = 2.5

## This group controls the camera settings.
@export_group("Camera")
## The sensitivity of the mouse for looking around.
@export_range(0.001, 0.01, 0.0001) var f_mouse_sensitivity: float = 0.002
## Amount of camera roll when strafing.
@export_range(0.0, 10.0, 0.1) var f_camera_roll_amount: float = 5.0
## How quickly the camera roll happens.
@export_range(0.0, 20.0, 0.1) var f_camera_roll_speed: float = 10.0
## How much to reduce the roll amount when crouching.
##
## 0 = no roll
## 1 = full roll
@export_range(0.0, 1.0, 0.01) var f_crouch_roll_multiplier: float = 0.5

## This group controls crouching settings.
@export_group("Crouching")
## Vertical position of head node when crouching.
@export var f_crouch_depth: float = -0.5
## How quickly the transition happens.
@export var f_crouch_transition_speed: float = 10.0
## Height of collision shape when standing.
@export var f_standing_height: float = 2.0
## Height of collision shape when crouching.
@export var f_crouching_height: float = 1.2

#
# These variables are not exported and are used internally.
#
# So update this file if node names change or anything.
#

## Reference to the head node for camera rotation.
@onready var node_head: Node3D = $head
## Reference to the camera node.
@onready var node_camera: Camera3D = $head/camera
## Reference to the collision shape node.
@onready var node_collision_shape: CollisionShape3D = $character/collision

# References to ceiling raycasts for crouch checks.

## node_ceiling_check_1 - First raycast for ceiling detection.
@onready var node_ceiling_check_1: RayCast3D = $ccheck1
## node_ceiling_check_2 - Second raycast for ceiling detection.
@onready var node_ceiling_check_2: RayCast3D = $ccheck2
## node_ceiling_check_3 - Third raycast for ceiling detection.
@onready var node_ceiling_check_3: RayCast3D = $ccheck3
## node_ceiling_check_4 - Fourth raycast for ceiling detection.
@onready var node_ceiling_check_4: RayCast3D = $ccheck4

# Gravity value from project settings.
var f_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
# Whether the character is currently crouching.
var b_is_crouching: bool = false

# Lock cursor to the center of the screen on ready.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Handle mouse movement for looking around.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Rotate character and head based on mouse movement
		rotate_y(-event.relative.x * f_mouse_sensitivity)
		# Rotate head based on mouse movement
		node_head.rotate_x(-event.relative.y * f_mouse_sensitivity)
		# Clamp head rotation to prevent flipping
		node_head.rotation.x = clamp(node_head.rotation.x, deg_to_rad(-90.0), deg_to_rad(90.0))

# Process physics / movement and everything.
func _physics_process(delta: float) -> void:
	## v3_current_velocity - Variable to hold the current velocity during calculations.
	var v3_current_velocity: Vector3 = velocity

	# Apply gravity
	if not is_on_floor():
		v3_current_velocity.y -= f_gravity * delta

	# Handle jumping
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		v3_current_velocity.y = f_jump_force

	## b_wants_to_crouch - Boolean indicating if the player wants to crouch.
	var b_wants_to_crouch: bool = Input.is_action_pressed("Duck")

	# Boolean to check if any of the ceiling raycasts are colliding.
	var IsCeilingAbove: bool = (node_ceiling_check_1 and node_ceiling_check_1.is_colliding()) or \
		(node_ceiling_check_2 and node_ceiling_check_2.is_colliding()) or \
		(node_ceiling_check_3 and node_ceiling_check_3.is_colliding()) or \
		(node_ceiling_check_4 and node_ceiling_check_4.is_colliding())

	# Prevent standing up if there's a ceiling above
	if b_is_crouching and not b_wants_to_crouch and IsCeilingAbove:
		b_wants_to_crouch = true

	b_is_crouching = b_wants_to_crouch

	# Determine target heights and speed based on the crouch state

	## f_target_head_y - Vertical position of the head node.
	var f_target_head_y: float = f_crouch_depth if b_is_crouching else 0.0

	## f_target_collision_height - Height of the collision shape.
	var f_target_collision_height: float = f_crouching_height if b_is_crouching else f_standing_height

	## f_current_speed - Movement speed based on crouch state.
	var f_current_speed: float = f_crouch_speed if b_is_crouching else f_movement_speed

	# Smoothly interpolate head position
	node_head.position.y = lerp(node_head.position.y, f_target_head_y, delta * f_crouch_transition_speed)
	node_collision_shape.shape.height = lerp(node_collision_shape.shape.height, f_target_collision_height, delta * f_crouch_transition_speed)

	# Handle movement input 
	# We get a 2D vector from input actions and convert it to a 3D movement direction.
	# which is the v3_movement_direction variable respectively.

	## v2_input_dir - 2D vector representing input direction.
	var v2_input_dir: Vector2 = Input.get_vector("StrafeLeft", "StrafeRight", "MoveForward", "MoveBackward")

	## v3_movement_direction - 3D vector representing movement direction.
	var v3_movement_direction: Vector3 = (transform.basis * Vector3(v2_input_dir.x, 0, v2_input_dir.y)).normalized()

	# Handle the camera roll.

	## f_target_roll - Target roll angle based on strafing input.
	var f_target_roll: float = -v2_input_dir.x * deg_to_rad(f_camera_roll_amount)

	node_camera.rotation.z = lerp(node_camera.rotation.z, f_target_roll, delta * f_camera_roll_speed)

	# Handle horizontal movement
	if v3_movement_direction:
		v3_current_velocity.x = v3_movement_direction.x * f_current_speed
		v3_current_velocity.z = v3_movement_direction.z * f_current_speed
	else:
		v3_current_velocity.x = move_toward(v3_current_velocity.x, 0, f_current_speed)
		v3_current_velocity.z = move_toward(v3_current_velocity.z, 0, f_current_speed)

	# Apply the calculated velocity
	velocity = v3_current_velocity
	# Call the move_and_slide function to move the character
	move_and_slide()
