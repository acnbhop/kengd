#==================================================================================================
# Copyright Grant Abernathy & Kendalynn Kohler. All rights reserved.
#==================================================================================================
# File:		code/character.gd
# Author: 	Grant Abernathy & Kendalynn Kohler
# Date:		October 17th, 2025
#
# Purpose: 	Main character controller script.
#==================================================================================================

extends CharacterBody3D

## This group controls movement settings.
@export_group("Movement")
## Movement speed of the character.
@export_range(0.0, 20.0, 0.1) var f_movement_speed: float = 5.0
## Movement speed when sprinting.
@export_range(0.0, 20.0, 0.1) var f_sprint_speed: float = 10.0
## Movement speed when crouching
@export_range(0.0, 20.0, 0.1) var f_crouch_speed: float = 2.5
## The force applied when the character jumps.
@export_range(0.0, 20.0, 0.1) var f_jump_force: float = 4.0
## The force applied when the character crouch jumps.
@export_range(0.0, 20.0, 0.1) var f_crouch_jump_force: float = 2.3
## Weight of the player.
@export_range(0.1, 5.0, 0.1) var f_player_weight: float = 1.3

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
## How much to increase fov when sprinting
@export_range(0.0, 20.0, 0.1) var f_sprint_fov_increase: float = 10.0
## How quickly the fov change happens.
@export_range(0.0, 20.0, 0.1) var f_fov_transition_speed: float = 8.0

## This group controls jumping and landing
@export_group("Jump & Land FX")
## How much the FOV increases while in the air.
@export_range(0.0, 20.0, 0.1) var f_jump_fov_boost: float = 5.0
## How much the FOV dips upon landing.
@export_range(-20.0, 0.0, 0.1) var f_land_fov_dip: float = -7.0
## How quickly the jump and land FOV effects happen.
@export_range(0.0, 20.0, 0.1) var f_jump_land_fov_speed: float = 12.0

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

#==================================================================================================
# These variables are not exported and are used internally.
# So update this file if node names change or anything.
#==================================================================================================

## Reference to the head node for camera rotation.
@onready var node_head: Node3D = $head
## Reference to the camera node.
@onready var node_camera: Camera3D = $head/camera
## Reference to the collision shape node.
@onready var node_collision_shape: CollisionShape3D = $collision

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
## Can we sprint
var b_is_sprinting: bool = false
## Stores the default FOV to return to.
var f_default_fov: float

#==================================================================================================
# Godot Built-in Functions
#==================================================================================================

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	f_default_fov = node_camera.fov

func _unhandled_input(event: InputEvent) -> void:
	# Handle mouse cursor locking/unlocking.
	if event.is_action_pressed("pause"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Only process mouse look if the cursor is captured.
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * f_mouse_sensitivity)
		node_head.rotate_x(-event.relative.y * f_mouse_sensitivity)
		node_head.rotation.x = clamp(node_head.rotation.x, deg_to_rad(-90.0), deg_to_rad(90.0))

func _physics_process(delta: float) -> void:
	# Don't process if cursor isn't captured.
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	
	# 01. Get Inputs
	var v2_input_dir: Vector2 = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_backward")
	var v3_movement_direction: Vector3 = (transform.basis * Vector3(v2_input_dir.x, 0, v2_input_dir.y)).normalized()
	
	# 02. Handle Player State (Crouching, Sprinting)
	handle_state(v2_input_dir)
	
	# 03. Handle Movement & Physics
	var f_current_speed = get_current_speed()
	var v3_current_velocity = velocity
	v3_current_velocity = apply_gravity(v3_current_velocity, delta)
	v3_current_velocity = handle_jump(v3_current_velocity)
	v3_current_velocity = handle_horizontal_movement(v3_current_velocity, v3_movement_direction, f_current_speed)
	velocity = v3_current_velocity
	move_and_slide()
	
	# 04. Handle Visuals
	handle_crouch_visuals(delta)
	handle_camera_effects(v2_input_dir, delta)

#==================================================================================================
# State Handling Functions
#==================================================================================================

## Handles the logic for crouching and sprinting states.
func handle_state(v2_input_dir: Vector2):
	var b_wants_to_sprint: bool = Input.is_action_pressed("sprint")
	var b_wants_to_crouch: bool = Input.is_action_pressed("duck")

	# Sprinting state logic
	b_is_sprinting = b_wants_to_sprint and not b_is_crouching and v2_input_dir.y <= 0 and v2_input_dir != Vector2.ZERO
	
	# Crouching state logic
	var is_ceiling_above: bool = (node_ceiling_check_1 and node_ceiling_check_1.is_colliding()) or \
							   (node_ceiling_check_2 and node_ceiling_check_2.is_colliding()) or \
							   (node_ceiling_check_3 and node_ceiling_check_3.is_colliding()) or \
							   (node_ceiling_check_4 and node_ceiling_check_4.is_colliding())
	if b_is_crouching and not b_wants_to_crouch and is_ceiling_above:
		b_wants_to_crouch = true
	b_is_crouching = b_wants_to_crouch

## Determines the current movement speed based on player state.
func get_current_speed() -> float:
	if b_is_sprinting:
		return f_sprint_speed
	elif b_is_crouching:
		return f_crouch_speed
	else:
		return f_movement_speed

#==================================================================================================
# Physics & Movement Functions
#==================================================================================================

## Applies gravity to the character.
func apply_gravity(p_velocity: Vector3, delta: float) -> Vector3:
	if not is_on_floor():
		p_velocity.y -= (f_gravity * f_player_weight) * delta
	return p_velocity

## Handles the jump action.
func handle_jump(p_velocity: Vector3) -> Vector3:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if b_is_crouching:
			p_velocity.y = f_crouch_jump_force
		else:
			p_velocity.y = f_jump_force
	return p_velocity
	
## Handles horizontal character movement.
func handle_horizontal_movement(p_velocity: Vector3, p_direction: Vector3, p_speed: float) -> Vector3:
	if p_direction:
		p_velocity.x = p_direction.x * p_speed
		p_velocity.z = p_direction.z * p_speed
	else:
		p_velocity.x = move_toward(p_velocity.x, 0, p_speed)
		p_velocity.z = move_toward(p_velocity.z, 0, p_speed)
	return p_velocity

#==================================================================================================
# Visual & Camera Functions
#==================================================================================================

## Handles the visual feedback for crouching (camera height, collision shape).
func handle_crouch_visuals(delta: float):
	var target_head_y: float = f_crouch_depth if b_is_crouching else 0.0
	var target_collision_height: float = f_crouching_height if b_is_crouching else f_standing_height
	
	node_head.position.y = lerp(node_head.position.y, target_head_y, delta * f_crouch_transition_speed)
	if node_collision_shape and node_collision_shape.shape:
		node_collision_shape.shape.height = lerp(node_collision_shape.shape.height, target_collision_height, delta * f_crouch_transition_speed)

## Handles camera effects like FOV changes and strafe roll.
func handle_camera_effects(v2_input_dir: Vector2, delta: float):
	# Handle Smooth FOV change for sprinting
	var target_fov = f_default_fov + f_sprint_fov_increase if b_is_sprinting else f_default_fov
	node_camera.fov = lerp(node_camera.fov, target_fov, delta * f_fov_transition_speed)
		
	# Handle the camera roll.
	var current_roll_amount = f_camera_roll_amount if not b_is_crouching else f_camera_roll_amount * f_crouch_roll_multiplier
	var target_roll: float = -v2_input_dir.x * deg_to_rad(current_roll_amount)
	node_camera.rotation.z = lerp(node_camera.rotation.z, target_roll, delta * f_camera_roll_speed)
