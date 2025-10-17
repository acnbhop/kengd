# Copyright Grant Abernathy & Kendalynn Kohler. All rights reserved.

extends CharacterBody3D

## This group controls movement settings.
@export_group("Movement")
## Movement speed of the character.
@export_range(0.0, 20.0, 0.1) var MovementSpeed: float = 5.0
## The force applied when the character jumps.
@export_range(0.0, 20.0, 0.1) var JumpForce: float = 4.0
## Movement speed when crouching
@export_range(0.0, 20.0, 0.1) var CrouchSpeed: float = 2.5

## This group controls the camera settings.
@export_group("Camera")
## The sensitivity of the mouse for looking around.
@export_range(0.001, 0.01, 0.0001) var MouseSensitivity: float = 0.002
## Amount of camera roll when strafing.
@export_range(0.0, 10.0, 0.1) var CameraRollAmount: float = 5.0
## How quickly the camera roll happens.
@export_range(0.0, 20.0, 0.1) var CameraRollSpeed: float = 10.0

## This group controls crouching settings.
@export_group("Crouching")
## Vertical position of head node when crouching.
@export var CrouchDepth: float = -0.5
## How quickly the transition happens.
@export var CrouchTransitionSpeed: float = 10.0
## Height of collision shape when standing.
@export var StandingHeight: float = 2.0
## Height of collision shape when crouching.
@export var CrouchingHeight: float = 1.2

#
# These variables are not exported and are used internally.
#
# So update this file if node names change or anything.
#

## Reference to the head node for camera rotation.
@onready var HeadNode: Node3D = $Head
## Reference to the camera node.
@onready var CameraNode: Camera3D = $Head/Camera
## Reference to the collision shape node.
@onready var CollisionShapeNode: CollisionShape3D = $CharacterCollision
# References to ceiling raycasts for crouch checks.

## CeilingCheck1 - First raycast for ceiling detection.
@onready var CeilingCheck1: RayCast3D = $CeilingCheck1
## CeilingCheck2 - Second raycast for ceiling detection.
@onready var CeilingCheck2: RayCast3D = $CeilingCheck2
## CeilingCheck3 - Third raycast for ceiling detection.
@onready var CeilingCheck3: RayCast3D = $CeilingCheck3
## CeilingCheck4 - Fourth raycast for ceiling detection.
@onready var CeilingCheck4: RayCast3D = $CeilingCheck4

# Gravity value from project settings.
var Gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
# Whether the character is currently crouching.
var IsCrouching: bool = false

# Lock cursor to the center of the screen on ready.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Handle mouse movement for looking around.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Rotate character and head based on mouse movement
		rotate_y(-event.relative.x * MouseSensitivity)
		# Rotate head based on mouse movement
		HeadNode.rotate_x(-event.relative.y * MouseSensitivity)
		# Clamp head rotation to prevent flipping
		HeadNode.rotation.x = clamp(HeadNode.rotation.x, deg_to_rad(-90.0), deg_to_rad(90.0))

# Process physics / movement and everything.
func _physics_process(delta: float) -> void:
	## CurrentVelocity - Variable to hold the current velocity during calculations.
	var CurrentVelocity: Vector3 = velocity

	# Apply gravity
	if not is_on_floor():
		CurrentVelocity.y -= Gravity * delta
	
	# Handle jumping
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		CurrentVelocity.y = JumpForce

	## WantsToCrouch - Boolean indicating if the player wants to crouch.
	var WantsToCrouch: bool = Input.is_action_pressed("Duck")

	# Boolean to check if any of the ceiling raycasts are colliding.
	var IsCeilingAbove: bool = (CeilingCheck1 and CeilingCheck1.is_colliding()) or \
		(CeilingCheck2 and CeilingCheck2.is_colliding()) or \
		(CeilingCheck3 and CeilingCheck3.is_colliding()) or \
		(CeilingCheck4 and CeilingCheck4.is_colliding())

	# Prevent standing up if there's a ceiling above
	if IsCrouching and not WantsToCrouch and IsCeilingAbove:
		WantsToCrouch = true
	
	IsCrouching = WantsToCrouch

	# Determine target heights and speed based on the crouch state

	## TargetHeadY - Vertical position of the head node.
	var TargetHeadY: float = CrouchDepth if IsCrouching else 0.0
	## TargetCollisionHeight - Height of the collision shape.
	var TargetCollisionHeight: float = CrouchingHeight if IsCrouching else StandingHeight
	## CurrentSpeed - Movement speed based on crouch state.
	var CurrentSpeed: float = CrouchSpeed if IsCrouching else MovementSpeed

	# Smoothly interpolate head position
	HeadNode.position.y = lerp(HeadNode.position.y, TargetHeadY, delta * CrouchTransitionSpeed)
	CollisionShapeNode.shape.height = lerp(CollisionShapeNode.shape.height, TargetCollisionHeight, delta * CrouchTransitionSpeed)

	# Handle movement input 
	# We get a 2D vector from input actions and convert it to a 3D movement direction.
	# which is the MovementDirection variable respectively.

	## InputDirection - 2D vector representing input direction.
	var InputDirection: Vector2 = Input.get_vector("StrafeLeft", "StrafeRight", "MoveForward", "MoveBackward")
	## MovementDirection - 3D vector representing movement direction.
	var MovementDirection: Vector3 = (transform.basis * Vector3(InputDirection.x, 0, InputDirection.y)).normalized()

	# Handle horizontal movement
	if MovementDirection:
		CurrentVelocity.x = MovementDirection.x * CurrentSpeed
		CurrentVelocity.z = MovementDirection.z * CurrentSpeed
	else:
		CurrentVelocity.x = move_toward(CurrentVelocity.x, 0, CurrentSpeed)
		CurrentVelocity.z = move_toward(CurrentVelocity.z, 0, CurrentSpeed)
	
	# Apply the calculated velocity
	velocity = CurrentVelocity
	# Call the move_and_slide function to move the character
	move_and_slide()
