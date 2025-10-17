# Copyright Grant Abernathy & Kendalynn Kohler. All rights reserved.

extends CharacterBody3D

@export_group("Movement")
# Movement speed of the character.
@export_range(0.0, 20.0, 0.1) var MovementSpeed: float = 5.0
# The force applied when the character jumps.
@export_range(0.0, 20.0, 0.1) var JumpForce: float = 4.0
# Movement speed when crouching
@export_range(0.0, 20.0, 0.1) var CrouchSpeed: float = 2.5

@export_group("Camera")
# The sensitivity of the mouse for looking around.
@export_range(0.001, 0.01, 0.0001) var MouseSensitivity: float = 0.002

@export_group("Crouching")
# Vertical position of head node when crouching.
@export var CrouchDepth: float = -0.5
# How quickly the transition happens.
@export var CrouchTransitionSpeed: float = 10.0
# Height of collision shape when standing.
@export var StandingHeight: float = 2.0
# Height of collision shape when crouching.
@export var CrouchingHeight: float = 1.2

# Reference to the head node for camera rotation.
@onready var HeadNode: Node3D = $Head
# Reference to the camera node.
@onready var CameraNode: Camera3D = $Head/Camera

# Gravity value from project settings.
var Gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

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
    var CurrentVelocity: Vector3 = velocity

    # Apply gravity
    if not is_on_floor():
        CurrentVelocity.y -= Gravity * delta
    
    # Handle jumping
    if Input.is_action_just_pressed("Jump") and is_on_floor():
        CurrentVelocity.y = JumpForce

    # Handle movement input 
    var InputDirection: Vector2 = Input.get_vector("StrafeLeft", "StrafeRight", "MoveForward", "MoveBackward")
    # Convert input direction to 3D movement direction
    var MovementDirection: Vector3 = (transform.basis * Vector3(InputDirection.x, 0, InputDirection.y)).normalized()

    # Handle horizontal movement
    if MovementDirection:
        CurrentVelocity.x = MovementDirection.x * MovementSpeed
        CurrentVelocity.z = MovementDirection.z * MovementSpeed
    else:
        CurrentVelocity.x = move_toward(CurrentVelocity.x, 0, MovementSpeed)
        CurrentVelocity.z = move_toward(CurrentVelocity.z, 0, MovementSpeed)
    
    # Apply the calculated velocity
    velocity = CurrentVelocity
    # Call the move_and_slide function to move the character
    move_and_slide()