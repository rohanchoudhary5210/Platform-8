class_name StationPlayer
extends CharacterBody3D

## First-person walker. WASD / arrows + mouse look, or a gamepad: left stick walks, right stick looks,
## A uses things. Esc / Start is the pause menu (Game); a click captures the mouse again.

const SPEED := 2.8  # slow on purpose: you have time to look, and to dread
const STRIDE := 0.8  # metres per footstep
const BOB := 0.035
const HEAD_Y := 0.7
const SENSITIVITY := 0.0025
const GRAVITY := 9.8
const STICK_LOOK := 2.6  # rad/s at full right-stick tilt
const DEADZONE := 0.2

var active := true:
	set(v):
		active = v
		velocity = Vector3.ZERO

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var sensitivity_scale := 1.0  # from the save's settings
var tokens := 0  # metro tokens picked up; the AFC gates take one as you pass
var _walked := 0.0
var _step := AudioStreamPlayer.new()
var _look := RayCast3D.new()

func _ready() -> void:
	add_to_group(&"player")
	platform_on_leave = PLATFORM_ON_LEAVE_DO_NOTHING  # stepping off the escalator mustn't fling you
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = 68.0
	_step.stream = SynthAudio.footstep()
	_step.bus = Atmosphere.BUS
	_step.volume_db = -10.0
	add_child(_step)
	_look.target_position = Vector3(0, 0, -1.8)  # arm's reach
	_look.collision_mask = 1 | TokenMachine.TOKEN_LAYER
	camera.add_child(_look)

## What you're looking at that can be used (has interact()), or null.
func interactable() -> Node:
	var n: Node = _look.get_collider() if active else null
	while n and not n.has_method("interact"):
		n = n.get_parent()
	return n

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
	elif (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		var thing := interactable()
		if thing:
			thing.interact(self)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not active:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var look := _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y) * STICK_LOOK * sensitivity_scale * delta
	rotate_y(-look.x)
	head.rotation.x = clampf(head.rotation.x - look.y, -1.4, 1.4)
	var input := (Vector2(
		_key(KEY_D, KEY_RIGHT) - _key(KEY_A, KEY_LEFT),
		_key(KEY_S, KEY_DOWN) - _key(KEY_W, KEY_UP)) + _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)).limit_length(1.0)
	var dir := transform.basis * Vector3(input.x, 0, input.y)
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()
	_bob_and_step(Vector2(velocity.x, velocity.z).length() * delta)

## First connected gamepad's stick, zero inside the deadzone.
func _stick(x: JoyAxis, y: JoyAxis) -> Vector2:
	var v := Vector2(Input.get_joy_axis(0, x), Input.get_joy_axis(0, y))
	return Vector2.ZERO if v.length() < DEADZONE else v

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
