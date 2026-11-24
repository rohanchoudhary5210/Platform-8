class_name StationPlayer
extends CharacterBody3D

## First-person walker. WASD / arrows, mouse look, Esc frees the mouse, click captures it.

const SPEED := 2.8  # slow on purpose: you have time to look, and to dread
const STRIDE := 0.8  # metres per footstep
const BOB := 0.035
const HEAD_Y := 0.7
const SENSITIVITY := 0.0025
const GRAVITY := 9.8

var active := true:
	set(v):
		active = v
		velocity = Vector3.ZERO

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var sensitivity_scale := 1.0  # from the save's settings
var _walked := 0.0
var _step := AudioStreamPlayer.new()

func _ready() -> void:
	add_to_group(&"player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = 68.0
	_step.stream = SynthAudio.footstep()
	_step.bus = Atmosphere.BUS
	_step.volume_db = -10.0
	add_child(_step)

func place(at: Transform3D) -> void:
	global_transform = at
	head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	camera.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENSITIVITY * sensitivity_scale)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * SENSITIVITY * sensitivity_scale, -1.4, 1.4)
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
	_bob_and_step(Vector2(velocity.x, velocity.z).length() * delta)

func _key(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0

func _bob_and_step(moved: float) -> void:
	if moved <= 0.0 or not is_on_floor():
		return
	var before := int(_walked / STRIDE)
	_walked += moved
	head.position.y = HEAD_Y + sin(_walked / STRIDE * PI) * BOB
	if int(_walked / STRIDE) != before:
		_step.pitch_scale = randf_range(0.85, 1.1)
		_step.play()
