# Copyright Grant Abernathy & Kendalynn Kohler. All rights reserved.

extends CharacterBody3D

@export var MovementSpeed: float = 5.0
@export var JumpForce: float = 7.0
@export var MouseSensitivity: float = 0.002

@onready var HeadNode: Node3D = $Head
@onready var CameraNode: Camera3D = $Head/Camera

var Gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        rotate_y(-event.relative.x * MouseSensitivity)
        HeadNode.rotate_x(-event.relative.y * MouseSensitivity)
        HeadNode.rotation.x = clamp(HeadNode.rotation.x, deg_to_rad(-90.0), deg_to_rad(90.0))

func _physics_process(delta: float) -> void:
    var CurrentVelocity: Vector3 = velocity

    if not is_on_floor():
        CurrentVelocity.y -= Gravity * delta
    
    if Input.is_action_just_pressed("Jump") and is_on_floor():
        CurrentVelocity.y = JumpForce

    var InputDirection: Vector2 = Input.get_vector("StrafeLeft", "StrafeRight", "MoveForward", "MoveBackward")
    var MovementDirection: Vector3 = (transform.basis * Vector3(InputDirection.x, 0, InputDirection.y)).normalized()

    if MovementDirection:
        CurrentVelocity.x = MovementDirection.x * MovementSpeed
        CurrentVelocity.z = MovementDirection.z * MovementSpeed
    else:
        CurrentVelocity.x = move_toward(CurrentVelocity.x, 0, MovementSpeed)
        CurrentVelocity.z = move_toward(CurrentVelocity.z, 0, MovementSpeed)
    
    velocity = CurrentVelocity
    move_and_slide()