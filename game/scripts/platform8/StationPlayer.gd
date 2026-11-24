class_name StationPlayer
extends CharacterBody3D

## First-person walker. WASD / arrows, mouse look, Esc frees the mouse, click captures it.

const SPEED := 4.0
const SENSITIVITY := 0.0025
const GRAVITY := 9.8

var active := true:
	set(v):
		active = v
		velocity = Vector3.ZERO

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func place(at: Transform3D) -> void:
	global_transform = at
	head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	camera.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * SENSITIVITY, -1.4, 1.4)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not active:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var input := Vector2(
		_key(KEY_D, KEY_RIGHT) - _key(KEY_A, KEY_LEFT),
		_key(KEY_S, KEY_DOWN) - _key(KEY_W, KEY_UP)).limit_length(1.0)
	var dir := transform.basis * Vector3(input.x, 0, input.y)
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()

func _key(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0
