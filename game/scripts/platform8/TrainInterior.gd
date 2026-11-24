class_name TrainInterior
extends Node3D

## The coach stays still; tunnel lights scroll past the windows to fake motion.

const TUNNEL_SPEED := 28.0
const LIGHT_SPACING := 5.0
const LIGHT_COUNT := 10

var camera: Camera3D

var _display: Label3D
var _tunnel_lights: Array[Node3D] = []

func _ready() -> void:
	var floor_c := Color(0.3, 0.3, 0.32)
	var wall := Color(0.85, 0.86, 0.88)
	_box(Vector3(3, 0.2, 16), Vector3(0, -0.1, 0), floor_c)
	_box(Vector3(3, 0.2, 16), Vector3(0, 2.5, 0), wall)
	for x in [-1.5, 1.5]:
		_box(Vector3(0.1, 1.0, 16), Vector3(x, 0.5, 0), wall)   # below window
		_box(Vector3(0.1, 0.6, 16), Vector3(x, 2.1, 0), wall)   # above window
		_box(Vector3(0.5, 0.45, 12), Vector3(x * 0.8, 0.22, 0), Color(0.25, 0.35, 0.6))  # bench
		_box(Vector3(0.2, 3.2, 40), Vector3(x * 2.4, 1.2, 0), Color(0.05, 0.05, 0.05))  # tunnel wall
	for z in [-8.0, 8.0]:
		_box(Vector3(3, 2.6, 0.1), Vector3(0, 1.2, z), wall)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.2, 0)
	lamp.omni_range = 9
	lamp.light_energy = 0.9
	add_child(lamp)

	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.85, 0.55)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.8)
	mesh.material = glow
	for i in LIGHT_COUNT:
		for x in [-3.2, 3.2]:
			var m := MeshInstance3D.new()
			m.mesh = mesh
			m.position = Vector3(x, 1.5, -LIGHT_COUNT * LIGHT_SPACING / 2.0 + i * LIGHT_SPACING)
			add_child(m)
			_tunnel_lights.append(m)

	_display = Label3D.new()
	_display.position = Vector3(-1.44, 2.1, 0)
	_display.rotation.y = PI / 2
	_display.font_size = 40
	_display.modulate = Color(1.0, 0.35, 0.2)
	add_child(_display)

	# Seated on the right bench, looking across at the left windows and the display.
	camera = Camera3D.new()
	camera.position = Vector3(1.0, 1.15, 0)
	camera.rotation.y = PI / 2
	add_child(camera)

	visible = false
	set_process(false)

func ride(next_name: String, duration: float) -> void:
	visible = true
	camera.make_current()
	set_process(true)
	var doors := minf(2.5, duration * 0.25)
	_display.text = "DOORS CLOSING"
	await get_tree().create_timer(doors).timeout
	_display.text = "NEXT STATION\n" + next_name.to_upper()
	await get_tree().create_timer(duration - doors).timeout
	set_process(false)
	visible = false

func _process(delta: float) -> void:
	var span := LIGHT_COUNT * LIGHT_SPACING
	for l in _tunnel_lights:
		l.position.z += TUNNEL_SPEED * delta
		if l.position.z > span / 2.0:
			l.position.z -= span

func _box(size: Vector3, pos: Vector3, c: Color) -> void:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	b.material = m
	add_child(b)
